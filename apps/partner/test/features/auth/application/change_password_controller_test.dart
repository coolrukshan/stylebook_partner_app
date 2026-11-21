import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sb_core/sb_core.dart';
import 'package:stylebook_partner/features/auth/application/change_password_controller.dart';
import 'package:stylebook_partner/features/auth/application/providers.dart';
import 'package:stylebook_partner/features/auth/application/session_controller.dart';

import '../../../support/fakes.dart';

void main() {
  late InMemoryTokenStorage tokens;
  late FakeAuthRepository repo;

  setUp(() async {
    tokens = InMemoryTokenStorage();
    repo = FakeAuthRepository(tokens);
    await tokens.saveTokens(accessToken: 'acc', refreshToken: 'ref');
    await tokens.saveCachedUser(
      jsonEncode({'user': kOwnerUser.toJson(), 'tier': 'full', 'must_change_password': true}),
    );
  });

  Future<ProviderContainer> start() async {
    final c = ProviderContainer(
      overrides: [tokenStorageProvider.overrideWithValue(tokens), authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    c.listen(changePasswordControllerProvider, (_, _) {});
    await c.read(sessionControllerProvider.future);
    return c;
  }

  ChangePasswordState read(ProviderContainer c) => c.read(changePasswordControllerProvider);
  ChangePasswordController ctrl(ProviderContainer c) => c.read(changePasswordControllerProvider.notifier);

  test('mismatching confirmation is a client-only check and makes no request', () async {
    final c = await start();
    expect(await ctrl(c).submit(current: 'Temp#1', next: 'abc', confirm: 'abd'), isFalse);
    expect(read(c).confirmError, ChangePasswordError.mismatch);
    expect(repo.changeCalls, isEmpty);
  });

  test('empty fields make no request', () async {
    final c = await start();
    expect(await ctrl(c).submit(current: '', next: 'abc', confirm: 'abc'), isFalse);
    expect(await ctrl(c).submit(current: 'a', next: '', confirm: ''), isFalse);
    expect(repo.changeCalls, isEmpty);
  });

  test('success sends current and new only (never the confirmation) and clears the forced flag', () async {
    final c = await start();
    expect(await ctrl(c).submit(current: 'Temp#1', next: 'My-New-Passw0rd', confirm: 'My-New-Passw0rd'), isTrue);

    expect(repo.changeCalls.single, (current: 'Temp#1', next: 'My-New-Passw0rd'));
    expect((c.read(sessionControllerProvider).value as Full).mustChangePassword, isFalse);
    expect(read(c).submitting, isFalse);
  });

  test('INVALID_CREDENTIALS marks the current password wrong and clears the password fields', () async {
    repo.changeError = apiError(400, 'INVALID_CREDENTIALS');
    final c = await start();
    final before = read(c).passwordResetSignal;

    expect(await ctrl(c).submit(current: 'bad', next: 'n', confirm: 'n'), isFalse);

    expect(read(c).currentError, ChangePasswordError.currentWrong);
    expect(read(c).passwordResetSignal, before + 1);
  });

  test('WEAK_PASSWORD puts the server message on the new password and keeps the values', () async {
    repo.changeError = apiError(422, 'WEAK_PASSWORD', message: 'At least 12 characters');
    final c = await start();
    final before = read(c).passwordResetSignal;

    await ctrl(c).submit(current: 'Temp#1', next: 'short', confirm: 'short');

    expect(read(c).newError, ChangePasswordError.weak);
    expect(read(c).newErrorMessage, 'At least 12 characters');
    expect(read(c).passwordResetSignal, before);
  });

  test('429, offline, 5xx, cancelled step-up and unknown codes become banners', () async {
    final c = await start();
    repo.changeError = apiError(429, 'RATE_LIMITED', retryAfter: 10);
    await ctrl(c).submit(current: 'a', next: 'b', confirm: 'b');
    expect(read(c).banner, ChangePasswordBanner.rateLimited);

    repo.changeError = ApiError.offline();
    await ctrl(c).submit(current: 'a', next: 'b', confirm: 'b');
    expect(read(c).banner, ChangePasswordBanner.offline);

    repo.changeError = ApiError.server();
    await ctrl(c).submit(current: 'a', next: 'b', confirm: 'b');
    expect(read(c).banner, ChangePasswordBanner.server);

    repo.changeError = apiError(403, 'OTP_REQUIRED');
    await ctrl(c).submit(current: 'a', next: 'b', confirm: 'b');
    expect(read(c).banner, ChangePasswordBanner.stepUpRequired);

    repo.changeError = apiError(400, 'BRAND_NEW', message: 'Server text');
    await ctrl(c).submit(current: 'a', next: 'b', confirm: 'b');
    expect(read(c).banner, ChangePasswordBanner.unknown);
    expect(read(c).bannerMessage, 'Server text');
  });

  test('a second submit while one runs is ignored', () async {
    final c = await start();
    await Future.wait([
      ctrl(c).submit(current: 'a', next: 'b', confirm: 'b'),
      ctrl(c).submit(current: 'a', next: 'b', confirm: 'b'),
    ]);
    expect(repo.changeCalls.length, 1);
  });
}
