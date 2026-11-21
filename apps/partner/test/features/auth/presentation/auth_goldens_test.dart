import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylebook_partner/features/auth/presentation/change_password_screen.dart';
import 'package:stylebook_partner/features/auth/presentation/sign_in_screen.dart';
import 'package:stylebook_partner/features/auth/presentation/verify_code_screen.dart';

import '../../../support/harness.dart';

/// Golden files are rendered with the test font; regenerate with `flutter test --update-goldens`.
void main() {
  const phone = Size(390, 844);
  const wide = Size(1280, 800);

  testWidgets('sign_in_390', (tester) async {
    await ScreenHarness().pump(tester, const SignInScreen(), size: phone);
    await expectLater(find.byType(SignInScreen), matchesGoldenFile('goldens/sign_in_390.png'));
  });

  testWidgets('sign_in_1280', (tester) async {
    await ScreenHarness().pump(tester, const SignInScreen(), size: wide);
    await expectLater(find.byType(SignInScreen), matchesGoldenFile('goldens/sign_in_1280.png'));
  });

  testWidgets('verify_code_390', (tester) async {
    await ScreenHarness(tier: 'limited').pump(tester, const VerifyCodeScreen(), size: phone);
    await expectLater(find.byType(VerifyCodeScreen), matchesGoldenFile('goldens/verify_code_390.png'));
  });

  testWidgets('change_password_390', (tester) async {
    await ScreenHarness(tier: 'full', mustChange: true).pump(tester, const ChangePasswordScreen(), size: phone);
    await expectLater(find.byType(ChangePasswordScreen), matchesGoldenFile('goldens/change_password_390.png'));
  });
}
