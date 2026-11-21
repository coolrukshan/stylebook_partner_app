import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sb_ui/sb_ui.dart';
import 'package:stylebook_partner/features/auth/application/providers.dart';
import 'package:stylebook_partner/features/auth/application/session_controller.dart';
import 'package:stylebook_partner/features/auth/data/models/partner_otp_send_response.dart';
import 'package:stylebook_partner/features/auth/presentation/verify_code_screen.dart';

import '../../../support/fakes.dart';
import '../../../support/harness.dart';

void main() {
  late ScreenHarness h;

  setUp(() => h = ScreenHarness(tier: 'limited'));

  Finder verifyButton() => find.byType(SbPrimaryButton);
  bool enabled(WidgetTester tester) => tester.widget<SbPrimaryButton>(verifyButton()).onPressed != null;
  List<String> boxes(WidgetTester tester) =>
      tester.widgetList<TextField>(find.byType(TextField)).map((f) => f.controller!.text).toList();

  testWidgets('sends the code once on open and shows the masked phone from the API', (tester) async {
    await h.pump(tester, const VerifyCodeScreen());

    expect(h.repo.sendCalls, 1);
    expect(find.text('Verify your phone'), findsOneWidget);
    expect(find.text('We sent a 6-digit code to +9477***4567.'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(6));
  });

  testWidgets('a rebuild or rotation does not send again', (tester) async {
    await h.pump(tester, const VerifyCodeScreen());
    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(h.repo.sendCalls, 1);
  });

  testWidgets('the sixth digit verifies exactly once and the session becomes full', (tester) async {
    await h.pump(tester, const VerifyCodeScreen());
    await enterOtp(tester, '482910');
    await tester.pumpAndSettle();

    expect(h.repo.verifyCalls, ['482910']);
    expect(h.container(tester, VerifyCodeScreen).read(sessionControllerProvider).value, isA<Full>());
  });

  testWidgets('the Verify button is a fallback: disabled until six digits', (tester) async {
    await h.pump(tester, const VerifyCodeScreen());
    expect(enabled(tester), isFalse);
    await enterOtp(tester, '48291');
    expect(enabled(tester), isFalse);
    await tester.enterText(find.byType(TextField).at(5), '0');
    await tester.pumpAndSettle();
    expect(h.repo.verifyCalls.length, 1);
  });

  testWidgets('a wrong code shows the message and clears the boxes', (tester) async {
    h.repo.verifyError = apiError(400, 'OTP_INVALID');
    await h.pump(tester, const VerifyCodeScreen());
    await enterOtp(tester, '000000');
    await tester.pumpAndSettle();

    expect(find.text('That code is not right.'), findsOneWidget);
    expect(boxes(tester), everyElement(''));
  });

  testWidgets('expired code offers Resend immediately', (tester) async {
    h.repo.verifyError = apiError(410, 'OTP_EXPIRED');
    await h.pump(tester, const VerifyCodeScreen());
    await enterOtp(tester, '000000');
    await tester.pumpAndSettle();

    expect(find.text('This code has expired. Send a new code.'), findsOneWidget);
    expect(find.text('Resend code'), findsOneWidget);
  });

  testWidgets('too many wrong codes, and no pending code, show their messages', (tester) async {
    h.repo.verifyError = apiError(429, 'OTP_MAX_ATTEMPTS', retryAfter: 20);
    await h.pump(tester, const VerifyCodeScreen());
    await enterOtp(tester, '000000');
    await tester.pumpAndSettle();
    expect(find.text('Too many wrong codes. Send a new code.'), findsOneWidget);

    h.repo.verifyError = apiError(404, 'NOT_FOUND');
    await enterOtp(tester, '111111');
    await tester.pumpAndSettle();
    expect(find.text('No code is waiting. Send a new code.'), findsOneWidget);
  });

  testWidgets('Resend is disabled with a countdown until it reaches zero, then sends a new code', (tester) async {
    h.repo.sendResult = const PartnerOtpSendResponse(phoneMasked: '+9477***4567', retryAfter: 60);
    await h.pump(tester, const VerifyCodeScreen());

    expect(find.text('Resend code in 1:00'), findsOneWidget);
    await tester.tap(find.text('Resend code in 1:00'), warnIfMissed: false);
    await tester.pump();
    expect(h.repo.sendCalls, 1);

    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Resend code in 0:30'), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Resend code'), findsOneWidget);
    await tester.tap(find.text('Resend code'));
    await tester.pumpAndSettle();
    expect(h.repo.sendCalls, 2);
  });

  testWidgets('Cancel is offered only when a parked OTP_REQUIRED call opened the screen', (tester) async {
    await h.pump(tester, const VerifyCodeScreen());
    expect(find.text('Cancel'), findsNothing);

    final container = h.container(tester, VerifyCodeScreen);
    final parked = container.read(stepUpCoordinatorProvider.notifier).request();
    await tester.pump();
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(await parked, isFalse);
    expect(find.text('Cancel'), findsNothing);
  });

  testWidgets('Sign out is always available and signs out', (tester) async {
    await h.pump(tester, const VerifyCodeScreen());
    expect(find.text('Sign out'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(h.repo.logoutCalls, 1);
    expect(h.container(tester, VerifyCodeScreen).read(sessionControllerProvider).value, isA<Unauthenticated>());
  });

  testWidgets('no phone on the account blocks everything except Sign out', (tester) async {
    h.repo.sendError = apiError(409, 'CONFLICT');
    await h.pump(tester, const VerifyCodeScreen());

    expect(find.text('No mobile number on this account. Contact StyleBook support.'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Resend code'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField).first).enabled, isFalse);
  });

  testWidgets('SMS failure shows a Retry that sends again', (tester) async {
    h.repo.sendError = apiError(502, 'SMS_DELIVERY_FAILED');
    await h.pump(tester, const VerifyCodeScreen());
    expect(find.text('We could not send the SMS. Please try again.'), findsOneWidget);

    h.repo.sendError = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(h.repo.sendCalls, 2);
    expect(find.textContaining('could not send'), findsNothing);
  });

  testWidgets('OTP boxes have localised digit labels', (tester) async {
    final handle = tester.ensureSemantics();
    await h.pump(tester, const VerifyCodeScreen());
    expect(find.bySemanticsLabel('Digit 1 of 6'), findsOneWidget);
    expect(find.bySemanticsLabel('Digit 6 of 6'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('works at 200 % text scale on a phone without overflow', (tester) async {
    h.repo.verifyError = apiError(400, 'OTP_INVALID');
    await h.pump(tester, const VerifyCodeScreen(), textScale: 2);
    await enterOtp(tester, '000000');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Verify your phone'), findsOneWidget);
  });

  testWidgets('works at 200 % text scale on a wide screen', (tester) async {
    await h.pump(tester, const VerifyCodeScreen(), size: const Size(1280, 800), textScale: 2);
    expect(tester.takeException(), isNull);
  });
}
