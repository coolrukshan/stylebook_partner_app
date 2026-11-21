import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sb_ui/sb_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../application/providers.dart';
import '../application/session_controller.dart';
import '../application/sign_in_controller.dart';
import 'auth_error_text.dart';
import 'widgets/auth_header.dart';

/// Username + password sign in. No tabs, no phone, no sign-up: accounts are created by StyleBook.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  bool get _filled => _username.text.trim().isNotEmpty && _password.text.isNotEmpty;

  void _submit() {
    TextInput.finishAutofillContext();
    ref.read(signInControllerProvider.notifier).submit(_username.text, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(signInControllerProvider);

    ref.listen(signInControllerProvider.select((s) => s.passwordResetSignal), (_, _) {
      _password.clear();
      _passwordFocus.requestFocus();
      setState(() {});
    });

    final signedOut = ref.watch(sessionControllerProvider).value;
    final banner =
        AuthErrorText.signIn(l10n, state) ??
        (signedOut is Unauthenticated ? AuthErrorText.signedOut(l10n, signedOut.reason) : null);
    final retryable =
        state.error == SignInError.unavailable ||
        state.error == SignInError.server ||
        state.error == SignInError.offline;

    final canSubmit = _filled && !state.submitting && !state.isLocked;

    return SbAuthScaffold(
      child: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthHeader(title: l10n.signInTitle, subtitle: l10n.signInSubtitle),
            if (banner != null) ...[
              const SizedBox(height: SbTokens.gap20),
              SbErrorBanner(
                message: banner,
                retryLabel: retryable ? l10n.retry : null,
                onRetry: retryable && _filled ? _submit : null,
              ),
            ],
            const SizedBox(height: SbTokens.gap24),
            SbTextField(
              controller: _username,
              label: l10n.usernameLabel,
              enabled: !state.submitting,
              autocorrect: false,
              enableSuggestions: false,
              maxLength: 50,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              onChanged: (_) => setState(() {}),
              onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
            ),
            const SizedBox(height: SbTokens.gap16),
            SbPasswordField(
              controller: _password,
              focusNode: _passwordFocus,
              label: l10n.passwordLabel,
              showLabel: l10n.showPassword,
              hideLabel: l10n.hidePassword,
              enabled: !state.submitting,
              maxLength: 128,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onChanged: (_) => setState(() {}),
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: SbTokens.gap24),
            SbPrimaryButton(label: l10n.signIn, loading: state.submitting, onPressed: canSubmit ? _submit : null),
            const SizedBox(height: SbTokens.gap20),
            Text(
              l10n.forgotPasswordHint,
              textAlign: TextAlign.center,
              style: context.text.bodySmall!.copyWith(color: SbColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
