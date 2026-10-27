import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web2apk/src/apk/signing_key.dart';
import 'package:web2apk/src/ui/generator_page.dart';

import 'fakes.dart';

const _notice =
    'Your signing key is stored in this browser. Clearing site data loses it: '
    'apps you generated can still be installed, but no longer updated in '
    'place. For a key that lasts, install a web2apk build from the Releases '
    'page, or back the key up via Signing key.';

void main() {
  Future<void> pumpPage(WidgetTester tester, {bool? showWebKeyNotice}) async {
    final store = await memoryStore();
    Future<SigningKey> noKey() async => throw UnimplementedError();
    await tester.pumpWidget(
      MaterialApp(
        home: showWebKeyNotice == null
            ? GeneratorPage(
                actions: FakeActions(),
                loadKey: noKey,
                replaceKey: (_) async {},
                savedApps: store,
              )
            : GeneratorPage(
                actions: FakeActions(),
                loadKey: noKey,
                replaceKey: (_) async {},
                savedApps: store,
                showWebKeyNotice: showWebKeyNotice,
              ),
      ),
    );
  }

  testWidgets('web notice hidden when flag false', (tester) async {
    await pumpPage(tester, showWebKeyNotice: false);
    expect(find.text(_notice), findsNothing);
  });

  testWidgets('notice shown when flag true', (tester) async {
    await pumpPage(tester, showWebKeyNotice: true);
    expect(find.text(_notice), findsOneWidget);
  });

  testWidgets('notice default follows kIsWeb', (tester) async {
    await pumpPage(tester);
    expect(find.text(_notice), findsNWidgets(kIsWeb ? 1 : 0));
  });
}
