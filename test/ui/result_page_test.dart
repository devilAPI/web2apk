import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web2apk/src/apk_actions.dart';
import 'package:web2apk/src/ui/result_page.dart';

import 'fakes.dart';

void main() {
  Future<void> pumpResult(WidgetTester tester, FakeActions a) => tester.pumpWidget(
        MaterialApp(
          home: ResultPage(apk: Uint8List.fromList([1, 2, 3]), fileName: 'A.apk', actions: a),
        ),
      );

  testWidgets('hides Install/Share when unsupported', (tester) async {
    await pumpResult(tester, FakeActions(canInstall: false, canShare: false));
    expect(find.text('Install'), findsNothing);
    expect(find.text('Share'), findsNothing);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('shows Install/Share when supported', (tester) async {
    final a = FakeActions();
    await pumpResult(tester, a);
    expect(find.text('Install'), findsOneWidget);
    await tester.tap(find.text('Share'));
    await tester.pump();
    expect(a.shared, ['A.apk']);
  });

  testWidgets('needsPermission shows SnackBar', (tester) async {
    final a = FakeActions()..installResult = InstallResult.needsPermission;
    await pumpResult(tester, a);
    await tester.tap(find.text('Install'));
    await tester.pump();
    expect(find.textContaining('Allow installs from web2apk'), findsOneWidget);
  });
}
