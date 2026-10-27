import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'apk/app_spec.dart';
import 'apk/icons.dart';

const _kPrefsKey = 'saved_apps_v1';
const _kStoredIconSize = 192;

/// One remembered generated app (form data + a small icon), so it can be
/// regenerated with the same package id.
class SavedApp {
  final String name;
  final String url;

  /// ARGB color.
  final int color;
  final bool fullscreen;
  final String packageId;

  /// 192x192 PNG, or null when the app has no custom icon.
  final Uint8List? icon;
  final DateTime updatedAt;

  const SavedApp({
    required this.name,
    required this.url,
    required this.color,
    required this.fullscreen,
    required this.packageId,
    required this.updatedAt,
    this.icon,
  });

  /// Snapshot of [spec]; the icon is center-cropped and downscaled to 192x192.
  factory SavedApp.fromSpec(AppSpec spec, {DateTime? now}) => SavedApp(
    name: spec.name,
    url: spec.url,
    color: spec.color,
    fullscreen: spec.fullscreen,
    packageId: spec.packageId,
    icon: spec.icon == null ? null : squarePng(spec.icon!, _kStoredIconSize),
    updatedAt: (now ?? DateTime.now()).toUtc(),
  );

  factory SavedApp.fromJson(Map<String, dynamic> json) {
    try {
      final icon = json['icon'];
      return SavedApp(
        name: json['name'] as String,
        url: json['url'] as String,
        color: json['color'] as int,
        fullscreen: json['fullscreen'] as bool,
        packageId: json['packageId'] as String,
        icon: icon == null ? null : base64Decode(icon as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
    } on FormatException {
      rethrow;
    } on TypeError catch (e) {
      throw FormatException('Invalid saved app: $e');
    }
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'url': url,
    'color': color,
    'fullscreen': fullscreen,
    'packageId': packageId,
    'icon': icon == null ? null : base64Encode(icon!),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  AppSpec toSpec() => AppSpec(
    name: name,
    url: url,
    color: color,
    fullscreen: fullscreen,
    packageId: packageId,
    icon: icon,
  );
}

/// Persists saved apps (newest first, unique by package id) in
/// [SharedPreferences] under `saved_apps_v1`.
class SavedAppsStore {
  final SharedPreferences _prefs;
  SavedAppsStore(this._prefs);

  /// Throws [FormatException] when the stored value is corrupt.
  List<SavedApp> load() {
    final raw = _prefs.get(_kPrefsKey);
    if (raw == null) return [];
    if (raw is! String) throw const FormatException('Saved apps are corrupt');
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('Saved apps are corrupt');
    }
    if (decoded is! List) {
      throw const FormatException('Saved apps are corrupt');
    }
    return [
      for (final e in decoded)
        if (e is Map<String, dynamic>)
          SavedApp.fromJson(e)
        else
          throw const FormatException('Saved apps are corrupt'),
    ];
  }

  /// Adds or replaces [app] (by package id) and moves it to the top. Throws
  /// without writing when the stored value is corrupt.
  Future<void> upsert(SavedApp app) async {
    final apps = load()..removeWhere((a) => a.packageId == app.packageId);
    await _save([app, ...apps]);
  }

  Future<void> remove(String packageId) async {
    final apps = load()..removeWhere((a) => a.packageId == packageId);
    await _save(apps);
  }

  Future<void> _save(List<SavedApp> apps) => _prefs.setString(
    _kPrefsKey,
    jsonEncode([for (final a in apps) a.toJson()]),
  );
}
