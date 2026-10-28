import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:pointycastle/asn1.dart';
import 'package:web/web.dart' as web;

import '../apk/signing_key.dart';

/// Generates a signing key with the browser's WebCrypto (pure-Dart RSA key
/// generation is unusably slow under dart2js).
Future<SigningKey> generateSigningKey() async {
  final algorithm = JSObject()
    ..setProperty('name'.toJS, 'RSASSA-PKCS1-v1_5'.toJS)
    ..setProperty('modulusLength'.toJS, 2048.toJS)
    ..setProperty('publicExponent'.toJS, Uint8List.fromList([1, 0, 1]).toJS)
    ..setProperty('hash'.toJS, 'SHA-256'.toJS);

  final subtle = web.window.crypto.subtle;
  final pair =
      await subtle.generateKey(algorithm, true, ['sign'.toJS].toJS).toDart
          as JSObject;
  final privateKey = pair.getProperty('privateKey'.toJS) as web.CryptoKey;
  final pkcs8 =
      await subtle.exportKey('pkcs8', privateKey).toDart as JSArrayBuffer;
  return _signingKeyFromPkcs8(pkcs8.toDart.asUint8List());
}

/// The imported WebCrypto key of each [SigningKey], imported once.
final _imported = Expando<Future<web.CryptoKey>>();

JSObject _rsaAlgorithm() => JSObject()
  ..setProperty('name'.toJS, 'RSASSA-PKCS1-v1_5'.toJS)
  ..setProperty('hash'.toJS, 'SHA-256'.toJS);

/// RSASSA-PKCS1-v1_5 / SHA-256 signature of [message] with [key], made by
/// WebCrypto: pure-Dart RSA takes about half a second under dart2js, several
/// seconds on slow phones. Falls back to pure Dart where WebCrypto is
/// missing (insecure context) or fails. The signature is deterministic, so
/// both give the same bytes.
Future<Uint8List> rsaSign(SigningKey key, Uint8List message) async {
  try {
    final subtle = web.window.crypto.subtle;
    final cryptoKey = await (_imported[key] ??= subtle
        .importKey(
          'pkcs8',
          key.pkcs8Der.toJS,
          _rsaAlgorithm(),
          false,
          ['sign'.toJS].toJS,
        )
        .toDart);
    final sig =
        await subtle.sign(_rsaAlgorithm(), cryptoKey, message.toJS).toDart
            as JSArrayBuffer;
    return sig.toDart.asUint8List();
  } catch (_) {
    _imported[key] = null;
    return rsaSha256Sign(key.privateKey, message);
  }
}

SigningKey _signingKeyFromPkcs8(Uint8List der) {
  try {
    // PrivateKeyInfo ::= SEQUENCE { version, algorithm, privateKey OCTET STRING }
    final info = ASN1Parser(der).nextObject() as ASN1Sequence;
    final octets = info.elements![2] as ASN1OctetString;
    // RSAPrivateKey ::= SEQUENCE { version, n, e, d, p, q, dp, dq, qinv }
    final rsa =
        ASN1Parser(Uint8List.fromList(octets.octets!)).nextObject()
            as ASN1Sequence;
    BigInt at(int i) => (rsa.elements![i] as ASN1Integer).integer!;
    return SigningKey.fromRsaParts(n: at(1), d: at(3), p: at(4), q: at(5));
  } on FormatException {
    rethrow;
  } catch (e) {
    throw FormatException('WebCrypto returned an unexpected PKCS#8 key ($e)');
  }
}
