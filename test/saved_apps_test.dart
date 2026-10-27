import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web2apk/src/apk/app_spec.dart';
import 'package:web2apk/src/saved_apps.dart';

SavedApp app(
  String id, {
  String name = 'App',
  int minute = 0,
  Uint8List? icon,
}) => SavedApp(
  name: name,
  url: 'https://$id.example',
  color: 0xFF2196F3,
  fullscreen: false,
  packageId: id,
  icon: icon,
  updatedAt: DateTime.utc(2026, 1, 1, 0, minute),
);

Future<SavedAppsStore> newStore([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  return SavedAppsStore(await SharedPreferences.getInstance());
}

void main() {
  test('empty store loads []', () async {
    expect((await newStore()).load(), isEmpty);
  });

  test('upsert two -> newest first', () async {
    final s = await newStore();
    await s.upsert(app('a.b'));
    await s.upsert(app('c.d'));
    expect(s.load().map((e) => e.packageId), ['c.d', 'a.b']);
  });

  test('upsert same packageId -> one entry, updated, moved first', () async {
    final s = await newStore();
    await s.upsert(app('a.b', name: 'Old'));
    await s.upsert(app('c.d'));
    await s.upsert(app('a.b', name: 'New'));
    final l = s.load();
    expect(l.map((e) => e.packageId), ['a.b', 'c.d']);
    expect(l.first.name, 'New');
  });

  test('remove', () async {
    final s = await newStore();
    await s.upsert(app('a.b'));
    await s.upsert(app('c.d'));
    await s.remove('a.b');
    expect(s.load().map((e) => e.packageId), ['c.d']);
    await s.remove('missing.id');
    expect(s.load(), hasLength(1));
  });

  test('JSON round-trip incl. icon bytes', () {
    final a = app('a.b', icon: Uint8List.fromList([1, 2, 3, 255]));
    final b = SavedApp.fromJson(
      jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>,
    );
    expect(b.name, a.name);
    expect(b.url, a.url);
    expect(b.color, a.color);
    expect(b.fullscreen, a.fullscreen);
    expect(b.packageId, a.packageId);
    expect(b.icon, a.icon);
    expect(b.updatedAt, a.updatedAt);
    final c = SavedApp.fromJson(app('x.y').toJson());
    expect(c.icon, isNull);
  });

  test('fromSpec downscales a 4000x4000 icon to 192x192 PNG', () {
    final big = img.Image(width: 4000, height: 4000)
      ..clear(img.ColorRgba8(10, 200, 30, 255));
    final spec = AppSpec(
      name: 'N',
      url: 'https://x.org',
      color: 0xFF000000,
      fullscreen: true,
      packageId: 'org.x.web2apk',
      icon: img.encodePng(big, level: 0),
    );
    final saved = SavedApp.fromSpec(spec, now: DateTime.utc(2026));
    final d = img.decodePng(saved.icon!)!;
    expect((d.width, d.height), (192, 192));
    expect(saved.updatedAt, DateTime.utc(2026));
    expect(
      SavedApp.fromSpec(
        AppSpec(
          name: 'N',
          url: 'u',
          color: 0,
          fullscreen: false,
          packageId: 'a.b',
        ),
      ).icon,
      isNull,
    );
  });

  test('corrupt value: load and remove throw and preserve it', () async {
    const bad = '{not json';
    final s = await newStore({'saved_apps_v1': bad});
    expect(s.load, throwsFormatException);
    await expectLater(s.remove('a.b'), throwsFormatException);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('saved_apps_v1'), bad);
  });

  test('upsert replaces a corrupt value with [app]', () async {
    final s = await newStore({'saved_apps_v1': '{not json'});
    await s.upsert(app('a.b'));
    expect(s.load().map((a) => a.packageId), ['a.b']);
  });

  test('wrong-shaped JSON is also a FormatException', () async {
    for (final v in ['{"a":1}', '[1]', '[{"name":1}]']) {
      final s = await newStore({'saved_apps_v1': v});
      expect(s.load, throwsFormatException, reason: v);
    }
  });
}
