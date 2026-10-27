@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:web2apk/src/apk/zip.dart';

import '../support/sdk_tools.dart';

void main() {
  test('round-trips template entries', () {
    final a = readZip(loadTemplate());
    final b = readZip(writeZip(a));
    expect(a, isNotEmpty);
    expect(b.map((e) => e.name), a.map((e) => e.name));
    expect(b.map((e) => e.method), a.map((e) => e.method));
    for (var i = 0; i < a.length; i++) {
      expect(b[i].data, a[i].data, reason: a[i].name);
      expect(b[i].crc32, a[i].crc32, reason: a[i].name);
    }
  });

  test('stored entry data is 4-byte aligned', () {
    final bytes = writeZip([
      ZipEntry.deflated('a.txt', Uint8List.fromList([1, 2, 3])),
      ZipEntry.stored('b.bin', Uint8List.fromList(List.filled(10, 7))),
    ]);
    final bd = ByteData.sublistView(bytes);
    final name = 'b.bin'.codeUnits;
    var found = -1;
    for (var i = 0; i + 30 + name.length <= bytes.length; i++) {
      if (bd.getUint32(i, Endian.little) == 0x04034b50 &&
          bd.getUint16(i + 26, Endian.little) == name.length &&
          List.generate(name.length, (k) => bytes[i + 30 + k]).join(',') ==
              name.join(',')) {
        found = i;
        break;
      }
    }
    expect(found, greaterThanOrEqualTo(0));
    final nameLen = bd.getUint16(found + 26, Endian.little);
    final extraLen = bd.getUint16(found + 28, Endian.little);
    expect((found + 30 + nameLen + extraLen) % 4, 0);
  });

  test('deflated factory compresses and data inflates back', () {
    final src = Uint8List.fromList(List.generate(5000, (i) => i % 7));
    final e = ZipEntry.deflated('x', src);
    expect(e.method, 8);
    expect(e.rawData.length, lessThan(src.length));
    expect(e.uncompressedSize, src.length);
    expect(e.data, src);
    // Survives a full write/read cycle (raw deflate, no zlib header).
    expect(readZip(writeZip([e])).single.data, src);
  });

  test('zipalign accepts output', () async {
    final out = writeZip(readZip(loadTemplate()));
    final dir = Directory.systemTemp.createTempSync('zip_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final f = File('${dir.path}/out.apk')..writeAsBytesSync(out);
    final r = await runTool('zipalign', ['-c', '-P', '16', '4', f.path]);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
  }, skip: buildTool('zipalign') == null ? 'zipalign not available' : false);
}
