import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sb_core/sb_core.dart';
import 'package:stylebook_partner/features/auth/application/providers.dart';
import 'package:stylebook_partner/features/auth/application/session_controller.dart';
import 'package:stylebook_partner/features/auth/application/sign_in_controller.dart';
import 'package:stylebook_partner/features/auth/data/models/partner_user_out.dart';

import '../../../support/fakes.dart';

void main() {
  late InMemoryTokenStorage tokens;
  late FakeAuthRepository repo;

  setUp(() {
    tokens = InMemoryTokenStorage();
    repo = FakeAuthRepository(tokens);
  });

  Future<ProviderContainer> start() async {
    final c = ProviderContainer(
      overrides: [tokenStorageProvider.overrideWithValue(tokens), authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    c.listen(signInControllerProvider, (_, _) {});
    await c.read(sessionControllerProvider.future);
    return c;
  }

  SignInState read(ProviderContainer c) => c.read(signInControllerProvider);
  SignInController ctrl(ProviderContainer c) => c.read(signInControllerProvider.notifier);

  test('submit trims the username, sends the raw password once and signs in as limited', () async {
    final c = await start();
    await ctrl(c).submit('  nimal.kandy  ', ' pass word ');

    expect(repo.loginCalls.single, (username: 'nimal.kandy', password: ' pass word '));
    expect(read(c).error, isNull);
    expect(read(c).submitting, isFalse);
    expect(c.read(sessionControllerProvider).value, isA<Limited>());
  });

  test('empty username or password makes no request', () async {
    final c = await start();
    await ctrl(c).submit('', 'pw');
    await ctrl(c).submit('   ', 'pw');
    await ctrl(c).submit('nimal', '');
    expect(repo.loginCalls, isEmpty);
  });

  test('a second submit while one is running is ignored', () async {
    final c = await start();
    await Future.wait([ctrl(c).submit('a', 'b'), ctrl(c).submit('a', 'b')]);
    expect(repo.loginCalls.length, 1);
  });

  test('INVALID_CREDENTIALS: one generic error and the password field is told to clear', () async {
    repo.loginError = apiError(401, 'INVALID_CREDENTIALS');
    final c = await start();
    final before = read(c).passwordResetSignal;

    await ctrl(c).submit('nimal', 'wrong');

    expect(read(c).error, SignInError.invalidCredentials);
    expect(read(c).passwordResetSignal, before + 1);
    expect(read(c).submitting, isFalse);
  });

  test('ACCOUNT_LOCKED locks sign in for Retry-After seconds and never retries by itself', () {
    fakeAsync((async) {
      repo.loginError = apiError(429, 'ACCOUNT_LOCKED', retryAfter: 90);
      late ProviderContainer c;
      start().then((v) => c = v);
      async.flushMicrotasks();

      ctrl(c).submit('nimal', 'pw');
      async.flushMicrotasks();
      expect(read(c).error, SignInError.accountLocked);
      expect(read(c).lockSecondsLeft, 90);
      expect(read(c).isLocked, isTrue);

      async.elapse(const Duration(seconds: 89));
      expect(read(c).lockSecondsLeft, 1);
      async.elapse(const Duration(seconds: 1));
      expect(read(c).lockSecondsLeft, 0);
      expect(read(c).isLocked, isFalse);
      expect(repo.loginCalls.length, 1);
      c.dispose();
    });
  });

  test('a submit during a lockout is ignored', () async {
    repo.loginError = apiError(429, 'ACCOUNT_LOCKED', retryAfter: 90);
    final c = await start();
    await ctrl(c).submit('nimal', 'pw');
    await ctrl(c).submit('nimal', 'pw');
    expect(repo.loginCalls.length, 1);
  });

  test('RATE_LIMITED without Retry-After shows the generic message and does not lock', () async {
    repo.loginError = apiError(429, 'RATE_LIMITED');
    final c = await start();
    await ctrl(c).submit('nimal', 'pw');
    expect(read(c).error, SignInError.rateLimited);
    expect(read(c).isLocked, isFalse);
  });

  test('RATE_LIMITED with Retry-After counts down', () async {
    repo.loginError = apiError(429, 'RATE_LIMITED', retryAfter: 30);
    final c = await start();
    await ctrl(c).submit('nimal', 'pw');
    expect(read(c).error, SignInError.rateLimited);
    expect(read(c).lockSecondsLeft, 30);
  });

  test('403 account codes map to their own errors and store no tokens', () async {
    final c = await start();
    for (final entry in {
      'ACCOUNT_SUSPENDED': SignInError.suspended,
      'ACCOUNT_DISABLED': SignInError.disabled,
      'NOT_SALON_MEMBER': SignInError.noSalonAccess,
    }.entries) {
      repo.loginError = apiError(403, entry.key);
      await ctrl(c).submit('nimal', 'pw');
      expect(read(c).error, entry.value, reason: entry.key);
    }
    expect(await tokens.getAccessToken(), isNull);
  });

  test('an account with no salons shows the no-access error', () async {
    repo.loginResult = loginResponse(
      user: const PartnerUserOut(id: 'u', fullName: null, salons: []),
    );
    final c = await start();
    await ctrl(c).submit('nimal', 'pw');
    expect(read(c).error, SignInError.noSalonAccess);
    expect(c.read(sessionControllerProvider).value, isA<Unauthenticated>());
  });

  test('503, offline, 500 and unknown codes', () async {
    final c = await start();
    repo.loginError = apiError(503, 'RATE_LIMIT_UNAVAILABLE');
    await ctrl(c).submit('a', 'b');
    expect(read(c).error, SignInError.unavailable);

    repo.loginError = ApiError.offline();
    await ctrl(c).submit('a', 'b');
    expect(read(c).error, SignInError.offline);

    repo.loginError = ApiError.server();
    await ctrl(c).submit('a', 'b');
    expect(read(c).error, SignInError.server);

    repo.loginError = apiError(400, 'BRAND_NEW', message: 'Please call us');
    await ctrl(c).submit('a', 'b');
    expect(read(c).error, SignInError.unknown);
    expect(read(c).serverMessage, 'Please call us');
  });

  test('clearError dismisses the banner', () async {
    repo.loginError = apiError(401, 'INVALID_CREDENTIALS');
    final c = await start();
    await ctrl(c).submit('a', 'b');
    ctrl(c).clearError();
    expect(read(c).error, isNull);
  });
}
