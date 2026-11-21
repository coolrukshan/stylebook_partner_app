import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// Bridges the HTTP layer (403 OTP_REQUIRED) and the Verify code screen.
///
/// `state` is true while a call is parked waiting for step-up. One request is shared by
/// every parked call.
class StepUpCoordinator extends Notifier<bool> {
  Completer<bool>? _pending;

  @override
  bool build() => false;

  /// Parks the caller until step-up succeeds (true) or is cancelled / the session ends (false).
  Future<bool> request() {
    final completer = _pending ??= Completer<bool>();
    state = true;
    ref.read(sessionControllerProvider.notifier).markStepUpRequired();
    return completer.future;
  }

  void resolve(bool success) {
    final completer = _pending;
    _pending = null;
    if (state) state = false;
    if (completer != null && !completer.isCompleted) completer.complete(success);
  }
}
