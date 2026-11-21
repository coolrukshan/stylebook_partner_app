import 'package:dio/dio.dart';
import 'package:sb_api/sb_api.dart';
import 'package:sb_core/sb_core.dart';

import 'models/otp_send_response.dart';
import 'models/partner_settings_out.dart';
import 'models/sign_in_response.dart';
import 'models/token_response.dart';
import 'models/user_out.dart';

/// Repository handling authentication, token management, and salon context bootstrapping.
class AuthRepository {
  AuthRepository({
    required this.dio,
    required this.tokenStorage,
  });

  final Dio dio;
  final TokenStorage tokenStorage;

  /// Requests a 6-digit OTP code to the provided E.164 phone number.
  Future<OtpSendResponse> sendOtp(String e164) async {
    return wrapApiCall(() async {
      final res = await dio.post<Map<String, dynamic>>(
        '/v1/auth/otp/send',
        data: {'phone': e164},
      );
      return OtpSendResponse.fromJson(res.data!);
    });
  }

  /// Verifies an OTP code and returns access/refresh tokens.
  Future<SignInResponse> verifyOtp(String e164, String otp) async {
    return wrapApiCall(() async {
      final res = await dio.post<Map<String, dynamic>>(
        '/v1/auth/otp/verify',
        data: {'phone': e164, 'otp': otp},
      );
      return SignInResponse.fromJson(res.data!);
    });
  }

  /// Manually refreshes the session using the stored refresh token.
  Future<TokenResponse> refresh() async {
    return wrapApiCall(() async {
      final refreshToken = await tokenStorage.getRefreshToken();
      final res = await dio.post<Map<String, dynamic>>(
        '/v1/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      return TokenResponse.fromJson(res.data!);
    });
  }

  /// Fetches the profile of the authenticated user.
  Future<UserOut> me() async {
    return wrapApiCall(() async {
      final res = await dio.get<Map<String, dynamic>>('/v1/me');
      return UserOut.fromJson(res.data!);
    });
  }

  /// Loads the salon profile settings (ID, salon name, time zone).
  Future<PartnerSettingsOut> loadSalonContext() async {
    return wrapApiCall(() async {
      final res = await dio.get<Map<String, dynamic>>('/v1/partner/settings');
      return PartnerSettingsOut.fromJson(res.data!);
    });
  }

  /// Signs out: makes best-effort logout call and clears stored tokens and cached user.
  Future<void> logout() async {
    final refreshToken = await tokenStorage.getRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await dio.post<dynamic>(
          '/v1/auth/logout',
          data: {'refresh_token': refreshToken},
        );
      } catch (_) {
        // Best effort
      }
    }
    await tokenStorage.clearTokens();
    await tokenStorage.clearCachedUser();
  }
}
