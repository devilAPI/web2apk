import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web2apk/src/apk/signing_key.dart';
import 'package:web2apk/src/ui/generator_page.dart';

import 'fakes.dart';

const _notice =
    'Your signing key is stored in this browser. Clearing site data loses it, '
    'and apps you generated can then no longer be updated in place.';

void main() {
  Future<void> pumpPage(WidgetTester tester, {bool? showWebKeyNotice}) {
    Future<SigningKey> noKey() async => throw UnimplementedError();
    return tester.pumpWidget(
      MaterialApp(
        home: showWebKeyNotice == null
            ? GeneratorPage(actions: FakeActions(), loadKey: noKey)
            : GeneratorPage(
                actions: FakeActions(),
                loadKey: noKey,
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
