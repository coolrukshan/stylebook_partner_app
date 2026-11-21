import 'package:flutter/foundation.dart';

import 'partner_user_out.dart';

/// `PartnerLoginResponse`: a LIMITED session. An SMS code upgrades it to full.
@immutable
class PartnerLoginResponse {
  const PartnerLoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.mustChangePassword,
    required this.user,
    this.tokenType = 'bearer',
    this.expiresIn = 900,
    this.session = 'limited',
    this.otpRequiredForFullAccess = true,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final String session;
  final bool otpRequiredForFullAccess;
  final bool mustChangePassword;
  final PartnerUserOut user;

  factory PartnerLoginResponse.fromJson(Map<String, dynamic> json) => PartnerLoginResponse(
    accessToken: json['access_token'] as String,
    refreshToken: json['refresh_token'] as String,
    tokenType: json['token_type'] as String? ?? 'bearer',
    expiresIn: json['expires_in'] as int? ?? 900,
    session: json['session'] as String? ?? 'limited',
    otpRequiredForFullAccess: json['otp_required_for_full_access'] as bool? ?? true,
    mustChangePassword: json['must_change_password'] as bool,
    user: PartnerUserOut.fromJson(json['user'] as Map<String, dynamic>),
  );
}
