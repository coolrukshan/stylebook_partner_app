import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sb_core/sb_core.dart';
import 'package:stylebook_partner/features/auth/data/auth_repository.dart';

const _loginJson = '''
{"access_token":"lim-acc","refresh_token":"lim-ref","token_type":"bearer","expires_in":900,
 "session":"limited","otp_required_for_full_access":true,"must_change_password":true,
 "user":{"id":"u-1","full_name":"Nimal Perera","salons":[{"id":"s-1","name":"Elegance Salon","is_owner":true}]}}''';
const _fullJson =
    '{"access_token":"full-acc","refresh_token":"full-ref","token_type":"bearer","expires_in":900,"session":"full","must_change_password":false}';

void main() {
  late Dio dio;
  late InMemoryTokenStorage tokens;
  late AuthRepository repo;
  RequestOptions? seen;

  void reply(String body, int status, {Map<String, List<String>>? headers}) {
    dio.httpClientAdapter = _Adapter((options) async {
      seen = options;
      return ResponseBody.fromString(
        body,
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          ...?headers,
        },
      );
    });
  }

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    tokens = InMemoryTokenStorage();
    repo = AuthRepository(dio: dio, tokenStorage: tokens);
    seen = null;
  });

  group('login', () {
    test('posts username and password, parses the limited session and stores both tokens', () async {
      reply(_loginJson, 200);
      final res = await repo.login('nimal.kandy', 'Secret#1');

      expect(seen!.path, '/v1/partner/auth/login');
      expect(seen!.method, 'POST');
      expect(seen!.data, {'username': 'nimal.kandy', 'password': 'Secret#1'});
      expect(res.session, 'limited');
      expect(res.mustChangePassword, isTrue);
      expect(res.otpRequiredForFullAccess, isTrue);
      expect(res.user.id, 'u-1');
      expect(res.user.fullName, 'Nimal Perera');
      expect(res.user.salons.single.isOwner, isTrue);
      expect(res.user.salons.single.name, 'Elegance Salon');
      expect(await tokens.getAccessToken(), 'lim-acc');
      expect(await tokens.getRefreshToken(), 'lim-ref');
    });

    test('a null full_name is accepted', () async {
      reply(_loginJson.replaceAll('"Nimal Perera"', 'null'), 200);
      final res = await repo.login('a', 'b');
      expect(res.user.fullName, isNull);
    });

    test('INVALID_CREDENTIALS is surfaced by code and leaves stored tokens untouched', () async {
      await tokens.saveTokens(accessToken: 'keep', refreshToken: 'keep-r');
      reply('{"code":"INVALID_CREDENTIALS","message":"Invalid username or password","field":null}', 401);

      await expectLater(
        repo.login('a', 'b'),
        throwsA(
          isA<ApiError>().having((e) => e.code, 'code', 'INVALID_CREDENTIALS').having((e) => e.status, 'status', 401),
        ),
      );
      expect(await tokens.getAccessToken(), 'keep');
    });

    test('ACCOUNT_LOCKED carries Retry-After', () async {
      reply(
        '{"code":"ACCOUNT_LOCKED","message":"Locked","field":null}',
        429,
        headers: {
          'retry-after': ['120'],
        },
      );
      await expectLater(
        repo.login('a', 'b'),
        throwsA(
          isA<ApiError>()
              .having((e) => e.code, 'code', 'ACCOUNT_LOCKED')
              .having((e) => e.retryAfter, 'retryAfter', 120),
        ),
      );
    });
  });

  group('otp', () {
    test('sendOtp posts with no body and parses phone_masked, expires_in and retry_after', () async {
      reply('{"message":"OTP sent","phone_masked":"+9477***4567","expires_in":300,"retry_after":60}', 200);
      final res = await repo.sendOtp();

      expect(seen!.path, '/v1/partner/auth/otp/send');
      expect(seen!.method, 'POST');
      expect(seen!.data, isNull);
      expect(res.phoneMasked, '+9477***4567');
      expect(res.expiresIn, 300);
      expect(res.retryAfter, 60);
    });

    test('verifyOtp posts {otp} and REPLACES both stored tokens', () async {
      await tokens.saveTokens(accessToken: 'lim-acc', refreshToken: 'lim-ref');
      reply(_fullJson, 200);
      final res = await repo.verifyOtp('482910');

      expect(seen!.path, '/v1/partner/auth/otp/verify');
      expect(seen!.data, {'otp': '482910'});
      expect(res.session, 'full');
      expect(res.mustChangePassword, isFalse);
      expect(await tokens.getAccessToken(), 'full-acc');
      expect(await tokens.getRefreshToken(), 'full-ref');
    });

    test('verify errors keep the old tokens', () async {
      await tokens.saveTokens(accessToken: 'lim-acc', refreshToken: 'lim-ref');
      reply('{"code":"OTP_INVALID","message":"bad","field":null}', 400);
      await expectLater(
        repo.verifyOtp('000000'),
        throwsA(isA<ApiError>().having((e) => e.code, 'code', 'OTP_INVALID')),
      );
      expect(await tokens.getAccessToken(), 'lim-acc');
    });
  });

  group('changePassword', () {
    test('posts current_password and new_password only and replaces tokens', () async {
      await tokens.saveTokens(accessToken: 'old', refreshToken: 'old-r');
      reply(_fullJson, 200);
      await repo.changePassword(current: 'Temp#1', next: 'My-New-Passw0rd');

      expect(seen!.path, '/v1/partner/auth/password/change');
      expect(seen!.data, {'current_password': 'Temp#1', 'new_password': 'My-New-Passw0rd'});
      expect(await tokens.getAccessToken(), 'full-acc');
      expect(await tokens.getRefreshToken(), 'full-ref');
    });

    test('WEAK_PASSWORD keeps the server message', () async {
      reply('{"code":"WEAK_PASSWORD","message":"Too short","field":"new_password"}', 422);
      await expectLater(
        repo.changePassword(current: 'a', next: 'b'),
        throwsA(
          isA<ApiError>()
              .having((e) => e.code, 'code', 'WEAK_PASSWORD')
              .having((e) => e.message, 'message', 'Too short'),
        ),
      );
    });
  });

  group('refresh and logout', () {
    test('refresh sends the stored refresh token and stores BOTH new tokens', () async {
      await tokens.saveTokens(accessToken: 'old', refreshToken: 'old-r');
      reply('{"access_token":"n-acc","refresh_token":"n-ref","token_type":"bearer","expires_in":900}', 200);
      await repo.refresh();

      expect(seen!.path, '/v1/auth/refresh');
      expect(seen!.data, {'refresh_token': 'old-r'});
      expect(await tokens.getAccessToken(), 'n-acc');
      expect(await tokens.getRefreshToken(), 'n-ref');
    });

    test('logout posts the refresh token and clears tokens and cached user', () async {
      await tokens.saveTokens(accessToken: 'a', refreshToken: 'r');
      await tokens.saveCachedUser('{}');
      reply('', 204);
      await repo.logout();

      expect(seen!.path, '/v1/auth/logout');
      expect(seen!.data, {'refresh_token': 'r'});
      expect(await tokens.getAccessToken(), isNull);
      expect(await tokens.getCachedUser(), isNull);
    });

    test('logout still clears locally when the call fails', () async {
      await tokens.saveTokens(accessToken: 'a', refreshToken: 'r');
      reply('{"code":"TOKEN_INVALID","message":"x","field":null}', 401);
      await repo.logout();
      expect(await tokens.getAccessToken(), isNull);
      expect(await tokens.getRefreshToken(), isNull);
    });
  });

  test('passwords and tokens never appear in an ApiError message', () async {
    reply('{"code":"INVALID_CREDENTIALS","message":"Invalid username or password","field":null}', 401);
    try {
      await repo.login('nimal', 'Sup3rSecret!');
      fail('expected error');
    } on ApiError catch (e) {
      expect(jsonEncode({'m': e.message, 's': e.toString()}), isNot(contains('Sup3rSecret!')));
    }
  });
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) =>
      handler(options);

  @override
  void close({bool force = false}) {}
}
