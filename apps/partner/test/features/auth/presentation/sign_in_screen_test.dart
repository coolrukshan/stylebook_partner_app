import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sb_core/sb_core.dart';
import 'package:sb_ui/sb_ui.dart';
import 'package:stylebook_partner/features/auth/application/providers.dart';
import 'package:stylebook_partner/features/auth/data/auth_repository.dart';
import 'package:stylebook_partner/features/auth/data/models/otp_send_response.dart';
import 'package:stylebook_partner/features/auth/data/models/sign_in_response.dart';
import 'package:stylebook_partner/features/auth/presentation/sign_in_screen.dart';
import 'package:stylebook_partner/l10n/app_localizations.dart';

class MockAuthRepo implements AuthRepository {
  MockAuthRepo(this.tokenStorage);

  @override
  final TokenStorage tokenStorage;

  var sendOtpCalled = false;
  var verifyOtpCalled = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<OtpSendResponse> sendOtp(String e164) async {
    sendOtpCalled = true;
    return const OtpSendResponse(message: 'Code sent', expiresIn: 300, retryAfter: 30);
  }

  @override
  Future<SignInResponse> verifyOtp(String e164, String otp) async {
    verifyOtpCalled = true;
    return const SignInResponse(
      accessToken: 'acc',
      refreshToken: 'ref',
      tokenType: 'bearer',
      expiresIn: 900,
    );
  }
}

void main() {
  late InMemoryTokenStorage tokenStorage;
  late MockAuthRepo mockRepo;

  setUp(() {
    tokenStorage = InMemoryTokenStorage();
    mockRepo = MockAuthRepo(tokenStorage);
  });

  Widget buildTestApp({List<dynamic> overrides = const []}) {
    return ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(tokenStorage),
        authRepositoryProvider.overrideWithValue(mockRepo),
        ...overrides,
      ],
      child: MaterialApp(
        theme: SbTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SignInScreen(),
      ),
    );
  }

  group('SignInScreen', () {
    testWidgets('renders phone step with input and send code button', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Sign in to your salon'), findsOneWidget);
      expect(find.text('Send code'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('entering invalid phone shows inline error and does not call repo', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '12345');
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();

      expect(mockRepo.sendOtpCalled, isFalse);
      expect(find.text('Please enter a valid Sri Lankan mobile number'), findsOneWidget);
    });

    testWidgets('entering valid phone and pressing Send code transitions to OTP step', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '771234567');
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();

      expect(mockRepo.sendOtpCalled, isTrue);
      expect(find.text('Verification code'), findsOneWidget);
      expect(find.byType(SbOtpInput), findsOneWidget);
      expect(find.text('Change number'), findsOneWidget);
    });

    testWidgets('Change number button transitions back to phone step', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '771234567');
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();

      expect(find.text('Verification code'), findsOneWidget);

      await tester.tap(find.text('Change number'));
      await tester.pumpAndSettle();

      expect(find.text('Sign in to your salon'), findsOneWidget);
    });
  });
}
