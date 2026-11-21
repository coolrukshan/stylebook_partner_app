import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sb_core/sb_core.dart';
import 'package:sb_ui/sb_ui.dart';
import 'package:stylebook_partner/features/auth/application/providers.dart';
import 'package:stylebook_partner/features/auth/data/models/partner_otp_send_response.dart';
import 'package:stylebook_partner/features/auth/data/models/partner_user_out.dart';
import 'package:stylebook_partner/l10n/app_localizations.dart';
import 'package:stylebook_partner/router.dart';

import 'support/fakes.dart';

void main() {
  late InMemoryTokenStorage tokens;
  late FakeAuthRepository repo;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    tokens = InMemoryTokenStorage();
    repo = FakeAuthRepository(tokens);
    // No resend countdown timer in these tests.
    repo.sendResult = const PartnerOtpSendResponse(phoneMasked: '+9477***4567', retryAfter: 0);
  });

  Future<void> seed(String tier, {bool mustChange = false, PartnerUserOut user = kOwnerUser}) async {
    await tokens.saveTokens(accessToken: 'acc', refreshToken: 'ref');
    await tokens.saveCachedUser(jsonEncode({'user': user.toJson(), 'tier': tier, 'must_change_password': mustChange}));
  }

  Future<ProviderContainer> launch(WidgetTester tester, {String? at}) async {
    final container = ProviderContainer(
      overrides: [tokenStorageProvider.overrideWithValue(tokens), authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.future);

    final router = container.read(routerProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: SbTheme.light(),
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (at != null) {
      router.go(at);
      await tester.pumpAndSettle();
    }
    return container;
  }

  String location(ProviderContainer c) => c.read(routerProvider).routeInformationProvider.value.uri.toString();

  group('signed out', () {
    testWidgets('is sent to /sign-in', (tester) async {
      final c = await launch(tester);
      expect(location(c), '/sign-in');
    });

    testWidgets('a deep link goes to /sign-in carrying the link', (tester) async {
      final c = await launch(tester, at: '/staff');
      expect(location(c), '/sign-in?from=%2Fstaff');
    });

    testWidgets('cannot open /verify or /change-password', (tester) async {
      final c = await launch(tester);
      c.read(routerProvider).go('/verify');
      await tester.pumpAndSettle();
      expect(location(c), '/sign-in');
      c.read(routerProvider).go('/change-password');
      await tester.pumpAndSettle();
      expect(location(c).startsWith('/sign-in'), isTrue);
    });
  });

  group('launch', () {
    testWidgets('shows a spinner at /loading while the session is restored, never the sign-in screen', (tester) async {
      await seed('full');
      final gate = Completer<void>();
      repo.refreshGate = gate.future;
      final container = ProviderContainer(
        overrides: [tokenStorageProvider.overrideWithValue(tokens), authRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final router = container.read(routerProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: SbTheme.light(),
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();
      expect(router.routeInformationProvider.value.uri.path, '/loading');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Sign in to your salon'), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/');
    });
  });

  group('limited session', () {
    testWidgets('every route goes to /verify', (tester) async {
      await seed('limited');
      final c = await launch(tester);
      expect(location(c), '/verify');

      c.read(routerProvider).go('/staff');
      await tester.pumpAndSettle();
      expect(location(c), '/verify?from=%2Fstaff');
    });

    testWidgets('must-change-password still goes to /verify first', (tester) async {
      await seed('limited', mustChange: true);
      final c = await launch(tester);
      expect(location(c), '/verify');
    });
  });

  group('full session', () {
    testWidgets('lands on Today and /sign-in, /verify and /loading bounce back to /', (tester) async {
      await seed('full');
      final c = await launch(tester);
      expect(location(c), '/');
      for (final path in ['/sign-in', '/verify']) {
        c.read(routerProvider).go(path);
        await tester.pumpAndSettle();
        expect(location(c), '/', reason: path);
      }
    });

    testWidgets('must-change-password forces /change-password from every route', (tester) async {
      await seed('full', mustChange: true);
      final c = await launch(tester);
      expect(location(c), '/change-password');

      c.read(routerProvider).go('/');
      await tester.pumpAndSettle();
      expect(location(c), '/change-password');

      c.read(routerProvider).go('/staff');
      await tester.pumpAndSettle();
      expect(location(c), '/change-password?from=%2Fstaff');
    });

    testWidgets('/change-password stays reachable when not forced', (tester) async {
      await seed('full');
      final c = await launch(tester, at: '/change-password');
      expect(location(c), '/change-password');
    });

    testWidgets('a specialist deep link to a manager-only route lands on Today', (tester) async {
      await seed('full', user: kStaffUser);
      final c = await launch(tester, at: '/staff');
      expect(location(c), '/');
    });

    testWidgets('an owner may open /staff', (tester) async {
      await seed('full');
      final c = await launch(tester, at: '/staff');
      expect(location(c), '/staff');
    });
  });

  group('tier changes move the user', () {
    testWidgets('OTP_REQUIRED on a full session sends the user to /verify and back after verifying', (tester) async {
      await seed('full');
      final c = await launch(tester, at: '/staff');
      expect(location(c), '/staff');

      final parked = c.read(stepUpCoordinatorProvider.notifier).request();
      await tester.pumpAndSettle();
      expect(location(c), '/verify?from=%2Fstaff');

      await c.read(sessionControllerProvider.notifier).upgradeToFull(fullResponse());
      await tester.pumpAndSettle();
      expect(location(c), '/staff');
      c.read(stepUpCoordinatorProvider.notifier).resolve(true);
      expect(await parked, isTrue);
    });

    testWidgets('deep link survives sign in, verify and a forced password change', (tester) async {
      repo.loginResult = loginResponse(mustChangePassword: true);
      final c = await launch(tester, at: '/staff');
      expect(location(c), '/sign-in?from=%2Fstaff');

      await c.read(sessionControllerProvider.notifier).signIn('nimal', 'pw');
      await tester.pumpAndSettle();
      expect(location(c), '/verify?from=%2Fstaff');

      await c.read(sessionControllerProvider.notifier).upgradeToFull(fullResponse(mustChangePassword: true));
      await tester.pumpAndSettle();
      expect(location(c), '/change-password?from=%2Fstaff');

      await c.read(sessionControllerProvider.notifier).changePassword(current: 'a', next: 'b');
      c.read(routerProvider).go('/staff');
      await tester.pumpAndSettle();
      expect(location(c), '/staff');
    });

    testWidgets('a specialist who signs in with an owner-only deep link lands on Today', (tester) async {
      repo.loginResult = loginResponse(user: kStaffUser);
      final c = await launch(tester, at: '/staff');
      await c.read(sessionControllerProvider.notifier).signIn('kamal', 'pw');
      await tester.pumpAndSettle();
      await c.read(sessionControllerProvider.notifier).upgradeToFull(fullResponse());
      await tester.pumpAndSettle();
      expect(location(c), '/');
    });

    testWidgets('sign out returns to /sign-in', (tester) async {
      await seed('full');
      final c = await launch(tester);
      await c.read(sessionControllerProvider.notifier).signOut();
      await tester.pumpAndSettle();
      expect(location(c), '/sign-in');
    });

    testWidgets('an expired session returns to /sign-in with the expired banner', (tester) async {
      await seed('full');
      final c = await launch(tester);
      await c.read(sessionControllerProvider.notifier).expire('TOKEN_REVOKED');
      await tester.pumpAndSettle();
      expect(location(c), '/sign-in');
      expect(find.text('Your session has expired. Please sign in again.'), findsOneWidget);
    });
  });

  test('an open redirect through from is not followed', () {
    expect(safeFromTarget('//evil.example'), isNull);
    expect(safeFromTarget('https://evil.example'), isNull);
    expect(safeFromTarget('/sign-in'), isNull);
    expect(safeFromTarget('/verify?from=/'), isNull);
    expect(safeFromTarget('/staff'), '/staff');
    expect(safeFromTarget(null), isNull);
  });
}
