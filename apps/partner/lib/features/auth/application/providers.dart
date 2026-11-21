import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sb_api/sb_api.dart';
import 'package:sb_core/sb_core.dart';

import '../data/auth_repository.dart';
import 'session_controller.dart';

/// Epoch counter bumped whenever a session expires or user signs out.
class SessionEpochNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
}

final sessionEpochProvider = NotifierProvider<SessionEpochNotifier, int>(SessionEpochNotifier.new);

/// Secure token storage provider.
final tokenStorageProvider = Provider<TokenStorage>((ref) => const SecureTokenStorage());

/// Configured Dio instance with auth and salon header interceptors.
final dioProvider = Provider<Dio>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  return buildDio(
    tokenStorage: tokenStorage,
    onSessionExpired: (_) {
      ref.read(sessionEpochProvider.notifier).increment();
      ref.invalidate(sessionControllerProvider);
    },
    salonIdProvider: () => ref.read(currentUserProvider)?.salonId,
  );
});

/// Auth repository provider.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    dio: ref.watch(dioProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});

/// Session controller provider.
final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, AuthState>(SessionController.new);

/// Convenience provider for current authenticated user.
final currentUserProvider = Provider<SessionUser?>((ref) {
  return ref.watch(sessionControllerProvider).value?.user;
});

/// Convenience provider for current user role.
final currentRoleProvider = Provider<Role?>((ref) {
  return ref.watch(currentUserProvider)?.role;
});
