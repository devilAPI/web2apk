import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web2apk/src/ui/app_preview.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    String name = 'My Site',
    String? url = 'https://example.org/',
    Color color = const Color(0xFF2196F3),
    bool fullscreen = false,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AppPreview(
          name: name,
          url: url,
          color: color,
          fullscreen: fullscreen,
        ),
      ),
    ),
  );

  testWidgets('shows title bar with the name, label and host', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('preview-title-bar')), findsOneWidget);
    expect(find.text('My Site'), findsNWidgets(2)); // title bar + label
    expect(find.text('example.org'), findsOneWidget);
  });

  testWidgets('fullscreen hides only the title bar', (tester) async {
    await pump(tester, fullscreen: true);
    expect(find.byKey(const Key('preview-title-bar')), findsNothing);
    expect(find.byKey(const Key('preview-status-bar')), findsOneWidget);
    expect(find.text('My Site'), findsOneWidget); // label only
  });

  testWidgets('placeholders while name and URL are empty', (tester) async {
    await pump(tester, name: '  ', url: null);
    expect(find.text('App name'), findsNWidgets(2));
    expect(find.text('Your website'), findsOneWidget);
  });

  test('colors match the template', () {
    expect(titleColor(const Color(0xFF2196F3)), Colors.white);
    expect(titleColor(const Color(0xFFFFEB3B)), Colors.black);
    expect(statusBarColor(const Color(0xFF2196F3)), const Color(0xFF1A78C2));
  });
}
