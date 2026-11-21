import 'package:flutter/foundation.dart';

@immutable
class TokenResponse {
  const TokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;

  factory TokenResponse.fromJson(Map<String, dynamic> json) => TokenResponse(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        tokenType: json['token_type'] as String? ?? 'bearer',
        expiresIn: json['expires_in'] as int? ?? 900,
      );

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'token_type': tokenType,
        'expires_in': expiresIn,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenResponse &&
          accessToken == other.accessToken &&
          refreshToken == other.refreshToken &&
          tokenType == other.tokenType &&
          expiresIn == other.expiresIn;

  @override
  int get hashCode => Object.hash(accessToken, refreshToken, tokenType, expiresIn);
}
