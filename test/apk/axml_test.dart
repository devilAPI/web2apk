import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:web2apk/src/apk/axml.dart';
import 'package:web2apk/src/apk/template_contract.dart';
import 'package:web2apk/src/apk/zip.dart';

import '../support/sdk_tools.dart';

const _activity = 'de.devilapi.web2apk.template.MainActivity';

Uint8List _manifest() =>
    readZip(loadTemplate()).firstWhere((e) => e.name == kManifestPath).data;

Future<String> _badging(Uint8List manifest) async {
  final entries = readZip(loadTemplate())
      .map(
        (e) =>
            e.name == kManifestPath ? ZipEntry.deflated(e.name, manifest) : e,
      )
      .toList();
  final dir = Directory.systemTemp.createTempSync('axml_test');
  try {
    final f = File('${dir.path}/t.apk')..writeAsBytesSync(writeZip(entries));
    final r = await runTool('aapt2', ['dump', 'badging', f.path]);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    return r.stdout as String;
  } finally {
    dir.deleteSync(recursive: true);
  }
}

void main() {
  final hasAapt2 = buildTool('aapt2') != null;

  test('template manifest contains placeholders', () {
    final s = readXmlStrings(_manifest());
    expect(s, containsAll([kTemplatePackage, kTemplateLabel, _activity]));
  });

  test('replaces package and label', () {
    final out = replaceXmlStrings(_manifest(), {
      kTemplatePackage: 'org.example.web2apk',
      kTemplateLabel: 'Café 🚀',
    });
    final s = readXmlStrings(out);
    expect(s, contains('org.example.web2apk'));
    expect(s, contains('Café 🚀'));
    expect(s, isNot(contains(kTemplatePackage)));
    expect(s, isNot(contains(kTemplateLabel)));
    expect(s, contains(_activity));
  });

  test('long name', () {
    final label = 'L' * 60;
    final out = replaceXmlStrings(_manifest(), {kTemplateLabel: label});
    expect(readXmlStrings(out), contains(label));
  });

  test('very long name uses two-byte lengths', () {
    final label = 'é' * 300;
    final out = replaceXmlStrings(_manifest(), {kTemplateLabel: label});
    expect(readXmlStrings(out), contains(label));
  });

  test('missing key throws FormatException', () {
    expect(
      () => replaceXmlStrings(_manifest(), {'nope.nope': 'x'}),
      throwsFormatException,
    );
  });

  test('aapt2 reads patched manifest', () async {
    final out = replaceXmlStrings(_manifest(), {
      kTemplatePackage: 'org.example.web2apk',
      kTemplateLabel: 'Café 🚀',
    });
    final text = await _badging(out);
    expect(text, contains("package: name='org.example.web2apk'"));
    expect(text, contains("application-label:'Café 🚀'"));
  }, skip: hasAapt2 ? false : 'aapt2 not available');

  test('aapt2 reads manifest after large length change', () async {
    final out = replaceXmlStrings(_manifest(), {
      kTemplatePackage: 'a.b',
      kTemplateLabel: 'X',
    });
    final text = await _badging(out);
    expect(text, contains("package: name='a.b'"));
    expect(text, contains("application-label:'X'"));
  }, skip: hasAapt2 ? false : 'aapt2 not available');
}
