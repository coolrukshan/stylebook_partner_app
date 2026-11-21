import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sb_core/sb_core.dart';

void main() {
  group('ApiError', () {
    test('parses standard ErrorResponse body', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/v1/auth/otp/send'),
        response: Response(
          requestOptions: RequestOptions(path: '/v1/auth/otp/send'),
          statusCode: 422,
          data: {
            'error': 'Unprocessable Entity',
            'message': 'Invalid phone number format',
            'code': 'INVALID_PHONE',
            'field': 'phone',
          },
        ),
        type: DioExceptionType.badResponse,
      );

      final error = ApiError.fromDio(dioException);
      expect(error.status, equals(422));
      expect(error.message, equals('Invalid phone number format'));
      expect(error.code, equals('INVALID_PHONE'));
      expect(error.field, equals('phone'));
      expect(error.isOffline, isFalse);
    });

    test('extracts retryAfter from 429 response body and headers', () {
      final dioExceptionBody = DioException(
        requestOptions: RequestOptions(path: '/v1/auth/otp/send'),
        response: Response(
          requestOptions: RequestOptions(path: '/v1/auth/otp/send'),
          statusCode: 429,
          data: {
            'message': 'Too many requests',
            'retry_after': 45,
          },
        ),
        type: DioExceptionType.badResponse,
      );

      final errorBody = ApiError.fromDio(dioExceptionBody);
      expect(errorBody.status, equals(429));
      expect(errorBody.retryAfter, equals(45));

      final dioExceptionHeader = DioException(
        requestOptions: RequestOptions(path: '/v1/auth/otp/send'),
        response: Response(
          requestOptions: RequestOptions(path: '/v1/auth/otp/send'),
          statusCode: 429,
          headers: Headers.fromMap({
            'retry-after': ['60'],
          }),
          data: 'Rate limited',
        ),
        type: DioExceptionType.badResponse,
      );

      final errorHeader = ApiError.fromDio(dioExceptionHeader);
      expect(errorHeader.status, equals(429));
      expect(errorHeader.retryAfter, equals(60));
    });

    test('handles connection timeout and offline errors', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/v1/me'),
        type: DioExceptionType.connectionTimeout,
      );

      final error = ApiError.fromDio(dioException);
      expect(error.isOffline, isTrue);
      expect(error.code, equals('OFFLINE'));
    });

    test('handles 502/503 server errors', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/v1/me'),
        response: Response(
          requestOptions: RequestOptions(path: '/v1/me'),
          statusCode: 502,
          data: 'Bad Gateway',
        ),
        type: DioExceptionType.badResponse,
      );

      final error = ApiError.fromDio(dioException);
      expect(error.status, equals(502));
      expect(error.isServer, isTrue);
    });
  });
}
