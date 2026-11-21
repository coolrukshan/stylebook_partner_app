import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sb_core/sb_core.dart';
import 'package:stylebook_partner/app.dart';
import 'package:stylebook_partner/features/auth/application/providers.dart';
import 'package:stylebook_partner/features/auth/application/session_controller.dart';

import 'support/fakes.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pumpApp(WidgetTester tester, AuthState initial) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionControllerProvider.overrideWith(() => _FakeSessionController(initial))],
        child: const PartnerApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('signed-out user sees Sign in', (tester) async {
    await pumpApp(tester, const Unauthenticated());
    expect(find.text('Sign in to your salon'), findsOneWidget);
  });

  testWidgets('a limited user sees Verify your phone', (tester) async {
    await pumpApp(tester, const Limited(partnerUser: kOwnerUser, mustChangePassword: false));
    expect(find.text('Verify your phone'), findsOneWidget);
  });

  testWidgets('a full user sees Today', (tester) async {
    await pumpApp(tester, const Full(partnerUser: kOwnerUser, mustChangePassword: false));
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Partner app scaffold ready.'), findsOneWidget);
  });

  testWidgets('a full user who must change the password sees Set a new password', (tester) async {
    await pumpApp(tester, const Full(partnerUser: kOwnerUser, mustChangePassword: true));
    expect(find.text('Set a new password'), findsOneWidget);
  });

  test('role comes from the server: owner flag gives owner, otherwise specialist', () {
    expect(const Full(partnerUser: kOwnerUser, mustChangePassword: false).user.role, Role.owner);
    expect(const Full(partnerUser: kStaffUser, mustChangePassword: false).user.role, Role.specialist);
  });
}

class _FakeSessionController extends SessionController {
  _FakeSessionController(this._initial);
  final AuthState _initial;

  @override
  Future<AuthState> build() async => _initial;
}
