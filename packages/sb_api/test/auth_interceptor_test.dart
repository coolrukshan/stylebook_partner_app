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
  String? sessionExpiredCode;
  var refreshCount = 0;

  setUp(() {
    tokenStorage = InMemoryTokenStorage();
    sessionExpiredCalled = false;
    sessionExpiredCode = null;
    refreshCount = 0;

    authDio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'));

    final authInterceptor = AuthInterceptor(
      tokenStorage: tokenStorage,
      authDio: authDio,
      onSessionExpired: (code) {
        sessionExpiredCalled = true;
        sessionExpiredCode = code;
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

  ResponseBody json(String body, int status) => ResponseBody.fromString(
        body,
        status,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );

  test('does not attach Bearer to the public partner login and never refreshes on its 401', () async {
    await tokenStorage.saveTokens(accessToken: 'stale', refreshToken: 'stale-refresh');
    authDio.httpClientAdapter = _MockHttpAdapter((options) async {
      refreshCount++;
      return json('{}', 200);
    });
    dio.httpClientAdapter = _MockHttpAdapter((options) async {
      expect(options.headers['Authorization'], isNull);
      return json('{"code":"INVALID_CREDENTIALS","message":"x","field":null}', 401);
    });

    await expectLater(
      dio.post<dynamic>('/v1/partner/auth/login', data: {'username': 'a', 'password': 'b'}),
      throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'status', 401)),
    );
    expect(refreshCount, equals(0));
    expect(sessionExpiredCalled, isFalse);
    expect(await tokenStorage.getAccessToken(), equals('stale'));
  });

  test('attaches Bearer to partner otp endpoints', () async {
    await tokenStorage.saveTokens(accessToken: 'limited-token', refreshToken: 'r');
    dio.httpClientAdapter = _MockHttpAdapter((options) async {
      expect(options.headers['Authorization'], equals('Bearer limited-token'));
      return json('{}', 200);
    });
    final res = await dio.post<dynamic>('/v1/partner/auth/otp/send');
    expect(res.statusCode, equals(200));
  });

  test('a network failure during refresh keeps the tokens and does not sign out', () async {
    await tokenStorage.saveTokens(accessToken: 'expired', refreshToken: 'good-refresh');
    authDio.httpClientAdapter = _MockHttpAdapter((options) async {
      throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
    });
    dio.httpClientAdapter = _MockHttpAdapter((options) async => json('{}', 401));

    await expectLater(dio.get<dynamic>('/v1/partner/today'), throwsA(isA<DioException>()));
    expect(sessionExpiredCalled, isFalse);
    expect(await tokenStorage.getRefreshToken(), equals('good-refresh'));
  });

  test('refresh rejection passes the API code to onSessionExpired', () async {
    await tokenStorage.saveTokens(accessToken: 'expired', refreshToken: 'revoked');
    authDio.httpClientAdapter = _MockHttpAdapter(
      (options) async => json('{"code":"TOKEN_REVOKED","message":"x","field":null}', 401),
    );
    dio.httpClientAdapter = _MockHttpAdapter((options) async => json('{}', 401));

    await expectLater(dio.get<dynamic>('/v1/partner/today'), throwsA(isA<DioException>()));
    expect(sessionExpiredCode, equals('TOKEN_REVOKED'));
    expect(await tokenStorage.getAccessToken(), isNull);
  });

  test('error of the retried request after refresh is surfaced, not the original 401', () async {
    await tokenStorage.saveTokens(accessToken: 'expired', refreshToken: 'ok');
    authDio.httpClientAdapter = _MockHttpAdapter((options) async {
      if (options.path.contains('/v1/auth/refresh')) {
        return json('{"access_token":"n","refresh_token":"nr"}', 200);
      }
      return json('{"code":"OTP_REQUIRED","message":"x","field":null}', 403);
    });
    dio.httpClientAdapter = _MockHttpAdapter((options) async => json('{}', 401));

    await expectLater(
      dio.get<dynamic>('/v1/partner/today'),
      throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'status', 403)),
    );
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
