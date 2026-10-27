// Made by devilAPI with <3
// https://github.com/devilAPI/web2apk

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/apk_actions.dart';
import 'src/key_store.dart';
import 'src/saved_apps.dart';
import 'src/ui/generator_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(Web2ApkApp(prefs: prefs));
}

class Web2ApkApp extends StatelessWidget {
  const Web2ApkApp({super.key, required this.prefs});

  final SharedPreferences prefs;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'web2apk',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2196F3),
      ),
      home: GeneratorPage(
        actions: PlatformApkActions(),
        savedApps: SavedAppsStore(prefs),
        loadKey: () async => loadOrCreateSigningKey(prefs),
      ),
    );
  }
}
