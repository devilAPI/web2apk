import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import 'apk/app_spec.dart';
import 'apk/icons.dart';

const _kPrefsKey = 'saved_apps_v1';
const _kStoredIconSize = 192;
const _corrupt = FormatException('Saved apps are corrupt');

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

  /// The stored icon for [icon]: center-cropped and downscaled to 192x192.
  /// Slow for big images; callers may run it off the UI isolate.
  static Uint8List storedIcon(Uint8List icon) =>
      squarePng(icon, _kStoredIconSize);

  /// Snapshot of [spec]; the icon is center-cropped and downscaled to 192x192
  /// unless an already-downscaled [icon192] is given.
  factory SavedApp.fromSpec(
    AppSpec spec, {
    DateTime? now,
    Uint8List? icon192,
  }) => SavedApp(
    name: spec.name,
    url: spec.url,
    color: spec.color,
    fullscreen: spec.fullscreen,
    packageId: spec.packageId,
    icon: spec.icon == null ? null : (icon192 ?? storedIcon(spec.icon!)),
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
    if (raw is! String) throw _corrupt;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw _corrupt;
    }
    if (decoded is! List) {
      throw _corrupt;
    }
    return [
      for (final e in decoded)
        if (e is Map<String, dynamic>) SavedApp.fromJson(e) else throw _corrupt,
    ];
  }

  /// Adds or replaces [app] (by package id) and moves it to the top. A corrupt
  /// stored value is replaced by a list containing only [app].
  Future<void> upsert(SavedApp app) async {
    List<SavedApp> apps;
    try {
      apps = load()..removeWhere((a) => a.packageId == app.packageId);
    } on FormatException {
      apps = [];
    }
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
