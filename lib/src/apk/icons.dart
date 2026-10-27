import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;

import 'template_contract.dart';

/// Renders launcher icon PNGs (path -> PNG bytes) for each icon path, sized by
/// density. Center-crops to a square first (cheap on huge sources), then
/// resizes with cubic interpolation; alpha is preserved.
Map<String, Uint8List> renderLauncherIcons(
  Uint8List source,
  Iterable<String> iconPaths,
) {
  final rgba = _centerSquare(source);

  final out = <String, Uint8List>{};
  for (final path in iconPaths) {
    final m = kIconPath.firstMatch(path);
    if (m == null) throw FormatException('Not an icon path: $path');
    final px = kIconSizes[m.group(1)]!;
    out[path] = _encodePng(_resize(rgba, px));
  }
  return out;
}

/// Center-crops [source] to a square and renders it as a [size]x[size] PNG
/// (same pipeline as the launcher icons). Throws [FormatException] when
/// [source] is not a supported image.
Uint8List squarePng(Uint8List source, int size) =>
    _encodePng(_resize(_centerSquare(source), size));

img.Image _resize(img.Image square, int px) => img.copyResize(
  square,
  width: px,
  height: px,
  interpolation: img.Interpolation.cubic,
);

/// Decodes [source] and center-crops it to a square (cheap on huge sources).
img.Image _centerSquare(Uint8List source) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(source);
  } catch (_) {
    decoded = null;
  }
  if (decoded == null) throw const FormatException('Not a supported image');

  final side = decoded.width < decoded.height ? decoded.width : decoded.height;
  final square = img.copyCrop(
    decoded,
    x: (decoded.width - side) ~/ 2,
    y: (decoded.height - side) ~/ 2,
    width: side,
    height: side,
  );
  return square.numChannels == 4 || square.hasPalette
      ? square.convert(numChannels: 4)
      : square;
}

/// Encodes [image] as an 8-bit RGBA PNG.
///
/// `package:image` compresses with the platform's zlib (native on the VM,
/// pure Dart on web), so its PNG bytes differ per platform. This writer uses
/// the pure-Dart [Deflate] everywhere so the generated APK is byte-identical.
Uint8List _encodePng(img.Image image) {
  final rgba = image.convert(numChannels: 4, format: img.Format.uint8);
  final w = rgba.width, h = rgba.height;
  final pixels = rgba.getBytes(order: img.ChannelOrder.rgba);
  final raw = Uint8List(h * (1 + w * 4)); // filter type 0 (None) per row
  for (var y = 0; y < h; y++) {
    raw.setRange(y * (1 + w * 4) + 1, (y + 1) * (1 + w * 4), pixels, y * w * 4);
  }
  final adler = getAdler32(raw);
  final deflated = Deflate(raw).getBytes();
  final zlib = BytesBuilder()
    ..add(const [0x78, 0x9c])
    ..add(deflated)
    ..add([
      (adler >> 24) & 0xff,
      (adler >> 16) & 0xff,
      (adler >> 8) & 0xff,
      adler & 0xff,
    ]);

  final out = BytesBuilder()..add(const [137, 80, 78, 71, 13, 10, 26, 10]);
  void chunk(String type, List<int> data) {
    final typed = Uint8List.fromList([...type.codeUnits, ...data]);
    final crc = getCrc32(typed);
    out
      ..add(_u32(data.length))
      ..add(typed)
      ..add(_u32(crc));
  }

  chunk('IHDR', [..._u32(w), ..._u32(h), 8, 6, 0, 0, 0]);
  chunk('IDAT', zlib.toBytes());
  chunk('IEND', const []);
  return out.toBytes();
}

List<int> _u32(int v) => [
  (v >> 24) & 0xff,
  (v >> 16) & 0xff,
  (v >> 8) & 0xff,
  v & 0xff,
];
