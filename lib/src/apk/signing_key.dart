import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';
import 'package:pointycastle/asn1.dart';

final _e = BigInt.from(65537);

/// OID 1.2.840.113549.1.1.1 rsaEncryption.
const _oidRsaEncryption = [1, 2, 840, 113549, 1, 1, 1];

/// OID 1.2.840.113549.1.1.11 sha256WithRSAEncryption.
const _oidSha256WithRsa = [1, 2, 840, 113549, 1, 1, 11];

/// OID 2.5.4.3 commonName.
const _oidCommonName = [2, 5, 4, 3];

/// RSA 2048 signing key plus its self-signed X.509 certificate (`CN=web2apk`).
class SigningKey {
  final RSAPrivateKey privateKey;
  final RSAPublicKey publicKey;
  final Uint8List certificateDer;

  SigningKey._(this.privateKey, this.publicKey, this.certificateDer);

  /// Generates a fresh 2048-bit key (e = 65537) and a self-signed certificate
  /// valid from yesterday for 30 years. Slow (seconds) in pure Dart.
  static SigningKey generate() {
    final random = _secureRandom();
    final gen = RSAKeyGenerator()
      ..init(
        ParametersWithRandom(RSAKeyGeneratorParameters(_e, 2048, 64), random),
      );
    final priv = gen.generateKeyPair().privateKey;
    return SigningKey.fromRsaParts(
      n: priv.modulus!,
      d: priv.privateExponent!,
      p: priv.p!,
      q: priv.q!,
    );
  }

  /// Builds a signing key (e = 65537) from externally generated RSA parts,
  /// e.g. from WebCrypto, and issues its self-signed certificate (valid from
  /// yesterday for 30 years). Throws [FormatException] for inconsistent parts
  /// or a public exponent other than 65537.
  factory SigningKey.fromRsaParts({
    required BigInt n,
    required BigInt d,
    required BigInt p,
    required BigInt q,
  }) {
    // WebCrypto (BoringSSL) reduces d modulo lcm(p-1, q-1) while pointycastle
    // derives the public exponent as d^-1 mod (p-1)(q-1), so a perfectly valid
    // external d can make it yield a different e. Validate the parts and
    // normalise d to the (p-1)(q-1) form, which signs identically.
    final p1 = p - BigInt.one, q1 = q - BigInt.one;
    if (n != p * q ||
        (d * _e) % p1 != BigInt.one ||
        (d * _e) % q1 != BigInt.one) {
      throw const FormatException('SigningKey: inconsistent RSA values');
    }
    final dCanonical = _e.modInverse(p1 * q1);
    final RSAPrivateKey priv;
    try {
      priv = RSAPrivateKey(n, dCanonical, p, q);
    } catch (e) {
      throw FormatException('SigningKey: inconsistent RSA values ($e)');
    }
    final pub = RSAPublicKey(n, _e);
    return SigningKey._(
      priv,
      pub,
      _selfSignedCertificate(priv, pub, _secureRandom()),
    );
  }

  /// SubjectPublicKeyInfo DER of [publicKey] (as embedded in the certificate).
  Uint8List get publicKeyDer => _subjectPublicKeyInfo(publicKey).encode();

  /// `n, d, p, q` as lowercase hex, `cert` as base64 DER.
  Map<String, String> toJson() => {
    'n': privateKey.modulus!.toRadixString(16),
    'd': privateKey.privateExponent!.toRadixString(16),
    'p': privateKey.p!.toRadixString(16),
    'q': privateKey.q!.toRadixString(16),
    'cert': base64.encode(certificateDer),
  };

  /// Inverse of [toJson]. Throws [FormatException] when a field is missing or
  /// malformed, the RSA values are inconsistent, the public exponent is not
  /// 65537, or the certificate does not carry this key's public key.
  factory SigningKey.fromJson(Map<String, dynamic> json) {
    String field(String name) {
      final v = json[name];
      if (v is! String || v.isEmpty) {
        throw FormatException('SigningKey: missing or non-string "$name"');
      }
      return v;
    }

    BigInt hex(String name) {
      final s = field(name);
      if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(s)) {
        throw FormatException('SigningKey: "$name" is not hex', s);
      }
      return BigInt.parse(s, radix: 16);
    }

    final n = hex('n'), d = hex('d'), p = hex('p'), q = hex('q');
    final Uint8List cert;
    try {
      cert = base64.decode(field('cert'));
    } on FormatException {
      throw const FormatException('SigningKey: "cert" is not base64');
    }

