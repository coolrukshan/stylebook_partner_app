import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sb_core/sb_core.dart';
import 'package:stylebook_partner/features/auth/data/auth_repository.dart';

void main() {
  late Dio dio;
  late InMemoryTokenStorage tokenStorage;
  late AuthRepository repository;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    tokenStorage = InMemoryTokenStorage();
    repository = AuthRepository(dio: dio, tokenStorage: tokenStorage);
  });

  group('AuthRepository', () {
    test('sendOtp sends correct payload and returns OtpSendResponse', () async {
      dio.httpClientAdapter = _MockHttpAdapter((options) async {
        expect(options.path, equals('/v1/auth/otp/send'));
        expect(options.data, equals({'phone': '+94771234567'}));
        return ResponseBody.fromString(
          '{"message":"OTP sent","expires_in":300,"retry_after":60}',
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      });

      final res = await repository.sendOtp('+94771234567');
      expect(res.message, equals('OTP sent'));
      expect(res.expiresIn, equals(300));
      expect(res.retryAfter, equals(60));
    });

    test('verifyOtp sends phone and otp and returns SignInResponse', () async {
      dio.httpClientAdapter = _MockHttpAdapter((options) async {
        expect(options.path, equals('/v1/auth/otp/verify'));
        expect(options.data, equals({'phone': '+94771234567', 'otp': '123456'}));
        return ResponseBody.fromString(
          '{"access_token":"acc-1","refresh_token":"ref-1","token_type":"bearer","expires_in":900,"is_new_user":false}',
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      });

      final res = await repository.verifyOtp('+94771234567', '123456');
      expect(res.accessToken, equals('acc-1'));
      expect(res.refreshToken, equals('ref-1'));
      expect(res.isNewUser, isFalse);
    });

    test('me fetches and returns UserOut', () async {
      dio.httpClientAdapter = _MockHttpAdapter((options) async {
        expect(options.path, equals('/v1/me'));
        return ResponseBody.fromString(
          '{"id":"u-1","phone":"+94771234567","full_name":"Kasun Perera","role":"owner"}',
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      });

      final user = await repository.me();
      expect(user.id, equals('u-1'));
      expect(user.fullName, equals('Kasun Perera'));
      expect(user.role, equals('owner'));
    });

    test('loadSalonContext fetches and returns PartnerSettingsOut', () async {
      dio.httpClientAdapter = _MockHttpAdapter((options) async {
        expect(options.path, equals('/v1/partner/settings'));
        return ResponseBody.fromString(
          '{"salon_id":"s-100","salon_name":"Elegance Salon","time_zone":"Asia/Colombo"}',
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      });

      final settings = await repository.loadSalonContext();
      expect(settings.salonId, equals('s-100'));
      expect(settings.salonName, equals('Elegance Salon'));
      expect(settings.timeZone, equals('Asia/Colombo'));
    });

    test('throws ApiError when server returns error response', () async {
      dio.httpClientAdapter = _MockHttpAdapter((options) async {
        return ResponseBody.fromString(
          '{"message":"Invalid OTP","code":"OTP_INVALID"}',
          400,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      });

      expect(
        () => repository.verifyOtp('+94771234567', '000000'),
        throwsA(isA<ApiError>().having((e) => e.code, 'code', 'OTP_INVALID')),
      );
    });
  });
}

class _MockHttpAdapter implements HttpClientAdapter {
  _MockHttpAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}
