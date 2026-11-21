import 'dart:async';
import 'package:dio/dio.dart';

/// Handles 403 `OTP_REQUIRED` on any call: parks the request, asks the app to run step-up
/// (via [onOtpRequired]) and retries the call ONCE with the new token on success.
///
/// - One step-up is shared by all parked calls.
/// - A call that already was retried is never retried again (no loop).
/// - The OTP endpoints and login are never intercepted (a parked verify call would deadlock).
/// - On cancel the original error is returned unchanged.
class OtpRequiredInterceptor extends Interceptor {
  OtpRequiredInterceptor({required this.dio, required this.onOtpRequired});

  final Dio dio;

  /// Returns true when step-up succeeded and the session now holds a full token pair.
  final Future<bool> Function() onOtpRequired;

  static const _retriedKey = 'sb_otp_retried';
  static const _generationKey = 'sb_otp_generation';
  static const _code = 'OTP_REQUIRED';

  Future<bool>? _stepUp;

  /// Counts successful step-ups. A call sent before the latest step-up that fails afterwards
  /// with OTP_REQUIRED is simply retried with the new token; it must not prompt again.
  int _generation = 0;

  static bool _skip(String path) =>
      path.contains('/v1/partner/auth/otp/') || path.contains('/v1/partner/auth/login') || path.contains('/v1/auth/');

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_generationKey] = _generation;
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final body = err.response?.data;
    final isOtpRequired =
        err.response?.statusCode == 403 && body is Map && body['code'] == _code && !_skip(options.path);

    if (!isOtpRequired || options.extra[_retriedKey] == true) {
      return handler.next(err);
    }

    final sentAt = options.extra[_generationKey] as int? ?? _generation;
    if (sentAt == _generation) {
      final bool verified;
      try {
        verified = await (_stepUp ??= _runStepUp());
      } catch (_) {
        return handler.next(err);
      }
      if (!verified) {
        return handler.next(err);
      }
    }

    options.extra[_retriedKey] = true;
    try {
      // Goes through the auth interceptor again, so the CURRENT (new) token is attached.
      final response = await dio.fetch<dynamic>(options);
      return handler.resolve(response);
    } on DioException catch (retryError) {
      // Already mapped by the interceptors of the retry; do not run later interceptors twice.
      return handler.reject(retryError);
    }
  }

  Future<bool> _runStepUp() async {
    try {
      final verified = await onOtpRequired();
      if (verified) _generation++;
      return verified;
    } finally {
      _stepUp = null;
    }
  }
}
