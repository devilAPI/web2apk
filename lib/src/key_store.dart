import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'apk/signing_key.dart';

const signingKeyPrefsKey = 'signing_key_v1';

SigningKey _generateInIsolate(void _) => SigningKey.generate();

Future<SigningKey> _defaultGenerate() => compute(_generateInIsolate, null);

/// Returns the persisted signing key, creating and storing one on first use.
///
/// A stored value that cannot be read is never replaced: regenerating would
/// silently break in-place updates of apps signed with the old key. A
/// [StateError] is thrown instead and the stored value is left untouched.
Future<SigningKey> loadOrCreateSigningKey(
  SharedPreferences prefs, {
  Future<SigningKey> Function()? generate,
}) async {
  if (prefs.containsKey(signingKeyPrefsKey)) {
    try {
      final raw = prefs.get(signingKeyPrefsKey);
      if (raw is! String) throw const FormatException('not a string');
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('not a JSON object');
      }
      return SigningKey.fromJson(decoded);
    } on FormatException {
      throw StateError('Stored signing key is unreadable');
    }
  }
  final key = await (generate ?? _defaultGenerate)();
  final ok = await prefs.setString(signingKeyPrefsKey, jsonEncode(key.toJson()));
  if (!ok) throw StateError('Signing key could not be stored');
  return key;
}
