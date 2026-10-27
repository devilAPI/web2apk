import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

enum InstallResult { started, needsPermission }

/// What can be done with a generated APK on the current platform.
abstract class ApkActions {
  bool get canInstall;
  bool get canShare;
  Future<InstallResult> install(Uint8List apk, String fileName);

  /// Returns false when the user cancelled.
  Future<bool> save(Uint8List apk, String fileName);
  Future<void> share(Uint8List apk, String fileName);
}

/// Real implementation. Platform-specific code lives only here.
class PlatformApkActions implements ApkActions {
  static const _channel = MethodChannel('de.devilapi.web2apk/install');

  @override
  bool get canInstall => Platform.isAndroid;

  @override
  bool get canShare => Platform.isAndroid;

  Future<String> _writeTemp(Uint8List apk, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(apk, flush: true);
    return file.path;
  }

  @override
  Future<InstallResult> install(Uint8List apk, String fileName) async {
    final path = await _writeTemp(apk, fileName);
    final r = await _channel.invokeMethod<String>('install', {'path': path});
    return r == 'needs_permission'
        ? InstallResult.needsPermission
        : InstallResult.started;
  }

  @override
  Future<bool> save(Uint8List apk, String fileName) async {
    final result = await FilePicker.saveFile(
      fileName: fileName,
      bytes: apk,
    );
    return result != null;
  }

  @override
  Future<void> share(Uint8List apk, String fileName) async {
    final path = await _writeTemp(apk, fileName);
    await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
  }
}