    // WebCrypto (BoringSSL) reduces d modulo lcm(p-1, q-1) while pointycastle
    // derives the public exponent as d^-1 mod (p-1)(q-1), so a perfectly valid
    // external d can make it yield a different e. Validate the parts and
    // normalise d to the (p-1)(q-1) form, which signs identically.
    final p1 = p - BigInt.one, q1 = q - BigInt.one;
    if (n != p * q ||
        (d * _e) % p1 != BigInt.one ||
        (d * _e) % q1 != BigInt.one) {
      throw const FormatException('SigningKey: inconsistent RSA values');
    }
    final dCanonical = _e.modInverse(p1 * q1);
    final RSAPrivateKey priv;
    try {
      priv = RSAPrivateKey(n, dCanonical, p, q);
    } catch (e) {
      throw FormatException('SigningKey: inconsistent RSA values ($e)');
    }
    if (_certificateModulus(cert) != n) {
      throw const FormatException(
        'SigningKey: certificate does not match the key',
      );
    }
    return SigningKey._(priv, RSAPublicKey(n, _e), cert);
  }
}

SecureRandom _secureRandom() {
  final seedSource = Random.secure();
  final seed = Uint8List.fromList(
    List.generate(32, (_) => seedSource.nextInt(256)),
  );
  return FortunaRandom()..seed(KeyParameter(seed));
}

/// RSA PKCS#1 v1.5 signature with SHA-256.
Uint8List rsaSha256Sign(RSAPrivateKey key, Uint8List message) {
  final signer = Signer('SHA-256/RSA')
    ..init(true, PrivateKeyParameter<RSAPrivateKey>(key));
  return (signer.generateSignature(message) as RSASignature).bytes;
}

ASN1Sequence _algorithmIdentifier(List<int> oid) =>
    ASN1Sequence(elements: [ASN1ObjectIdentifier(oid), ASN1Null()]);

ASN1Sequence _subjectPublicKeyInfo(RSAPublicKey key) {
  final rsaKey = ASN1Sequence(
    elements: [ASN1Integer(key.modulus), ASN1Integer(key.publicExponent)],
  );
  return ASN1Sequence(
    elements: [
      _algorithmIdentifier(_oidRsaEncryption),
      ASN1BitString(stringValues: rsaKey.encode())..unusedbits = 0,
    ],
  );
}

ASN1Sequence _name(String commonName) => ASN1Sequence(
  elements: [
    ASN1Set(
      elements: [
        ASN1Sequence(
          elements: [
            ASN1ObjectIdentifier(_oidCommonName),
            ASN1UTF8String(utf8StringValue: commonName),
          ],
        ),
      ],
    ),
  ],
);

/// GeneralizedTime `YYYYMMDDHHMMSSZ`. Hand-encoded: pointycastle's encoder
/// does not zero-pad the fields.
ASN1Object _generalizedTime(DateTime t) {
  final u = t.toUtc();
  String two(int v) => v.toString().padLeft(2, '0');
  final s =
      '${u.year.toString().padLeft(4, '0')}${two(u.month)}${two(u.day)}'
      '${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
  return ASN1Object(tag: ASN1Tags.GENERALIZED_TIME)
    ..valueBytes = Uint8List.fromList(ascii.encode(s));
}

Uint8List _selfSignedCertificate(
  RSAPrivateKey priv,
  RSAPublicKey pub,
  SecureRandom random,
) {
  // Positive, non-zero 63-bit serial.
  var serial = BigInt.zero;
  while (serial == BigInt.zero) {
    final b = random.nextBytes(8);
    b[0] &= 0x7f;
    serial = b.fold(BigInt.zero, (a, x) => (a << 8) | BigInt.from(x));
  }
  final now = DateTime.now().toUtc();
  final notBefore = now.subtract(const Duration(days: 1));
  final notAfter = DateTime.utc(
    now.year + 30,
    now.month,
    now.day,
    now.hour,
    now.minute,
    now.second,
  );

  final tbs = ASN1Sequence(
    elements: [
      ASN1Object(tag: 0xa0)..valueBytes = ASN1Integer(BigInt.two).encode(),
      ASN1Integer(serial),
      _algorithmIdentifier(_oidSha256WithRsa),
      _name('web2apk'),
      ASN1Sequence(
        elements: [ASN1UtcTime(notBefore), _generalizedTime(notAfter)],
      ),
      _name('web2apk'),
      _subjectPublicKeyInfo(pub),
    ],
  );
  final tbsDer = tbs.encode();
  final cert = ASN1Sequence(
    elements: [
      tbs,
      _algorithmIdentifier(_oidSha256WithRsa),
      ASN1BitString(stringValues: rsaSha256Sign(priv, tbsDer))..unusedbits = 0,
    ],
  );
  return cert.encode();
}

/// Modulus of the RSA key in [certDer]'s SubjectPublicKeyInfo.
BigInt _certificateModulus(Uint8List certDer) {
  try {
    final cert = ASN1Parser(certDer).nextObject() as ASN1Sequence;
    final tbs = cert.elements![0] as ASN1Sequence;
    final spki = tbs.elements![6] as ASN1Sequence;
    final bits = spki.elements![1] as ASN1BitString;
    final rsaKey =
        ASN1Parser(Uint8List.fromList(bits.stringValues!)).nextObject()
            as ASN1Sequence;
    return (rsaKey.elements![0] as ASN1Integer).integer!;
  } catch (_) {
    throw const FormatException('SigningKey: "cert" is not an X.509 RSA cert');
  }
}
