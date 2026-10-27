@TestOn('vm')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web2apk/src/apk/signing_key.dart';
import 'package:web2apk/src/ui/key_page.dart';

import 'fakes.dart';

void main() {
  late SigningKey key;
  setUpAll(() => key = SigningKey.generate());

  const backupWarning =
      'Anyone with this file can publish updates to your apps. Keep it private.';
  const restoreWarning =
      'This replaces your current signing key. Apps signed with the current '
      'key can then no longer be updated in place, unless you restore it again.';

  Uint8List fileBytes(Map<String, Object?> m) =>
      Uint8List.fromList(utf8.encode(jsonEncode(m)));

  Future<void> pump(
    WidgetTester tester,
    FakeActions actions,
    List<SigningKey> replaced, {
    Future<Uint8List?> Function()? pickFile,
  }) => tester.pumpWidget(
    MaterialApp(
      home: KeyPage(
        loadKey: () async => key,
        replaceKey: (k) async => replaced.add(k),
        actions: actions,
        pickFile: pickFile,
      ),
    ),
  );

  testWidgets('shows the fingerprint', (tester) async {
    await pump(tester, FakeActions(), []);
    await tester.pumpAndSettle();
    expect(find.text(key.certificateSha256), findsOneWidget);
  });

  testWidgets('backup writes a round-trippable file after the warning', (
    tester,
  ) async {
    final actions = FakeActions();
    await pump(tester, actions, []);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back up key'));
    await tester.pumpAndSettle();
    expect(find.text(backupWarning), findsOneWidget);
    expect(actions.saved, isEmpty);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(actions.savedNames.single, 'web2apk-signing-key.json');
    expect(actions.savedMimes.single, 'application/json');
    final json =
        jsonDecode(utf8.decode(actions.saved.single)) as Map<String, dynamic>;
    expect(json['format'], 'web2apk-signing-key-v1');
    expect(
      SigningKey.fromJson(json).privateKey.modulus,
      key.privateKey.modulus,
    );
  });

  testWidgets('backup cancelled at the warning saves nothing', (tester) async {
    final actions = FakeActions();
    await pump(tester, actions, []);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back up key'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(actions.saved, isEmpty);
  });

  testWidgets('restoring garbage shows an error and keeps the key', (
    tester,
  ) async {
    final replaced = <SigningKey>[];
    for (final bytes in [
      Uint8List.fromList(utf8.encode('not json')),
      fileBytes({'n': '1'}),
      fileBytes({...key.toJson(), 'format': 'other'}),
      fileBytes(key.toJson()), // missing format field
      fileBytes({
        ...key.toJson(),
        'format': 'web2apk-signing-key-v1',
        'd': '3',
      }),
    ]) {
      await pump(tester, FakeActions(), replaced, pickFile: () async => bytes);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore key'));
      await tester.pumpAndSettle();
      expect(find.text('Not a valid web2apk key file'), findsOneWidget);
      expect(find.text(restoreWarning), findsNothing);
      await tester.pumpWidget(const SizedBox());
    }
    expect(replaced, isEmpty);
  });

  testWidgets('restoring a valid file replaces the key after confirm', (
    tester,
  ) async {
    final other = SigningKey.generate();
    final replaced = <SigningKey>[];
    await pump(
      tester,
      FakeActions(),
      replaced,
      pickFile: () async =>
          fileBytes({...other.toJson(), 'format': 'web2apk-signing-key-v1'}),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore key'));
    await tester.pumpAndSettle();
    expect(find.text(restoreWarning), findsOneWidget);
    expect(replaced, isEmpty);
    await tester.tap(find.text('Replace key'));
    // pump, not pumpAndSettle: settling would run past the SnackBar's timeout.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(replaced.single.privateKey.modulus, other.privateKey.modulus);
    expect(find.text('Signing key restored'), findsOneWidget);
  });

  testWidgets('restore cancelled at the confirm changes nothing', (
    tester,
  ) async {
    final replaced = <SigningKey>[];
    await pump(
      tester,
      FakeActions(),
      replaced,
      pickFile: () async =>
          fileBytes({...key.toJson(), 'format': 'web2apk-signing-key-v1'}),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore key'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(replaced, isEmpty);
    expect(find.text('Signing key restored'), findsNothing);
  });

  testWidgets('restore with no file picked does nothing', (tester) async {
    final replaced = <SigningKey>[];
    await pump(tester, FakeActions(), replaced, pickFile: () async => null);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore key'));
    await tester.pumpAndSettle();
    expect(replaced, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });
}
