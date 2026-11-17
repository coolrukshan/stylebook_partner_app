import 'package:dio/dio.dart';
import 'package:sb_core/sb_core.dart';

/// Thin Dio wrapper. Auth refresh + idempotency interceptors are added with P-01.
Dio buildDio({String? baseUrl}) => Dio(BaseOptions(
      baseUrl: baseUrl ?? SbConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ));
