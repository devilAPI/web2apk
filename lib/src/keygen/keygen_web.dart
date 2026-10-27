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
