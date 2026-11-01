import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:web2apk/src/apk/app_options.dart';
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
      ...const AppOptions().toJson(),
    });
  });

  group('AppOptions', () {
    const custom = AppOptions(
      orientation: AppOrientation.landscape,
      darkMode: AppDarkMode.system,
      externalLinks: true,
      progressBar: true,
      offlinePage: false,
      reloadButton: true,
      hideSystemBars: true,
      keepScreenOn: true,
      pinchZoom: true,
      loadingColor: true,
      desktopMode: true,
      userAgent: 'UA',
      versionName: '2.1',
    );

    test('JSON round-trip keeps every field', () {
      final copy = AppOptions.fromJson(custom.toJson());
      expect(copy.toJson(), custom.toJson());
    });

    test('config.json carries the options the template reads', () {
      final config = jsonDecode(
        const AppSpec(
          name: 'My',
          url: 'https://x.de',
          color: 0xFF2196F3,
          fullscreen: false,
          packageId: 'de.x.web2apk',
          options: custom,
        ).configJson(),
      );
      expect(config['orientation'], 'landscape');
      expect(config['darkMode'], 'system');
      expect(config['hideSystemBars'], isTrue);
      expect(config['offlinePage'], isFalse);
      expect(config['userAgent'], 'UA');
    });

    test('missing keys and unknown values fall back to the defaults', () {
      final defaults = const AppOptions().toJson();
      expect(AppOptions.fromJson({}).toJson(), defaults);
      expect(
        AppOptions.fromJson({'orientation': 'sideways'}).toJson(),
        defaults,
      );
    });

    test('copyWith changes only what is given', () {
      final changed = const AppOptions().copyWith(pinchZoom: true);
      expect(changed.pinchZoom, isTrue);
      expect(changed.offlinePage, isTrue);
    });

    test('user agent and version are trimmed', () {
      final json = const AppOptions(
        userAgent: ' a ',
        versionName: ' 1 ',
      ).toJson();
      expect(json['userAgent'], 'a');
      expect(json['versionName'], '1');
    });
  });
}
