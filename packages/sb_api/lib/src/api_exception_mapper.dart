import 'package:dio/dio.dart';
import 'package:sb_core/sb_core.dart';

/// Interceptor that attaches the domain [ApiError] to [DioException.error].
class ApiExceptionMapper extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final apiError = ApiError.fromDio(err);
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: apiError,
        message: apiError.message,
      ),
    );
  }
}

/// Helper to execute API calls and throw unwrapped [ApiError] on failure.
Future<T> wrapApiCall<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (e) {
    if (e.error is ApiError) {
      throw e.error as ApiError;
    }
    throw ApiError.fromDio(e);
  }
}
