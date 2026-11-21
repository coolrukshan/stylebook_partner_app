import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sb_core/sb_core.dart';
import 'package:stylebook_partner/features/auth/application/providers.dart';
import 'package:stylebook_partner/features/auth/application/session_controller.dart';
import 'package:stylebook_partner/features/auth/data/auth_repository.dart';
import 'package:stylebook_partner/features/auth/data/models/partner_settings_out.dart';
import 'package:stylebook_partner/features/auth/data/models/sign_in_response.dart';
import 'package:stylebook_partner/features/auth/data/models/user_out.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    required this.tokenStorage,
    this.meResult,
    this.salonResult,
    this.shouldThrow401 = false,
    this.shouldThrowOffline = false,
  });

  @override
  final TokenStorage tokenStorage;
  UserOut? meResult;
  PartnerSettingsOut? salonResult;
  bool shouldThrow401;
  bool shouldThrowOffline;
  var logoutCalled = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<UserOut> me() async {
    if (shouldThrow401) {
      throw const ApiError(message: 'Unauthorized', status: 401);
    }
    if (shouldThrowOffline) {
      throw ApiError.offline();
    }
    return meResult ??
        const UserOut(
          id: 'u-1',
          phone: '+94771234567',
          fullName: 'Kasun Perera',
          role: 'owner',
        );
  }

  @override
  Future<PartnerSettingsOut> loadSalonContext() async {
    if (shouldThrow401) {
      throw const ApiError(message: 'Unauthorized', status: 401);
    }
    if (shouldThrowOffline) {
      throw ApiError.offline();
    }
    return salonResult ??
        const PartnerSettingsOut(
          salonId: 's-1',
          salonName: 'Elegance Salon',
          timeZone: 'Asia/Colombo',
        );
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
    await tokenStorage.clearTokens();
    await tokenStorage.clearCachedUser();
  }
}

void main() {
  late InMemoryTokenStorage tokenStorage;
  late FakeAuthRepository fakeRepo;

  setUp(() {
    tokenStorage = InMemoryTokenStorage();
    fakeRepo = FakeAuthRepository(tokenStorage: tokenStorage);
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

  group('SessionController', () {
    test('returns unauthenticated when no tokens are stored', () async {
      final container = createContainer();
      final state = await container.read(sessionControllerProvider.future);

      expect(state, isA<Unauthenticated>());
    });

    test('authenticates and loads user when valid tokens exist', () async {
      await tokenStorage.saveTokens(accessToken: 'acc', refreshToken: 'ref');

      final container = createContainer();
      final state = await container.read(sessionControllerProvider.future);

      expect(state, isA<Authenticated>());
      final user = (state as Authenticated).user;
      expect(user.id, equals('u-1'));
      expect(user.role, equals(Role.owner));
      expect(user.salonName, equals('Elegance Salon'));
    });

    test('clears tokens and returns unauthenticated on 401 error', () async {
      await tokenStorage.saveTokens(accessToken: 'bad-acc', refreshToken: 'bad-ref');
      fakeRepo.shouldThrow401 = true;

      final container = createContainer();
      final state = await container.read(sessionControllerProvider.future);

      expect(state, isA<Unauthenticated>());
      expect(await tokenStorage.getAccessToken(), isNull);
    });

    test('returns NoSalonAccess when user role is not salon role', () async {
      await tokenStorage.saveTokens(accessToken: 'acc', refreshToken: 'ref');
      fakeRepo.meResult = const UserOut(
        id: 'u-client',
        phone: '+94771234567',
        fullName: 'Client Person',
        role: 'client',
      );

      final container = createContainer();
      final state = await container.read(sessionControllerProvider.future);

      expect(state, isA<NoSalonAccess>());
    });

    test('completeSignIn stores tokens and authenticates user', () async {
      final container = createContainer();
      final controller = container.read(sessionControllerProvider.notifier);

      await controller.completeSignIn(
        const SignInResponse(
          accessToken: 'new-acc',
          refreshToken: 'new-ref',
          tokenType: 'bearer',
          expiresIn: 900,
        ),
      );

      final state = container.read(sessionControllerProvider).value;
      expect(state, isA<Authenticated>());
      expect(await tokenStorage.getAccessToken(), equals('new-acc'));
    });

    test('signOut clears tokens, bumps sessionEpoch, and transitions to unauthenticated', () async {
      await tokenStorage.saveTokens(accessToken: 'acc', refreshToken: 'ref');
      final container = createContainer();
      await container.read(sessionControllerProvider.future);

      final initialEpoch = container.read(sessionEpochProvider);
      final controller = container.read(sessionControllerProvider.notifier);

      await controller.signOut();

      final state = container.read(sessionControllerProvider).value;
      expect(state, isA<Unauthenticated>());
      expect(container.read(sessionEpochProvider), equals(initialEpoch + 1));
      expect(await tokenStorage.getAccessToken(), isNull);
    });
  });
}
