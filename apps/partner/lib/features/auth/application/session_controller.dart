import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sb_core/sb_core.dart';

import '../data/models/sign_in_response.dart';
import 'providers.dart';

/// Sealed hierarchy representing current session state.
sealed class AuthState {
  const AuthState();
  SessionUser? get user => null;
}

class Unauthenticated extends AuthState {
  const Unauthenticated({this.reason});
  final String? reason;
}

class Authenticated extends AuthState {
  const Authenticated(this._user);
  final SessionUser _user;

  @override
  SessionUser get user => _user;
}

class NoSalonAccess extends AuthState {
  const NoSalonAccess([this.message = 'This mobile number is not registered with a salon.']);
  final String message;
}

/// Controller managing session authentication lifecycle.
class SessionController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final tokenStorage = ref.watch(tokenStorageProvider);
    final authRepo = ref.watch(authRepositoryProvider);

    final accessToken = await tokenStorage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      return const Unauthenticated();
    }

    try {
      final me = await authRepo.me();
      final role = Role.parse(me.role);
      if (role == null) {
        await tokenStorage.clearTokens();
        return const NoSalonAccess();
      }

      final salon = await authRepo.loadSalonContext();
      final sessionUser = SessionUser(
        id: me.id,
        fullName: me.fullName,
        phone: me.phone,
        avatarUrl: me.avatarUrl,
        role: role,
        salonId: salon.salonId,
        salonName: salon.salonName,
        timeZone: salon.timeZone ?? 'Asia/Colombo',
      );

      await tokenStorage.saveCachedUser(jsonEncode(sessionUser.toJson()));
      return Authenticated(sessionUser);
    } on ApiError catch (e) {
      if (e.status == 401) {
        await tokenStorage.clearTokens();
        return const Unauthenticated(reason: 'expired');
      }
      final cachedJson = await tokenStorage.getCachedUser();
      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          final user = SessionUser.fromJson(jsonDecode(cachedJson) as Map<String, dynamic>);
          return Authenticated(user);
        } catch (_) {}
      }
      return Unauthenticated(reason: e.isOffline ? 'offline' : 'error');
    } catch (_) {
      return const Unauthenticated(reason: 'error');
    }
  }

  /// Completes sign-in after OTP verification, bootstraps profile, and updates state.
  Future<void> completeSignIn(SignInResponse response) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final tokenStorage = ref.read(tokenStorageProvider);
      final authRepo = ref.read(authRepositoryProvider);

      await tokenStorage.saveTokens(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
      );

      final me = await authRepo.me();
      final role = Role.parse(me.role);
      if (role == null) {
        await tokenStorage.clearTokens();
        return const NoSalonAccess();
      }

      final salon = await authRepo.loadSalonContext();
      final sessionUser = SessionUser(
        id: me.id,
        fullName: me.fullName,
        phone: me.phone,
        avatarUrl: me.avatarUrl,
        role: role,
        salonId: salon.salonId,
        salonName: salon.salonName,
        timeZone: salon.timeZone ?? 'Asia/Colombo',
      );

      await tokenStorage.saveCachedUser(jsonEncode(sessionUser.toJson()));
      return Authenticated(sessionUser);
    });
  }

  /// Signs out, revoking refresh tokens and resetting the session epoch.
  Future<void> signOut() async {
    final authRepo = ref.read(authRepositoryProvider);
    await authRepo.logout();
    ref.read(sessionEpochProvider.notifier).increment();
    state = const AsyncValue.data(Unauthenticated());
  }
}
