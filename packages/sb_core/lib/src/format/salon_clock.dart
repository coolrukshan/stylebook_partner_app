import 'package:timezone/data/latest_10y.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Salon clock utility to convert UTC timestamps to salon timezone.
class SalonClock {
  static bool _initialized = false;

  static void ensureInitialized() {
    if (!_initialized) {
      tz_data.initializeTimeZones();
      _initialized = true;
    }
  }

  /// Converts a UTC [DateTime] to a timezone-aware [DateTime] in [timeZone].
  static DateTime toSalonTime(DateTime utc, [String timeZone = 'Asia/Colombo']) {
    ensureInitialized();
    try {
      final location = tz.getLocation(timeZone);
      return tz.TZDateTime.from(utc.toUtc(), location);
    } catch (_) {
      // Fallback: Colombo is UTC+05:30
      if (timeZone == 'Asia/Colombo') {
        return utc.toUtc().add(const Duration(hours: 5, minutes: 30));
      }
      return utc.toLocal();
    }
  }
}
