import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:web2apk/src/icon_loader.dart';

void main() {
  testWidgets('loadIcon center-crops to a 192 px square PNG', (tester) async {
    // 300x100: red | green | blue thirds; the center square is the green one.
    final src = img.Image(width: 300, height: 100);
    for (final p in src) {
      final third = p.x ~/ 100;
      p
        ..r = third == 0 ? 255 : 0
        ..g = third == 1 ? 255 : 0
        ..b = third == 2 ? 255 : 0;
    }
    final out = (await tester.runAsync(
      () => loadIcon(Uint8List.fromList(img.encodePng(src))),
    ))!;
    final png = img.decodePng(out)!;
    expect((png.width, png.height), (192, 192));
    final c = png.getPixel(96, 96);
    expect((c.r, c.g, c.b), (0, 255, 0));
  });

  testWidgets('loadIcon rejects data that is not an image', (tester) async {
    await tester.runAsync(() async {
      await expectLater(
        loadIcon(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
