import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:web2apk/src/apk_actions.dart';
import 'package:web2apk/src/saved_apps.dart';

/// In-memory [SavedAppsStore], optionally seeded with raw prefs [values].
Future<SavedAppsStore> memoryStore([
  Map<String, Object> values = const {},
]) async {
  SharedPreferences.setMockInitialValues(values);
  return SavedAppsStore(await SharedPreferences.getInstance());
}

class FakeActions implements ApkActions {
  FakeActions({this.canInstall = true, this.canShare = true});

  @override
  final bool canInstall;
  @override
  final bool canShare;

  InstallResult installResult = InstallResult.started;
  bool saveResult = true;
  final saved = <Uint8List>[];
  final savedNames = <String>[];
  final savedMimes = <String>[];
  final installed = <String>[];
  final shared = <String>[];

  @override
  Future<InstallResult> install(Uint8List apk, String fileName) async {
    installed.add(fileName);
    return installResult;
  }

  @override
  Future<bool> save(Uint8List apk, String fileName) => saveFile(
    apk,
    fileName,
    mimeType: 'application/vnd.android.package-archive',
  );

  @override
  Future<bool> saveFile(
    Uint8List bytes,
    String fileName, {
    String mimeType = 'application/octet-stream',
  }) async {
    saved.add(bytes);
    savedNames.add(fileName);
    savedMimes.add(mimeType);
    return saveResult;
  }

  @override
  Future<void> share(Uint8List apk, String fileName) async {
    shared.add(fileName);
  }
}
