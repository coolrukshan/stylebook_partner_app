import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stylebook_partner/app.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('shows Today screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PartnerApp()));
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsOneWidget);
  });
}
