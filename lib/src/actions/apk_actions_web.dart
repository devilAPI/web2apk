import 'dart:js_interop';

import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

import '../apk_actions.dart';

const _apkMime = 'application/vnd.android.package-archive';

/// Browser implementation: only Save, as a download of `<name>.apk`.
class PlatformApkActions implements ApkActions {
  @override
  bool get canInstall => false;

  @override
  bool get canShare => false;

  @override
  Future<InstallResult> install(Uint8List apk, String fileName) =>
      throw UnsupportedError('Install is not available on web');

  @override
  Future<void> share(Uint8List apk, String fileName) =>
      throw UnsupportedError('Share is not available on web');

  @override
  Future<bool> save(Uint8List apk, String fileName) =>
      saveFile(apk, fileName, mimeType: _apkMime);

  @override
  Future<bool> saveFile(
    Uint8List bytes,
    String fileName, {
    String mimeType = 'application/octet-stream',
  }) async {
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = fileName
      ..style.display = 'none';
    web.document.body!.append(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);
    return true;
  }
}
