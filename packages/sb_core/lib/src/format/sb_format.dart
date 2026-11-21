import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'salon_clock.dart';

/// Formatting utilities for currency and timestamps.
abstract final class SbFormat {
  static bool _localeInitialized = false;

  /// Ensures date symbol data is initialized for English formatting.
  static void ensureInitialized() {
    if (!_localeInitialized) {
      initializeDateFormatting('en', null);
      _localeInitialized = true;
    }
  }

  static final _currencyWhole = NumberFormat('#,##0', 'en');
  static final _currencyDecimals = NumberFormat('#,##0.00', 'en');

  static DateFormat get _dateTimeFormat {
    ensureInitialized();
    return DateFormat('EEE d MMM, h:mm a', 'en');
  }

  static DateFormat get _timeFormat {
    ensureInitialized();
    return DateFormat('h:mm a', 'en');
  }

  static DateFormat get _dayLabelFormat {
    ensureInitialized();
    return DateFormat('EEE d MMM', 'en');
  }

  /// Formats amount in cents to Sri Lankan Rupee representation (e.g. `150000` -> `LKR 1,500`).
  /// Omits decimal cents when remainder is zero.
  static String money(int cents) {
    if (cents % 100 == 0) {
      return 'LKR ${_currencyWhole.format(cents ~/ 100)}';
    }
    return 'LKR ${_currencyDecimals.format(cents / 100.0)}';
  }

  /// Formats a UTC timestamp to salon date & time string: `Thu 29 Oct, 9:30 AM`.
  static String dateTime(DateTime utc, {String timeZone = 'Asia/Colombo'}) {
    final salonTime = SalonClock.toSalonTime(utc, timeZone);
    return _dateTimeFormat.format(salonTime);
  }

  /// Formats a UTC timestamp to time string: `9:30 AM`.
  static String time(DateTime utc, {String timeZone = 'Asia/Colombo'}) {
    final salonTime = SalonClock.toSalonTime(utc, timeZone);
    return _timeFormat.format(salonTime);
  }

  /// Formats a UTC timestamp to day label: `Thu 29 Oct`.
  static String dayLabel(DateTime utc, {String timeZone = 'Asia/Colombo'}) {
    final salonTime = SalonClock.toSalonTime(utc, timeZone);
    return _dayLabelFormat.format(salonTime);
  }

  /// Formats a number of seconds as a countdown: `125` -> `2:05`.
  static String countdown(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    return '${safe ~/ 60}:${(safe % 60).toString().padLeft(2, '0')}';
  }
}
