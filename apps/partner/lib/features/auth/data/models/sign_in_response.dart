import 'package:flutter/foundation.dart';

@immutable
class SignInResponse {
  const SignInResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
    this.isNewUser = false,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final bool isNewUser;

  factory SignInResponse.fromJson(Map<String, dynamic> json) => SignInResponse(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        tokenType: json['token_type'] as String? ?? 'bearer',
        expiresIn: json['expires_in'] as int? ?? 900,
        isNewUser: json['is_new_user'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'token_type': tokenType,
        'expires_in': expiresIn,
        'is_new_user': isNewUser,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SignInResponse &&
          accessToken == other.accessToken &&
          refreshToken == other.refreshToken &&
          tokenType == other.tokenType &&
          expiresIn == other.expiresIn &&
          isNewUser == other.isNewUser;

  @override
  int get hashCode => Object.hash(accessToken, refreshToken, tokenType, expiresIn, isNewUser);
}
