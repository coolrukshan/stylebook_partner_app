import 'package:flutter/foundation.dart';

/// `PartnerOtpSendResponse`. [phoneMasked] is shown as given, never built from client data.
@immutable
class PartnerOtpSendResponse {
  const PartnerOtpSendResponse({
    required this.phoneMasked,
    this.message = 'OTP sent',
    this.expiresIn = 300,
    this.retryAfter = 60,
  });

  final String message;
  final String phoneMasked;
  final int expiresIn;
  final int retryAfter;

  factory PartnerOtpSendResponse.fromJson(Map<String, dynamic> json) => PartnerOtpSendResponse(
    message: json['message'] as String? ?? 'OTP sent',
    phoneMasked: json['phone_masked'] as String,
    expiresIn: json['expires_in'] as int? ?? 300,
    retryAfter: json['retry_after'] as int? ?? 60,
  );
}
