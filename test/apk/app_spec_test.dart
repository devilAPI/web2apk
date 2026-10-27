import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:web2apk/src/apk/app_spec.dart';

void main() {
  group('normalizeUrl', () {
    test('adds https and lowercases', () {
      expect(normalizeUrl('example.org'), 'https://example.org');
      expect(
        normalizeUrl('  HTTP://Example.org:8080/path  '),
        'http://example.org:8080/path',
      );
      expect(normalizeUrl('  https://www.x.de  '), 'https://www.x.de');
    });
    test('rejects bad input', () {
      expect(() => normalizeUrl('ftp://x'), throwsFormatException);
      expect(() => normalizeUrl('https://'), throwsFormatException);
      expect(() => normalizeUrl('   '), throwsFormatException);
    });
  });

  group('packageIdFromUrl', () {
    final cases = {
      'https://example.org': 'org.example.web2apk',
      'https://www.blog.example.org': 'org.example.blog.web2apk',
      'https://1und1.de': 'de.x1und1.web2apk',
      'https://my-site.com': 'com.my_site.web2apk',
      'http://192.168.0.10': 'x10.x0.x168.x192.web2apk',
    };
    cases.forEach((url, id) {
      test(url, () => expect(packageIdFromUrl(url), id));
    });
    for (final url in [
      'https://münchen.de',
      'https://xn--mnchen-3ya.de',
      'https://1und1.de',
      'https://my-site.com',
      'http://192.168.0.10',
      '  HTTP://WWW.Example.org:8080/p  ',
    ]) {
      test('valid id for $url', () {
        expect(isValidPackageId(packageIdFromUrl(url)), isTrue);
      });
    }
  });

  test('isValidPackageId', () {
    expect(isValidPackageId('org.example.web2apk'), isTrue);
    for (final bad in ['example', '1a.b', 'a..b', 'a.b-c']) {
      expect(isValidPackageId(bad), isFalse, reason: bad);
    }
  });

  test('configJson', () {
    final spec = AppSpec(
      name: 'My',
      url: 'https://x.de',
      color: 0xFF2196F3,
      fullscreen: true,
      packageId: 'de.x.web2apk',
    );
    expect(jsonDecode(spec.configJson()), {
      'url': 'https://x.de',
      'title': 'My',
      'color': '#2196F3',
      'fullscreen': true,
    });
  });
}
