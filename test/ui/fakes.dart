import 'dart:typed_data';

import 'package:web2apk/src/apk_actions.dart';

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
  final installed = <String>[];
  final shared = <String>[];

  @override
  Future<InstallResult> install(Uint8List apk, String fileName) async {
    installed.add(fileName);
    return installResult;
  }

  @override
  Future<bool> save(Uint8List apk, String fileName) async {
    saved.add(apk);
    savedNames.add(fileName);
    return saveResult;
  }

  @override
  Future<void> share(Uint8List apk, String fileName) async {
    shared.add(fileName);
  }
}
