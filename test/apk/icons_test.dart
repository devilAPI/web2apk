import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:web2apk/src/apk/icons.dart';

void main() {
  const paths = [
    'res/mipmap-mdpi-v4/ic_launcher.png',
    'res/mipmap-hdpi-v4/ic_launcher.png',
    'res/mipmap-xhdpi-v4/ic_launcher.png',
    'res/mipmap-xxhdpi-v4/ic_launcher.png',
    'res/mipmap-xxxhdpi-v4/ic_launcher.png',
  ];

  test('4000x1000 opaque -> five square icons', () {
    final src = img.Image(width: 4000, height: 1000, numChannels: 3);
    img.fill(src, color: img.ColorRgb8(10, 120, 200));
    final out = renderLauncherIcons(
      Uint8List.fromList(img.encodeJpg(src)),
      paths,
    );
    expect(out.keys.toList(), paths);
    final sizes = [48, 72, 96, 144, 192];
    for (var i = 0; i < 5; i++) {
      final d = img.decodePng(out[paths[i]]!)!;
      expect([d.width, d.height], [sizes[i], sizes[i]]);
    }
  });

  test('transparency is kept', () {
    final src = img.Image(width: 300, height: 300, numChannels: 4);
    final out = renderLauncherIcons(Uint8List.fromList(img.encodePng(src)), [
      paths.first,
    ]);
    final d = img.decodePng(out[paths.first]!)!;
    expect(d.getPixel(0, 0).a, 0);
  });

  test('undecodable input throws FormatException', () {
    expect(
      () =>
          renderLauncherIcons(Uint8List.fromList(utf8.encode('hello')), paths),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          'Not a supported image',
        ),
      ),
    );
  });
}
