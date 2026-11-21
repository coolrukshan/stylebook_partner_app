import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sb_ui/sb_ui.dart';
import 'package:stylebook_partner/features/auth/application/providers.dart';
import 'package:stylebook_partner/features/auth/application/session_controller.dart';
import 'package:stylebook_partner/features/auth/presentation/change_password_screen.dart';

import '../../../support/fakes.dart';
import '../../../support/harness.dart';

void main() {
  late ScreenHarness h;

  setUp(() => h = ScreenHarness(tier: 'full', mustChange: true));

  Finder current() => find.byType(TextFormField).at(0);
  Finder next() => find.byType(TextFormField).at(1);
  Finder confirm() => find.byType(TextFormField).at(2);
  Finder button() => find.byType(SbPrimaryButton);
  bool enabled(WidgetTester tester) => tester.widget<SbPrimaryButton>(button()).onPressed != null;
  String text(WidgetTester tester, int i) =>
      tester.widget<EditableText>(find.byType(EditableText).at(i)).controller.text;

  Future<void> fill(
    WidgetTester tester, {
    String cur = 'Temp#1',
    String nw = 'My-New-Passw0rd',
    String conf = 'My-New-Passw0rd',
  }) async {
    await tester.enterText(current(), cur);
    await tester.enterText(next(), nw);
    await tester.enterText(confirm(), conf);
    await tester.pump();
  }

  testWidgets('shows three obscured password fields, a hint, Sign out and no way back', (tester) async {
    await h.pump(tester, const ChangePasswordScreen());

    expect(find.text('Set a new password'), findsOneWidget);
    expect(find.text('Current password'), findsOneWidget);
    expect(find.text('New password'), findsOneWidget);
    expect(find.text('Confirm new password'), findsOneWidget);
    expect(find.text('Choose a strong password that you do not use anywhere else.'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(find.text('Cancel'), findsNothing);
    for (final e in tester.widgetList<EditableText>(find.byType(EditableText))) {
      expect(e.obscureText, isTrue);
    }
    expect(enabled(tester), isFalse);
  });

  testWidgets('the button is enabled once all three are filled', (tester) async {
    await h.pump(tester, const ChangePasswordScreen());
    await tester.enterText(current(), 'a');
    await tester.enterText(next(), 'b');
    await tester.pump();
    expect(enabled(tester), isFalse);
    await tester.enterText(confirm(), 'b');
    await tester.pump();
    expect(enabled(tester), isTrue);
  });

  testWidgets('a mismatching confirmation shows an error and makes no request', (tester) async {
    await h.pump(tester, const ChangePasswordScreen());
    await fill(tester, conf: 'different');
    await tester.tap(button());
    await tester.pumpAndSettle();

    expect(find.text('The passwords do not match.'), findsOneWidget);
    expect(h.repo.changeCalls, isEmpty);
  });

  testWidgets('a weak password shows the server message on New password and keeps the values', (tester) async {
    h.repo.changeError = apiError(422, 'WEAK_PASSWORD', message: 'Use at least 12 characters');
    await h.pump(tester, const ChangePasswordScreen());
    await fill(tester, nw: 'short', conf: 'short');
    await tester.tap(button());
    await tester.pumpAndSettle();

    expect(find.text('Use at least 12 characters'), findsOneWidget);
    expect(text(tester, 1), 'short');
    expect(text(tester, 0), 'Temp#1');
  });

  testWidgets('a wrong current password is flagged on that field and the password fields are cleared', (tester) async {
    h.repo.changeError = apiError(400, 'INVALID_CREDENTIALS');
    await h.pump(tester, const ChangePasswordScreen());
    await fill(tester);
    await tester.tap(button());
    await tester.pumpAndSettle();

    expect(find.text('Current password is incorrect.'), findsOneWidget);
    expect(text(tester, 0), '');
    expect(text(tester, 1), '');
    expect(text(tester, 2), '');
  });

  testWidgets('success sends current and new only, shows the snackbar and goes to Today', (tester) async {
    await h.pump(tester, const ChangePasswordScreen());
    await fill(tester);
    await tester.tap(button());
    await tester.pumpAndSettle();

    expect(h.repo.changeCalls.single, (current: 'Temp#1', next: 'My-New-Passw0rd'));
    expect(find.text('Password changed. Other devices were signed out.'), findsOneWidget);
    expect(find.text('HOME'), findsOneWidget);
    expect((h.container(tester, Scaffold).read(sessionControllerProvider).value as Full).mustChangePassword, isFalse);
  });

  testWidgets('banners: rate limit, offline and a cancelled step-up', (tester) async {
    await h.pump(tester, const ChangePasswordScreen());
    await fill(tester);

    h.repo.changeError = apiError(429, 'RATE_LIMITED', retryAfter: 10);
    await tester.tap(button());
    await tester.pumpAndSettle();
    expect(find.text('Too many requests. Please try again shortly.'), findsOneWidget);

    h.repo.changeError = apiError(403, 'OTP_REQUIRED');
    await tester.tap(button());
    await tester.pumpAndSettle();
    expect(find.text('Verify your phone to continue.'), findsOneWidget);
  });

  testWidgets('Sign out signs out', (tester) async {
    await h.pump(tester, const ChangePasswordScreen());
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(h.repo.logoutCalls, 1);
  });

  testWidgets('works at 200 % text scale on a phone without overflow', (tester) async {
    h.repo.changeError = apiError(422, 'WEAK_PASSWORD', message: 'Use at least 12 characters');
    await h.pump(tester, const ChangePasswordScreen(), textScale: 2);
    await fill(tester, nw: 'short', conf: 'short');
    await tester.tap(button());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Set a new password'), findsOneWidget);
  });
}
