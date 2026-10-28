import 'package:flutter/foundation.dart';

import 'apk/apk_builder.dart';
import 'apk/app_spec.dart';
import 'apk/signing_key.dart';
import 'apk/v2_signer.dart';
import 'crypto/crypto.dart';

/// Everything the build isolate needs, sent through [compute] as one message.
class _BuildJob {
  const _BuildJob(this.template, this.spec, this.key);
  final Uint8List template;
  final AppSpec spec;
  final SigningKey key;
}

Uint8List _buildInIsolate(_BuildJob job) =>
    buildApk(template: job.template, spec: job.spec, key: job.key);

/// Builds the signed APK for [spec] without blocking the UI for long.
///
/// Native platforms build in a background isolate. The web has none
/// ([compute] runs inline), so there the cheap patching runs inline and the
/// expensive RSA signature is made by WebCrypto.
Future<Uint8List> buildSignedApk({
  required Uint8List template,
  required AppSpec spec,
  required SigningKey key,
}) async {
  if (!kIsWeb) return compute(_buildInIsolate, _BuildJob(template, spec, key));
  final zip = buildUnsignedApk(template: template, spec: spec);
  return signApkV2With(zip, key, (message) => rsaSign(key, message));
}
