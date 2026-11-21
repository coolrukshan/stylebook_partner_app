import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sb_core/sb_core.dart';
import 'package:stylebook_partner/features/auth/application/providers.dart';
import 'package:stylebook_partner/features/auth/application/session_controller.dart';
import 'package:stylebook_partner/features/auth/data/models/partner_user_out.dart';

import '../../../support/fakes.dart';

void main() {
  late InMemoryTokenStorage tokens;
  late FakeAuthRepository repo;

  setUp(() {
    tokens = InMemoryTokenStorage();
    repo = FakeAuthRepository(tokens);
  });

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [tokenStorageProvider.overrideWithValue(tokens), authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> seed({required String tier, bool mustChange = false, PartnerUserOut user = kOwnerUser}) async {
    await tokens.saveTokens(accessToken: 'acc', refreshToken: 'ref');
    await tokens.saveCachedUser(jsonEncode({'user': user.toJson(), 'tier': tier, 'must_change_password': mustChange}));
  }

  AuthState? current(ProviderContainer c) => c.read(sessionControllerProvider).value;

  group('launch', () {
    test('no tokens: unauthenticated', () async {
      final c = container();
      expect(await c.read(sessionControllerProvider.future), isA<Unauthenticated>());
      expect(repo.refreshCalls, 0);
    });

    test('tokens but no cached user: tokens are cleared and the user is signed out', () async {
      await tokens.saveTokens(accessToken: 'acc', refreshToken: 'ref');
      final c = container();
      expect(await c.read(sessionControllerProvider.future), isA<Unauthenticated>());
      expect(await tokens.getAccessToken(), isNull);
    });

    test('restores a LIMITED session from storage, refreshes silently and replaces both tokens', () async {
      await seed(tier: 'limited', mustChange: true);
      final state = await container().read(sessionControllerProvider.future);

      expect(state, isA<Limited>());
      expect((state as Limited).mustChangePassword, isTrue);
      expect(state.user.id, 'u-1');
      expect(repo.refreshCalls, 1);
      expect(await tokens.getAccessToken(), 'refreshed-acc');
      expect(await tokens.getRefreshToken(), 'refreshed-ref');
    });

    test('refresh keeps the last known FULL tier (the refresh response has none)', () async {
      await seed(tier: 'full');
      final state = await container().read(sessionControllerProvider.future);
      expect(state, isA<Full>());
    });

    test('TOKEN_REVOKED on refresh clears tokens and signs out as expired', () async {
      await seed(tier: 'full');
      repo.refreshError = apiError(401, 'TOKEN_REVOKED');
      final state = await container().read(sessionControllerProvider.future);

      expect(state, isA<Unauthenticated>());
      expect((state as Unauthenticated).reason, SignedOutReason.expired);
      expect(await tokens.getAccessToken(), isNull);
      expect(await tokens.getCachedUser(), isNull);
    });

    test('ACCOUNT_SUSPENDED on refresh signs out as suspended', () async {
      await seed(tier: 'full');
      repo.refreshError = apiError(403, 'ACCOUNT_SUSPENDED');
      final state = await container().read(sessionControllerProvider.future);
      expect((state as Unauthenticated).reason, SignedOutReason.suspended);
    });

    test('offline at launch keeps the cached user and tokens', () async {
      await seed(tier: 'full');
      repo.refreshError = ApiError.offline();
      final state = await container().read(sessionControllerProvider.future);

      expect(state, isA<Full>());
      expect(await tokens.getAccessToken(), 'acc');
    });
  });

  group('signIn', () {
    test('login gives a LIMITED session, persists user and tier, owner role', () async {
      repo.loginResult = loginResponse(mustChangePassword: true);
      final c = container();
      await c.read(sessionControllerProvider.future);

      await c.read(sessionControllerProvider.notifier).signIn('nimal', 'pw');

      final state = current(c);
      expect(state, isA<Limited>());
      expect((state as Limited).mustChangePassword, isTrue);
      expect(state.user.role, Role.owner);
      expect(state.user.salonId, 's-1');
      expect(state.user.salonName, 'Elegance Salon');
      expect(state.user.fullName, 'Nimal Perera');
      expect(state.user.timeZone, 'Asia/Colombo');
      expect(await tokens.getAccessToken(), 'limited-acc');

      final cached = jsonDecode((await tokens.getCachedUser())!) as Map<String, dynamic>;
      expect(cached['tier'], 'limited');
      expect(cached['must_change_password'], true);
      expect((cached['user'] as Map)['id'], 'u-1');
      expect(jsonEncode(cached), isNot(contains('pw')));
      expect(jsonEncode(cached), isNot(contains('limited-acc')));
    });

    test('a user who is not an owner gets specialist level', () async {
      repo.loginResult = loginResponse(user: kStaffUser);
      final c = container();
      await c.read(sessionControllerProvider.future);
      await c.read(sessionControllerProvider.notifier).signIn('kamal', 'pw');
      expect(current(c)!.user!.role, Role.specialist);
    });

    test('errors are rethrown and the session stays unauthenticated with no tokens', () async {
      repo.loginError = apiError(401, 'INVALID_CREDENTIALS');
      final c = container();
      await c.read(sessionControllerProvider.future);

      await expectLater(
        c.read(sessionControllerProvider.notifier).signIn('a', 'b'),
        throwsA(isA<ApiError>().having((e) => e.code, 'code', 'INVALID_CREDENTIALS')),
      );
      expect(current(c), isA<Unauthenticated>());
      expect(await tokens.getAccessToken(), isNull);
    });

    test('an account with no salons is refused with NOT_SALON_MEMBER and tokens are cleared', () async {
      repo.loginResult = loginResponse(
        user: const PartnerUserOut(id: 'u-9', fullName: 'X', salons: []),
      );
      final c = container();
      await c.read(sessionControllerProvider.future);

      await expectLater(
        c.read(sessionControllerProvider.notifier).signIn('x', 'pw'),
        throwsA(isA<ApiError>().having((e) => e.code, 'code', 'NOT_SALON_MEMBER')),
      );
      expect(current(c), isA<Unauthenticated>());
      expect(await tokens.getAccessToken(), isNull);
      expect(await tokens.getCachedUser(), isNull);
    });

    test('cold start after sign in restores the same user from storage', () async {
      final first = container();
      await first.read(sessionControllerProvider.future);
      await first.read(sessionControllerProvider.notifier).signIn('nimal', 'pw');

      final second = container();
      final state = await second.read(sessionControllerProvider.future);
      expect(state, isA<Limited>());
      expect(state.user!.id, 'u-1');
    });
  });

  group('tier transitions', () {
    test('verify upgrades limited to full and takes must_change_password from the response', () async {
      repo.loginResult = loginResponse(mustChangePassword: true);
      final c = container();
      await c.read(sessionControllerProvider.future);
      final session = c.read(sessionControllerProvider.notifier);
      await session.signIn('nimal', 'pw');

      await session.upgradeToFull(fullResponse(mustChangePassword: true));

      expect(current(c), isA<Full>());
      expect((current(c) as Full).mustChangePassword, isTrue);
      expect(jsonDecode((await tokens.getCachedUser())!)['tier'], 'full');
    });

    test('changePassword clears must_change_password, stays full and replaces tokens', () async {
      await seed(tier: 'full', mustChange: true);
      final c = container();
      await c.read(sessionControllerProvider.future);

      await c.read(sessionControllerProvider.notifier).changePassword(current: 'Temp#1', next: 'New-Passw0rd');

      expect(current(c), isA<Full>());
      expect((current(c) as Full).mustChangePassword, isFalse);
      expect(repo.changeCalls.single, (current: 'Temp#1', next: 'New-Passw0rd'));
      expect(await tokens.getAccessToken(), 'changed-acc');
    });

    test('a failed changePassword rethrows and leaves the state alone', () async {
      await seed(tier: 'full', mustChange: true);
      repo.changeError = apiError(422, 'WEAK_PASSWORD');
      final c = container();
      await c.read(sessionControllerProvider.future);

      await expectLater(
        c.read(sessionControllerProvider.notifier).changePassword(current: 'a', next: 'b'),
        throwsA(isA<ApiError>()),
      );
      expect((current(c) as Full).mustChangePassword, isTrue);
    });

    test('OTP_REQUIRED corrects a full session to limited', () async {
      await seed(tier: 'full');
      final c = container();
      await c.read(sessionControllerProvider.future);

      c.read(sessionControllerProvider.notifier).markStepUpRequired();

      expect(current(c), isA<Limited>());
      expect(jsonDecode((await tokens.getCachedUser())!)['tier'], 'limited');
    });

    test('markStepUpRequired does nothing when signed out', () async {
      final c = container();
      await c.read(sessionControllerProvider.future);
      c.read(sessionControllerProvider.notifier).markStepUpRequired();
      expect(current(c), isA<Unauthenticated>());
    });
  });

  group('ending a session', () {
    test('signOut logs out, clears everything, bumps the epoch', () async {
      await seed(tier: 'full');
      final c = container();
      await c.read(sessionControllerProvider.future);
      final epoch = c.read(sessionEpochProvider);

      await c.read(sessionControllerProvider.notifier).signOut();

      expect(current(c), isA<Unauthenticated>());
      expect(repo.logoutCalls, 1);
      expect(c.read(sessionEpochProvider), epoch + 1);
      expect(await tokens.getAccessToken(), isNull);
      expect(await tokens.getCachedUser(), isNull);
    });

    test('expire with a TOKEN code signs out as expired and clears the cache', () async {
      await seed(tier: 'full');
      final c = container();
      await c.read(sessionControllerProvider.future);
      final epoch = c.read(sessionEpochProvider);

      await c.read(sessionControllerProvider.notifier).expire('TOKEN_REVOKED');

      final state = current(c) as Unauthenticated;
      expect(state.reason, SignedOutReason.expired);
      expect(c.read(sessionEpochProvider), epoch + 1);
      expect(await tokens.getCachedUser(), isNull);
      expect(await tokens.getAccessToken(), isNull);
    });

    test('expire with ACCOUNT_SUSPENDED reports suspended', () async {
      await seed(tier: 'full');
      final c = container();
      await c.read(sessionControllerProvider.future);
      await c.read(sessionControllerProvider.notifier).expire('ACCOUNT_SUSPENDED');
      expect((current(c) as Unauthenticated).reason, SignedOutReason.suspended);
    });
  });
}
