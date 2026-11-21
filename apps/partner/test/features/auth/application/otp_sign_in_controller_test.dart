import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sb_core/sb_core.dart';
import 'package:stylebook_partner/features/auth/application/otp_controller.dart';
import 'package:stylebook_partner/features/auth/application/providers.dart';
import 'package:stylebook_partner/features/auth/data/auth_repository.dart';
import 'package:stylebook_partner/features/auth/data/models/otp_send_response.dart';
import 'package:stylebook_partner/features/auth/data/models/sign_in_response.dart';

class FakeAuthRepoForOtp implements AuthRepository {
  FakeAuthRepoForOtp({required this.tokenStorage});

  @override
  final TokenStorage tokenStorage;

  bool shouldThrowInvalidPhone = false;
  bool shouldThrow429 = false;
  bool shouldThrowWrongOtp = false;
  bool shouldThrowExpiredOtp = false;
  String? lastSentPhone;
  String? lastVerifiedOtp;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<OtpSendResponse> sendOtp(String e164) async {
    lastSentPhone = e164;
    if (shouldThrowInvalidPhone) {
      throw const ApiError(message: 'Invalid phone', status: 422, field: 'phone');
    }
    if (shouldThrow429) {
      throw const ApiError(message: 'Too many requests', status: 429, retryAfter: 45);
    }
    return const OtpSendResponse(message: 'OTP sent', expiresIn: 300, retryAfter: 30);
  }

  @override
  Future<SignInResponse> verifyOtp(String e164, String otp) async {
    lastVerifiedOtp = otp;
    if (shouldThrowWrongOtp) {
      throw const ApiError(message: 'Invalid OTP', status: 400, code: 'OTP_INVALID');
    }
    if (shouldThrowExpiredOtp) {
      throw const ApiError(message: 'Expired OTP', status: 410, code: 'OTP_EXPIRED');
    }
    return const SignInResponse(
      accessToken: 'acc',
      refreshToken: 'ref',
      tokenType: 'bearer',
      expiresIn: 900,
    );
  }
}

void main() {
  late InMemoryTokenStorage tokenStorage;
  late FakeAuthRepoForOtp fakeRepo;

  setUp(() {
    tokenStorage = InMemoryTokenStorage();
    fakeRepo = FakeAuthRepoForOtp(tokenStorage: tokenStorage);
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(tokenStorage),
        authRepositoryProvider.overrideWithValue(fakeRepo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('OtpSignInController', () {
    test('sendOtp with invalid local phone sets fieldError without calling repo', () async {
      final container = createContainer();
      final controller = container.read(otpSignInControllerProvider.notifier);

      controller.setPhone('123'); // invalid
      final success = await controller.sendOtp();

      expect(success, isFalse);
      final state = container.read(otpSignInControllerProvider);
      expect(state.fieldError, isNotNull);
      expect(state.step, equals(OtpStep.phone));
      expect(fakeRepo.lastSentPhone, isNull);
    });

    test('sendOtp with valid phone transitions to code step and sets countdown', () async {
      final container = createContainer();
      final controller = container.read(otpSignInControllerProvider.notifier);

      controller.setPhone('0771234567');
      final success = await controller.sendOtp();

      expect(success, isTrue);
      final state = container.read(otpSignInControllerProvider);
      expect(state.step, equals(OtpStep.code));
      expect(state.resendSecondsLeft, equals(30));
      expect(state.e164Phone, equals('+94771234567'));
      expect(fakeRepo.lastSentPhone, equals('+94771234567'));
    });

    test('sendOtp with 429 sets banner and backoff timer', () async {
      fakeRepo.shouldThrow429 = true;
      final container = createContainer();
      final controller = container.read(otpSignInControllerProvider.notifier);

      controller.setPhone('0771234567');
      final success = await controller.sendOtp();

      expect(success, isFalse);
      final state = container.read(otpSignInControllerProvider);
      expect(state.resendSecondsLeft, equals(45));
      expect(state.bannerError, isNotNull);
    });

    test('verifyOtp with < 6 digits does not call repo', () async {
      final container = createContainer();
      final controller = container.read(otpSignInControllerProvider.notifier);

      controller.setPhone('0771234567');
      await controller.sendOtp();

      final success = await controller.verifyOtp('12345'); // 5 digits
      expect(success, isFalse);
      expect(fakeRepo.lastVerifiedOtp, isNull);
    });

    test('verifyOtp with wrong code sets fieldError', () async {
      fakeRepo.shouldThrowWrongOtp = true;
      final container = createContainer();
      final controller = container.read(otpSignInControllerProvider.notifier);

      controller.setPhone('0771234567');
      await controller.sendOtp();

      final success = await controller.verifyOtp('123456');
      expect(success, isFalse);
      final state = container.read(otpSignInControllerProvider);
      expect(state.fieldError, isNotNull);
    });

    test('verifyOtp with expired code enables resend immediately', () async {
      fakeRepo.shouldThrowExpiredOtp = true;
      final container = createContainer();
      final controller = container.read(otpSignInControllerProvider.notifier);

      controller.setPhone('0771234567');
      await controller.sendOtp();
      expect(container.read(otpSignInControllerProvider).resendSecondsLeft, greaterThan(0));

      final success = await controller.verifyOtp('123456');
      expect(success, isFalse);
      final state = container.read(otpSignInControllerProvider);
      expect(state.resendSecondsLeft, equals(0)); // enabled resend
    });

    test('changeNumber navigates back to phone step', () async {
      final container = createContainer();
      final controller = container.read(otpSignInControllerProvider.notifier);

      controller.setPhone('0771234567');
      await controller.sendOtp();
      expect(container.read(otpSignInControllerProvider).step, equals(OtpStep.code));

      controller.changeNumber();
      expect(container.read(otpSignInControllerProvider).step, equals(OtpStep.phone));
    });
  });
}
