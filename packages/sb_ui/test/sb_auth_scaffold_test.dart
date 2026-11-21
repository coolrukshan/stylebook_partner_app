import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sb_ui/sb_ui.dart';

Future<void> _pump(WidgetTester tester, Size size, Widget child, {double scale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: SbTheme.light(),
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: c!,
      ),
      home: SbAuthScaffold(child: child),
    ),
  );
}

void main() {
  testWidgets('wide layout centres the form in a card capped at authCardMaxWidth', (tester) async {
    await _pump(tester, const Size(1280, 800), const SizedBox(key: Key('body'), height: 40, width: double.infinity));
    expect(find.byType(SbCard), findsOneWidget);
    expect(tester.getSize(find.byType(SbCard)).width, lessThanOrEqualTo(SbTokens.authCardMaxWidth));
    expect(tester.getCenter(find.byKey(const Key('body'))).dx, closeTo(640, 1));
  });

  testWidgets('phone layout is full width, scrolls and has no card', (tester) async {
    await _pump(tester, const Size(390, 844), const SizedBox(key: Key('body'), height: 40, width: double.infinity));
    expect(find.byType(SbCard), findsNothing);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('body'))).width, 390 - 2 * SbTokens.screenPadding);
  });

  testWidgets('tall content at 200 % text scale scrolls without overflow', (tester) async {
    await _pump(
      tester,
      const Size(390, 844),
      Column(children: [for (var i = 0; i < 30; i++) const Text('A long line of text for scrolling')]),
      scale: 2,
    );
    expect(tester.takeException(), isNull);
  });
}
