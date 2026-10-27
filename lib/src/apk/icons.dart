import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'template_contract.dart';

/// Renders launcher icon PNGs (path -> PNG bytes) for each icon path, sized by
/// density. Center-crops to a square first (cheap on huge sources), then
/// resizes with cubic interpolation; alpha is preserved.
Map<String, Uint8List> renderLauncherIcons(
  Uint8List source,
  Iterable<String> iconPaths,
) {
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
  final rgba = square.numChannels == 4 || square.hasPalette
      ? square.convert(numChannels: 4)
      : square;

  final out = <String, Uint8List>{};
  for (final path in iconPaths) {
    final m = kIconPath.firstMatch(path);
    if (m == null) throw FormatException('Not an icon path: $path');
    final px = kIconSizes[m.group(1)]!;
    final resized = img.copyResize(
      rgba,
      width: px,
      height: px,
      interpolation: img.Interpolation.cubic,
    );
    out[path] = Uint8List.fromList(img.encodePng(resized));
  }
  return out;
}
