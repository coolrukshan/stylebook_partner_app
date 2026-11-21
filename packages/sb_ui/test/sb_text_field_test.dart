import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sb_ui/sb_ui.dart';

void main() {
  testWidgets('SbTextField renders label, prefixText, and handles input', (tester) async {
    String? enteredText;

    await tester.pumpWidget(
      MaterialApp(
        theme: SbTheme.light(),
        home: Scaffold(
          body: SbTextField(
            label: 'Mobile number',
            prefixText: '+94 ',
            hint: '77 123 4567',
            onChanged: (val) => enteredText = val,
          ),
        ),
      ),
    );

    expect(find.text('Mobile number'), findsOneWidget);
    expect(find.text('+94 '), findsOneWidget);
    expect(find.text('77 123 4567'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '771234567');
    expect(enteredText, equals('771234567'));
  });

  testWidgets('SbTextField displays error text when provided', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: SbTheme.light(),
        home: const Scaffold(
          body: SbTextField(
            label: 'Mobile number',
            errorText: 'Invalid phone',
          ),
        ),
      ),
    );

    expect(find.text('Invalid phone'), findsOneWidget);
  });
}
