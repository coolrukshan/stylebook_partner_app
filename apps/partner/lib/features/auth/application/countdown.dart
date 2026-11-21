import 'dart:async';

/// One-second tick used for resend and lockout countdowns.
const kCountdownTick = Duration(seconds: 1);

/// Counts down whole seconds and reports each value (including the start value and 0).
class Countdown {
  Countdown(this._onTick);

  final void Function(int secondsLeft) _onTick;
  Timer? _timer;

  void start(int seconds) {
    stop();
    final initial = seconds < 0 ? 0 : seconds;
    _onTick(initial);
    if (initial == 0) return;

    var left = initial;
    _timer = Timer.periodic(kCountdownTick, (timer) {
      left--;
      if (left <= 0) {
        timer.cancel();
        left = 0;
      }
      _onTick(left);
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
