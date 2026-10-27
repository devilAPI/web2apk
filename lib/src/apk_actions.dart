import 'package:flutter/services.dart';

export 'actions/apk_actions_io.dart'
    if (dart.library.js_interop) 'actions/apk_actions_web.dart';

enum InstallResult { started, needsPermission }

/// What can be done with a generated APK on the current platform.
abstract class ApkActions {
  bool get canInstall;
  bool get canShare;
  Future<InstallResult> install(Uint8List apk, String fileName);

  /// Returns false when the user cancelled.
  Future<bool> save(Uint8List apk, String fileName);

  /// Saves arbitrary [bytes] under [fileName]. Returns false when the user
  /// cancelled.
  Future<bool> saveFile(
    Uint8List bytes,
    String fileName, {
    String mimeType = 'application/octet-stream',
  });
  Future<void> share(Uint8List apk, String fileName);
}
