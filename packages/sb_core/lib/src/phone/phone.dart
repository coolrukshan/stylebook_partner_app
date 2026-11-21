/// Pure phone normalisation for Sri Lankan mobile numbers.
abstract final class Phone {
  static final _digitsOnlyRegex = RegExp(r'\D');

  /// Normalises a Sri Lankan phone string into E.164 format (`+947XXXXXXXX`).
  ///
  /// Accepts formats:
  /// - `0771234567`
  /// - `+94771234567`
  /// - `94771234567`
  /// - `771234567`
  ///
  /// Returns `null` if the input is not a valid 9-digit subscriber mobile number.
  static String? toE164(String? input) {
    if (input == null) return null;
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final cleaned = trimmed.replaceAll(_digitsOnlyRegex, '');

    String subscriber;
    if (cleaned.startsWith('94') && cleaned.length == 11) {
      subscriber = cleaned.substring(2);
    } else if (cleaned.startsWith('0') && cleaned.length == 10) {
      subscriber = cleaned.substring(1);
    } else if (cleaned.length == 9) {
      subscriber = cleaned;
    } else {
      return null;
    }

    // Sri Lankan mobile subscriber numbers start with 7 and are 9 digits
    if (!subscriber.startsWith('7') || subscriber.length != 9) {
      return null;
    }

    return '+94$subscriber';
  }

  /// Returns `true` if the phone number can be successfully normalised.
  static bool isValid(String? input) => toE164(input) != null;
}
