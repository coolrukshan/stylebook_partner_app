import '../../../l10n/app_localizations.dart';
import '../application/sign_in_controller.dart';
import '../application/session_controller.dart';
import '../application/step_up_controller.dart';

import 'package:sb_core/sb_core.dart';

/// Localised copy for controller errors. Controllers expose enums, never strings.
abstract final class AuthErrorText {
  static String? signIn(AppLocalizations l10n, SignInState state) {
    return switch (state.error) {
      null => null,
      SignInError.invalidCredentials => l10n.errInvalidCredentials,
      SignInError.accountLocked || SignInError.rateLimited =>
        state.isLocked ? l10n.errAccountLocked(SbFormat.countdown(state.lockSecondsLeft)) : l10n.errRateLimited,
      SignInError.suspended => l10n.errAccountSuspended,
      SignInError.disabled => l10n.errAccountDisabled,
      SignInError.noSalonAccess => l10n.errNotSalonMember,
      SignInError.unavailable => l10n.errRateLimitUnavailable,
      SignInError.offline => l10n.errOffline,
      SignInError.server => l10n.errServer,
      SignInError.unknown => state.serverMessage ?? l10n.errServer,
    };
  }

  static String? signedOut(AppLocalizations l10n, SignedOutReason? reason) {
    return switch (reason) {
      null => null,
      SignedOutReason.expired => l10n.errSessionExpired,
      SignedOutReason.suspended => l10n.errAccountSuspended,
      SignedOutReason.disabled => l10n.errAccountDisabled,
      SignedOutReason.noSalonAccess => l10n.errNotSalonMember,
    };
  }

  /// Errors about the code itself: shown under the boxes.
  static String? stepUpField(AppLocalizations l10n, StepUpState state) {
    return switch (state.error) {
      StepUpError.invalidCode => l10n.errOtpInvalid,
      StepUpError.expired => l10n.errOtpExpired,
      StepUpError.maxAttempts => l10n.errOtpMaxAttempts,
      StepUpError.noPendingCode => l10n.errNoPendingCode,
      _ => null,
    };
  }

  /// Errors about sending or the service: shown as a banner.
  static String? stepUpBanner(AppLocalizations l10n, StepUpState state) {
    return switch (state.error) {
      StepUpError.rateLimited =>
        state.resendSecondsLeft > 0
            ? l10n.errAccountLocked(SbFormat.countdown(state.resendSecondsLeft))
            : l10n.errRateLimited,
      StepUpError.smsFailed => l10n.errSmsFailed,
      StepUpError.unavailable => l10n.errRateLimitUnavailable,
      StepUpError.noPhone => l10n.errNoPhoneOnAccount,
      StepUpError.offline => l10n.errOffline,
      StepUpError.server => l10n.errServer,
      StepUpError.unknown => state.serverMessage ?? l10n.errServer,
      _ => null,
    };
  }
}
