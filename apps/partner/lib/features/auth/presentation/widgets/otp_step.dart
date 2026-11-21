import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sb_ui/sb_ui.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/otp_controller.dart';

/// 6-digit OTP verification step with resend countdown and change number option.
class OtpStepWidget extends ConsumerStatefulWidget {
  const OtpStepWidget({super.key});

  @override
  ConsumerState<OtpStepWidget> createState() => _OtpStepWidgetState();
}

class _OtpStepWidgetState extends ConsumerState<OtpStepWidget> {
  String _enteredCode = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final otpState = ref.watch(otpSignInControllerProvider);
    final controller = ref.read(otpSignInControllerProvider.notifier);

    String? errorText;
    if (otpState.fieldError == 'errOtpWrong') {
      errorText = l10n.errOtpWrong;
    } else if (otpState.fieldError == 'errOtpExpired') {
      errorText = l10n.errOtpExpired;
    } else if (otpState.fieldError != null) {
      errorText = otpState.fieldError;
    }

    final isVerifying = otpState.status == OtpStatus.verifying;
    final resendSeconds = otpState.resendSecondsLeft;
    final resendText = resendSeconds > 0
        ? l10n.resendIn('0:${resendSeconds.toString().padLeft(2, '0')}')
        : l10n.resendCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.otpTitle,
          style: context.text.headlineMedium!.copyWith(
            color: SbColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.otpSentTo(otpState.e164Phone ?? otpState.phone),
          style: context.text.bodyMedium!.copyWith(
            color: SbColors.text2,
          ),
        ),
        const SizedBox(height: 28),
        SbOtpInput(
          length: 6,
          hasError: errorText != null,
          onChanged: (code) {
            setState(() {
              _enteredCode = code;
            });
          },
          onCompleted: (code) {
            _enteredCode = code;
            if (!isVerifying) {
              controller.verifyOtp(code);
            }
          },
        ),
        if (errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            errorText,
            style: context.text.bodySmall!.copyWith(
              color: SbColors.danger,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            SbTextLink(
              text: resendText,
              enabled: otpState.canResend && !isVerifying,
              onTap: () => controller.sendOtp(),
            ),
            SbTextLink(
              text: l10n.changeNumber,
              enabled: !isVerifying,
              onTap: () => controller.changeNumber(),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SbPrimaryButton(
          label: isVerifying ? '...' : l10n.verifyCode,
          onPressed: _enteredCode.length == 6 && !isVerifying
              ? () => controller.verifyOtp(_enteredCode)
              : null,
        ),
      ],
    );
  }
}
