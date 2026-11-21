import 'package:dio/dio.dart';

/// Normalized domain API error.
class ApiError implements Exception {
  const ApiError({
    required this.message,
    this.code,
    this.field,
    this.status,
    this.retryAfter,
    this.isOffline = false,
    this.isServer = false,
  });

  final String message;
  final String? code;
  final String? field;
  final int? status;
  final int? retryAfter;
  final bool isOffline;
  final bool isServer;

  factory ApiError.offline([String message = 'You are offline. Please check your internet connection.']) => ApiError(
        message: message,
        code: 'OFFLINE',
        isOffline: true,
      );

  factory ApiError.server([String message = 'A server error occurred. Please try again later.', int? status]) =>
      ApiError(
        message: message,
        code: 'SERVER_ERROR',
        status: status,
        isServer: true,
      );

  factory ApiError.fromDio(DioException error) {
    final status = error.response?.statusCode;

    // Check for offline / connectivity failure
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return ApiError.offline();
    }

    // Check for server-side errors
    if (status != null && status >= 500) {
      return ApiError.server(
        'A server error occurred. Please try again later.',
        status,
      );
    }

    String message = error.message ?? 'An unexpected error occurred.';
    String? code;
    String? field;
    int? retryAfter;

    final data = error.response?.data;
    if (data is Map) {
      if (data['message'] is String) {
        message = data['message'] as String;
      } else if (data['error'] is String) {
        message = data['error'] as String;
      }
      if (data['code'] is String) {
        code = data['code'] as String;
      }
      if (data['field'] is String) {
        field = data['field'] as String;
      }
      if (data['retry_after'] is int) {
        retryAfter = data['retry_after'] as int;
      } else if (data['retry_after'] is String) {
        retryAfter = int.tryParse(data['retry_after'] as String);
      }
    }

    // Check Retry-After header on 429
    if (status == 429 && retryAfter == null) {
      final header = error.response?.headers.value('retry-after');
      if (header != null) {
        retryAfter = int.tryParse(header);
      }
    }

    return ApiError(
      message: message,
      code: code,
      field: field,
      status: status,
      retryAfter: retryAfter,
    );
  }

  @override
  String toString() =>
      'ApiError(status: $status, code: $code, field: $field, retryAfter: $retryAfter, message: $message)';
}
