import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Contract for persisting access/refresh tokens and session cache.
abstract class TokenStorage {
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
  Future<void> saveTokens({required String accessToken, required String refreshToken});
  Future<void> clearTokens();

  Future<String?> getCachedUser();
  Future<void> saveCachedUser(String userJson);
  Future<void> clearCachedUser();
}

/// Token storage backed by [FlutterSecureStorage].
class SecureTokenStorage implements TokenStorage {
  const SecureTokenStorage([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  static const _kAccessToken = 'sb_access_token';
  static const _kRefreshToken = 'sb_refresh_token';
  static const _kCachedUser = 'sb_cached_user';

  @override
  Future<String?> getAccessToken() => _storage.read(key: _kAccessToken);

  @override
  Future<String?> getRefreshToken() => _storage.read(key: _kRefreshToken);

  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _kAccessToken, value: accessToken);
    await _storage.write(key: _kRefreshToken, value: refreshToken);
  }

  @override
  Future<void> clearTokens() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
  }

  @override
  Future<String?> getCachedUser() => _storage.read(key: _kCachedUser);

  @override
  Future<void> saveCachedUser(String userJson) => _storage.write(key: _kCachedUser, value: userJson);

  @override
  Future<void> clearCachedUser() => _storage.delete(key: _kCachedUser);
}

/// In-memory token storage for tests and fake environments.
class InMemoryTokenStorage implements TokenStorage {
  String? _accessToken;
  String? _refreshToken;
  String? _cachedUser;

  @override
  Future<String?> getAccessToken() async => _accessToken;

  @override
  Future<String?> getRefreshToken() async => _refreshToken;

  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  @override
  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
  }

  @override
  Future<String?> getCachedUser() async => _cachedUser;

  @override
  Future<void> saveCachedUser(String userJson) async {
    _cachedUser = userJson;
  }

  @override
  Future<void> clearCachedUser() async {
    _cachedUser = null;
  }
}
