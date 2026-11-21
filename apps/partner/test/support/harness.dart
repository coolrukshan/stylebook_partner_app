import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sb_core/sb_core.dart';
import 'package:sb_ui/sb_ui.dart';
import 'package:stylebook_partner/features/auth/application/providers.dart';
import 'package:stylebook_partner/features/auth/data/models/partner_user_out.dart';
import 'package:stylebook_partner/features/auth/presentation/widgets/session_notices.dart';
import 'package:stylebook_partner/l10n/app_localizations.dart';

import 'fakes.dart';

/// Wires a screen into a tiny router (`/screen`, and `/` showing HOME) with fakes for the API.
class ScreenHarness {
  ScreenHarness({this.tier, this.mustChange = false, this.user = kOwnerUser}) : tokens = InMemoryTokenStorage() {
    repo = FakeAuthRepository(tokens);
  }

  /// null = signed out; otherwise `limited` or `full`.
  final String? tier;
  final bool mustChange;
  final PartnerUserOut user;
  final InMemoryTokenStorage tokens;
  late final FakeAuthRepository repo;

  Future<void> seed() async {
    if (tier == null) return;
    await tokens.saveTokens(accessToken: 'acc', refreshToken: 'ref');
    await tokens.saveCachedUser(jsonEncode({'user': user.toJson(), 'tier': tier, 'must_change_password': mustChange}));
  }

  ProviderContainer container(WidgetTester tester, Type screen) =>
      ProviderScope.containerOf(tester.element(find.byType(screen)));

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(390, 844),
    double textScale = 1,
    String location = '/screen',
  }) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await seed();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(path: '/screen', builder: (_, _) => screen),
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('HOME')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [tokenStorageProvider.overrideWithValue(tokens), authRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(
          theme: SbTheme.light(),
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => Consumer(
            // The real app's router watches the session, so it is always built.
            builder: (context, ref, _) {
              ref.watch(sessionControllerProvider);
              return SessionNotices(
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
                  child: child!,
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> enterOtp(WidgetTester tester, String code) async {
  final boxes = find.byType(TextField);
  for (var i = 0; i < code.length; i++) {
    await tester.enterText(boxes.at(i), code[i]);
    await tester.pump();
  }
}
