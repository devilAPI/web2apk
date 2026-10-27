import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../apk_actions.dart';
import 'snack.dart';

class ResultPage extends StatelessWidget {
  const ResultPage({
    super.key,
    required this.apk,
    required this.fileName,
    required this.actions,
  });

  final Uint8List apk;
  final String fileName;
  final ApkActions actions;

  Future<void> _run(BuildContext context, Future<void> Function() body) async {
    try {
      await body();
    } catch (e) {
      if (context.mounted) showSnack(context, 'Failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final kb = (apk.length / 1024).round();
    return Scaffold(
      appBar: AppBar(title: const Text('Your APK is ready')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.check_circle, size: 64, color: Colors.green),
                const SizedBox(height: 12),
                Text(
                  fileName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text('$kb KB', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                if (actions.canInstall) ...[
                  FilledButton.icon(
                    icon: const Icon(Icons.install_mobile),
                    label: const Text('Install'),
                    onPressed: () => _run(context, () async {
                      final r = await actions.install(apk, fileName);
                      if (r == InstallResult.needsPermission &&
                          context.mounted) {
                        showSnack(
                          context,
                          'Allow installs from web2apk in the settings, then tap Install again.',
                        );
                      }
                    }),
                  ),
                  const SizedBox(height: 8),
                ],
                OutlinedButton.icon(
                  icon: const Icon(Icons.save_alt),
                  label: const Text('Save'),
                  onPressed: () => _run(context, () async {
                    final ok = await actions.save(apk, fileName);
                    if (ok && context.mounted) showSnack(context, 'Saved');
                  }),
                ),
                if (actions.canShare) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                    onPressed: () =>
                        _run(context, () => actions.share(apk, fileName)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
