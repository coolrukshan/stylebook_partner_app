import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sb_api/sb_api.dart';

void main() {
  test('adds X-Salon-Id header when salonId is available', () async {
    String? currentSalonId = 'salon-abc';
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    dio.interceptors.add(SalonHeaderInterceptor(salonIdProvider: () => currentSalonId));

    String? capturedHeader;
    dio.httpClientAdapter = _MockHttpAdapter((options) async {
      capturedHeader = options.headers['X-Salon-Id'] as String?;
      return ResponseBody.fromString(
        '{"ok":true}',
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    });

    await dio.get<Map<String, dynamic>>('/v1/partner/bookings');
    expect(capturedHeader, equals('salon-abc'));

    currentSalonId = null;
    await dio.get<Map<String, dynamic>>('/v1/partner/bookings');
    expect(capturedHeader, isNull);
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
