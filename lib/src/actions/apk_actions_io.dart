import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../apk_actions.dart';

const _apkMime = 'application/vnd.android.package-archive';

/// Real implementation for Android and desktop. Platform-specific code lives
/// only in this directory.
class PlatformApkActions implements ApkActions {
  static const _channel = MethodChannel('de.devilapi.web2apk/install');

  @override
  bool get canInstall => Platform.isAndroid;

  @override
  bool get canShare => Platform.isAndroid || Platform.isMacOS;

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

  /// file_picker 13 writes [apk] to the chosen path itself on Android, Linux,
  /// macOS and Windows (its desktop backends write after the dialog), so the
  /// bytes must not be written again here.
  @override
  Future<bool> save(Uint8List apk, String fileName) async {
    final result = await FilePicker.saveFile(
      fileName: fileName,
      bytes: apk,
      mimeType: _apkMime,
    );
    return result != null;
  }

  @override
  Future<void> share(Uint8List apk, String fileName) async {
    final path = await _writeTemp(apk, fileName);
    await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
  }
}
