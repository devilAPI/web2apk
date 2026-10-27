import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web2apk/src/apk/signing_key.dart';
import 'package:web2apk/src/ui/generator_page.dart';
import 'package:web2apk/src/ui/result_page.dart';

import '../support/sdk_tools.dart' as sdk;
import 'fakes.dart';

void main() {
  late SigningKey key;
  setUpAll(() => key = SigningKey.generate());

  Future<void> pumpPage(WidgetTester tester, FakeActions actions) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GeneratorPage(
          actions: actions,
          loadKey: () async => key,
          loadTemplate: () async => sdk.loadTemplate(),
        ),
      ),
    );
  }

  Future<void> enter(WidgetTester tester, String field, String text) async {
    await tester.enterText(find.byKey(Key(field)), text);
    await tester.pump();
  }

  testWidgets('package line follows URL', (tester) async {
    await pumpPage(tester, FakeActions());
    await enter(tester, 'url-field', 'example.org');
    expect(find.textContaining('org.example.web2apk'), findsOneWidget);
  });

  testWidgets('manual package edit sticks', (tester) async {
    await pumpPage(tester, FakeActions());
    await enter(tester, 'url-field', 'example.org');
    await tester.tap(find.byKey(const Key('package-tile')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('package-field')), 'org.example.shop');
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.textContaining('org.example.shop'), findsOneWidget);
    await enter(tester, 'url-field', 'other.com');
    expect(find.textContaining('org.example.shop'), findsOneWidget);
    expect(find.textContaining('com.other.web2apk'), findsNothing);
  });

  testWidgets('invalid URL disables Generate', (tester) async {
    await pumpPage(tester, FakeActions());
    await enter(tester, 'name-field', 'Test');
    await enter(tester, 'url-field', 'ftp://x');
    expect(find.textContaining('Unsupported URL scheme'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byKey(const Key('generate')));
    expect(button.onPressed, isNull);
  });

  testWidgets('generate navigates to result', (tester) async {
    final actions = FakeActions();
    await pumpPage(tester, actions);
    await enter(tester, 'name-field', 'Test');
    await enter(tester, 'url-field', 'example.org');
    await tester.tap(find.byKey(const Key('generate')));
    await tester.pump();
    for (var i = 0; i < 200 && find.byType(ResultPage).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.byType(ResultPage), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(actions.saved.single, isNotEmpty);
    expect(actions.savedNames.single, 'Test.apk');
  });

  testWidgets('About shows credit', (tester) async {
    await pumpPage(tester, FakeActions());
    await tester.tap(find.byTooltip('About'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Made by devilAPI with <3'), findsOneWidget);
  });
}
