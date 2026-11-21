import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sb_ui/sb_ui.dart';

void main() {
  testWidgets('SbErrorBanner renders message and retry button', (tester) async {
    var retried = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: SbTheme.light(),
        home: Scaffold(
          body: SbErrorBanner(
            message: 'You are offline',
            retryLabel: 'Retry',
            onRetry: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.text('You are offline'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });
}
