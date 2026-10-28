@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:web2apk/src/apk/signing_key.dart';
import 'package:web2apk/src/crypto/crypto.dart';

import 'fixtures/golden_key.dart';

void main() {
  test('WebCrypto key generation is fast and round-trips', () async {
    final sw = Stopwatch()..start();
    final k = await generateSigningKey();
    sw.stop();
    expect(sw.elapsed, lessThan(const Duration(seconds: 45)));
    expect(k.publicKey.exponent, BigInt.from(65537));
    expect(k.publicKey.modulus!.bitLength, 2048);
    final k2 = SigningKey.fromJson(k.toJson());
    expect(k2.privateKey.modulus, k.privateKey.modulus);
    expect(k2.certificateDer, k.certificateDer);
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('WebCrypto signature equals the pure-Dart one', () async {
    final k = SigningKey.fromJson(goldenKeyJson);
    final message = Uint8List.fromList(List.generate(1000, (i) => i % 251));
    expect(await rsaSign(k, message), rsaSha256Sign(k.privateKey, message));
  });
}
