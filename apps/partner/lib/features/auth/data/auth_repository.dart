import 'package:dio/dio.dart';
import 'package:sb_api/sb_api.dart';
import 'package:sb_core/sb_core.dart';

import 'models/partner_full_session_response.dart';
import 'models/partner_login_response.dart';
import 'models/partner_otp_send_response.dart';
import 'models/token_response.dart';

/// Partner authentication calls. Every call that issues a token pair REPLACES both stored
/// tokens. Passwords, codes and tokens are never logged.
class AuthRepository {
  AuthRepository({required this.dio, required this.tokenStorage});

  final Dio dio;
  final TokenStorage tokenStorage;

  /// `POST /v1/partner/auth/login`: username + password, returns a LIMITED session.
  Future<PartnerLoginResponse> login(String username, String password) {
    return wrapApiCall(() async {
      final res = await dio.post<Map<String, dynamic>>(
        '/v1/partner/auth/login',
        data: {'username': username, 'password': password},
      );
      final response = PartnerLoginResponse.fromJson(res.data!);
      await tokenStorage.saveTokens(accessToken: response.accessToken, refreshToken: response.refreshToken);
      return response;
    });
  }

  /// `POST /v1/partner/auth/otp/send`: SMS to the account phone (Bearer, no body).
  Future<PartnerOtpSendResponse> sendOtp() {
    return wrapApiCall(() async {
      final res = await dio.post<Map<String, dynamic>>('/v1/partner/auth/otp/send');
      return PartnerOtpSendResponse.fromJson(res.data!);
    });
  }

  /// `POST /v1/partner/auth/otp/verify`: upgrades to a FULL session with a NEW token pair.
  Future<PartnerFullSessionResponse> verifyOtp(String otp) {
    return wrapApiCall(() async {
      final res = await dio.post<Map<String, dynamic>>('/v1/partner/auth/otp/verify', data: {'otp': otp});
      final response = PartnerFullSessionResponse.fromJson(res.data!);
      await tokenStorage.saveTokens(accessToken: response.accessToken, refreshToken: response.refreshToken);
      return response;
    });
  }

  /// `POST /v1/partner/auth/password/change` (FULL session): NEW token pair, other sessions signed out.
  Future<PartnerFullSessionResponse> changePassword({required String current, required String next}) {
    return wrapApiCall(() async {
      final res = await dio.post<Map<String, dynamic>>(
        '/v1/partner/auth/password/change',
        data: {'current_password': current, 'new_password': next},
      );
      final response = PartnerFullSessionResponse.fromJson(res.data!);
      await tokenStorage.saveTokens(accessToken: response.accessToken, refreshToken: response.refreshToken);
      return response;
    });
  }

  /// `POST /v1/auth/refresh`: rotation, so both tokens are stored. The response has no tier.
  Future<TokenResponse> refresh() {
    return wrapApiCall(() async {
      final refreshToken = await tokenStorage.getRefreshToken();
      final res = await dio.post<Map<String, dynamic>>('/v1/auth/refresh', data: {'refresh_token': refreshToken});
      final response = TokenResponse.fromJson(res.data!);
      await tokenStorage.saveTokens(accessToken: response.accessToken, refreshToken: response.refreshToken);
      return response;
    });
  }

  /// Best-effort `POST /v1/auth/logout`, then clears tokens and the cached user locally.
  Future<void> logout() async {
    final refreshToken = await tokenStorage.getRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await dio.post<dynamic>('/v1/auth/logout', data: {'refresh_token': refreshToken});
      } catch (_) {
        // Best effort: always clear locally.
      }
    }
    await tokenStorage.clearTokens();
    await tokenStorage.clearCachedUser();
  }
}
