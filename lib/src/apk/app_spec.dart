import 'dart:convert';
import 'dart:typed_data';

/// Form data for one generated app, plus URL / package-id rules.
class AppSpec {
  final String name;
  final String url;

  /// ARGB color.
  final int color;
  final bool fullscreen;
  final String packageId;
  final Uint8List? icon;

  const AppSpec({
    required this.name,
    required this.url,
    required this.color,
    required this.fullscreen,
    required this.packageId,
    this.icon,
  });

  /// Contents of `assets/config.json` in the generated APK.
  String configJson() {
    final rgb = (color & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return jsonEncode({
      'url': url,
      'title': name,
      'color': '#${rgb.toUpperCase()}',
      'fullscreen': fullscreen,
    });
  }
}

/// Trims, adds `https://` when no scheme is given, lowercases scheme and host.
/// Throws [FormatException] for non-http(s) schemes or an empty host.
String normalizeUrl(String input) {
  var s = input.trim();
  if (s.isEmpty) throw const FormatException('URL is empty');
  if (!s.contains('://')) s = 'https://$s';
  final Uri uri;
  try {
    uri = Uri.parse(s);
  } on FormatException {
    throw const FormatException('Invalid URL');
  }
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') {
    throw FormatException('Unsupported URL scheme: ${uri.scheme}');
  }
  if (uri.host.isEmpty) throw const FormatException('URL has no host');
  return uri.replace(scheme: scheme, host: uri.host.toLowerCase()).toString();
}

/// Derives a valid Android package id: reversed host + `web2apk`.
String packageIdFromUrl(String url) {
  var host = Uri.parse(normalizeUrl(url)).host.toLowerCase();
  if (host.startsWith('www.')) host = host.substring(4);
  final segments = host
      .split('.')
      .where((p) => p.isNotEmpty)
      .toList()
      .reversed
      .map((p) {
        final clean = p.replaceAll(RegExp(r'[^a-z0-9_]'), '_');
        return RegExp(r'^[a-z]').hasMatch(clean) ? clean : 'x$clean';
      });
  return [...segments, 'web2apk'].join('.');
}

final _packageIdRe = RegExp(
  r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$',
);

bool isValidPackageId(String id) => _packageIdRe.hasMatch(id);
