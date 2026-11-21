import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sb_ui/sb_ui.dart';
import 'package:stylebook_partner/features/auth/application/providers.dart';
import 'package:stylebook_partner/features/auth/application/session_controller.dart';
import 'package:stylebook_partner/features/auth/presentation/sign_in_screen.dart';

import '../../../support/fakes.dart';
import '../../../support/harness.dart';

void main() {
  late ScreenHarness h;

  setUp(() => h = ScreenHarness());

  Finder username() => find.byType(TextFormField).at(0);
  Finder password() => find.byType(TextFormField).at(1);
  Finder signInButton() => find.byType(SbPrimaryButton);
  bool enabled(WidgetTester tester) => tester.widget<SbPrimaryButton>(signInButton()).onPressed != null;

  Future<void> fill(WidgetTester tester, {String user = 'nimal.kandy', String pass = 'Secret#1'}) async {
    await tester.enterText(username(), user);
    await tester.enterText(password(), pass);
    await tester.pump();
  }

  testWidgets('shows username, password, a disabled Sign in button and the forgot-password line', (tester) async {
    await h.pump(tester, const SignInScreen());

    expect(find.text('Sign in to your salon'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Forgot password? Ask your salon owner or StyleBook support.'), findsOneWidget);
    expect(enabled(tester), isFalse);
  });

  testWidgets('has no phone, email, sign-up or create-account wording and no tabs', (tester) async {
    await h.pump(tester, const SignInScreen());
    for (final word in ['phone', 'mobile', 'email', 'sign up', 'sign-up', 'create account', 'register']) {
      expect(find.textContaining(RegExp(word, caseSensitive: false)), findsNothing, reason: word);
    }
    expect(find.byType(TabBar), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('username disables autocorrect and uses autofill hints; password autofill too', (tester) async {
    await h.pump(tester, const SignInScreen());
    final fields = tester.widgetList<EditableText>(find.byType(EditableText)).toList();
    expect(fields[0].autocorrect, isFalse);
    expect(fields[0].autofillHints, contains(AutofillHints.username));
    expect(fields[1].obscureText, isTrue);
    expect(fields[1].autofillHints, contains(AutofillHints.password));
  });

  testWidgets('the button stays disabled until both fields are non-empty, and no request is made', (tester) async {
    await h.pump(tester, const SignInScreen());
    await tester.enterText(username(), 'nimal');
    await tester.pump();
    expect(enabled(tester), isFalse);
    await tester.enterText(password(), 'x');
    await tester.pump();
    expect(enabled(tester), isTrue);
    await tester.enterText(username(), '   ');
    await tester.pump();
    expect(enabled(tester), isFalse);
    expect(h.repo.loginCalls, isEmpty);
  });

  testWidgets('tapping Sign in logs in once with the trimmed username and the raw password', (tester) async {
    await h.pump(tester, const SignInScreen());
    await fill(tester, user: '  nimal.kandy ', pass: 'Secret#1');

    await tester.tap(signInButton());
    await tester.pumpAndSettle();

    expect(h.repo.loginCalls.single, (username: 'nimal.kandy', password: 'Secret#1'));
    expect(h.container(tester, SignInScreen).read(sessionControllerProvider).value, isA<Limited>());
  });

  testWidgets('the keyboard Done action on the password field submits', (tester) async {
    await h.pump(tester, const SignInScreen());
    await fill(tester);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(h.repo.loginCalls.length, 1);
  });

  testWidgets('while signing in the button shows progress, fields are disabled and taps are ignored', (tester) async {
    final gate = Completer<void>();
    h.repo.loginError = null;
    await h.pump(tester, const SignInScreen());
    // Slow login: wrap the fake by delaying through a pending completer on the token storage write.
    h.repo.loginGate = gate.future;
    await fill(tester);

    await tester.tap(signInButton());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField).at(0)).enabled, isFalse);
    expect(tester.widget<SbPrimaryButton>(signInButton()).onPressed, isNull);

    gate.complete();
    await tester.pumpAndSettle();
    expect(h.repo.loginCalls.length, 1);
  });

  testWidgets('wrong credentials: one generic message, password cleared and focused, username kept', (tester) async {
    h.repo.loginError = apiError(401, 'INVALID_CREDENTIALS');
    await h.pump(tester, const SignInScreen());
    await fill(tester, user: 'nimal.kandy', pass: 'wrong');

    await tester.tap(signInButton());
    await tester.pumpAndSettle();

    expect(find.text('Username or password is incorrect.'), findsOneWidget);
    expect(tester.widget<EditableText>(find.byType(EditableText).at(0)).controller.text, 'nimal.kandy');
    expect(tester.widget<EditableText>(find.byType(EditableText).at(1)).controller.text, '');
    expect(tester.widget<EditableText>(find.byType(EditableText).at(1)).focusNode.hasFocus, isTrue);
    expect(enabled(tester), isFalse);
  });

  testWidgets('lockout shows a countdown, disables Sign in and re-enables it when it ends', (tester) async {
    h.repo.loginError = apiError(429, 'ACCOUNT_LOCKED', retryAfter: 90);
    await h.pump(tester, const SignInScreen());
    await fill(tester);

    await tester.tap(signInButton());
    await tester.pumpAndSettle();
    expect(find.text('Too many attempts. Try again in 1:30.'), findsOneWidget);
    expect(enabled(tester), isFalse);

    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Too many attempts. Try again in 1:00.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 60));
    expect(find.textContaining('Too many attempts'), findsNothing);
    expect(enabled(tester), isTrue);
    expect(h.repo.loginCalls.length, 1);
  });

  testWidgets('account problems show their own messages', (tester) async {
    await h.pump(tester, const SignInScreen());
    await fill(tester);
    final cases = {
      'ACCOUNT_SUSPENDED': 'This account is suspended. Contact StyleBook support.',
      'ACCOUNT_DISABLED': 'This account has been disabled. Contact your salon owner or StyleBook support.',
      'NOT_SALON_MEMBER': 'This account has no salon access.',
    };
    for (final entry in cases.entries) {
      h.repo.loginError = apiError(403, entry.key);
      await tester.enterText(password(), 'pw');
      await tester.pump();
      await tester.tap(signInButton());
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget, reason: entry.key);
    }
  });

  testWidgets('503 shows the service message with a Retry that tries again', (tester) async {
    h.repo.loginError = apiError(503, 'RATE_LIMIT_UNAVAILABLE');
    await h.pump(tester, const SignInScreen());
    await fill(tester);
    await tester.tap(signInButton());
    await tester.pumpAndSettle();

    expect(find.text('Service temporarily unavailable. Please try again.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    h.repo.loginError = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(h.repo.loginCalls.length, 2);
  });

  testWidgets('a server message for an unknown code is shown as is', (tester) async {
    h.repo.loginError = apiError(400, 'BRAND_NEW', message: 'Please call the salon');
    await h.pump(tester, const SignInScreen());
    await fill(tester);
    await tester.tap(signInButton());
    await tester.pumpAndSettle();
    expect(find.text('Please call the salon'), findsOneWidget);
  });

  testWidgets('an expired session at launch shows the session-expired banner', (tester) async {
    final expired = ScreenHarness(tier: 'full');
    expired.repo.refreshError = apiError(401, 'TOKEN_REVOKED');
    await expired.pump(tester, const SignInScreen());
    expect(find.text('Your session has expired. Please sign in again.'), findsOneWidget);
  });

  testWidgets('the password eye toggles visibility and has a spoken label', (tester) async {
    final handle = tester.ensureSemantics();
    await h.pump(tester, const SignInScreen());
    expect(tester.widget<EditableText>(find.byType(EditableText).at(1)).obscureText, isTrue);
    expect(find.bySemanticsLabel('Show password'), findsOneWidget);

    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(tester.widget<EditableText>(find.byType(EditableText).at(1)).obscureText, isFalse);
    expect(find.bySemanticsLabel('Hide password'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('error banner is announced as a live region', (tester) async {
    final handle = tester.ensureSemantics();
    h.repo.loginError = apiError(401, 'INVALID_CREDENTIALS');
    await h.pump(tester, const SignInScreen());
    await fill(tester);
    await tester.tap(signInButton());
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.text('Username or password is incorrect.')),
      matchesSemantics(label: 'Username or password is incorrect.', isLiveRegion: true),
    );
    handle.dispose();
  });

  testWidgets('works at 200 % text scale on a phone without overflow', (tester) async {
    h.repo.loginError = apiError(429, 'ACCOUNT_LOCKED', retryAfter: 90);
    await h.pump(tester, const SignInScreen(), textScale: 2);
    await fill(tester);
    await tester.tap(signInButton());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Sign in to your salon'), findsOneWidget);
  });

  testWidgets('works at 200 % text scale on a wide screen', (tester) async {
    await h.pump(tester, const SignInScreen(), size: const Size(1280, 800), textScale: 2);
    expect(tester.takeException(), isNull);
    expect(find.byType(SbCard), findsOneWidget);
  });
}
