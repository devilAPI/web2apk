import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:web2apk/src/apk/apk_builder.dart';
import 'package:web2apk/src/apk/app_spec.dart';
import 'package:web2apk/src/apk/signing_key.dart';
import 'package:web2apk/src/apk/template_contract.dart';
import 'package:web2apk/src/apk/zip.dart';

import '../support/sdk_tools.dart';

void main() {
  late SigningKey key;
  late Uint8List template;
  late Uint8List redPng;

  setUpAll(() {
    key = SigningKey.generate();
    template = loadTemplate();
    final src = img.Image(width: 512, height: 512, numChannels: 3);
    img.fill(src, color: img.ColorRgb8(255, 0, 0));
    redPng = Uint8List.fromList(img.encodePng(src));
  });

  AppSpec spec({Uint8List? icon, String name = 'Café 🚀', String? pkg}) =>
      AppSpec(
        name: name,
        url: 'https://example.org',
        color: 0xFFFFEB3B,
        fullscreen: true,
        packageId: pkg ?? 'org.example.web2apk',
        icon: icon,
      );

  Map<String, ZipEntry> entries(Uint8List apk) => {
    for (final e in readZip(apk)) e.name: e,
  };

  test('config.json holds the spec config', () {
    final s = spec();
    final apk = buildApk(template: template, spec: s, key: key);
    final e = entries(apk)[kConfigPath]!;
    expect(utf8.decode(e.data), s.configJson());
  });

  test('icons replaced', () {
    final apk = buildApk(
      template: template,
      spec: spec(icon: redPng),
      key: key,
    );
    final icons = entries(apk).entries.where((e) => kIconPath.hasMatch(e.key));
    expect(icons, isNotEmpty);
    for (final e in icons) {
      final density = RegExp(r'mipmap-(\w+?)(-v4)?/').firstMatch(e.key)![1]!;
      final d = img.decodePng(e.value.data)!;
      final size = kIconSizes[density]!;
      expect([d.width, d.height], [size, size]);
      final p = d.getPixel(size ~/ 2, size ~/ 2);
      expect([p.r, p.g, p.b], [255, 0, 0]);
    }
  });

  test('no icon keeps template icons', () {
    final apk = buildApk(template: template, spec: spec(), key: key);
    final before = entries(template);
    final after = entries(apk);
    for (final n in before.keys.where(kIconPath.hasMatch)) {
      expect(after[n]!.data, before[n]!.data);
    }
  });

  test('resources.arsc stays stored and META-INF only has the v2 block', () {
    final apk = buildApk(template: template, spec: spec(), key: key);
    final m = entries(apk);
    expect(m['resources.arsc']!.method, 0);
    expect(
      m.keys.where(
        (n) =>
            RegExp(r'^META-INF/.*\.(SF|RSA|DSA|EC)$|MANIFEST\.MF$').hasMatch(n),
      ),
      isEmpty,
    );
  });

  test('empty name / bad package id throw ArgumentError', () {
    expect(
      () => buildApk(
        template: template,
        spec: spec(name: '  '),
        key: key,
      ),
      throwsArgumentError,
    );
    expect(
      () => buildApk(
        template: template,
        spec: spec(pkg: '1bad'),
        key: key,
      ),
      throwsArgumentError,
    );
  });

  test('badging, apksigner and zipalign accept the APK', () async {
    if (buildTool('aapt2') == null ||
        buildTool('apksigner') == null ||
        buildTool('zipalign') == null) {
      markTestSkipped('Android SDK build-tools not available');
      return;
    }
    final apk = buildApk(
      template: template,
      spec: spec(icon: redPng),
      key: key,
    );
    final dir = Directory.systemTemp.createTempSync('apkb');
    addTearDown(() => dir.deleteSync(recursive: true));
    final f = File('${dir.path}/out.apk')..writeAsBytesSync(apk);

    final badging = await runTool('aapt2', ['dump', 'badging', f.path]);
    expect(badging.exitCode, 0, reason: '${badging.stderr}');
    expect(badging.stdout, contains("package: name='org.example.web2apk'"));
    expect(badging.stdout, contains("application-label:'Café 🚀'"));

    final v = await runTool('apksigner', [
      'verify',
      '--min-sdk-version',
      '24',
      f.path,
    ]);
    expect(v.exitCode, 0, reason: '${v.stdout}${v.stderr}');

    final z = await runTool('zipalign', ['-c', '-P', '16', '4', f.path]);
    expect(z.exitCode, 0, reason: '${z.stdout}${z.stderr}');
  });
}
