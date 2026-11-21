import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sb_ui/sb_ui.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/otp_controller.dart';

/// Phone entry step for the partner OTP sign-in flow.
class PhoneStep extends ConsumerStatefulWidget {
  const PhoneStep({super.key});

  @override
  ConsumerState<PhoneStep> createState() => _PhoneStepState();
}

class _PhoneStepState extends ConsumerState<PhoneStep> {
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    final currentPhone = ref.read(otpSignInControllerProvider).phone;
    _phoneController = TextEditingController(text: currentPhone);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final otpState = ref.watch(otpSignInControllerProvider);
    final controller = ref.read(otpSignInControllerProvider.notifier);

    String? errorText;
    if (otpState.fieldError == 'errPhoneInvalid') {
      errorText = l10n.errPhoneInvalid;
    } else if (otpState.fieldError != null) {
      errorText = otpState.fieldError;
    }

    final isSending = otpState.status == OtpStatus.sending;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.signInTitle,
          style: context.text.headlineMedium!.copyWith(
            color: SbColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.signInSubtitle,
          style: context.text.bodyMedium!.copyWith(
            color: SbColors.text2,
          ),
        ),
        const SizedBox(height: 28),
        SbTextField(
          controller: _phoneController,
          label: l10n.phoneLabel,
          hint: l10n.phoneHint,
          prefixText: '+94 ',
          keyboardType: TextInputType.phone,
          errorText: errorText,
          enabled: !isSending,
          onChanged: (val) => controller.setPhone(val),
          onFieldSubmitted: (_) {
            if (!isSending) controller.sendOtp();
          },
        ),
        const SizedBox(height: 24),
        SbPrimaryButton(
          label: isSending ? '...' : l10n.sendCode,
          onPressed: isSending ? null : () => controller.sendOtp(),
        ),
      ],
    );
  }
}
