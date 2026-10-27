@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:web2apk/src/apk/signing_key.dart';
import 'package:web2apk/src/apk/v2_signer.dart';
import 'package:web2apk/src/apk/zip.dart';

import '../support/sdk_tools.dart';

void main() {
  late SigningKey key;
  late Directory tmp;
  final noApksigner = buildTool('apksigner') == null
      ? 'apksigner not found (set ANDROID_HOME)'
      : null;

  setUpAll(() {
    key = SigningKey.generate();
    tmp = Directory.systemTemp.createTempSync('web2apk_signer');
  });

  tearDownAll(() => tmp.deleteSync(recursive: true));

  Future<String> signToFile(SigningKey k, String name) async {
    final signed = signApkV2(writeZip(readZip(loadTemplate())), k);
    final f = File('${tmp.path}/$name.apk')..writeAsBytesSync(signed);
    return f.path;
  }

  Future<String> certSha256(String apk) async {
    final r = await runTool('apksigner', ['verify', '--print-certs', apk]);
    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
    final m = RegExp(r'certificate SHA-256 digest: ([0-9a-f]+)')
        .firstMatch(r.stdout as String);
    expect(m, isNotNull, reason: r.stdout as String);
    return m!.group(1)!;
  }

  test('json round-trip', () {
    final k2 = SigningKey.fromJson(key.toJson());
    expect(k2.privateKey.modulus, key.privateKey.modulus);
    expect(k2.privateKey.privateExponent, key.privateKey.privateExponent);
    expect(k2.publicKey.publicExponent, key.publicKey.publicExponent);
    expect(k2.certificateDer, key.certificateDer);
    // Reconstructed key signs identically (PKCS#1 v1.5 is deterministic).
    final zip = writeZip([
      ZipEntry.stored('a.txt', Uint8List.fromList([1, 2, 3])),
    ]);
    expect(signApkV2(zip, k2), signApkV2(zip, key));
  });

  test(
    'fromRsaParts rebuilds the key with a fresh valid certificate',
    () async {
      final k = key.privateKey;
      final rebuilt = SigningKey.fromRsaParts(
        n: k.modulus!,
        d: k.privateExponent!,
        p: k.p!,
        q: k.q!,
      );
      expect(rebuilt.publicKey.modulus, key.publicKey.modulus);
      expect(rebuilt.publicKey.exponent, BigInt.from(65537));
      // Survives the strict JSON validation (cert matches key).
      SigningKey.fromJson(rebuilt.toJson());
      if (noApksigner != null) return;
      final apk = await signToFile(rebuilt, 'rebuilt');
      final r = await runTool('apksigner', [
        'verify',
        '--min-sdk-version',
        '24',
        apk,
      ]);
      expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
    },
  );

  test('fromRsaParts accepts d reduced mod lcm(p-1,q-1) (WebCrypto style)', () {
    final k = key.privateKey;
    final p1 = k.p! - BigInt.one, q1 = k.q! - BigInt.one;
    final lambda = p1 * q1 ~/ p1.gcd(q1);
    final e = BigInt.from(65537);
    // Both d and d+lambda invert e mod lambda; pick the one that differs from
    // pointycastle's (p-1)(q-1) form so the normalisation is really exercised.
    final dPhi = e.modInverse(p1 * q1);
    var dLambda = e.modInverse(lambda);
    if (dLambda == dPhi) dLambda += lambda;
    final rebuilt = SigningKey.fromRsaParts(
      n: k.modulus!,
      d: dLambda,
      p: k.p!,
      q: k.q!,
    );
    expect(rebuilt.publicKey.exponent, e);
    SigningKey.fromJson(rebuilt.toJson());
    expect(
      () => SigningKey.fromRsaParts(
        n: k.modulus!,
        d: dLambda + BigInt.two,
        p: k.p!,
        q: k.q!,
      ),
      throwsFormatException,
    );
  });

  test('fromJson rejects garbage', () {
    expect(() => SigningKey.fromJson({'n': 'zz'}), throwsFormatException);
    expect(() => SigningKey.fromJson({}), throwsFormatException);
    final j = key.toJson();
    expect(
      () => SigningKey.fromJson({...j, 'cert': '!!notbase64'}),
      throwsFormatException,
    );
    expect(() => SigningKey.fromJson({...j, 'p': '3'}), throwsFormatException);
    expect(
      () => SigningKey.fromJson({...j, 'p': '1', 'q': j['n']}),
      throwsFormatException,
    );
  });

  test('apksigner verifies v2 signature', () async {
    final apk = await signToFile(key, 'a');
    final r = await runTool('apksigner', [
      'verify',
      '--verbose',
      '--min-sdk-version',
      '24',
      apk,
    ]);
    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
    expect(
      r.stdout,
      contains('Verified using v2 scheme (APK Signature Scheme v2): true'),
    );
  }, skip: noApksigner);

  test(
    'same key gives same certificate digest',
    () async {
      final d1 = await certSha256(await signToFile(key, 'b1'));
      final d2 = await certSha256(await signToFile(key, 'b2'));
      expect(d1, d2);
      final d3 = await certSha256(await signToFile(SigningKey.generate(), 'c'));
      expect(d3, isNot(d1));
    },
    skip: noApksigner,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
