import 'package:dio/dio.dart';
import 'package:sb_core/sb_core.dart';

import 'api_exception_mapper.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/idempotency_interceptor.dart';
import 'interceptors/otp_required_interceptor.dart';
import 'interceptors/salon_header_interceptor.dart';

/// Builds a configured Dio instance with auth refresh, idempotency, salon header, and exception mapping.
Dio buildDio({
  String? baseUrl,
  TokenStorage? tokenStorage,
  void Function(String? code)? onSessionExpired,
  Future<bool> Function()? onOtpRequired,
  String? Function()? salonIdProvider,
}) {
  final base = baseUrl ?? SbConfig.apiBaseUrl;
  final dio = Dio(BaseOptions(
    baseUrl: base,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  ));

  if (tokenStorage != null) {
    final authDio = Dio(BaseOptions(
      baseUrl: base,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ));

    dio.interceptors.add(AuthInterceptor(
      tokenStorage: tokenStorage,
      authDio: authDio,
      onSessionExpired: onSessionExpired,
    ));
  }

  dio.interceptors.add(IdempotencyInterceptor());

  if (salonIdProvider != null) {
    dio.interceptors.add(SalonHeaderInterceptor(salonIdProvider: salonIdProvider));
  }

  if (onOtpRequired != null) {
    dio.interceptors.add(OtpRequiredInterceptor(dio: dio, onOtpRequired: onOtpRequired));
  }

  dio.interceptors.add(ApiExceptionMapper());

  return dio;
}
