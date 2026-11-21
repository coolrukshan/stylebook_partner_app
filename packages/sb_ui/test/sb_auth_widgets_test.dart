import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sb_ui/sb_ui.dart';

Widget _app(Widget child) => MaterialApp(
  theme: SbTheme.light(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('SbTextLink is at least 44 x 44 even for a short label', (tester) async {
    await tester.pumpWidget(_app(SbTextLink(text: 'OK', onTap: () {})));
    final size = tester.getSize(find.byType(TextButton));
    expect(size.width, greaterThanOrEqualTo(SbTokens.minTouch));
    expect(size.height, greaterThanOrEqualTo(SbTokens.minTouch));
  });

  testWidgets('SbPrimaryButton loading shows progress and ignores taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(SbPrimaryButton(label: 'Sign in', loading: true, onPressed: () => taps++)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(SbPrimaryButton));
    expect(taps, 0);
  });

  testWidgets('SbPrimaryButton not loading taps and shows no progress', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(SbPrimaryButton(label: 'Sign in', onPressed: () => taps++)));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.byType(SbPrimaryButton));
    expect(taps, 1);
  });

  testWidgets('SbErrorBanner is a live region and its retry target is 44 px', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(SbErrorBanner(message: 'Offline', retryLabel: 'Retry', onRetry: () {})));
    expect(tester.getSemantics(find.text('Offline')), matchesSemantics(label: 'Offline', isLiveRegion: true));
    expect(tester.getSize(find.byType(TextButton)).height, greaterThanOrEqualTo(SbTokens.minTouch));
    handle.dispose();
  });

  testWidgets('SbOtpInput clears and refocuses when clearSignal changes', (tester) async {
    Widget build(int signal) => _app(SbOtpInput(clearSignal: signal));
    await tester.pumpWidget(build(0));
    final fields = find.byType(TextField);
    for (var i = 0; i < 6; i++) {
      await tester.enterText(fields.at(i), '${i + 1}');
    }
    await tester.pump();
    expect(tester.widget<TextField>(fields.at(5)).controller!.text, '6');

    await tester.pumpWidget(build(1));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      expect(tester.widget<TextField>(fields.at(i)).controller!.text, '');
    }
    expect(tester.widget<TextField>(fields.at(0)).focusNode!.hasFocus, isTrue);
  });

  testWidgets('SbOtpInput uses the supplied semantics label builder and honours enabled', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(SbOtpInput(enabled: false, semanticLabelBuilder: (i, n) => 'Cijfer $i van $n')));
    expect(find.bySemanticsLabel('Cijfer 1 van 6'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField).first).enabled, isFalse);
    handle.dispose();
  });

  testWidgets('SbOtpInput boxes meet the 44 px touch target', (tester) async {
    await tester.pumpWidget(_app(const SbOtpInput()));
    final box = tester.getSize(find.byType(TextField).first);
    expect(box.width, greaterThanOrEqualTo(SbTokens.minTouch));
    expect(box.height, greaterThanOrEqualTo(SbTokens.minTouch));
  });

  testWidgets('SbTextField forwards obscure, autofill and input action', (tester) async {
    await tester.pumpWidget(
      _app(
        const SbTextField(
          label: 'Username',
          autocorrect: false,
          enableSuggestions: false,
          maxLength: 50,
          autofillHints: [AutofillHints.username],
          textInputAction: TextInputAction.next,
        ),
      ),
    );
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.autocorrect, isFalse);
    expect(editable.autofillHints, contains(AutofillHints.username));
    expect(editable.textInputAction, TextInputAction.next);
  });
}
