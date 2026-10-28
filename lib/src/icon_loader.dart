import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'apk/icons.dart';
import 'apk/template_contract.dart';

/// Edge of the square every launcher icon is rendered from: the largest one.
final kIconSourceSize = kIconSizes.values.reduce(max);

/// Turns a picked image into the app's icon source: a center-cropped
/// [kIconSourceSize] square PNG.
///
/// Decodes and scales with the platform's image code (native, in the browser
/// the browser's decoder and the renderer's GPU/wasm path): decoding a photo
/// with pure-Dart `package:image` takes over a second under dart2js, many
/// seconds on slow phones, and blocks the UI. Throws [FormatException] when
/// [bytes] is not a supported image.
Future<Uint8List> loadIcon(Uint8List bytes) async {
  final size = kIconSourceSize;
  ui.Codec? codec;
  ui.Image? source;
  ui.Image? square;
  try {
    codec = await ui.instantiateImageCodecFromBuffer(
      await ui.ImmutableBuffer.fromUint8List(bytes),
    );
    source = (await codec.getNextFrame()).image;
    final side = min(source.width, source.height).toDouble();
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawImageRect(
      source,
      ui.Rect.fromLTWH(
        (source.width - side) / 2,
        (source.height - side) / 2,
        side,
        side,
      ),
      ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
    final picture = recorder.endRecording();
    square = await picture.toImage(size, size);
    picture.dispose();
    final data = await square.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    return encodeRgbaPng(
      data!.buffer.asUint8List(data.offsetInBytes),
      size,
      size,
    );
  } catch (_) {
    throw const FormatException('Not a supported image');
  } finally {
    square?.dispose();
    source?.dispose();
    codec?.dispose();
  }
}
