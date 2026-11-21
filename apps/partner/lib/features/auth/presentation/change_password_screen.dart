import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sb_ui/sb_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shell/routes.dart';
import '../application/change_password_controller.dart';
import '../application/providers.dart';
import 'widgets/auth_header.dart';

/// Forced after a temporary password (no way back), reusable later from More.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _filled => _current.text.isNotEmpty && _new.text.isNotEmpty && _confirm.text.isNotEmpty;

  Future<void> _submit() async {
    final router = GoRouter.of(context);
    final from = safeFromTarget(GoRouterState.of(context).uri.queryParameters['from']);

    final changed = await ref
        .read(changePasswordControllerProvider.notifier)
        .submit(current: _current.text, next: _new.text, confirm: _confirm.text);
    if (!changed || !mounted) return;

    // The "Password changed" snackbar comes from SessionNotices (it survives a step-up).
    router.go(from ?? kHomePath);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(changePasswordControllerProvider);

    ref.listen(changePasswordControllerProvider.select((s) => s.passwordResetSignal), (_, _) {
      _current.clear();
      _new.clear();
      _confirm.clear();
      setState(() {});
    });

    final banner = switch (state.banner) {
      null => null,
      ChangePasswordBanner.rateLimited => l10n.errRateLimited,
      ChangePasswordBanner.unavailable => l10n.errRateLimitUnavailable,
      ChangePasswordBanner.offline => l10n.errOffline,
      ChangePasswordBanner.server => l10n.errServer,
      ChangePasswordBanner.stepUpRequired => l10n.errOtpRequired,
      ChangePasswordBanner.unknown => state.bannerMessage ?? l10n.errServer,
    };
    final newError = state.newError == null
        ? null
        : (state.newErrorMessage?.isNotEmpty ?? false)
        ? state.newErrorMessage
        : l10n.errWeakPassword;

    return PopScope(
      canPop: false,
      child: SbAuthScaffold(
        child: AutofillGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthHeader(title: l10n.changePasswordTitle, subtitle: l10n.changePasswordSubtitle),
              if (banner != null) ...[const SizedBox(height: SbTokens.gap20), SbErrorBanner(message: banner)],
              const SizedBox(height: SbTokens.gap24),
              SbPasswordField(
                controller: _current,
                label: l10n.currentPasswordLabel,
                showLabel: l10n.showPassword,
                hideLabel: l10n.hidePassword,
                enabled: !state.submitting,
                maxLength: 128,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.password],
                errorText: state.currentError == null ? null : l10n.errCurrentPasswordWrong,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: SbTokens.gap16),
              SbPasswordField(
                controller: _new,
                label: l10n.newPasswordLabel,
                showLabel: l10n.showPassword,
                hideLabel: l10n.hidePassword,
                enabled: !state.submitting,
                maxLength: 128,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                errorText: newError,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: SbTokens.gap8),
              Text(l10n.passwordPolicyHint, style: context.text.bodySmall!.copyWith(color: SbColors.muted)),
              const SizedBox(height: SbTokens.gap16),
              SbPasswordField(
                controller: _confirm,
                label: l10n.confirmPasswordLabel,
                showLabel: l10n.showPassword,
                hideLabel: l10n.hidePassword,
                enabled: !state.submitting,
                maxLength: 128,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                errorText: state.confirmError == null ? null : l10n.errPasswordMismatch,
                onChanged: (_) => setState(() {}),
                onFieldSubmitted: (_) => _filled && !state.submitting ? _submit() : null,
              ),
              const SizedBox(height: SbTokens.gap24),
              SbPrimaryButton(
                label: l10n.savePassword,
                loading: state.submitting,
                onPressed: _filled && !state.submitting ? _submit : null,
              ),
              const SizedBox(height: SbTokens.gap8),
              Align(
                child: SbTextLink(
                  text: l10n.signOut,
                  onTap: () => ref.read(sessionControllerProvider.notifier).signOut(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
