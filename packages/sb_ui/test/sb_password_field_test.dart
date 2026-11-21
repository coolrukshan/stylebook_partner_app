import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sb_ui/sb_ui.dart';

Widget _app(Widget child) => MaterialApp(
  theme: SbTheme.light(),
  home: Scaffold(body: child),
);

void main() {
  const field = SbPasswordField(label: 'Password', showLabel: 'Show password', hideLabel: 'Hide password');

  bool obscured(WidgetTester tester) => tester.widget<EditableText>(find.byType(EditableText)).obscureText;

  testWidgets('is obscured by default and the eye toggles it', (tester) async {
    await tester.pumpWidget(_app(field));
    expect(obscured(tester), isTrue);

    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(obscured(tester), isFalse);

    await tester.tap(find.byTooltip('Hide password'));
    await tester.pump();
    expect(obscured(tester), isTrue);
  });

  testWidgets('toggle has a Semantics label and a 44 px target', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(field));
    expect(find.bySemanticsLabel('Show password'), findsOneWidget);
    final size = tester.getSize(find.byTooltip('Show password'));
    expect(size.width, greaterThanOrEqualTo(SbTokens.minTouch));
    expect(size.height, greaterThanOrEqualTo(SbTokens.minTouch));
    handle.dispose();
  });

  testWidgets('visibility resets when the app goes to the background', (tester) async {
    await tester.pumpWidget(_app(field));
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(obscured(tester), isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(obscured(tester), isTrue);
  });

  testWidgets('disables autocorrect and suggestions and forwards autofill hints', (tester) async {
    await tester.pumpWidget(
      _app(
        const SbPasswordField(
          label: 'Password',
          showLabel: 's',
          hideLabel: 'h',
          autofillHints: [AutofillHints.password],
          maxLength: 128,
        ),
      ),
    );
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.autocorrect, isFalse);
    expect(editable.enableSuggestions, isFalse);
    expect(editable.autofillHints, contains(AutofillHints.password));
    await tester.enterText(find.byType(TextFormField), 'x' * 200);
    expect(tester.widget<EditableText>(find.byType(EditableText)).controller.text.length, 128);
  });
}
