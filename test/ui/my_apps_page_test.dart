import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web2apk/src/saved_apps.dart';
import 'package:web2apk/src/ui/my_apps_page.dart';

import 'fakes.dart';

void main() {
  SavedApp app(String name, String pkg) => SavedApp(
    name: name,
    url: 'https://example.org',
    color: 0xFF4CAF50,
    fullscreen: false,
    packageId: pkg,
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  testWidgets('tile tap reports the app; delete removes after confirm', (
    tester,
  ) async {
    final store = await memoryStore();
    await store.upsert(app('A', 'org.a.web2apk'));
    await store.upsert(app('B', 'org.b.web2apk'));
    SavedApp? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: MyAppsPage(store: store, onOpen: (a) => opened = a),
      ),
    );
    await tester.pump();
    expect(find.text('org.b.web2apk'), findsOneWidget);
    await tester.tap(find.text('A'));
    expect(opened?.packageId, 'org.a.web2apk');
    await tester.tap(find.byTooltip('Delete').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(store.load().map((a) => a.name), ['A']);
  });
}
