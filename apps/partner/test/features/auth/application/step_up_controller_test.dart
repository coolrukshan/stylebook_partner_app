import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sb_core/sb_core.dart';
import 'package:stylebook_partner/features/auth/application/providers.dart';
import 'package:stylebook_partner/features/auth/application/session_controller.dart';
import 'package:stylebook_partner/features/auth/application/step_up_controller.dart';
import 'package:stylebook_partner/features/auth/data/models/partner_otp_send_response.dart';

import '../../../support/fakes.dart';

void main() {
  late InMemoryTokenStorage tokens;
  late FakeAuthRepository repo;

  setUp(() async {
    tokens = InMemoryTokenStorage();
    repo = FakeAuthRepository(tokens);
    await tokens.saveTokens(accessToken: 'acc', refreshToken: 'ref');
    await tokens.saveCachedUser(
      jsonEncode({'user': kOwnerUser.toJson(), 'tier': 'limited', 'must_change_password': false}),
    );
  });

  Future<ProviderContainer> start() async {
    final c = ProviderContainer(
      overrides: [tokenStorageProvider.overrideWithValue(tokens), authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    c.listen(stepUpControllerProvider, (_, _) {});
    await c.read(sessionControllerProvider.future);
    return c;
  }

  StepUpState read(ProviderContainer c) => c.read(stepUpControllerProvider);
  StepUpController ctrl(ProviderContainer c) => c.read(stepUpControllerProvider.notifier);

  test('the controller survives a rebuild (invalidate) without a late-init error', () async {
    final c = await start();
    await ctrl(c).send();
    expect(read(c).resendSecondsLeft, greaterThan(0));

    c.invalidate(stepUpControllerProvider);
    expect(read(c).resendSecondsLeft, 0);

    await ctrl(c).send();
    expect(read(c).resendSecondsLeft, greaterThan(0));
  });

  group('send', () {
    test('ensureSent sends once, keeps phone_masked and starts the resend countdown from retry_after', () async {
      repo.sendResult = const PartnerOtpSendResponse(phoneMasked: '+9477***4567', retryAfter: 45);
      final c = await start();

      await ctrl(c).ensureSent();
      await ctrl(c).ensureSent();

      expect(repo.sendCalls, 1);
      expect(read(c).phoneMasked, '+9477***4567');
      expect(read(c).resendSecondsLeft, 45);
      expect(read(c).canResend, isFalse);
      expect(read(c).status, StepUpStatus.idle);
    });

    test('countdown reaches zero and then Resend sends a new code', () {
      fakeAsync((async) {
        late ProviderContainer c;
        start().then((v) => c = v);
        async.flushMicrotasks();
        ctrl(c).ensureSent();
        async.flushMicrotasks();
        expect(read(c).resendSecondsLeft, 60);

        ctrl(c).resend();
        async.flushMicrotasks();
        expect(repo.sendCalls, 1, reason: 'resend is blocked while the countdown runs');

        async.elapse(const Duration(seconds: 59));
        expect(read(c).resendSecondsLeft, 1);
        async.elapse(const Duration(seconds: 1));
        expect(read(c).resendSecondsLeft, 0);
        expect(read(c).canResend, isTrue);

        ctrl(c).resend();
        async.flushMicrotasks();
        expect(repo.sendCalls, 2);
        expect(read(c).resendSecondsLeft, 60);
        c.dispose();
      });
    });

    test('409 means no phone on the account: blocking', () async {
      repo.sendError = apiError(409, 'CONFLICT');
      final c = await start();
      await ctrl(c).ensureSent();
      expect(read(c).error, StepUpError.noPhone);
      expect(read(c).isBlocked, isTrue);
    });

    test('429 RATE_LIMITED starts a countdown from Retry-After', () async {
      repo.sendError = apiError(429, 'RATE_LIMITED', retryAfter: 30);
      final c = await start();
      await ctrl(c).ensureSent();
      expect(read(c).error, StepUpError.rateLimited);
      expect(read(c).resendSecondsLeft, 30);
    });

    test('SMS_DELIVERY_FAILED, RATE_LIMIT_UNAVAILABLE and offline map to their own errors', () async {
      final c = await start();
      repo.sendError = apiError(502, 'SMS_DELIVERY_FAILED');
      await ctrl(c).send();
      expect(read(c).error, StepUpError.smsFailed);

      repo.sendError = apiError(503, 'RATE_LIMIT_UNAVAILABLE');
      await ctrl(c).send();
      expect(read(c).error, StepUpError.unavailable);

      repo.sendError = ApiError.offline();
      await ctrl(c).send();
      expect(read(c).error, StepUpError.offline);
    });

    test('an unknown code shows the server message', () async {
      repo.sendError = apiError(400, 'SOMETHING_NEW', message: 'Server says no');
      final c = await start();
      await ctrl(c).send();
      expect(read(c).error, StepUpError.unknown);
      expect(read(c).serverMessage, 'Server says no');
    });
  });

  group('verify', () {
    test('success calls verify once, upgrades the session to full and resolves a parked request', () async {
      final c = await start();
      final parked = c.read(stepUpCoordinatorProvider.notifier).request();
      expect(c.read(stepUpCoordinatorProvider), isTrue);

      final ok = await ctrl(c).verify('482910');

      expect(ok, isTrue);
      expect(repo.verifyCalls, ['482910']);
      expect(c.read(sessionControllerProvider).value, isA<Full>());
      expect(await parked, isTrue);
      expect(c.read(stepUpCoordinatorProvider), isFalse);
      expect(await tokens.getAccessToken(), 'full-acc');
    });

    test('only submits once while a verification is running', () async {
      final c = await start();
      final a = ctrl(c).verify('111111');
      final b = ctrl(c).verify('111111');
      await Future.wait([a, b]);
      expect(repo.verifyCalls.length, 1);
    });

    test('ignores anything that is not exactly 6 digits', () async {
      final c = await start();
      expect(await ctrl(c).verify('12345'), isFalse);
      expect(await ctrl(c).verify('12345a'), isFalse);
      expect(repo.verifyCalls, isEmpty);
    });

    test('OTP_INVALID asks the boxes to clear and keeps the session limited', () async {
      repo.verifyError = apiError(400, 'OTP_INVALID');
      final c = await start();
      final before = read(c).clearSignal;

      expect(await ctrl(c).verify('000000'), isFalse);

      expect(read(c).error, StepUpError.invalidCode);
      expect(read(c).clearSignal, before + 1);
      expect(c.read(sessionControllerProvider).value, isA<Limited>());
    });

    test('OTP_EXPIRED offers a new code straight away', () async {
      repo.verifyError = apiError(410, 'OTP_EXPIRED');
      final c = await start();
      await ctrl(c).ensureSent();
      await ctrl(c).verify('000000');
      expect(read(c).error, StepUpError.expired);
      expect(read(c).canResend, isTrue);
    });

    test('OTP_MAX_ATTEMPTS forces a new code, limited by retry_after', () async {
      repo.verifyError = apiError(429, 'OTP_MAX_ATTEMPTS', retryAfter: 20);
      final c = await start();
      await ctrl(c).verify('000000');
      expect(read(c).error, StepUpError.maxAttempts);
      expect(read(c).resendSecondsLeft, 20);
    });

    test('404 NOT_FOUND means no code is waiting', () async {
      repo.verifyError = apiError(404, 'NOT_FOUND');
      final c = await start();
      await ctrl(c).verify('000000');
      expect(read(c).error, StepUpError.noPendingCode);
    });

    test('429 RATE_LIMITED on verify shows the rate limit with a countdown', () async {
      repo.verifyError = apiError(429, 'RATE_LIMITED', retryAfter: 15);
      final c = await start();
      await ctrl(c).verify('000000');
      expect(read(c).error, StepUpError.rateLimited);
      expect(read(c).resendSecondsLeft, 15);
    });
  });

  group('coordinator', () {
    test('request marks a full session as limited and shares one pending request', () async {
      await tokens.saveCachedUser(
        jsonEncode({'user': kOwnerUser.toJson(), 'tier': 'full', 'must_change_password': false}),
      );
      final c = await start();
      expect(c.read(sessionControllerProvider).value, isA<Full>());

      final coordinator = c.read(stepUpCoordinatorProvider.notifier);
      final a = coordinator.request();
      final b = coordinator.request();

      expect(identical(a, b), isTrue);
      expect(c.read(sessionControllerProvider).value, isA<Limited>());
      coordinator.resolve(false);
      expect(await a, isFalse);
    });

    test('cancel fails the parked request', () async {
      final c = await start();
      final parked = c.read(stepUpCoordinatorProvider.notifier).request();
      ctrl(c).cancel();
      expect(await parked, isFalse);
      expect(c.read(stepUpCoordinatorProvider), isFalse);
    });

    test('signing out fails the parked request', () async {
      final c = await start();
      final parked = c.read(stepUpCoordinatorProvider.notifier).request();
      await c.read(sessionControllerProvider.notifier).signOut();
      expect(await parked, isFalse);
    });
  });
}
