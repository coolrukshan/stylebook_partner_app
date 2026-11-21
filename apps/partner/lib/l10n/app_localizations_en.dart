// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'StyleBook Partner';

  @override
  String get signInTitle => 'Sign in to your salon';

  @override
  String get signInSubtitle =>
      'Enter your mobile number to receive a one-time verification code.';

  @override
  String get phoneLabel => 'Mobile number';

  @override
  String get phoneHint => '77 123 4567';

  @override
  String get sendCode => 'Send code';

  @override
  String get verifyCode => 'Verify code';

  @override
  String get otpTitle => 'Verification code';

  @override
  String otpSentTo(String phone) {
    return 'Enter the 6-digit code sent to $phone';
  }

  @override
  String otpDigitSemantics(int index, int total) {
    return 'Digit $index of $total';
  }

  @override
  String get resendCode => 'Resend code';

  @override
  String resendIn(String time) {
    return 'Resend code in $time';
  }

  @override
  String get changeNumber => 'Change number';

  @override
  String get errPhoneInvalid => 'Please enter a valid Sri Lankan mobile number';

  @override
  String get errOtpWrong =>
      'The code you entered is incorrect. Please try again.';

  @override
  String get errOtpExpired =>
      'This code has expired. Please request a new one.';

  @override
  String errTooManyRequests(int seconds) {
    return 'Too many attempts. Please try again in $seconds seconds.';
  }

  @override
  String get errNotRegistered =>
      'This mobile number is not registered with a salon.';

  @override
  String get errSessionExpired =>
      'Your session has expired. Please sign in again.';

  @override
  String get errOffline =>
      'You are offline. Please check your internet connection.';

  @override
  String get errServer => 'A server error occurred. Please try again later.';

  @override
  String get errSmsProviderDown =>
      'SMS delivery is currently unavailable. Please try again later.';

  @override
  String get retry => 'Retry';

  @override
  String get signOut => 'Sign out';

  @override
  String get roleOwner => 'Owner';

  @override
  String get roleManager => 'Manager';

  @override
  String get roleSpecialist => 'Specialist';
}
