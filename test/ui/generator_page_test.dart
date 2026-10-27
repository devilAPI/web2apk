@TestOn('vm')
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web2apk/src/apk/signing_key.dart';
import 'package:web2apk/src/saved_apps.dart';
import 'package:web2apk/src/ui/generator_page.dart';
import 'package:web2apk/src/ui/key_page.dart';
import 'package:web2apk/src/ui/my_apps_page.dart';
import 'package:web2apk/src/ui/result_page.dart';

import '../support/sdk_tools.dart' as sdk;
import 'fakes.dart';

void main() {
  late SigningKey key;
  setUpAll(() => key = SigningKey.generate());

  Future<SavedAppsStore> pumpPage(
    WidgetTester tester,
    FakeActions actions, {
    Map<String, Object> prefs = const {},
  }) async {
    final store = await memoryStore(prefs);
    await tester.pumpWidget(
      MaterialApp(
        home: GeneratorPage(
          actions: actions,
          savedApps: store,
          loadKey: () async => key,
          replaceKey: (_) async {},
          loadTemplate: () async => sdk.loadTemplate(),
        ),
      ),
    );
    return store;
  }

  String savedJson(List<SavedApp> apps) =>
      jsonEncode([for (final a in apps) a.toJson()]);

  SavedApp saved(
    String name,
    String url,
    String pkg, {
    bool fullscreen = true,
  }) => SavedApp(
    name: name,
    url: url,
    color: 0xFF4CAF50,
    fullscreen: fullscreen,
    packageId: pkg,
    updatedAt: DateTime.utc(2026, 1, 1),
  );

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
    await tester.enterText(
      find.byKey(const Key('package-field')),
      'org.example.shop',
    );
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
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('generate')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('generate navigates to result', (tester) async {
    final actions = FakeActions();
    final store = await pumpPage(tester, actions);
    await enter(tester, 'name-field', 'Test');
    await enter(tester, 'url-field', 'example.org');
    await tester.tap(find.byKey(const Key('generate')));
    await tester.pump();
    for (
      var i = 0;
      i < 200 && find.byType(ResultPage).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.byType(ResultPage), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(actions.saved.single, isNotEmpty);
    expect(actions.savedNames.single, 'Test.apk');
    final apps = store.load();
    expect(apps, hasLength(1));
    expect(apps.single.name, 'Test');
    expect(apps.single.packageId, 'org.example.web2apk');
  });

  testWidgets('corrupt store is replaced by the new app on generate', (
    tester,
  ) async {
    final store = await pumpPage(
      tester,
      FakeActions(),
      prefs: {'saved_apps_v1': 'garbage'},
    );
    await enter(tester, 'name-field', 'Test');
    await enter(tester, 'url-field', 'example.org');
    await tester.tap(find.byKey(const Key('generate')));
    await tester.pump();
    for (
      var i = 0;
      i < 200 && find.byType(ResultPage).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    await tester.pump();
    expect(find.byType(ResultPage), findsOneWidget);
    expect(find.textContaining('could not be saved'), findsNothing);
    expect(store.load().map((a) => a.packageId), ['org.example.web2apk']);
  });

  Future<void> openMyApps(WidgetTester tester) async {
    await tester.tap(find.byTooltip('My apps'));
    await tester.pumpAndSettle();
  }

  testWidgets('My apps lists apps; tap fills form and keeps package', (
    tester,
  ) async {
    await pumpPage(
      tester,
      FakeActions(),
      prefs: {
        'saved_apps_v1': savedJson([
          saved('Shop', 'https://shop.example.com', 'org.example.shop'),
        ]),
      },
    );
    await openMyApps(tester);
    expect(find.byType(MyAppsPage), findsOneWidget);
    expect(find.text('Shop'), findsOneWidget);
    expect(find.text('org.example.shop'), findsOneWidget);
    await tester.tap(find.text('Shop'));
    await tester.pumpAndSettle();
    expect(find.byType(MyAppsPage), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('name-field')))
          .controller!
          .text,
      'Shop',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('url-field')))
          .controller!
          .text,
      'https://shop.example.com',
    );
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
    expect(find.textContaining('org.example.shop'), findsOneWidget);
    await enter(tester, 'url-field', 'other.com');
    expect(find.textContaining('org.example.shop'), findsOneWidget);
    expect(find.textContaining('com.other.web2apk'), findsNothing);
  });

  testWidgets('initial prefills the form', (tester) async {
    final store = await memoryStore();
    await tester.pumpWidget(
      MaterialApp(
        home: GeneratorPage(
          actions: FakeActions(),
          loadKey: () async => key,
          replaceKey: (_) async {},
          savedApps: store,
          initial: saved(
            'Shop',
            'https://shop.example.com',
            'org.example.shop',
          ),
        ),
      ),
    );
    expect(find.textContaining('org.example.shop'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('generate')),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('empty store shows empty state', (tester) async {
    await pumpPage(tester, FakeActions());
    await openMyApps(tester);
    expect(find.text('No saved apps yet'), findsOneWidget);
  });

  testWidgets('delete asks to confirm; cancel keeps, confirm removes', (
    tester,
  ) async {
    final store = await pumpPage(
      tester,
      FakeActions(),
      prefs: {
        'saved_apps_v1': savedJson([
          saved('Shop', 'https://shop.example.com', 'org.example.shop'),
        ]),
      },
    );
    await openMyApps(tester);
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Shop'), findsOneWidget);
    expect(store.load(), hasLength(1));
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Shop'), findsNothing);
    expect(find.text('No saved apps yet'), findsOneWidget);
    expect(store.load(), isEmpty);
  });

  testWidgets('corrupt store shows error and empty state, value kept', (
    tester,
  ) async {
    final store = await pumpPage(
      tester,
      FakeActions(),
      prefs: {'saved_apps_v1': 'garbage'},
    );
    await openMyApps(tester);
    expect(find.text('Saved apps could not be read'), findsOneWidget);
    expect(find.text('No saved apps yet'), findsOneWidget);
    expect(() => store.load(), throwsFormatException);
  });

  testWidgets('About shows credit', (tester) async {
    await pumpPage(tester, FakeActions());
    await tester.tap(find.byTooltip('About'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Made by devilAPI with <3'), findsOneWidget);
  });

  testWidgets('every build loads the key again (no stale key after restore)', (
    tester,
  ) async {
    final other = SigningKey.generate();
    final keys = [key, other];
    var calls = 0;
    final store = await memoryStore();
    await tester.pumpWidget(
      MaterialApp(
        home: GeneratorPage(
          actions: FakeActions(),
          savedApps: store,
          loadKey: () async => keys[calls++],
          replaceKey: (_) async {},
          loadTemplate: () async => sdk.loadTemplate(),
        ),
      ),
    );
    await enter(tester, 'name-field', 'Test');
    await enter(tester, 'url-field', 'example.org');
    for (var round = 1; round <= 2; round++) {
      await tester.tap(find.byKey(const Key('generate')));
      await tester.pump();
      for (
        var i = 0;
        i < 200 && find.byType(ResultPage).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.byType(ResultPage), findsOneWidget);
      expect(calls, round);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Signing key action opens the key page', (tester) async {
    await pumpPage(tester, FakeActions());
    await tester.tap(find.byTooltip('Signing key'));
    await tester.pumpAndSettle();
    expect(find.byType(KeyPage), findsOneWidget);
    expect(find.text(key.certificateSha256), findsOneWidget);
  });
}
