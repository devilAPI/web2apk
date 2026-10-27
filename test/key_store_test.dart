import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web2apk/src/apk/signing_key.dart';
import 'package:web2apk/src/key_store.dart';

import 'fixtures/golden_key.dart';

void main() {
  late SigningKey fixed;
  // Fixture key: generating 2048-bit RSA in pure Dart is far too slow in
  // dart2js tests.
  setUpAll(() => fixed = SigningKey.fromJson(goldenKeyJson));

  Future<SigningKey> Function() counting(List<int> calls) => () async {
    calls.add(1);
    return fixed;
  };

  test('creates and stores when empty', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final calls = <int>[];
    final key = await loadOrCreateSigningKey(prefs, generate: counting(calls));
    expect(calls.length, 1);
    expect(key.publicKey.modulus, fixed.publicKey.modulus);
    expect(prefs.getString('signing_key_v1'), isNotNull);
  });

  test('reuses stored key', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final calls = <int>[];
    await loadOrCreateSigningKey(prefs, generate: counting(calls));
    final again = await loadOrCreateSigningKey(
      prefs,
      generate: counting(calls),
    );
    expect(calls.length, 1);
    expect(again.publicKey.modulus, fixed.publicKey.modulus);
  });

  for (final bad in ['not json', '{"a":"b"}', '[1,2]']) {
    test('corrupt value "$bad" throws and is preserved', () async {
      SharedPreferences.setMockInitialValues({'signing_key_v1': bad});
      final prefs = await SharedPreferences.getInstance();
      final calls = <int>[];
      await expectLater(
        loadOrCreateSigningKey(prefs, generate: counting(calls)),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            startsWith('Stored signing key is unreadable: '),
          ),
        ),
      );
      expect(calls, isEmpty);
      expect(prefs.getString('signing_key_v1'), bad);
    });
  }

  test('unreadable key error names the cause', () async {
    SharedPreferences.setMockInitialValues({'signing_key_v1': '{"a":"b"}'});
    final prefs = await SharedPreferences.getInstance();
    await expectLater(
      loadOrCreateSigningKey(prefs, generate: () async => fixed),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'Stored signing key is unreadable: '
              'SigningKey: missing or non-string "n"',
        ),
      ),
    );
  });

  test('valid JSON with inconsistent key throws and is preserved', () async {
    final json = Map<String, String>.from(fixed.toJson());
    json['n'] = json['n']!.substring(0, json['n']!.length - 4);
    final raw = jsonEncode(json);
    SharedPreferences.setMockInitialValues({'signing_key_v1': raw});
    final prefs = await SharedPreferences.getInstance();
    await expectLater(
      loadOrCreateSigningKey(prefs, generate: () async => fixed),
      throwsA(isA<StateError>()),
    );
    expect(prefs.getString('signing_key_v1'), raw);
  });

  test('non-string stored value throws and is preserved', () async {
    SharedPreferences.setMockInitialValues({'signing_key_v1': 42});
    final prefs = await SharedPreferences.getInstance();
    await expectLater(
      loadOrCreateSigningKey(prefs, generate: () async => fixed),
      throwsA(isA<StateError>()),
    );
    expect(prefs.get('signing_key_v1'), 42);
  });

  test('replaceSigningKey overwrites an existing or corrupt value', () async {
    SharedPreferences.setMockInitialValues({'signing_key_v1': 'garbage'});
    final prefs = await SharedPreferences.getInstance();
    await replaceSigningKey(prefs, fixed);
    final loaded = await loadOrCreateSigningKey(
      prefs,
      generate: () async => fail('must not generate'),
    );
    expect(loaded.publicKey.modulus, fixed.publicKey.modulus);
  });
}
