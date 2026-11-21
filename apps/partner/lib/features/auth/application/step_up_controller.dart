import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sb_core/sb_core.dart';

import 'countdown.dart';
import 'providers.dart';

enum StepUpStatus { idle, sending, verifying }

enum StepUpError {
  invalidCode,
  expired,
  maxAttempts,
  noPendingCode,
  rateLimited,
  smsFailed,
  unavailable,
  noPhone,
  offline,
  server,
  unknown,
}

@immutable
class StepUpState {
  const StepUpState({
    this.status = StepUpStatus.idle,
    this.error,
    this.serverMessage,
    this.phoneMasked,
    this.resendSecondsLeft = 0,
    this.clearSignal = 0,
  });

  final StepUpStatus status;
  final StepUpError? error;

  /// Server `message`, shown only for [StepUpError.unknown].
  final String? serverMessage;

  /// Exactly as returned by the API (for example `+9477***4567`).
  final String? phoneMasked;
  final int resendSecondsLeft;

  /// Bumped after a wrong code so the OTP boxes clear.
  final int clearSignal;

  bool get isBlocked => error == StepUpError.noPhone;
  bool get isBusy => status != StepUpStatus.idle;
  bool get canResend => resendSecondsLeft <= 0 && !isBusy && !isBlocked;

  StepUpState copyWith({
    StepUpStatus? status,
    StepUpError? error,
    bool clearError = false,
    String? serverMessage,
    String? phoneMasked,
    int? resendSecondsLeft,
    int? clearSignal,
  }) => StepUpState(
    status: status ?? this.status,
    error: clearError ? null : (error ?? this.error),
    serverMessage: clearError ? null : (serverMessage ?? this.serverMessage),
    phoneMasked: phoneMasked ?? this.phoneMasked,
    resendSecondsLeft: resendSecondsLeft ?? this.resendSecondsLeft,
    clearSignal: clearSignal ?? this.clearSignal,
  );
}

/// Backend-enforced step-up: send the SMS code, verify it, upgrade to a full session.
class StepUpController extends Notifier<StepUpState> {
  late final Countdown _countdown;
  var _autoSent = false;

  @override
  StepUpState build() {
    _countdown = Countdown((left) {
      if (ref.mounted) state = state.copyWith(resendSecondsLeft: left);
    });
    ref.onDispose(_countdown.stop);
    return const StepUpState();
  }

  /// Sends the first code for this screen. Safe to call on every build: it sends once.
  Future<void> ensureSent() async {
    if (_autoSent) return;
    _autoSent = true;
    await send();
  }

  /// Resend: only when the countdown has finished.
  Future<void> resend() async {
    if (!state.canResend) return;
    await send();
  }

  Future<void> send() async {
    if (state.status == StepUpStatus.sending) return;
    state = state.copyWith(status: StepUpStatus.sending, clearError: true);
    try {
      final response = await ref.read(authRepositoryProvider).sendOtp();
      if (!ref.mounted) return;
      state = state.copyWith(status: StepUpStatus.idle, phoneMasked: response.phoneMasked);
      _countdown.start(response.retryAfter);
    } on ApiError catch (e) {
      _fail(e, forSend: true);
    } catch (_) {
      _setError(StepUpError.server);
    }
  }

  /// Submits the code once. Returns true when the session became full.
  Future<bool> verify(String code) async {
    if (state.status == StepUpStatus.verifying || !RegExp(r'^[0-9]{6}$').hasMatch(code)) return false;
    state = state.copyWith(status: StepUpStatus.verifying, clearError: true);
    try {
      final response = await ref.read(authRepositoryProvider).verifyOtp(code);
      await ref.read(sessionControllerProvider.notifier).upgradeToFull(response);
      ref.read(stepUpCoordinatorProvider.notifier).resolve(true);
      if (ref.mounted) state = state.copyWith(status: StepUpStatus.idle);
      return true;
    } on ApiError catch (e) {
      _fail(e, forSend: false);
      return false;
    } catch (_) {
      _setError(StepUpError.server);
      return false;
    }
  }

  /// Only offered when the screen was opened by a parked OTP_REQUIRED call.
  void cancel() => ref.read(stepUpCoordinatorProvider.notifier).resolve(false);

  Future<void> signOut() => ref.read(sessionControllerProvider.notifier).signOut();

  void _fail(ApiError e, {required bool forSend}) {
    if (!ref.mounted) return;
    final retryAfter = e.retryAfter ?? 0;

    if (e.isOffline) return _setError(StepUpError.offline);

    switch (e.code) {
      case 'OTP_INVALID':
        _setError(StepUpError.invalidCode, clearBoxes: true);
      case 'OTP_EXPIRED':
        _countdown.stop();
        _setError(StepUpError.expired, seconds: 0);
      case 'OTP_MAX_ATTEMPTS':
        _setError(StepUpError.maxAttempts, seconds: retryAfter, clearBoxes: true);
      case 'RATE_LIMITED':
        _setError(StepUpError.rateLimited, seconds: retryAfter);
      case 'SMS_DELIVERY_FAILED':
        _setError(StepUpError.smsFailed);
      case 'RATE_LIMIT_UNAVAILABLE':
        _setError(StepUpError.unavailable);
      case 'NOT_FOUND' when !forSend:
        _setError(StepUpError.noPendingCode);
      default:
        // The 409 "no phone" code is undocumented (plan Gap 10), so it is recognised by status.
        if (forSend && e.status == 409) {
          _setError(StepUpError.noPhone);
        } else if (e.isServer) {
          _setError(StepUpError.server);
        } else {
          _setError(StepUpError.unknown, message: e.message);
        }
    }
  }

  void _setError(StepUpError error, {int? seconds, bool clearBoxes = false, String? message}) {
    if (!ref.mounted) return;
    state = state.copyWith(
      status: StepUpStatus.idle,
      error: error,
      serverMessage: message,
      clearSignal: clearBoxes ? state.clearSignal + 1 : null,
    );
    if (seconds != null) _countdown.start(seconds);
  }
}

final stepUpControllerProvider = NotifierProvider.autoDispose<StepUpController, StepUpState>(StepUpController.new);
