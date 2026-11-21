import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sb_core/sb_core.dart';

import 'providers.dart';

enum ChangePasswordError { currentWrong, weak, mismatch }

enum ChangePasswordBanner { rateLimited, unavailable, offline, server, stepUpRequired, unknown }

@immutable
class ChangePasswordState {
  const ChangePasswordState({
    this.submitting = false,
    this.currentError,
    this.newError,
    this.newErrorMessage,
    this.confirmError,
    this.banner,
    this.bannerMessage,
    this.passwordResetSignal = 0,
  });

  final bool submitting;
  final ChangePasswordError? currentError;
  final ChangePasswordError? newError;

  /// Server `message` for [ChangePasswordError.weak] (the policy text; the API documents no rules).
  final String? newErrorMessage;
  final ChangePasswordError? confirmError;
  final ChangePasswordBanner? banner;
  final String? bannerMessage;

  /// Bumped when the password fields must be cleared (wrong current password).
  final int passwordResetSignal;

  ChangePasswordState copyWith({
    bool? submitting,
    ChangePasswordError? currentError,
    ChangePasswordError? newError,
    String? newErrorMessage,
    ChangePasswordError? confirmError,
    ChangePasswordBanner? banner,
    String? bannerMessage,
    int? passwordResetSignal,
    bool clearErrors = false,
  }) => ChangePasswordState(
    submitting: submitting ?? this.submitting,
    currentError: clearErrors ? currentError : (currentError ?? this.currentError),
    newError: clearErrors ? newError : (newError ?? this.newError),
    newErrorMessage: clearErrors ? newErrorMessage : (newErrorMessage ?? this.newErrorMessage),
    confirmError: clearErrors ? confirmError : (confirmError ?? this.confirmError),
    banner: clearErrors ? banner : (banner ?? this.banner),
    bannerMessage: clearErrors ? bannerMessage : (bannerMessage ?? this.bannerMessage),
    passwordResetSignal: passwordResetSignal ?? this.passwordResetSignal,
  );
}

/// Forced (or voluntary) password change. Values are passed through, never stored.
class ChangePasswordController extends Notifier<ChangePasswordState> {
  @override
  ChangePasswordState build() => const ChangePasswordState();

  /// Returns true when the password was changed.
  Future<bool> submit({required String current, required String next, required String confirm}) async {
    if (state.submitting || current.isEmpty || next.isEmpty) return false;

    if (next != confirm) {
      state = state.copyWith(clearErrors: true, confirmError: ChangePasswordError.mismatch);
      return false;
    }

    state = state.copyWith(submitting: true, clearErrors: true);
    try {
      await ref.read(sessionControllerProvider.notifier).changePassword(current: current, next: next);
      if (ref.mounted) state = state.copyWith(submitting: false);
      return true;
    } on ApiError catch (e) {
      _fail(e);
      return false;
    } catch (_) {
      _banner(ChangePasswordBanner.server);
      return false;
    }
  }

  void _fail(ApiError e) {
    if (!ref.mounted) return;
    if (e.isOffline) return _banner(ChangePasswordBanner.offline);

    switch (e.code) {
      case 'INVALID_CREDENTIALS':
        state = state.copyWith(
          submitting: false,
          currentError: ChangePasswordError.currentWrong,
          passwordResetSignal: state.passwordResetSignal + 1,
        );
      case 'WEAK_PASSWORD':
        state = state.copyWith(submitting: false, newError: ChangePasswordError.weak, newErrorMessage: e.message);
      case 'RATE_LIMITED':
        _banner(ChangePasswordBanner.rateLimited);
      case 'RATE_LIMIT_UNAVAILABLE':
        _banner(ChangePasswordBanner.unavailable);
      case 'OTP_REQUIRED':
        _banner(ChangePasswordBanner.stepUpRequired);
      default:
        if (e.code == 'VALIDATION_ERROR' && e.field == 'new_password') {
          state = state.copyWith(submitting: false, newError: ChangePasswordError.weak, newErrorMessage: e.message);
        } else if (e.isServer) {
          _banner(ChangePasswordBanner.server);
        } else {
          _banner(ChangePasswordBanner.unknown, message: e.message);
        }
    }
  }

  void _banner(ChangePasswordBanner banner, {String? message}) {
    if (!ref.mounted) return;
    state = state.copyWith(submitting: false, banner: banner, bannerMessage: message);
  }
}

final changePasswordControllerProvider = NotifierProvider.autoDispose<ChangePasswordController, ChangePasswordState>(
  ChangePasswordController.new,
);
