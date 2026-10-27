import 'package:flutter/foundation.dart';

import '../apk/signing_key.dart';

SigningKey _generateInIsolate(void _) => SigningKey.generate();

/// Generates a signing key in a background isolate (pure-Dart RSA).
Future<SigningKey> generateSigningKey() => compute(_generateInIsolate, null);
