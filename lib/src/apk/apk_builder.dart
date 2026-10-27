import 'dart:convert';
import 'dart:typed_data';

import 'app_spec.dart';
import 'axml.dart';
import 'icons.dart';
import 'signing_key.dart';
import 'template_contract.dart';
import 'v2_signer.dart';
import 'zip.dart';

final _oldSignature = RegExp(
  r'^META-INF/(.*\.(SF|RSA|DSA|EC)|MANIFEST\.MF)$',
  caseSensitive: false,
);

/// Patches [template] for [spec] and returns a v2-signed APK.
///
/// Throws [ArgumentError] for an empty name or an invalid package id, and
/// [FormatException] if the icon cannot be decoded.
Uint8List buildApk({
  required Uint8List template,
  required AppSpec spec,
  required SigningKey key,
}) {
  final name = spec.name.trim();
  if (name.isEmpty) throw ArgumentError.value(spec.name, 'name', 'is empty');
  if (!isValidPackageId(spec.packageId)) {
    throw ArgumentError.value(spec.packageId, 'packageId', 'invalid');
  }

  final entries = readZip(template)
      .where((e) => !_oldSignature.hasMatch(e.name))
      .toList();

  int indexOf(String n) => entries.indexWhere((e) => e.name == n);

  final mi = indexOf(kManifestPath);
  if (mi < 0) throw const FormatException('Template has no manifest');
  final manifest = entries[mi];
  final patched = replaceXmlStrings(manifest.data, {
    kTemplatePackage: spec.packageId,
    kTemplateLabel: name,
  });
  entries[mi] = manifest.method == 0
      ? ZipEntry.stored(manifest.name, patched)
      : ZipEntry.deflated(manifest.name, patched);

  final config = ZipEntry.deflated(
    kConfigPath,
    Uint8List.fromList(utf8.encode(spec.configJson())),
  );
  final ci = indexOf(kConfigPath);
  ci < 0 ? entries.add(config) : entries[ci] = config;

  final icon = spec.icon;
  if (icon != null) {
    final paths = entries.map((e) => e.name).where(kIconPath.hasMatch).toList();
    final icons = renderLauncherIcons(icon, paths);
    for (final p in paths) {
      entries[indexOf(p)] = ZipEntry.stored(p, icons[p]!);
    }
  }

  return signApkV2(writeZip(entries), key);
}
