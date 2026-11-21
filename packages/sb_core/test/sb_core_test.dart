import 'package:flutter_test/flutter_test.dart';
import 'package:sb_core/sb_core.dart';
import 'package:timezone/data/latest_10y.dart' as tz_data;

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
  });

  group('Phone', () {
    test('toE164 formats local Sri Lankan numbers correctly', () {
      expect(Phone.toE164('0771234567'), equals('+94771234567'));
      expect(Phone.toE164('+94771234567'), equals('+94771234567'));
      expect(Phone.toE164('94771234567'), equals('+94771234567'));
      expect(Phone.toE164('077 123 4567'), equals('+94771234567'));
      expect(Phone.toE164('771234567'), equals('+94771234567'));
    });

    test('toE164 returns null for invalid numbers', () {
      expect(Phone.toE164('abc'), isNull);
      expect(Phone.toE164('07712345'), isNull); // 8 digits
      expect(Phone.toE164(''), isNull);
      expect(Phone.toE164('1234567890123456'), isNull);
    });

    test('isValid validates correctly', () {
      expect(Phone.isValid('0771234567'), isTrue);
      expect(Phone.isValid('+94771234567'), isTrue);
      expect(Phone.isValid('abc'), isFalse);
    });
  });

  group('SbFormat', () {
    test('money formats cents with no decimals when whole amount', () {
      expect(SbFormat.money(150000), equals('LKR 1,500'));
      expect(SbFormat.money(0), equals('LKR 0'));
      expect(SbFormat.money(200000), equals('LKR 2,000'));
      expect(SbFormat.money(150050), equals('LKR 1,500.50'));
    });

    test('dateTime formats UTC in target timezone correctly', () {
      // 2026-10-29 04:00:00 UTC is 09:30 AM in Asia/Colombo (+05:30)
      final utc = DateTime.utc(2026, 10, 29, 4, 0);
      expect(SbFormat.dateTime(utc, timeZone: 'Asia/Colombo'), equals('Thu 29 Oct, 9:30 AM'));
      expect(SbFormat.time(utc, timeZone: 'Asia/Colombo'), equals('9:30 AM'));
      expect(SbFormat.dayLabel(utc, timeZone: 'Asia/Colombo'), equals('Thu 29 Oct'));
    });
  });

  group('Role', () {
    test('parse parses valid roles case-insensitively', () {
      expect(Role.parse('owner'), equals(Role.owner));
      expect(Role.parse('Owner'), equals(Role.owner));
      expect(Role.parse('MANAGER'), equals(Role.manager));
      expect(Role.parse('specialist'), equals(Role.specialist));
    });

    test('parse returns null for unknown roles', () {
      expect(Role.parse('client'), isNull);
      expect(Role.parse('admin'), isNull);
      expect(Role.parse(null), isNull);
    });
  });

  group('SessionUser', () {
    test('serializes to and from json', () {
      const user = SessionUser(
        id: 'u-1',
        fullName: 'Kasun Perera',
        phone: '+94771234567',
        avatarUrl: 'https://example.com/avatar.jpg',
        role: Role.owner,
        salonId: 's-1',
        salonName: 'Elegance Salon',
        timeZone: 'Asia/Colombo',
        staffId: 'st-1',
      );

      final json = user.toJson();
      final restored = SessionUser.fromJson(json);

      expect(restored.id, equals('u-1'));
      expect(restored.fullName, equals('Kasun Perera'));
      expect(restored.phone, equals('+94771234567'));
      expect(restored.avatarUrl, equals('https://example.com/avatar.jpg'));
      expect(restored.role, equals(Role.owner));
      expect(restored.salonId, equals('s-1'));
      expect(restored.salonName, equals('Elegance Salon'));
      expect(restored.timeZone, equals('Asia/Colombo'));
      expect(restored.staffId, equals('st-1'));
    });
  });

  group('TokenStorage (InMemory)', () {
    test('saves, retrieves, and clears tokens', () async {
      final storage = InMemoryTokenStorage();
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);

      await storage.saveTokens(accessToken: 'access-123', refreshToken: 'refresh-456');
      expect(await storage.getAccessToken(), equals('access-123'));
      expect(await storage.getRefreshToken(), equals('refresh-456'));

      await storage.clearTokens();
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.getRefreshToken(), isNull);
    });

    test('saves, retrieves, and clears cached user', () async {
      final storage = InMemoryTokenStorage();
      expect(await storage.getCachedUser(), isNull);

      await storage.saveCachedUser('{"id":"u1"}');
      expect(await storage.getCachedUser(), equals('{"id":"u1"}'));

      await storage.clearCachedUser();
      expect(await storage.getCachedUser(), isNull);
    });
  });
}
