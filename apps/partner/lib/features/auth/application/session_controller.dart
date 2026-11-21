import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sb_core/sb_core.dart';

import '../data/models/partner_full_session_response.dart';
import '../data/models/partner_user_out.dart';
import 'providers.dart';

/// Why the user is signed out (drives the banner on the sign-in screen).
enum SignedOutReason { expired, suspended, disabled, noSalonAccess }

/// Session state: `Unauthenticated | Limited | Full`.
///
/// The tier mirrors what the server issued; the app never grants access by itself.
sealed class AuthState {
  const AuthState();
  SessionUser? get user => null;
}

final class Unauthenticated extends AuthState {
  const Unauthenticated({this.reason});
  final SignedOutReason? reason;
}

/// A signed-in session (limited or full).
sealed class SignedIn extends AuthState {
  const SignedIn({required this.partnerUser, required this.mustChangePassword});

  final PartnerUserOut partnerUser;
  final bool mustChangePassword;

  String get tier;

  /// Interim role rule (plan Gap D): owner if the first salon says so, otherwise specialist.
  @override
  SessionUser get user {
    final salon = partnerUser.salons.first;
    return SessionUser(
      id: partnerUser.id,
      fullName: partnerUser.fullName ?? '',
      role: salon.isOwner ? Role.owner : Role.specialist,
      salonId: salon.id,
      salonName: salon.name,
    );
  }

  Map<String, dynamic> toJson() => {
    'user': partnerUser.toJson(),
    'tier': tier,
    'must_change_password': mustChangePassword,
  };
}

/// Calendar view only. An SMS code upgrades it to [Full].
final class Limited extends SignedIn {
  const Limited({required super.partnerUser, required super.mustChangePassword});

  @override
  String get tier => 'limited';
}

final class Full extends SignedIn {
  const Full({required super.partnerUser, required super.mustChangePassword});

  @override
  String get tier => 'full';
}

/// Owns the session lifecycle: sign in, step-up, password change, expiry, sign out.
class SessionController extends AsyncNotifier<AuthState> {
  /// True from the start of a manual sign-out until local state is cleared.
  var _signingOut = false;

  @override
  Future<AuthState> build() async {
    final storage = ref.watch(tokenStorageProvider);
    final repo = ref.watch(authRepositoryProvider);

    final accessToken = await storage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      return const Unauthenticated();
    }

    final cached = _decode(await storage.getCachedUser());
    if (cached == null) {
      await _clearStorage();
      return const Unauthenticated();
    }

    final refreshToken = await storage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await _clearStorage();
      return const Unauthenticated();
    }

    try {
      // Silent refresh: rotates both tokens. The response has no tier, so keep the stored one.
      //
      // This deliberately does not share the interceptor's single-flight. It is safe because
      // `/v1/auth/refresh` is a public path (the interceptor never handles it) and, while this
      // future is pending, the router holds every screen on /loading, so no authenticated
      // request can start and trigger a second refresh with the same refresh token.
      await repo.refresh();
    } on ApiError catch (e) {
      if (e.status == 401 || e.status == 403) {
        await _clearStorage();
        return Unauthenticated(reason: _reasonFor(e.code));
      }
      // Offline or server trouble: open the cached session read-only.
    } catch (_) {
      // Same: keep the cached session.
    }
    return cached;
  }

  /// Username + password. Gives a LIMITED session. Throws [ApiError] on failure.
  Future<void> signIn(String username, String password) async {
    final response = await ref.read(authRepositoryProvider).login(username, password);
    if (response.user.salons.isEmpty) {
      await _clearStorage();
      // Never shown: the sign-in screen maps the code to localised copy.
      throw const ApiError(message: 'NOT_SALON_MEMBER', code: 'NOT_SALON_MEMBER', status: 403);
    }
    await _set(Limited(partnerUser: response.user, mustChangePassword: response.mustChangePassword));
  }

  /// After a successful OTP verify (tokens already replaced by the repository).
  Future<void> upgradeToFull(PartnerFullSessionResponse response) async {
    final current = state.value;
    if (current is! SignedIn) return;
    await _set(Full(partnerUser: current.partnerUser, mustChangePassword: response.mustChangePassword));
  }

  /// Forced or voluntary password change. Needs a full session. Throws [ApiError] on failure.
  Future<void> changePassword({required String current, required String next}) async {
    final response = await ref.read(authRepositoryProvider).changePassword(current: current, next: next);
    final session = state.value;
    if (session is! SignedIn) return;
    await _set(Full(partnerUser: session.partnerUser, mustChangePassword: response.mustChangePassword));
    ref.read(passwordChangedSignalProvider.notifier).notify();
  }

  /// The server answered 403 OTP_REQUIRED: the stored tier was too optimistic.
  void markStepUpRequired() {
    final session = state.value;
    if (session is! Full) return;
    final limited = Limited(partnerUser: session.partnerUser, mustChangePassword: session.mustChangePassword);
    state = AsyncData(limited);
    unawaited(_persistTier(limited));
  }

  /// Best effort: the in-memory tier is already corrected, and the server enforces the tier anyway.
  Future<void> _persistTier(SignedIn session) async {
    try {
      await ref.read(tokenStorageProvider).saveCachedUser(jsonEncode(session.toJson()));
    } catch (_) {
      // A failed cache write only means the next cold start trusts the server's 403 again.
    }
  }

  /// The session can no longer be refreshed (called by the auth interceptor).
  /// Ignored unless signed in: a late 401 after sign-out must not show "Session expired".
  Future<void> expire([String? code]) async {
    if (_signingOut || state.value is! SignedIn) return;
    await _clearStorage();
    _ended(Unauthenticated(reason: _reasonFor(code)));
  }

  /// Clears tokens, tier, user and cached data FIRST, then fires a best-effort server logout
  /// with the saved refresh token. The POST never delays or undoes the local clearing.
  Future<void> signOut() async {
    if (_signingOut) return;
    _signingOut = true;
    final repo = ref.read(authRepositoryProvider);
    try {
      final refreshToken = await repo.clearLocalSession();
      _ended(const Unauthenticated());
      unawaited(repo.revokeRefreshToken(refreshToken));
    } finally {
      _signingOut = false;
    }
  }

  void _ended(Unauthenticated next) {
    ref.read(sessionEpochProvider.notifier).increment();
    ref.read(stepUpCoordinatorProvider.notifier).resolve(false);
    state = AsyncData(next);
  }

  Future<void> _set(SignedIn next) async {
    await ref.read(tokenStorageProvider).saveCachedUser(jsonEncode(next.toJson()));
    state = AsyncData(next);
  }

  Future<void> _clearStorage() async {
    final storage = ref.read(tokenStorageProvider);
    await storage.clearTokens();
    await storage.clearCachedUser();
  }

  static SignedOutReason _reasonFor(String? code) => switch (code) {
    'ACCOUNT_SUSPENDED' => SignedOutReason.suspended,
    'ACCOUNT_DISABLED' => SignedOutReason.disabled,
    'NOT_SALON_MEMBER' => SignedOutReason.noSalonAccess,
    _ => SignedOutReason.expired,
  };

  static SignedIn? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final user = PartnerUserOut.fromJson(json['user'] as Map<String, dynamic>);
      if (user.salons.isEmpty) return null;
      final mustChange = json['must_change_password'] as bool? ?? false;
      return json['tier'] == 'full'
          ? Full(partnerUser: user, mustChangePassword: mustChange)
          : Limited(partnerUser: user, mustChangePassword: mustChange);
    } catch (_) {
      return null;
    }
  }
}
