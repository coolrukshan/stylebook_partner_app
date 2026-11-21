import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sb_api/sb_api.dart';
import 'package:sb_core/sb_core.dart';

void main() {
  late InMemoryTokenStorage tokenStorage;
  late Dio dio;
  late Dio authDio;
  var sessionExpiredCalled = false;
  var refreshCount = 0;

  setUp(() {
    tokenStorage = InMemoryTokenStorage();
    sessionExpiredCalled = false;
    refreshCount = 0;

    authDio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'));

    final authInterceptor = AuthInterceptor(
      tokenStorage: tokenStorage,
      authDio: authDio,
      onSessionExpired: () {
        sessionExpiredCalled = true;
      },
    );

    dio.interceptors.add(authInterceptor);
  });

  test('attaches Authorization header for non-auth requests when token exists', () async {
    await tokenStorage.saveTokens(accessToken: 'initial-access', refreshToken: 'initial-refresh');

    dio.httpClientAdapter = _MockHttpAdapter((options) async {
      expect(options.headers['Authorization'], equals('Bearer initial-access'));
      return ResponseBody.fromString(
        '{"ok":true}',
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    });

    final res = await dio.get<Map<String, dynamic>>('/v1/me');
    expect(res.statusCode, equals(200));
  });

  test('does not attach Authorization header to /v1/auth/* requests', () async {
    await tokenStorage.saveTokens(accessToken: 'initial-access', refreshToken: 'initial-refresh');

    dio.httpClientAdapter = _MockHttpAdapter((options) async {
      expect(options.headers['Authorization'], isNull);
      return ResponseBody.fromString(
        '{"ok":true}',
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    });

    final res = await dio.post<Map<String, dynamic>>('/v1/auth/otp/send');
    expect(res.statusCode, equals(200));
  });

  test('on 401 performs single refresh for concurrent calls and retries', () async {
    await tokenStorage.saveTokens(accessToken: 'expired-access', refreshToken: 'valid-refresh');

    authDio.httpClientAdapter = _MockHttpAdapter((options) async {
      if (options.path.contains('/v1/auth/refresh')) {
        refreshCount++;
        return ResponseBody.fromString(
          '{"access_token":"new-access","refresh_token":"new-refresh","token_type":"bearer","expires_in":900}',
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      }
      final auth = options.headers['Authorization'];
      if (auth == 'Bearer new-access') {
        return ResponseBody.fromString(
          '{"id":"user-1"}',
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      }
      return ResponseBody.fromString(
        '{"error":"Unauthorized"}',
        401,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    });

    dio.httpClientAdapter = _MockHttpAdapter((options) async {
      final auth = options.headers['Authorization'];
      if (auth == 'Bearer expired-access') {
        return ResponseBody.fromString(
          '{"error":"Unauthorized"}',
          401,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      }
      return ResponseBody.fromString(
        '{"error":"Unauthorized"}',
        401,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    });

    // Fire 3 concurrent calls
    final futures = [
      dio.get<Map<String, dynamic>>('/v1/me'),
      dio.get<Map<String, dynamic>>('/v1/partner/settings'),
      dio.get<Map<String, dynamic>>('/v1/me'),
    ];

    final responses = await Future.wait(futures);
    expect(responses.length, equals(3));
    for (final r in responses) {
      expect(r.statusCode, equals(200));
    }

    // Single-flight refresh was executed only once!
    expect(refreshCount, equals(1));
    expect(await tokenStorage.getAccessToken(), equals('new-access'));
    expect(await tokenStorage.getRefreshToken(), equals('new-refresh'));
    expect(sessionExpiredCalled, isFalse);
  });

  test('refresh 401 triggers onSessionExpired and clears tokens', () async {
    await tokenStorage.saveTokens(accessToken: 'expired-access', refreshToken: 'dead-refresh');

    authDio.httpClientAdapter = _MockHttpAdapter((options) async {
      return ResponseBody.fromString(
        '{"error":"Invalid refresh token"}',
        401,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    });

    dio.httpClientAdapter = _MockHttpAdapter((options) async {
      return ResponseBody.fromString(
        '{"error":"Unauthorized"}',
        401,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    });

    try {
      await dio.get<Map<String, dynamic>>('/v1/me');
    } catch (_) {}

    expect(sessionExpiredCalled, isTrue);
    expect(await tokenStorage.getAccessToken(), isNull);
    expect(await tokenStorage.getRefreshToken(), isNull);
  });
}

class _MockHttpAdapter implements HttpClientAdapter {
  _MockHttpAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}
