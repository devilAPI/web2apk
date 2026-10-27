@TestOn('vm')
library;

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

/// Hand-built AXML: outer chunk + UTF-16 pool (3 strings) + trailing chunk.
Uint8List _synthetic(List<int> trailing) {
  final strs = ['one', 'two', 'three'];
  final blob = BytesBuilder();
  final offs = <int>[];
  for (final s in strs) {
    offs.add(blob.length);
    final b = ByteData(2 + 2 * s.length + 2);
    b.setUint16(0, s.length, Endian.little);
    for (var i = 0; i < s.length; i++) {
      b.setUint16(2 + 2 * i, s.codeUnitAt(i), Endian.little);
    }
    blob.add(b.buffer.asUint8List());
  }
  while (blob.length % 4 != 0) {
    blob.addByte(0);
  }
  final strBytes = blob.toBytes();
  final stringsStart = 28 + 4 * strs.length;
  final poolSize = stringsStart + strBytes.length;
  final total = 8 + poolSize + trailing.length;
  final b = BytesBuilder();
  void u16(int v) => b.add([v & 0xff, v >> 8]);
  void u32(int v) {
    u16(v & 0xffff);
    u16(v >> 16);
  }

  u16(0x0003);
  u16(8);
  u32(total);
  u16(0x0001);
  u16(28);
  u32(poolSize);
  u32(strs.length);
  u32(0);
  u32(0x1); // sorted, UTF-16
  u32(stringsStart);
  u32(0);
  for (final o in offs) {
    u32(o);
  }
  b.add(strBytes);
  b.add(trailing);
  return b.toBytes();
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

  test('UTF-16 pool round-trips non-ASCII and very long strings', () {
    final trailing = [
      0x02,
      0x01,
      0x10,
      0x00,
      0x10,
      0,
      0,
      0,
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
    ];
    final src = _synthetic(trailing);
    expect(readXmlStrings(src), ['one', 'two', 'three']);
    final long = 'x' * 0x8005;
    final out = replaceXmlStrings(src, {'one': 'Café 🚀', 'three': long});
    expect(readXmlStrings(out), ['Café 🚀', 'two', long]);
    expect(out.sublist(out.length - trailing.length), trailing);
    expect(ByteData.sublistView(out).getUint32(4, Endian.little), out.length);
    expect(ByteData.sublistView(out).getUint32(8 + 16, Endian.little) & 1, 0);
  });

  test('truncated input throws FormatException', () {
    final m = _manifest();
    expect(() => readXmlStrings(m.sublist(0, 100)), throwsFormatException);
  });
}
