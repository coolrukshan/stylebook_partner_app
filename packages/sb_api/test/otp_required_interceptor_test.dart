import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sb_api/sb_api.dart';
import 'package:sb_core/sb_core.dart';

void main() {
  late InMemoryTokenStorage tokenStorage;
  late Dio dio;
  var stepUpCalls = 0;
  var requestsSeen = <String>[];

  ResponseBody json(String body, int status) => ResponseBody.fromString(
        body,
        status,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );

  const otpRequired = '{"code":"OTP_REQUIRED","message":"Verify","field":null}';

  setUp(() async {
    tokenStorage = InMemoryTokenStorage();
    await tokenStorage.saveTokens(accessToken: 'limited', refreshToken: 'r1');
    stepUpCalls = 0;
    requestsSeen = [];
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
  });

  void install(Future<bool> Function() onOtpRequired, ResponseBody Function(RequestOptions) server) {
    dio.interceptors.addAll([
      AuthInterceptor(tokenStorage: tokenStorage, authDio: Dio()),
      OtpRequiredInterceptor(dio: dio, onOtpRequired: () {
        stepUpCalls++;
        return onOtpRequired();
      }),
      ApiExceptionMapper(),
    ]);
    dio.httpClientAdapter = _Adapter((options) async {
      requestsSeen.add('${options.path} ${options.headers['Authorization']}');
      return server(options);
    });
  }

  test('parks a 403 OTP_REQUIRED call, then retries once with the NEW token', () async {
    install(() async {
      await tokenStorage.saveTokens(accessToken: 'full', refreshToken: 'r2');
      return true;
    }, (o) => o.headers['Authorization'] == 'Bearer full' ? json('{"ok":true}', 200) : json(otpRequired, 403));

    final res = await dio.get<Map<String, dynamic>>('/v1/partner/today');
    expect(res.data, equals({'ok': true}));
    expect(stepUpCalls, equals(1));
    expect(requestsSeen, equals(['/v1/partner/today Bearer limited', '/v1/partner/today Bearer full']));
  });

  test('on cancel the original OTP_REQUIRED error surfaces and there is no retry', () async {
    install(() async => false, (o) => json(otpRequired, 403));

    await expectLater(
      dio.get<dynamic>('/v1/partner/today'),
      throwsA(isA<DioException>().having((e) => (e.error as ApiError).code, 'code', 'OTP_REQUIRED')),
    );
    expect(stepUpCalls, equals(1));
    expect(requestsSeen.length, equals(1));
  });

  test('never loops: a second OTP_REQUIRED after the retry fails without another step-up', () async {
    install(() async => true, (o) => json(otpRequired, 403));

    await expectLater(
      dio.get<dynamic>('/v1/partner/today'),
      throwsA(isA<DioException>().having((e) => (e.error as ApiError).code, 'code', 'OTP_REQUIRED')),
    );
    expect(stepUpCalls, equals(1));
    expect(requestsSeen.length, equals(2));
  });

  test('concurrent OTP_REQUIRED calls share one step-up and each retries once', () async {
    install(() async {
      await tokenStorage.saveTokens(accessToken: 'full', refreshToken: 'r2');
      return true;
    }, (o) => o.headers['Authorization'] == 'Bearer full' ? json('{"ok":true}', 200) : json(otpRequired, 403));

    final results = await Future.wait([
      dio.get<dynamic>('/v1/partner/today'),
      dio.get<dynamic>('/v1/partner/calendar'),
    ]);
    expect(results.map((r) => r.statusCode), everyElement(200));
    expect(stepUpCalls, equals(1));
    expect(requestsSeen.length, equals(4));
  });

  test('does not intercept the OTP endpoints themselves (no deadlock)', () async {
    install(() async => true, (o) => json(otpRequired, 403));

    await expectLater(dio.post<dynamic>('/v1/partner/auth/otp/verify', data: {'otp': '123456'}), throwsA(isA<DioException>()));
    expect(stepUpCalls, equals(0));
  });

  test('handles OTP_REQUIRED on password change', () async {
    install(() async {
      await tokenStorage.saveTokens(accessToken: 'full', refreshToken: 'r2');
      return true;
    }, (o) => o.headers['Authorization'] == 'Bearer full' ? json('{"ok":true}', 200) : json(otpRequired, 403));

    final res = await dio.post<dynamic>('/v1/partner/auth/password/change', data: {'current_password': 'a', 'new_password': 'b'});
    expect(res.statusCode, equals(200));
    expect(stepUpCalls, equals(1));
  });

  test('other 403 codes are left alone', () async {
    install(() async => true, (o) => json('{"code":"FORBIDDEN","message":"no","field":null}', 403));

    await expectLater(dio.get<dynamic>('/v1/partner/staff'), throwsA(isA<DioException>()));
    expect(stepUpCalls, equals(0));
  });

  test('buildDio never installs a logging interceptor (tokens and passwords stay out of logs)', () {
    final built = buildDio(
      baseUrl: 'https://api.test',
      tokenStorage: tokenStorage,
      onOtpRequired: () async => false,
    );
    expect(built.interceptors.whereType<LogInterceptor>(), isEmpty);
    expect(built.interceptors.whereType<OtpRequiredInterceptor>(), hasLength(1));
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
