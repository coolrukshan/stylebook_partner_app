import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sb_ui/sb_ui.dart';

void main() {
  testWidgets('SbTextLink triggers onTap when enabled', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: SbTheme.light(),
        home: Scaffold(
          body: SbTextLink(
            text: 'Resend code',
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Resend code'), findsOneWidget);
    await tester.tap(find.text('Resend code'));
    expect(tapped, isTrue);
  });

  testWidgets('SbTextLink does not trigger onTap when disabled', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: SbTheme.light(),
        home: Scaffold(
          body: SbTextLink(
            text: 'Resend in 30s',
            enabled: false,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Resend in 30s'));
    expect(tapped, isFalse);
  });
}
