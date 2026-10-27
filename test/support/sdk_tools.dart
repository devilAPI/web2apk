import 'dart:io';
import 'dart:typed_data';

/// Path of [name] in the newest `$ANDROID_HOME/build-tools/*` dir, or null.
String? buildTool(String name) {
  final home =
      Platform.environment['ANDROID_HOME'] ??
      Platform.environment['ANDROID_SDK_ROOT'];
  if (home == null) return null;
  final dir = Directory('$home/build-tools');
  if (!dir.existsSync()) return null;
  int cmp(List<int> a, List<int> b) {
    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i] != b[i]) return a[i].compareTo(b[i]);
    }
    return a.length.compareTo(b.length);
  }

  List<int> ver(Directory d) => d.uri.pathSegments
      .where((s) => s.isNotEmpty)
      .last
      .split('.')
      .map((p) => int.tryParse(p) ?? 0)
      .toList();
  final dirs = dir.listSync().whereType<Directory>().toList()
    ..sort((a, b) => cmp(ver(b), ver(a)));
  for (final d in dirs) {
    final f = File('${d.path}/$name');
    if (f.existsSync()) return f.path;
  }
  return null;
}

/// Reads `assets/template.apk`.
Uint8List loadTemplate() {
  final f = File('assets/template.apk');
  if (!f.existsSync()) {
    throw StateError(
      'assets/template.apk missing: run scripts/build_template.sh',
    );
  }
  return f.readAsBytesSync();
}

Future<ProcessResult> runTool(String name, List<String> args) {
  final path = buildTool(name);
  if (path == null) throw StateError('Android build tool not found: $name');
  return Process.run(path, args);
}
