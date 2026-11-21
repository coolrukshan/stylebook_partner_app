import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sb_api/sb_api.dart';
import 'package:sb_core/sb_core.dart';

import '../data/auth_repository.dart';
import 'session_controller.dart';
import 'step_up_coordinator.dart';

/// Epoch counter bumped whenever a session expires or user signs out.
class SessionEpochNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
}

final sessionEpochProvider = NotifierProvider<SessionEpochNotifier, int>(SessionEpochNotifier.new);

/// Counter bumped when a password change completed. An app-level listener shows the notice,
/// so it survives the change-password screen being replaced by a step-up mid-request.
class PasswordChangedSignal extends Notifier<int> {
  @override
  int build() => 0;

  void notify() => state++;
}

final passwordChangedSignalProvider = NotifierProvider<PasswordChangedSignal, int>(PasswordChangedSignal.new);

/// Secure token storage provider.
final tokenStorageProvider = Provider<TokenStorage>((ref) => const SecureTokenStorage());

/// Configured Dio instance with auth, OTP_REQUIRED and salon header interceptors.
final dioProvider = Provider<Dio>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  return buildDio(
    tokenStorage: tokenStorage,
    onSessionExpired: (code) => unawaited(ref.read(sessionControllerProvider.notifier).expire(code)),
    onOtpRequired: () => ref.read(stepUpCoordinatorProvider.notifier).request(),
    salonIdProvider: () => ref.read(currentUserProvider)?.salonId,
  );
});

/// Auth repository provider.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(dio: ref.watch(dioProvider), tokenStorage: ref.watch(tokenStorageProvider));
});

/// Session controller provider.
final sessionControllerProvider = AsyncNotifierProvider<SessionController, AuthState>(SessionController.new);

/// True while a call is parked waiting for the user to verify their phone.
final stepUpCoordinatorProvider = NotifierProvider<StepUpCoordinator, bool>(StepUpCoordinator.new);

/// Convenience provider for current authenticated user.
final currentUserProvider = Provider<SessionUser?>((ref) {
  return ref.watch(sessionControllerProvider).value?.user;
});

/// Convenience provider for current user role.
final currentRoleProvider = Provider<Role?>((ref) {
  return ref.watch(currentUserProvider)?.role;
});
