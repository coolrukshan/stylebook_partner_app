import 'dart:async';
import 'package:dio/dio.dart';
import 'package:sb_core/sb_core.dart';

/// Result of a single-flight refresh: either a new access token or the reason it failed.
class _RefreshResult {
  const _RefreshResult.success(this.accessToken) : error = null;
  const _RefreshResult.failure([this.error]) : accessToken = null;

  final String? accessToken;
  final DioException? error;
}

/// Attaches the CURRENT stored Bearer token (read at request time, never captured earlier)
/// and performs a single-flight silent refresh on 401, retrying the call once.
///
/// Never logs tokens or bodies. Public endpoints (`/v1/auth/*`, partner login) get no Bearer
/// and never trigger a refresh.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this.tokenStorage,
    required this.authDio,
    this.onSessionExpired,
  });

  final TokenStorage tokenStorage;
  final Dio authDio;

  /// Called when the session can no longer be refreshed. [code] is the API error code
  /// (for example `TOKEN_REVOKED` or `ACCOUNT_SUSPENDED`) when the server gave one.
  final void Function(String? code)? onSessionExpired;

  Completer<_RefreshResult>? _refreshCompleter;

  static const _loginPath = '/v1/partner/auth/login';

  static bool _isPublic(String path) => path.contains('/v1/auth/') || path.contains(_loginPath);

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (_isPublic(options.path)) {
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

    if (status != 401 || _isPublic(path)) {
      return handler.next(err);
    }

    final requestAuth = err.requestOptions.headers['Authorization'] as String?;
    final currentToken = await tokenStorage.getAccessToken();

    String? accessToken;
    if (currentToken != null && requestAuth != null && requestAuth != 'Bearer $currentToken') {
      // Another call already replaced the token while this one was in flight: just retry.
      accessToken = currentToken;
    } else {
      final result = await _performTokenRefresh();
      accessToken = result.accessToken;
      if (accessToken == null) {
        return handler.next(result.error ?? err);
      }
    }

    try {
      final requestOptions = err.requestOptions;
      requestOptions.headers['Authorization'] = 'Bearer $accessToken';
      final response = await authDio.fetch<dynamic>(requestOptions);
      return handler.resolve(response);
    } on DioException catch (retryError) {
      // Surface the real failure of the retried call (it may be OTP_REQUIRED, 400, ...).
      return handler.next(retryError);
    } catch (_) {
      return handler.next(err);
    }
  }

  Future<_RefreshResult> _performTokenRefresh() async {
    final inFlight = _refreshCompleter;
    if (inFlight != null) {
      return inFlight.future;
    }

    final completer = Completer<_RefreshResult>();
    _refreshCompleter = completer;

    try {
      completer.complete(await _refresh());
    } catch (_) {
      await _expire(null);
      completer.complete(const _RefreshResult.failure());
    } finally {
      _refreshCompleter = null;
    }
    return completer.future;
  }

  Future<_RefreshResult> _refresh() async {
    final currentRefreshToken = await tokenStorage.getRefreshToken();
    if (currentRefreshToken == null || currentRefreshToken.isEmpty) {
      await _expire(null);
      return const _RefreshResult.failure();
    }

    try {
      final response = await authDio.post<Map<String, dynamic>>(
        '/v1/auth/refresh',
        data: {'refresh_token': currentRefreshToken},
      );

      final data = response.data;
      if (data != null && data['access_token'] is String && data['refresh_token'] is String) {
        final newAccessToken = data['access_token'] as String;
        // Rotation: the new pair replaces the old one together. The old refresh token is never reused.
        await tokenStorage.saveTokens(
          accessToken: newAccessToken,
          refreshToken: data['refresh_token'] as String,
        );
        return _RefreshResult.success(newAccessToken);
      }
      await _expire(null);
      return const _RefreshResult.failure();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        final body = e.response?.data;
        await _expire(body is Map && body['code'] is String ? body['code'] as String : null);
        return _RefreshResult.failure(e);
      }
      // Offline or server trouble: keep the session, let the caller see the real error.
      return _RefreshResult.failure(e);
    }
  }

  Future<void> _expire(String? code) async {
    await tokenStorage.clearTokens();
    onSessionExpired?.call(code);
  }
}
