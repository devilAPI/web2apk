import 'package:flutter/foundation.dart';

import '../apk/signing_key.dart';

SigningKey _generateInIsolate(void _) => SigningKey.generate();

/// Generates a signing key in a background isolate (pure-Dart RSA).
Future<SigningKey> generateSigningKey() => compute(_generateInIsolate, null);

/// RSASSA-PKCS1-v1_5 / SHA-256 signature of [message] with [key]. Pure Dart,
/// fast enough on the VM.
Future<Uint8List> rsaSign(SigningKey key, Uint8List message) async =>
    rsaSha256Sign(key.privateKey, message);
