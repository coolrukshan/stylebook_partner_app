import 'package:dio/dio.dart';

/// Interceptor that attaches the X-Salon-Id header to salon-scoped routes.
class SalonHeaderInterceptor extends Interceptor {
  SalonHeaderInterceptor({required this.salonIdProvider});

  final String? Function() salonIdProvider;

  static const _headerKey = 'X-Salon-Id';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.path.contains('/v1/partner/')) {
      final salonId = salonIdProvider();
      if (salonId != null && salonId.isNotEmpty && !options.headers.containsKey(_headerKey)) {
        options.headers[_headerKey] = salonId;
      }
    }
    handler.next(options);
  }
}
