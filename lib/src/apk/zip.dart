import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// One ZIP entry. [rawData] is the bytes as stored in the archive (compressed
/// when [method] is 8); [data] is the uncompressed content.
class ZipEntry {
  final String name;

  /// 0 = stored, 8 = deflated.
  final int method;
  final Uint8List rawData;
  final int crc32;
  final int uncompressedSize;

  const ZipEntry({
    required this.name,
    required this.method,
    required this.rawData,
    required this.crc32,
    required this.uncompressedSize,
  });

  factory ZipEntry.stored(String name, Uint8List data) => ZipEntry(
    name: name,
    method: 0,
    rawData: data,
    crc32: getCrc32(data),
    uncompressedSize: data.length,
  );

  factory ZipEntry.deflated(String name, Uint8List data) => ZipEntry(
    name: name,
    method: 8,
    rawData: Uint8List.fromList(Deflate(data).getBytes()),
    crc32: getCrc32(data),
    uncompressedSize: data.length,
  );

  /// Uncompressed content.
  Uint8List get data {
    if (method == 0) return rawData;
    if (method == 8) {
      return Uint8List.fromList(
        Inflate(rawData, uncompressedSize: uncompressedSize).getBytes(),
      );
    }
    throw FormatException('Unsupported ZIP method $method for $name');
  }
}

const _sigLocal = 0x04034b50;
const _sigCentral = 0x02014b50;
const _sigEocd = 0x06054b50;

/// Reads a ZIP archive, driven by its central directory. Keeps entry order.
List<ZipEntry> readZip(Uint8List bytes) {
  final bd = ByteData.sublistView(bytes);
  // Find the end-of-central-directory record (may be followed by a comment).
  var eocd = -1;
  final minPos = bytes.length - 22 - 0xFFFF;
  for (var i = bytes.length - 22; i >= 0 && i >= minPos; i--) {
    if (bd.getUint32(i, Endian.little) == _sigEocd) {
      eocd = i;
      break;
    }
  }
  if (eocd < 0) {
    throw const FormatException('ZIP end of central directory not found');
  }
  final count = bd.getUint16(eocd + 10, Endian.little);
  var pos = bd.getUint32(eocd + 16, Endian.little);

  final entries = <ZipEntry>[];
  for (var n = 0; n < count; n++) {
    if (pos + 46 > bytes.length ||
        bd.getUint32(pos, Endian.little) != _sigCentral) {
      throw const FormatException('Bad ZIP central directory entry');
    }
    final method = bd.getUint16(pos + 10, Endian.little);
    final crc = bd.getUint32(pos + 16, Endian.little);
    final compSize = bd.getUint32(pos + 20, Endian.little);
    final size = bd.getUint32(pos + 24, Endian.little);
    final nameLen = bd.getUint16(pos + 28, Endian.little);
    final extraLen = bd.getUint16(pos + 30, Endian.little);
    final commentLen = bd.getUint16(pos + 32, Endian.little);
    final localOffset = bd.getUint32(pos + 42, Endian.little);
    final name = utf8.decode(
      bytes.sublist(pos + 46, pos + 46 + nameLen),
      allowMalformed: true,
    );
    pos += 46 + nameLen + extraLen + commentLen;

    if (localOffset + 30 > bytes.length ||
        bd.getUint32(localOffset, Endian.little) != _sigLocal) {
      throw FormatException('Bad ZIP local header for $name');
    }
    final localNameLen = bd.getUint16(localOffset + 26, Endian.little);
    final localExtraLen = bd.getUint16(localOffset + 28, Endian.little);
    final start = localOffset + 30 + localNameLen + localExtraLen;
    if (start + compSize > bytes.length) {
      throw FormatException('Truncated ZIP entry $name');
    }
    entries.add(
      ZipEntry(
        name: name,
        method: method,
        rawData: Uint8List.sublistView(bytes, start, start + compSize),
        crc32: crc,
        uncompressedSize: size,
      ),
    );
  }
  return entries;
}

// 1981-01-01 00:00 in DOS format.
const _dosTime = 0;
const _dosDate = (1 << 5) | 1;

/// Writes a ZIP archive without data descriptors and with a fixed timestamp.
/// The data of every stored entry starts at a multiple of [alignment] (padding
/// goes into the local header extra field). Raw data is copied as-is.
Uint8List writeZip(List<ZipEntry> entries, {int alignment = 4}) {
  final out = BytesBuilder(copy: false);
  final central = BytesBuilder(copy: false);
  var offset = 0;

  for (final e in entries) {
    final nameBytes = utf8.encode(e.name);
    var extraLen = 0;
    if (e.method == 0 && alignment > 1) {
      extraLen =
          (alignment - ((offset + 30 + nameBytes.length) % alignment)) %
          alignment;
    }
    // General purpose flag bit 11: UTF-8 names.
    const flags = 0x0800;
    final local = ByteData(30)
      ..setUint32(0, _sigLocal, Endian.little)
      ..setUint16(4, 20, Endian.little)
      ..setUint16(6, flags, Endian.little)
      ..setUint16(8, e.method, Endian.little)
      ..setUint16(10, _dosTime, Endian.little)
      ..setUint16(12, _dosDate, Endian.little)
      ..setUint32(14, e.crc32, Endian.little)
      ..setUint32(18, e.rawData.length, Endian.little)
      ..setUint32(22, e.uncompressedSize, Endian.little)
      ..setUint16(26, nameBytes.length, Endian.little)
      ..setUint16(28, extraLen, Endian.little);

    final cd = ByteData(46)
      ..setUint32(0, _sigCentral, Endian.little)
      ..setUint16(4, 20, Endian.little)
      ..setUint16(6, 20, Endian.little)
      ..setUint16(8, flags, Endian.little)
      ..setUint16(10, e.method, Endian.little)
      ..setUint16(12, _dosTime, Endian.little)
      ..setUint16(14, _dosDate, Endian.little)
      ..setUint32(16, e.crc32, Endian.little)
      ..setUint32(20, e.rawData.length, Endian.little)
      ..setUint32(24, e.uncompressedSize, Endian.little)
      ..setUint16(28, nameBytes.length, Endian.little)
      ..setUint32(42, offset, Endian.little);
    central
      ..add(cd.buffer.asUint8List())
      ..add(nameBytes);

    out
      ..add(local.buffer.asUint8List())
      ..add(nameBytes)
      ..add(Uint8List(extraLen))
      ..add(e.rawData);
    offset += 30 + nameBytes.length + extraLen + e.rawData.length;
  }

  final cdBytes = central.takeBytes();
  final eocd = ByteData(22)
    ..setUint32(0, _sigEocd, Endian.little)
    ..setUint16(8, entries.length, Endian.little)
    ..setUint16(10, entries.length, Endian.little)
    ..setUint32(12, cdBytes.length, Endian.little)
    ..setUint32(16, offset, Endian.little);
  out
    ..add(cdBytes)
    ..add(eocd.buffer.asUint8List());
  return out.takeBytes();
}
