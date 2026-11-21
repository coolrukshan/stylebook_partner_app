import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sb_core/sb_core.dart';

import 'providers.dart';

enum OtpStep { phone, code }
enum OtpStatus { idle, sending, verifying }

@immutable
class OtpState {
  const OtpState({
    this.step = OtpStep.phone,
    this.phone = '',
    this.status = OtpStatus.idle,
    this.fieldError,
    this.bannerError,
    this.resendSecondsLeft = 0,
    this.expiresIn = 300,
  });

  final OtpStep step;
  final String phone;
  final OtpStatus status;
  final String? fieldError;
  final String? bannerError;
  final int resendSecondsLeft;
  final int expiresIn;

  String? get e164Phone => Phone.toE164(phone);
  bool get canResend => resendSecondsLeft <= 0;

  OtpState copyWith({
    OtpStep? step,
    String? phone,
    OtpStatus? status,
    String? fieldError,
    bool clearFieldError = false,
    String? bannerError,
    bool clearBannerError = false,
    int? resendSecondsLeft,
    int? expiresIn,
  }) =>
      OtpState(
        step: step ?? this.step,
        phone: phone ?? this.phone,
        status: status ?? this.status,
        fieldError: clearFieldError ? null : (fieldError ?? this.fieldError),
        bannerError: clearBannerError ? null : (bannerError ?? this.bannerError),
        resendSecondsLeft: resendSecondsLeft ?? this.resendSecondsLeft,
        expiresIn: expiresIn ?? this.expiresIn,
      );
}

class OtpSignInController extends Notifier<OtpState> {
  Timer? _countdownTimer;

  @override
  OtpState build() {
    ref.onDispose(() {
      _countdownTimer?.cancel();
    });
    return const OtpState();
  }

  void setPhone(String phone) {
    state = state.copyWith(phone: phone, clearFieldError: true, clearBannerError: true);
  }

  void changeNumber() {
    state = state.copyWith(step: OtpStep.phone, clearFieldError: true, clearBannerError: true);
  }

  void _startCountdown(int seconds) {
    _countdownTimer?.cancel();
    state = state.copyWith(resendSecondsLeft: seconds);
    if (seconds <= 0) return;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.resendSecondsLeft <= 1) {
        timer.cancel();
        state = state.copyWith(resendSecondsLeft: 0);
      } else {
        state = state.copyWith(resendSecondsLeft: state.resendSecondsLeft - 1);
      }
    });
  }

  Future<bool> sendOtp() async {
    final e164 = Phone.toE164(state.phone);
    if (e164 == null) {
      state = state.copyWith(fieldError: 'errPhoneInvalid');
      return false;
    }

    state = state.copyWith(
      status: OtpStatus.sending,
      clearFieldError: true,
      clearBannerError: true,
    );

    try {
      final repo = ref.read(authRepositoryProvider);
      final response = await repo.sendOtp(e164);
      state = state.copyWith(
        step: OtpStep.code,
        status: OtpStatus.idle,
        expiresIn: response.expiresIn,
      );
      _startCountdown(response.retryAfter);
      return true;
    } on ApiError catch (e) {
      if (e.status == 422) {
        state = state.copyWith(status: OtpStatus.idle, fieldError: 'errPhoneInvalid');
      } else if (e.status == 429) {
        final backoff = e.retryAfter ?? 60;
        _startCountdown(backoff);
        state = state.copyWith(status: OtpStatus.idle, bannerError: 'errTooManyRequests');
      } else if (e.isOffline) {
        state = state.copyWith(status: OtpStatus.idle, bannerError: 'errOffline');
      } else if (e.status == 502) {
        state = state.copyWith(status: OtpStatus.idle, bannerError: 'errSmsProviderDown');
      } else {
        state = state.copyWith(status: OtpStatus.idle, bannerError: e.message);
      }
      return false;
    } catch (_) {
      state = state.copyWith(status: OtpStatus.idle, bannerError: 'errServer');
      return false;
    }
  }

  Future<bool> verifyOtp(String otp) async {
    final trimmed = otp.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(trimmed)) {
      return false;
    }

    final e164 = state.e164Phone;
    if (e164 == null) {
      state = state.copyWith(step: OtpStep.phone, fieldError: 'errPhoneInvalid');
      return false;
    }

    state = state.copyWith(
      status: OtpStatus.verifying,
      clearFieldError: true,
      clearBannerError: true,
    );

    try {
      final repo = ref.read(authRepositoryProvider);
      final response = await repo.verifyOtp(e164, trimmed);
      state = state.copyWith(status: OtpStatus.idle);
      await ref.read(sessionControllerProvider.notifier).completeSignIn(response);
      return true;
    } on ApiError catch (e) {
      if (e.status == 400) {
        state = state.copyWith(status: OtpStatus.idle, fieldError: 'errOtpWrong');
      } else if (e.status == 410) {
        _countdownTimer?.cancel();
        state = state.copyWith(
          status: OtpStatus.idle,
          fieldError: 'errOtpExpired',
          resendSecondsLeft: 0,
        );
      } else if (e.status == 429) {
        final backoff = e.retryAfter ?? 60;
        _startCountdown(backoff);
        state = state.copyWith(status: OtpStatus.idle, bannerError: 'errTooManyRequests');
      } else if (e.isOffline) {
        state = state.copyWith(status: OtpStatus.idle, bannerError: 'errOffline');
      } else {
        state = state.copyWith(status: OtpStatus.idle, bannerError: e.message);
      }
      return false;
    } catch (_) {
      state = state.copyWith(status: OtpStatus.idle, bannerError: 'errServer');
      return false;
    }
  }
}

final otpSignInControllerProvider =
    NotifierProvider<OtpSignInController, OtpState>(OtpSignInController.new);
