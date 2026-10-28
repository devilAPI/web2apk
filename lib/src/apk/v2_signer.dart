import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'signing_key.dart';

/// v2 signature algorithm: RSASSA-PKCS1-v1_5 with SHA2-256.
const _algRsaPkcs1Sha256 = 0x0103;
const _v2BlockId = 0x7109871a;
const _chunkSize = 1024 * 1024;
const _eocdSig = 0x06054b50;
const _magic = 'APK Sig Block 42';

/// Signs [zip] (an unsigned ZIP, e.g. from `writeZip`) with APK Signature
/// Scheme v2 and returns the signed APK: entries ‖ APK Signing Block ‖
/// central directory ‖ EOCD (with its CD offset moved past the block).
///
/// See https://source.android.com/docs/security/features/apksigning/v2.
/// Throws [FormatException] if [zip] has no EOCD or its central directory is
/// not immediately followed by the EOCD, and [ArgumentError] if [zip] already
/// carries an APK Signing Block.
Uint8List signApkV2(Uint8List zip, SigningKey key) {
  final plan = _V2Plan(zip, key);
  return plan.finish(rsaSha256Sign(key.privateKey, plan.toBeSigned));
}

/// [signApkV2] with the RSA signature made by [sign] (RSASSA-PKCS1-v1_5 with
/// SHA-256 over its argument), e.g. by the browser's native WebCrypto.
Future<Uint8List> signApkV2With(
  Uint8List zip,
  SigningKey key,
  Future<Uint8List> Function(Uint8List message) sign,
) async {
  final plan = _V2Plan(zip, key);
  return plan.finish(await sign(plan.toBeSigned));
}

/// Everything of a v2 signature except the RSA signature itself.
class _V2Plan {
  _V2Plan(this.zip, this.key) {
    eocdOffset = _findEocd(zip);
    final bd = ByteData.sublistView(zip);
    final cdSize = bd.getUint32(eocdOffset + 12, Endian.little);
    cdOffset = bd.getUint32(eocdOffset + 16, Endian.little);
    if (cdOffset + cdSize != eocdOffset) {
      throw const FormatException(
        'Central directory is not immediately followed by the EOCD',
      );
    }
    if (_endsWithMagic(zip, cdOffset)) {
      throw ArgumentError('zip already carries an APK Signing Block');
    }

    final digest = _contentDigest([
      Uint8List.sublistView(zip, 0, cdOffset),
      Uint8List.sublistView(zip, cdOffset, eocdOffset),
      Uint8List.sublistView(zip, eocdOffset),
    ]);
    signedData = _lp(
      _concat([
        _lp(_lp(_concat([_u32(_algRsaPkcs1Sha256), _lp(digest)]))),
        _lp(_lp(key.certificateDer)),
        _lp(Uint8List(0)),
      ]),
    );
  }

  final Uint8List zip;
  final SigningKey key;
  late final int eocdOffset;
  late final int cdOffset;
  late final Uint8List signedData;

  /// The signature covers the signed-data payload, without its length prefix.
  Uint8List get toBeSigned => Uint8List.sublistView(signedData, 4);

  Uint8List finish(Uint8List signature) {
    final signer = _concat([
      signedData,
      _lp(_lp(_concat([_u32(_algRsaPkcs1Sha256), _lp(signature)]))),
      _lp(key.publicKeyDer),
    ]);
    final pairValue = _lp(_lp(signer));
    final pair = _concat([
      _u64(4 + pairValue.length),
      _u32(_v2BlockId),
      pairValue,
    ]);
    final magic = Uint8List.fromList(_magic.codeUnits);
    final blockSize = pair.length + 8 + magic.length;
    final block = _concat([_u64(blockSize), pair, _u64(blockSize), magic]);

    final newEocd = Uint8List.fromList(Uint8List.sublistView(zip, eocdOffset));
    ByteData.sublistView(newEocd)
        .setUint32(16, cdOffset + block.length, Endian.little);
    return _concat([
      Uint8List.sublistView(zip, 0, cdOffset),
      block,
      Uint8List.sublistView(zip, cdOffset, eocdOffset),
      newEocd,
    ]);
  }
}

/// Whether the APK Signing Block magic ends right before [cdOffset].
bool _endsWithMagic(Uint8List zip, int cdOffset) {
  if (cdOffset < _magic.length) return false;
  for (var i = 0; i < _magic.length; i++) {
    if (zip[cdOffset - _magic.length + i] != _magic.codeUnitAt(i)) return false;
  }
  return true;
}

int _findEocd(Uint8List zip) {
  final bd = ByteData.sublistView(zip);
  // EOCD is 22 bytes plus a comment of at most 65535 bytes.
  for (var i = zip.length - 22; i >= 0 && i >= zip.length - 22 - 0xffff; i--) {
    if (bd.getUint32(i, Endian.little) == _eocdSig &&
        bd.getUint16(i + 20, Endian.little) == zip.length - i - 22) {
      return i;
    }
  }
  throw const FormatException('No ZIP end-of-central-directory record');
}

/// Top-level v2 digest: chunk digests `SHA-256(0xa5 ‖ u32 len ‖ chunk)` over
/// 1 MiB chunks of each section, then `SHA-256(0x5a ‖ u32 count ‖ digests)`.
Uint8List _contentDigest(List<Uint8List> sections) {
  final chunkDigests = <Uint8List>[];
  for (final s in sections) {
    for (var off = 0; off < s.length; off += _chunkSize) {
      final end = off + _chunkSize < s.length ? off + _chunkSize : s.length;
      final out = _DigestSink();
      final input = sha256.startChunkedConversion(out)
        ..add([0xa5])
        ..add(_u32(end - off))
        ..add(Uint8List.sublistView(s, off, end));
      input.close();
      chunkDigests.add(out.bytes);
    }
  }
  final out = _DigestSink();
  final input = sha256.startChunkedConversion(out)
    ..add([0x5a])
    ..add(_u32(chunkDigests.length));
  for (final d in chunkDigests) {
    input.add(d);
  }
  input.close();
  return out.bytes;
}

class _DigestSink implements Sink<Digest> {
  late Uint8List bytes;

  @override
  void add(Digest data) => bytes = Uint8List.fromList(data.bytes);

  @override
  void close() {}
}

Uint8List _u32(int v) =>
    Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little);

Uint8List _u64(int v) {
  // Split into two u32 halves: setUint64 is unsupported on the web.
  final b = Uint8List(8);
  final bd = b.buffer.asByteData();
  bd.setUint32(0, v & 0xffffffff, Endian.little);
  bd.setUint32(4, v ~/ 0x100000000, Endian.little);
  return b;
}

/// u32le length prefix ‖ [data].
Uint8List _lp(Uint8List data) => _concat([_u32(data.length), data]);

Uint8List _concat(List<Uint8List> parts) {
  final out = BytesBuilder(copy: false);
  for (final p in parts) {
    out.add(p);
  }
  return out.toBytes();
}
