import 'package:flutter/foundation.dart';

@immutable
class OtpSendResponse {
  const OtpSendResponse({
    required this.message,
    required this.expiresIn,
    required this.retryAfter,
  });

  final String message;
  final int expiresIn;
  final int retryAfter;

  factory OtpSendResponse.fromJson(Map<String, dynamic> json) => OtpSendResponse(
        message: json['message'] as String? ?? '',
        expiresIn: json['expires_in'] as int? ?? 300,
        retryAfter: json['retry_after'] as int? ?? 60,
      );

  Map<String, dynamic> toJson() => {
        'message': message,
        'expires_in': expiresIn,
        'retry_after': retryAfter,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OtpSendResponse &&
          message == other.message &&
          expiresIn == other.expiresIn &&
          retryAfter == other.retryAfter;

  @override
  int get hashCode => Object.hash(message, expiresIn, retryAfter);
}
