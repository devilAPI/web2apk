import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'apk/signing_key.dart';
import 'crypto/crypto.dart';

const signingKeyPrefsKey = 'signing_key_v1';

/// Returns the persisted signing key, creating and storing one on first use.
///
/// A stored value that cannot be read is never replaced: regenerating would
/// silently break in-place updates of apps signed with the old key. A
/// [StateError] is thrown instead and the stored value is left untouched.
Future<SigningKey> loadOrCreateSigningKey(
  SharedPreferences prefs, {
  Future<SigningKey> Function()? generate,
}) async {
  if (prefs.containsKey(signingKeyPrefsKey)) return _readStored(prefs);
  // Two callers (Signing key page + Generate on first run) must not each
  // generate a key: the later write would silently replace the first.
  final running = _generating[prefs];
  if (running != null) return running;
  final future = _generateAndStore(prefs, generate ?? generateSigningKey);
  _generating[prefs] = future;
  try {
    return await future;
  } finally {
    _generating[prefs] = null;
  }
}

final _generating = Expando<Future<SigningKey>>('signing key generation');

SigningKey _readStored(SharedPreferences prefs) {
  try {
    final raw = prefs.get(signingKeyPrefsKey);
    if (raw is! String) throw const FormatException('not a string');
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('not a JSON object');
    }
    return SigningKey.fromJson(decoded);
  } on FormatException catch (e) {
    throw StateError('Stored signing key is unreadable: ${e.message}');
  }
}

Future<SigningKey> _generateAndStore(
  SharedPreferences prefs,
  Future<SigningKey> Function() generate,
) async {
  final key = await generate();
  // Something else (another tab/isolate-free caller) may have stored a key
  // while we were generating: that one wins, ours is discarded.
  if (prefs.containsKey(signingKeyPrefsKey)) return _readStored(prefs);
  final ok = await prefs.setString(
    signingKeyPrefsKey,
    jsonEncode(key.toJson()),
  );
  if (!ok) throw StateError('Signing key could not be stored');
  return key;
}

/// Persists [key] as the signing key, replacing any stored value (including
/// an unreadable one). Throws [StateError] if it could not be stored.
Future<void> replaceSigningKey(SharedPreferences prefs, SigningKey key) async {
  final ok = await prefs.setString(
    signingKeyPrefsKey,
    jsonEncode(key.toJson()),
  );
  if (!ok) throw StateError('Signing key could not be stored');
}
