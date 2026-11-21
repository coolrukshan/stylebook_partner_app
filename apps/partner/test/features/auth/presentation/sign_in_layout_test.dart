import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sb_core/sb_core.dart';
import 'package:sb_ui/sb_ui.dart';
import 'package:stylebook_partner/features/auth/application/otp_controller.dart';
import 'package:stylebook_partner/features/auth/application/providers.dart';
import 'package:stylebook_partner/features/auth/presentation/sign_in_screen.dart';
import 'package:stylebook_partner/l10n/app_localizations.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget buildApp({
    Size size = const Size(390, 844),
    double textScaleFactor = 1.0,
    OtpState otpState = const OtpState(),
  }) {
    return MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScaleFactor),
      ),
      child: ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
          otpSignInControllerProvider.overrideWith(() => _FakeOtpController(otpState)),
        ],
        child: MaterialApp(
          theme: SbTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SignInScreen(),
        ),
      ),
    );
  }

  testWidgets('SignInScreen handles 2.0 text scale on 390x844 without overflow', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildApp(
        size: const Size(390, 844),
        textScaleFactor: 2.0,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Sign in to your salon'), findsOneWidget);
  });

  testWidgets('Golden - sign_in_phone_390', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp(size: const Size(390, 844)));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(SignInScreen),
      matchesGoldenFile('goldens/sign_in_phone_390.png'),
    );
  });

  testWidgets('Golden - sign_in_otp_390', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildApp(
        size: const Size(390, 844),
        otpState: const OtpState(
          step: OtpStep.code,
          phone: '0771234567',
          resendSecondsLeft: 42,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(SignInScreen),
      matchesGoldenFile('goldens/sign_in_otp_390.png'),
    );
  });

  testWidgets('Golden - sign_in_phone_1280', (tester) async {
    tester.view.physicalSize = const Size(1280 * 2, 800 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp(size: const Size(1280, 800)));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(SignInScreen),
      matchesGoldenFile('goldens/sign_in_phone_1280.png'),
    );
  });
}

class _FakeOtpController extends OtpSignInController {
  _FakeOtpController(this._initialState);
  final OtpState _initialState;

  @override
  OtpState build() => _initialState;
}
