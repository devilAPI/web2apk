import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:web2apk/src/apk/apk_builder.dart';
import 'package:web2apk/src/apk/app_spec.dart';
import 'package:web2apk/src/apk/signing_key.dart';

import '../fixtures/golden_key.dart';
import '../fixtures/mini_template.dart';

/// SHA-256 of the APK produced on the Dart VM; Chrome (dart2js) must match.
const _goldenSha256 =
    '1c85ce14bde4bffbdee093674f69679e1f62d455e901175734a281faf84ab290';

void main() {
  test('buildApk on mini template is byte-identical across platforms', () {
    final src = img.Image(width: 64, height: 64, numChannels: 3);
    img.fill(src, color: img.ColorRgb8(0, 0, 255));
    final apk = buildApk(
      template: buildMiniTemplate(),
      spec: AppSpec(
        name: 'Golden ✓',
        url: 'https://example.org',
        color: 0xFF4CAF50,
        fullscreen: true,
        packageId: 'org.example.web2apk',
        icon: Uint8List.fromList(img.encodePng(src)),
      ),
      key: SigningKey.fromJson(goldenKeyJson),
    );
    expect(sha256.convert(apk).toString(), _goldenSha256);
  });
}
