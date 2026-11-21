import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sb_core/sb_core.dart';

import 'countdown.dart';
import 'providers.dart';

enum SignInError {
  invalidCredentials,
  accountLocked,
  rateLimited,
  suspended,
  disabled,
  noSalonAccess,
  unavailable,
  offline,
  server,
  unknown,
}

@immutable
class SignInState {
  const SignInState({
    this.submitting = false,
    this.error,
    this.serverMessage,
    this.lockSecondsLeft = 0,
    this.passwordResetSignal = 0,
  });

  final bool submitting;
  final SignInError? error;
  final String? serverMessage;

  /// Seconds left of a lockout or rate limit (from Retry-After). Sign in stays disabled until 0.
  final int lockSecondsLeft;

  /// Bumped after wrong credentials so the screen clears and refocuses the password field.
  final int passwordResetSignal;

  bool get isLocked => lockSecondsLeft > 0;

  SignInState copyWith({
    bool? submitting,
    SignInError? error,
    bool clearError = false,
    String? serverMessage,
    int? lockSecondsLeft,
    int? passwordResetSignal,
  }) => SignInState(
    submitting: submitting ?? this.submitting,
    error: clearError ? null : (error ?? this.error),
    serverMessage: clearError ? null : (serverMessage ?? this.serverMessage),
    lockSecondsLeft: lockSecondsLeft ?? this.lockSecondsLeft,
    passwordResetSignal: passwordResetSignal ?? this.passwordResetSignal,
  );
}

/// Username + password sign in. Holds no password: it is passed through and dropped.
class SignInController extends Notifier<SignInState> {
  late final Countdown _lock;

  @override
  SignInState build() {
    _lock = Countdown((left) {
      if (!ref.mounted) return;
      final expired = left == 0 && (state.error == SignInError.accountLocked || state.error == SignInError.rateLimited);
      state = state.copyWith(lockSecondsLeft: left, clearError: expired);
    });
    ref.onDispose(_lock.stop);
    return const SignInState();
  }

  Future<void> submit(String username, String password) async {
    final name = username.trim();
    if (name.isEmpty || password.isEmpty || state.submitting || state.isLocked) return;

    state = state.copyWith(submitting: true, clearError: true);
    try {
      await ref.read(sessionControllerProvider.notifier).signIn(name, password);
      if (ref.mounted) state = state.copyWith(submitting: false);
    } on ApiError catch (e) {
      _fail(e);
    } catch (_) {
      _setError(SignInError.server);
    }
  }

  void clearError() => state = state.copyWith(clearError: true);

  void _fail(ApiError e) {
    if (!ref.mounted) return;
    final retryAfter = e.retryAfter ?? 0;
    switch (e.code) {
      case 'INVALID_CREDENTIALS':
        _setError(SignInError.invalidCredentials, resetPassword: true);
      case 'ACCOUNT_LOCKED' when retryAfter > 0:
        _setError(SignInError.accountLocked, seconds: retryAfter);
      case 'ACCOUNT_LOCKED' || 'RATE_LIMITED':
        _setError(SignInError.rateLimited, seconds: retryAfter);
      case 'ACCOUNT_SUSPENDED':
        _setError(SignInError.suspended);
      case 'ACCOUNT_DISABLED':
        _setError(SignInError.disabled);
      case 'NOT_SALON_MEMBER':
        _setError(SignInError.noSalonAccess);
      case 'RATE_LIMIT_UNAVAILABLE':
        _setError(SignInError.unavailable);
      default:
        if (e.isOffline) {
          _setError(SignInError.offline);
        } else if (e.isServer) {
          _setError(SignInError.server);
        } else {
          _setError(SignInError.unknown, message: e.message);
        }
    }
  }

  void _setError(SignInError error, {int seconds = 0, bool resetPassword = false, String? message}) {
    if (!ref.mounted) return;
    state = state.copyWith(
      submitting: false,
      error: error,
      serverMessage: message,
      passwordResetSignal: resetPassword ? state.passwordResetSignal + 1 : null,
    );
    if (seconds > 0) _lock.start(seconds);
  }
}

final signInControllerProvider = NotifierProvider.autoDispose<SignInController, SignInState>(SignInController.new);
