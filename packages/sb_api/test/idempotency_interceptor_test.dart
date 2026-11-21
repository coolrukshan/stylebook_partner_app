import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sb_api/sb_api.dart';

void main() {
  late Dio dio;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    dio.interceptors.add(IdempotencyInterceptor());
  });

  test('adds Idempotency-Key header to POST requests on partner routes', () async {
    String? capturedKey;
    dio.httpClientAdapter = _MockHttpAdapter((options) async {
      capturedKey = options.headers['Idempotency-Key'] as String?;
      return ResponseBody.fromString(
        '{"ok":true}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });

    await dio.post<Map<String, dynamic>>('/v1/partner/bookings/1/accept');
    expect(capturedKey, isNotNull);
    expect(capturedKey!.length, greaterThan(10));
  });

  test('preserves existing Idempotency-Key if provided', () async {
    String? capturedKey;
    dio.httpClientAdapter = _MockHttpAdapter((options) async {
      capturedKey = options.headers['Idempotency-Key'] as String?;
      return ResponseBody.fromString(
        '{"ok":true}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });

    await dio.post<Map<String, dynamic>>(
      '/v1/partner/bookings/1/accept',
      options: Options(headers: {'Idempotency-Key': 'custom-key-123'}),
    );
    expect(capturedKey, equals('custom-key-123'));
  });

  test('does not add Idempotency-Key to GET requests', () async {
    String? capturedKey;
    dio.httpClientAdapter = _MockHttpAdapter((options) async {
      capturedKey = options.headers['Idempotency-Key'] as String?;
      return ResponseBody.fromString(
        '{"ok":true}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });

    await dio.get<Map<String, dynamic>>('/v1/partner/bookings');
    expect(capturedKey, isNull);
  });

  test('does not add Idempotency-Key to partner auth endpoints', () async {
    final seen = <String, Object?>{};
    dio.httpClientAdapter = _MockHttpAdapter((options) async {
      seen[options.path] = options.headers['Idempotency-Key'];
      return ResponseBody.fromString(
        '{"ok":true}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });

    await dio.post<dynamic>('/v1/partner/auth/login', data: {'username': 'a', 'password': 'b'});
    await dio.post<dynamic>('/v1/partner/auth/otp/send');
    await dio.post<dynamic>('/v1/partner/auth/otp/verify', data: {'otp': '123456'});
    await dio.post<dynamic>('/v1/partner/auth/password/change', data: {});
    expect(seen.values, everyElement(isNull));
    expect(seen.length, 4);
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
