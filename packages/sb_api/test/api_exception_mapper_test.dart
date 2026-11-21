import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sb_api/sb_api.dart';
import 'package:sb_core/sb_core.dart';

void main() {
  test('maps DioException to ApiError via interceptor and wrapApiCall', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    dio.interceptors.add(ApiExceptionMapper());

    dio.httpClientAdapter = _MockHttpAdapter((options) async {
      return ResponseBody.fromString(
        '{"message":"Not Found","code":"NOT_FOUND"}',
        404,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    });

    try {
      await dio.get<Map<String, dynamic>>('/v1/me');
      fail('Should have thrown');
    } on DioException catch (e) {
      expect(e.error, isA<ApiError>());
      final apiError = e.error as ApiError;
      expect(apiError.code, equals('NOT_FOUND'));
    }

    expect(
      () => wrapApiCall(() => dio.get<Map<String, dynamic>>('/v1/me')),
      throwsA(isA<ApiError>().having((e) => e.code, 'code', 'NOT_FOUND')),
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
