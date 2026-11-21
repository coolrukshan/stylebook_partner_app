import 'package:sb_core/sb_core.dart';
import 'package:stylebook_partner/features/auth/data/auth_repository.dart';
import 'package:stylebook_partner/features/auth/data/models/partner_full_session_response.dart';
import 'package:stylebook_partner/features/auth/data/models/partner_login_response.dart';
import 'package:stylebook_partner/features/auth/data/models/partner_otp_send_response.dart';
import 'package:stylebook_partner/features/auth/data/models/partner_user_out.dart';
import 'package:stylebook_partner/features/auth/data/models/token_response.dart';

const kOwnerSalon = PartnerSalonOut(id: 's-1', name: 'Elegance Salon', isOwner: true);
const kStaffSalon = PartnerSalonOut(id: 's-1', name: 'Elegance Salon', isOwner: false);
const kOwnerUser = PartnerUserOut(id: 'u-1', fullName: 'Nimal Perera', salons: [kOwnerSalon]);
const kStaffUser = PartnerUserOut(id: 'u-2', fullName: 'Kamal Silva', salons: [kStaffSalon]);

PartnerLoginResponse loginResponse({
  PartnerUserOut user = kOwnerUser,
  bool mustChangePassword = false,
  String access = 'limited-acc',
  String refresh = 'limited-ref',
}) => PartnerLoginResponse(
  accessToken: access,
  refreshToken: refresh,
  mustChangePassword: mustChangePassword,
  user: user,
);

PartnerFullSessionResponse fullResponse({
  bool mustChangePassword = false,
  String access = 'full-acc',
  String refresh = 'full-ref',
}) => PartnerFullSessionResponse(accessToken: access, refreshToken: refresh, mustChangePassword: mustChangePassword);

/// Scriptable repository. Mirrors the real one: successful calls replace the stored tokens.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository(this.tokenStorage);

  @override
  final TokenStorage tokenStorage;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  PartnerLoginResponse? loginResult;
  Object? loginError;
  Future<void>? loginGate;
  PartnerOtpSendResponse sendResult = const PartnerOtpSendResponse(phoneMasked: '+9477***4567');
  Object? sendError;
  PartnerFullSessionResponse? verifyResult;
  Object? verifyError;
  PartnerFullSessionResponse? changeResult;
  Object? changeError;
  Object? refreshError;
  Future<void>? refreshGate;

  final loginCalls = <({String username, String password})>[];
  var sendCalls = 0;
  final verifyCalls = <String>[];
  final changeCalls = <({String current, String next})>[];
  var refreshCalls = 0;
  var logoutCalls = 0;

  @override
  Future<PartnerLoginResponse> login(String username, String password) async {
    loginCalls.add((username: username, password: password));
    if (loginGate != null) await loginGate;
    if (loginError != null) throw loginError!;
    final r = loginResult ?? loginResponse();
    await tokenStorage.saveTokens(accessToken: r.accessToken, refreshToken: r.refreshToken);
    return r;
  }

  @override
  Future<PartnerOtpSendResponse> sendOtp() async {
    sendCalls++;
    if (sendError != null) throw sendError!;
    return sendResult;
  }

  @override
  Future<PartnerFullSessionResponse> verifyOtp(String otp) async {
    verifyCalls.add(otp);
    if (verifyError != null) throw verifyError!;
    final r = verifyResult ?? fullResponse();
    await tokenStorage.saveTokens(accessToken: r.accessToken, refreshToken: r.refreshToken);
    return r;
  }

  @override
  Future<PartnerFullSessionResponse> changePassword({required String current, required String next}) async {
    changeCalls.add((current: current, next: next));
    if (changeError != null) throw changeError!;
    final r = changeResult ?? fullResponse(access: 'changed-acc', refresh: 'changed-ref');
    await tokenStorage.saveTokens(accessToken: r.accessToken, refreshToken: r.refreshToken);
    return r;
  }

  @override
  Future<TokenResponse> refresh() async {
    refreshCalls++;
    if (refreshGate != null) await refreshGate;
    if (refreshError != null) throw refreshError!;
    const r = TokenResponse(
      accessToken: 'refreshed-acc',
      refreshToken: 'refreshed-ref',
      tokenType: 'bearer',
      expiresIn: 900,
    );
    await tokenStorage.saveTokens(accessToken: r.accessToken, refreshToken: r.refreshToken);
    return r;
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
    await tokenStorage.clearTokens();
    await tokenStorage.clearCachedUser();
  }
}

ApiError apiError(int status, String code, {String message = 'server message', int? retryAfter, String? field}) =>
    ApiError(message: message, code: code, status: status, retryAfter: retryAfter, field: field);
