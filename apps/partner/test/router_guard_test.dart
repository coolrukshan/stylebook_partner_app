import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sb_core/sb_core.dart';
import 'package:stylebook_partner/features/auth/application/providers.dart';
import 'package:stylebook_partner/features/auth/data/auth_repository.dart';
import 'package:stylebook_partner/features/auth/data/models/partner_settings_out.dart';
import 'package:stylebook_partner/features/auth/data/models/user_out.dart';
import 'package:stylebook_partner/l10n/app_localizations.dart';
import 'package:stylebook_partner/router.dart';

class FakeAuthRepoForRouter implements AuthRepository {
  FakeAuthRepoForRouter(this.tokenStorage, {this.role = 'owner'});

  @override
  final TokenStorage tokenStorage;
  String role;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<UserOut> me() async {
    return UserOut(
      id: 'u-1',
      phone: '+94771234567',
      fullName: 'Test User',
      role: role,
    );
  }

  @override
  Future<PartnerSettingsOut> loadSalonContext() async {
    return const PartnerSettingsOut(
      salonId: 's-1',
      salonName: 'Test Salon',
      timeZone: 'Asia/Colombo',
    );
  }

  @override
  Future<void> logout() async {
    await tokenStorage.clearTokens();
  }
}

void main() {
  late InMemoryTokenStorage tokenStorage;

  setUp(() {
    tokenStorage = InMemoryTokenStorage();
  });

  Widget buildApp(ProviderContainer container) {
    final router = container.read(routerProvider);
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  group('Router Guard', () {
    testWidgets('unauthenticated user is redirected to /sign-in', (tester) async {
      final fakeRepo = FakeAuthRepoForRouter(tokenStorage);
      final container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(tokenStorage),
          authRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(sessionControllerProvider.future);

      await tester.pumpWidget(buildApp(container));
      await tester.pumpAndSettle();

      final router = container.read(routerProvider);
      expect(router.routeInformationProvider.value.uri.path, equals('/sign-in'));
    });

    testWidgets('authenticated user at /sign-in is redirected to /', (tester) async {
      await tokenStorage.saveTokens(accessToken: 'acc', refreshToken: 'ref');
      final fakeRepo = FakeAuthRepoForRouter(tokenStorage);
      final container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(tokenStorage),
          authRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(sessionControllerProvider.future);

      await tester.pumpWidget(buildApp(container));
      await tester.pumpAndSettle();

      final router = container.read(routerProvider);
      router.go('/sign-in');
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, equals('/'));
    });

    testWidgets('specialist navigating to manager-only route is redirected to /', (tester) async {
      await tokenStorage.saveTokens(accessToken: 'acc', refreshToken: 'ref');
      final fakeRepo = FakeAuthRepoForRouter(tokenStorage, role: 'specialist');
      final container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(tokenStorage),
          authRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(sessionControllerProvider.future);

      await tester.pumpWidget(buildApp(container));
      await tester.pumpAndSettle();

      final router = container.read(routerProvider);
      router.go('/staff');
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, equals('/'));
    });
  });
}
