import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sb_core/sb_core.dart';
import 'package:sb_ui/sb_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../application/providers.dart';
import '../application/step_up_controller.dart';
import 'auth_error_text.dart';
import 'widgets/auth_header.dart';

/// Step-up: an SMS code upgrades the limited session to a full one. Also shown when a call
/// is parked by 403 OTP_REQUIRED (then Cancel is offered).
class VerifyCodeScreen extends ConsumerStatefulWidget {
  const VerifyCodeScreen({super.key});

  @override
  ConsumerState<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends ConsumerState<VerifyCodeScreen> {
  String _code = '';

  @override
  void initState() {
    super.initState();
    // Once per screen, never per rebuild or rotation (the controller guards it too).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(stepUpControllerProvider.notifier).ensureSent();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(stepUpControllerProvider);
    final controller = ref.read(stepUpControllerProvider.notifier);
    final parkedCall = ref.watch(stepUpCoordinatorProvider);

    final fieldError = AuthErrorText.stepUpField(l10n, state);
    final banner = AuthErrorText.stepUpBanner(l10n, state);
    final retryable =
        state.error == StepUpError.smsFailed ||
        state.error == StepUpError.unavailable ||
        state.error == StepUpError.offline ||
        state.error == StepUpError.server;

    final phone = state.phoneMasked;
    final resendText = state.resendSecondsLeft > 0
        ? l10n.resendIn(SbFormat.countdown(state.resendSecondsLeft))
        : l10n.resendCode;
    final verifying = state.status == StepUpStatus.verifying;

    return SbAuthScaffold(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthHeader(
            title: l10n.verifyTitle,
            subtitle: phone == null ? l10n.verifySubtitlePending : l10n.verifySubtitle(phone),
          ),
          if (banner != null) ...[
            const SizedBox(height: SbTokens.gap20),
            SbErrorBanner(
              message: banner,
              retryLabel: retryable ? l10n.retry : null,
              onRetry: retryable ? controller.send : null,
            ),
          ],
          const SizedBox(height: SbTokens.gap24),
          SbOtpInput(
            hasError: fieldError != null,
            enabled: !state.isBusy && !state.isBlocked,
            clearSignal: state.clearSignal,
            semanticLabelBuilder: (index, total) => l10n.otpDigitSemantics(index, total),
            onChanged: (code) => setState(() => _code = code),
            onCompleted: controller.verify,
          ),
          if (fieldError != null) ...[
            const SizedBox(height: SbTokens.gap8),
            Semantics(
              liveRegion: true,
              child: Text(
                fieldError,
                style: context.text.bodySmall!.copyWith(color: SbColors.danger, fontWeight: SbTokens.weightMedium),
              ),
            ),
          ],
          const SizedBox(height: SbTokens.gap20),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: SbTokens.gap12,
            runSpacing: SbTokens.gap8,
            children: [
              if (!state.isBlocked) SbTextLink(text: resendText, enabled: state.canResend, onTap: controller.resend),
              if (parkedCall) SbTextLink(text: l10n.cancel, onTap: controller.cancel),
              SbTextLink(text: l10n.signOut, onTap: controller.signOut),
            ],
          ),
          const SizedBox(height: SbTokens.gap24),
          SbPrimaryButton(
            label: l10n.verifyCode,
            loading: verifying,
            onPressed: _code.length == 6 && !state.isBusy && !state.isBlocked ? () => controller.verify(_code) : null,
          ),
        ],
      ),
    );
  }
}
