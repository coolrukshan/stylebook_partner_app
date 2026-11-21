import 'package:flutter/foundation.dart';

/// `PartnerFullSessionResponse`: NEW token pair of a FULL session (OTP verify, password change).
@immutable
class PartnerFullSessionResponse {
  const PartnerFullSessionResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.mustChangePassword,
    this.tokenType = 'bearer',
    this.expiresIn = 900,
    this.session = 'full',
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final String session;
  final bool mustChangePassword;

  factory PartnerFullSessionResponse.fromJson(Map<String, dynamic> json) => PartnerFullSessionResponse(
    accessToken: json['access_token'] as String,
    refreshToken: json['refresh_token'] as String,
    tokenType: json['token_type'] as String? ?? 'bearer',
    expiresIn: json['expires_in'] as int? ?? 900,
    session: json['session'] as String? ?? 'full',
    mustChangePassword: json['must_change_password'] as bool,
  );
}
