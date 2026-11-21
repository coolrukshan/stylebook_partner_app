import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

/// Interceptor that attaches an Idempotency-Key to POST requests for mutations.
class IdempotencyInterceptor extends Interceptor {
  IdempotencyInterceptor([this._uuid = const Uuid()]);

  final Uuid _uuid;

  static const _headerKey = 'Idempotency-Key';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.method.toUpperCase() == 'POST') {
      final path = options.path;
      // Partner auth endpoints take no idempotency header.
      final isTargetRoute =
          (path.contains('/v1/partner/') && !path.contains('/v1/partner/auth/')) || path.contains('/v1/bookings');
      if (isTargetRoute && !options.headers.containsKey(_headerKey)) {
        options.headers[_headerKey] = _uuid.v4();
      }
    }
    handler.next(options);
  }
}
