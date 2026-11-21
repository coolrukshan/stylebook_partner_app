import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sb_ui/sb_ui.dart';

void main() {
  testWidgets('SbOtpInput renders 6 boxes with semantics', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: SbTheme.light(),
        home: const Scaffold(
          body: SbOtpInput(
            length: 6,
          ),
        ),
      ),
    );

    expect(find.byType(TextField), findsNWidgets(6));
    expect(find.bySemanticsLabel('Digit 1 of 6'), findsOneWidget);
    expect(find.bySemanticsLabel('Digit 6 of 6'), findsOneWidget);
  });

  testWidgets('SbOtpInput triggers onCompleted when 6 digits are typed', (tester) async {
    String? completedCode;

    await tester.pumpWidget(
      MaterialApp(
        theme: SbTheme.light(),
        home: Scaffold(
          body: SbOtpInput(
            length: 6,
            onCompleted: (code) => completedCode = code,
          ),
        ),
      ),
    );

    final textFields = find.byType(TextField);
    for (var i = 0; i < 6; i++) {
      await tester.enterText(textFields.at(i), '${i + 1}');
      await tester.pump();
    }

    expect(completedCode, equals('123456'));
  });
}
