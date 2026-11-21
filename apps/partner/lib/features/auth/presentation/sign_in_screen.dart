import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sb_ui/sb_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../application/otp_controller.dart';
import '../application/providers.dart';
import '../application/session_controller.dart';
import 'widgets/otp_step.dart';
import 'widgets/phone_step.dart';

/// Screen for salon partner mobile OTP sign-in.
class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final otpState = ref.watch(otpSignInControllerProvider);
    final sessionAsync = ref.watch(sessionControllerProvider);

    String? bannerMessage;
    if (otpState.bannerError != null) {
      if (otpState.bannerError == 'errOffline') {
        bannerMessage = l10n?.errOffline ?? 'You are offline. Please check your internet connection.';
      } else if (otpState.bannerError == 'errTooManyRequests') {
        bannerMessage = l10n?.errTooManyRequests(otpState.resendSecondsLeft) ??
            'Too many attempts. Please try again later.';
      } else if (otpState.bannerError == 'errSmsProviderDown') {
        bannerMessage = l10n?.errSmsProviderDown ?? 'SMS delivery unavailable. Please try again later.';
      } else if (otpState.bannerError == 'errServer') {
        bannerMessage = l10n?.errServer ?? 'A server error occurred. Please try again.';
      } else {
        bannerMessage = otpState.bannerError;
      }
    } else {
      sessionAsync.whenData((state) {
        if (state is NoSalonAccess) {
          bannerMessage = l10n?.errNotRegistered ?? state.message;
        } else if (state is Unauthenticated && state.reason == 'expired') {
          bannerMessage = l10n?.errSessionExpired ?? 'Your session has expired. Please sign in again.';
        }
      });
    }

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (bannerMessage != null) ...[
          SbErrorBanner(message: bannerMessage!),
          const SizedBox(height: 20),
        ],
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: otpState.step == OtpStep.phone
              ? const PhoneStep(key: ValueKey('phone_step'))
              : const OtpStepWidget(key: ValueKey('otp_step')),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: SbColors.canvas,
      body: Stack(
        children: [
          // Ambient soft amber glow
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: SbColors.canvas,
                gradient: RadialGradient(
                  center: const Alignment(0.8, -0.8),
                  radius: 1.2,
                  colors: [
                    SbColors.glowAmber.withValues(alpha: 0.6),
                    SbColors.canvas,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTabletOrWeb = constraints.maxWidth >= 900;
                if (isTabletOrWeb) {
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: SbTokens.authCardMaxWidth),
                      child: SbCard(
                        padding: const EdgeInsets.all(32),
                        child: content,
                      ),
                    ),
                  );
                }

                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    24,
                    20,
                    24 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: content,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
