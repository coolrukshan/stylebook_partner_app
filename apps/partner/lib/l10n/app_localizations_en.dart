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
  String get loadingSession => 'Loading';

  @override
  String get todayTitle => 'Today';

  @override
  String get todayScaffoldReady => 'Partner app scaffold ready.';

  @override
  String get staffListPlaceholder => 'Staff';

  @override
  String get signInTitle => 'Sign in to your salon';

  @override
  String get signInSubtitle => 'Enter the username and password from your salon.';

  @override
  String get usernameLabel => 'Username';

  @override
  String get passwordLabel => 'Password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get signIn => 'Sign in';

  @override
  String get forgotPasswordHint => 'Forgot password? Ask your salon owner or StyleBook support.';

  @override
  String get errInvalidCredentials => 'Username or password is incorrect.';

  @override
  String errAccountLocked(String time) {
    return 'Too many attempts. Try again in $time.';
  }

  @override
  String get errRateLimited => 'Too many requests. Please try again shortly.';

  @override
  String get errAccountSuspended => 'This account is suspended. Contact StyleBook support.';

  @override
  String get errAccountDisabled => 'This account has been disabled. Contact your salon owner or StyleBook support.';

  @override
  String get errNotSalonMember => 'This account has no salon access.';

  @override
  String get errRateLimitUnavailable => 'Service temporarily unavailable. Please try again.';

  @override
  String get errSessionExpired => 'Your session has expired. Please sign in again.';

  @override
  String get errOffline => 'You are offline. Please check your internet connection.';

  @override
  String get errServer => 'A server error occurred. Please try again later.';

  @override
  String get retry => 'Retry';

  @override
  String get signOut => 'Sign out';

  @override
  String get cancel => 'Cancel';

  @override
  String get verifyTitle => 'Verify your phone';

  @override
  String verifySubtitle(String phone) {
    return 'We sent a 6-digit code to $phone.';
  }

  @override
  String get verifySubtitlePending => 'Sending a code to the phone on your account.';

  @override
  String get verifyCode => 'Verify';

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
  String get errOtpInvalid => 'That code is not right.';

  @override
  String get errOtpExpired => 'This code has expired. Send a new code.';

  @override
  String get errOtpMaxAttempts => 'Too many wrong codes. Send a new code.';

  @override
  String get errNoPendingCode => 'No code is waiting. Send a new code.';

  @override
  String get errNoPhoneOnAccount => 'No mobile number on this account. Contact StyleBook support.';

  @override
  String get errSmsFailed => 'We could not send the SMS. Please try again.';

  @override
  String get errOtpRequired => 'Verify your phone to continue.';

  @override
  String get changePasswordTitle => 'Set a new password';

  @override
  String get changePasswordSubtitle => 'Choose a new password to continue.';

  @override
  String get currentPasswordLabel => 'Current password';

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get confirmPasswordLabel => 'Confirm new password';

  @override
  String get passwordPolicyHint => 'Choose a strong password that you do not use anywhere else.';

  @override
  String get errCurrentPasswordWrong => 'Current password is incorrect.';

  @override
  String get errPasswordMismatch => 'The passwords do not match.';

  @override
  String get errWeakPassword => 'Choose a stronger password.';

  @override
  String get savePassword => 'Change password';

  @override
  String get passwordChanged => 'Password changed. Other devices were signed out.';

  @override
  String get roleOwner => 'Owner';

  @override
  String get roleManager => 'Manager';

  @override
  String get roleSpecialist => 'Specialist';
}
