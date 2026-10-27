import 'dart:convert';
import 'dart:typed_data';

const _xmlType = 0x0003;
const _poolType = 0x0001;
const _utf8Flag = 0x100;
const _sortedFlag = 0x1;

class _Pool {
  _Pool({
    required this.start,
    required this.end,
    required this.headerSize,
    required this.flags,
    required this.strings,
    required this.styleOffsets,
    required this.styleData,
  });
  final int start; // chunk start in file
  final int end; // chunk end in file
  final int headerSize;
  final int flags;
  final List<String> strings;
  final Uint8List styleOffsets; // raw style offset table
  final Uint8List styleData; // raw style data (may be empty)
  bool get isUtf8 => flags & _utf8Flag != 0;
}

_Pool _parse(Uint8List axml) {
  try {
    return _parseUnchecked(axml);
  } on RangeError {
    throw const FormatException('Truncated or malformed binary XML');
  }
}

_Pool _parseUnchecked(Uint8List axml) {
  if (axml.length < 8 + 28) throw const FormatException('AXML too short');
  final bd = ByteData.sublistView(axml);
  if (bd.getUint16(0, Endian.little) != _xmlType) {
    throw const FormatException('Not a binary XML file');
  }
  final start = bd.getUint16(2, Endian.little); // outer headerSize
  if (start + 28 > axml.length) throw const FormatException('Bad AXML header');
  if (bd.getUint16(start, Endian.little) != _poolType) {
    throw const FormatException('String pool not first chunk');
  }
  final headerSize = bd.getUint16(start + 2, Endian.little);
  final size = bd.getUint32(start + 4, Endian.little);
  final count = bd.getUint32(start + 8, Endian.little);
  final styleCount = bd.getUint32(start + 12, Endian.little);
  final flags = bd.getUint32(start + 16, Endian.little);
  final stringsStart = bd.getUint32(start + 20, Endian.little);
  final stylesStart = bd.getUint32(start + 24, Endian.little);
  final end = start + size;
  if (headerSize < 28 || end > axml.length) {
    throw const FormatException('Bad string pool header');
  }
  final utf8Pool = flags & _utf8Flag != 0;
  final offsetsAt = start + headerSize;
  final styleOffsetsAt = offsetsAt + 4 * count;
  if (styleOffsetsAt + 4 * styleCount > end) {
    throw const FormatException('Bad string pool offsets');
  }

  final strings = <String>[];
  for (var i = 0; i < count; i++) {
    var p =
        start + stringsStart + bd.getUint32(offsetsAt + 4 * i, Endian.little);
    if (p >= end) throw const FormatException('String offset out of range');
    if (utf8Pool) {
      int readLen() {
        var l = axml[p++];
        if (l & 0x80 != 0) l = ((l & 0x7f) << 8) | axml[p++];
        return l;
      }

      readLen(); // UTF-16 length, unused
      final byteLen = readLen();
      if (p + byteLen > end) throw const FormatException('String overflow');
      strings.add(utf8.decode(axml.sublist(p, p + byteLen)));
    } else {
      var l = bd.getUint16(p, Endian.little);
      p += 2;
      if (l & 0x8000 != 0) {
        l = ((l & 0x7fff) << 16) | bd.getUint16(p, Endian.little);
        p += 2;
      }
      if (p + 2 * l > end) throw const FormatException('String overflow');
      final units = Uint16List(l);
      for (var j = 0; j < l; j++) {
        units[j] = bd.getUint16(p + 2 * j, Endian.little);
      }
      strings.add(String.fromCharCodes(units));
    }
  }

  return _Pool(
    start: start,
    end: end,
    headerSize: headerSize,
    flags: flags,
    strings: strings,
    styleOffsets: axml.sublist(styleOffsetsAt, styleOffsetsAt + 4 * styleCount),
    styleData: styleCount == 0
        ? Uint8List(0)
        : axml.sublist(start + stylesStart, end),
  );
}

/// Returns the string pool of a binary XML file.
List<String> readXmlStrings(Uint8List axml) => _parse(axml).strings;

Uint8List _encodeUtf8(String s) {
  final bytes = utf8.encode(s);
  final out = BytesBuilder();
  void len(int l) {
    if (l > 0x7fff) throw const FormatException('String too long');
    if (l > 0x7f) {
      out.addByte(0x80 | (l >> 8));
      out.addByte(l & 0xff);
    } else {
      out.addByte(l);
    }
  }

  len(s.length); // UTF-16 code units
  len(bytes.length);
  out.add(bytes);
  out.addByte(0);
  return out.toBytes();
}

Uint8List _encodeUtf16(String s) {
  final units = s.codeUnits;
  final out = ByteData(4 + 2 * units.length + 2);
  var p = 0;
  if (units.length > 0x7fff) {
    out.setUint16(p, 0x8000 | (units.length >> 16), Endian.little);
    out.setUint16(p + 2, units.length & 0xffff, Endian.little);
    p += 4;
  } else {
    out.setUint16(p, units.length, Endian.little);
    p += 2;
  }
  for (final u in units) {
    out.setUint16(p, u, Endian.little);
    p += 2;
  }
  return Uint8List.sublistView(out, 0, p + 2);
}

/// Replaces string-pool entries equal to a key of [replacements] with the
/// mapped value, rebuilding the pool. Throws [FormatException] if a key is
/// not present.
Uint8List replaceXmlStrings(Uint8List axml, Map<String, String> replacements) {
  final pool = _parse(axml);
  final missing = replacements.keys.where((k) => !pool.strings.contains(k));
  if (missing.isNotEmpty) {
    throw FormatException('String(s) not found in XML: ${missing.join(', ')}');
  }

  final blob = BytesBuilder();
  final offsets = ByteData(4 * pool.strings.length);
  for (var i = 0; i < pool.strings.length; i++) {
    offsets.setUint32(4 * i, blob.length, Endian.little);
    final s = replacements[pool.strings[i]] ?? pool.strings[i];
    blob.add(pool.isUtf8 ? _encodeUtf8(s) : _encodeUtf16(s));
  }
  while (blob.length % 4 != 0) {
    blob.addByte(0);
  }
  final strBytes = blob.toBytes();

  final stringsStart =
      pool.headerSize + offsets.lengthInBytes + pool.styleOffsets.length;
  final hasStyles = pool.styleOffsets.isNotEmpty;
  final stylesStart = hasStyles ? stringsStart + strBytes.length : 0;
  final poolSize = stringsStart + strBytes.length + pool.styleData.length;

  final head = Uint8List.fromList(
    axml.sublist(pool.start, pool.start + pool.headerSize),
  );
  final hd = ByteData.sublistView(head);
  hd.setUint32(4, poolSize, Endian.little);
  hd.setUint32(16, pool.flags & ~_sortedFlag, Endian.little);
  hd.setUint32(20, stringsStart, Endian.little);
  hd.setUint32(24, stylesStart, Endian.little);

  final out = BytesBuilder()
    ..add(axml.sublist(0, pool.start))
    ..add(head)
    ..add(offsets.buffer.asUint8List())
    ..add(pool.styleOffsets)
    ..add(strBytes)
    ..add(pool.styleData)
    ..add(axml.sublist(pool.end));
  final result = out.toBytes();
  ByteData.sublistView(result).setUint32(4, result.length, Endian.little);
  return result;
}
