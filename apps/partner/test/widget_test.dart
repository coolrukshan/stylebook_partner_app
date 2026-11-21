import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sb_core/sb_core.dart';
import 'package:stylebook_partner/app.dart';
import 'package:stylebook_partner/features/auth/application/providers.dart';
import 'package:stylebook_partner/features/auth/application/session_controller.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('unauthenticated user sees Sign in screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PartnerApp()));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to your salon'), findsOneWidget);
  });

  testWidgets('authenticated user sees Today screen', (tester) async {
    const user = SessionUser(
      id: 'u-1',
      fullName: 'Kasun Perera',
      phone: '+94771234567',
      role: Role.owner,
      salonId: 's-1',
      salonName: 'Elegance Salon',
      timeZone: 'Asia/Colombo',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider.overrideWith(() => _FakeSessionController(const Authenticated(user))),
        ],
        child: const PartnerApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsOneWidget);
  });
}

class _FakeSessionController extends SessionController {
  _FakeSessionController(this._initialState);
  final AuthState _initialState;

  @override
  Future<AuthState> build() async => _initialState;
}
