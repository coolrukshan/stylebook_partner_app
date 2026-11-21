import 'dart:async';
import 'package:dio/dio.dart';
import 'package:sb_core/sb_core.dart';

/// Interceptor that attaches JWT Bearer token and performs single-flight silent refresh on 401.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this.tokenStorage,
    required this.authDio,
    this.onSessionExpired,
  });

  final TokenStorage tokenStorage;
  final Dio authDio;
  final void Function()? onSessionExpired;

  Completer<String?>? _refreshCompleter;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // Never attach token to auth endpoints
    if (options.path.contains('/v1/auth/')) {
      return handler.next(options);
    }

    final token = await tokenStorage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    final path = err.requestOptions.path;

    // Do not intercept 401 on /v1/auth/* endpoints
    if (status != 401 || path.contains('/v1/auth/')) {
      if (path.contains('/v1/auth/refresh') && status == 401) {
        await tokenStorage.clearTokens();
        onSessionExpired?.call();
      }
      return handler.next(err);
    }

    try {
      final requestAuth = err.requestOptions.headers['Authorization'] as String?;
      final currentToken = await tokenStorage.getAccessToken();

      // If token was already refreshed by another concurrent request while this one was in-flight,
      // retry immediately with the current token without refreshing again.
      if (currentToken != null && requestAuth != null && requestAuth != 'Bearer $currentToken') {
        final requestOptions = err.requestOptions;
        requestOptions.headers['Authorization'] = 'Bearer $currentToken';
        final response = await authDio.fetch<dynamic>(requestOptions);
        return handler.resolve(response);
      }

      final newAccessToken = await _performTokenRefresh();
      if (newAccessToken == null) {
        return handler.next(err);
      }

      // Retry original request with the new access token
      final requestOptions = err.requestOptions;
      requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';

      final response = await authDio.fetch<dynamic>(requestOptions);
      return handler.resolve(response);
    } catch (e) {
      return handler.next(err);
    }
  }

  Future<String?> _performTokenRefresh() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final completer = Completer<String?>();
    _refreshCompleter = completer;

    try {
      final currentRefreshToken = await tokenStorage.getRefreshToken();
      if (currentRefreshToken == null || currentRefreshToken.isEmpty) {
        await tokenStorage.clearTokens();
        onSessionExpired?.call();
        completer.complete(null);
        return null;
      }

      final response = await authDio.post<Map<String, dynamic>>(
        '/v1/auth/refresh',
        data: {'refresh_token': currentRefreshToken},
      );

      final data = response.data;
      if (data != null && data['access_token'] is String) {
        final newAccessToken = data['access_token'] as String;
        final newRefreshToken = (data['refresh_token'] as String?) ?? currentRefreshToken;

        await tokenStorage.saveTokens(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken,
        );

        completer.complete(newAccessToken);
        return newAccessToken;
      } else {
        await tokenStorage.clearTokens();
        onSessionExpired?.call();
        completer.complete(null);
        return null;
      }
    } catch (e) {
      await tokenStorage.clearTokens();
      onSessionExpired?.call();
      completer.complete(null);
      return null;
    } finally {
      _refreshCompleter = null;
    }
  }
}
