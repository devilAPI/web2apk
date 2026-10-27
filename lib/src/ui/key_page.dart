import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../apk/signing_key.dart';
import '../apk_actions.dart';
import 'snack.dart';

const keyBackupFileName = 'web2apk-signing-key.json';
const keyBackupFormat = 'web2apk-signing-key-v1';

const _backupWarning =
    'Anyone with this file can publish updates to your apps. Keep it private.';
const _restoreWarning =
    'This replaces your current signing key. Apps signed with the current '
    'key can then no longer be updated in place, unless you restore it again.';

/// Shows the signing key's fingerprint and lets the user back it up to a file
/// or restore it from one.
class KeyPage extends StatefulWidget {
  const KeyPage({
    super.key,
    required this.loadKey,
    required this.replaceKey,
    required this.actions,
    this.pickFile,
  });

  final Future<SigningKey> Function() loadKey;
  final Future<void> Function(SigningKey) replaceKey;
  final ApkActions actions;

  /// Returns the bytes of the chosen key file, or null if cancelled. Defaults
  /// to a file picker for `.json` files.
  final Future<Uint8List?> Function()? pickFile;

  @override
  State<KeyPage> createState() => _KeyPageState();
}

class _KeyPageState extends State<KeyPage> {
  late Future<SigningKey> _key = widget.loadKey();
  bool _busy = false;

  Future<Uint8List?> _pick() async {
    final custom = widget.pickFile;
    if (custom != null) return custom();
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    return file?.readAsBytes();
  }

  void _snack(String message) {
    if (mounted) showSnack(context, message);
  }

  Future<bool> _confirm(String text, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _guard(Future<void> Function() body, String failure) async {
    setState(() => _busy = true);
    try {
      await body();
    } catch (e) {
      _snack('$failure: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _backup(SigningKey key) async {
    if (!await _confirm(_backupWarning, 'Continue')) return;
    await _guard(() async {
      final json = jsonEncode({...key.toJson(), 'format': keyBackupFormat});
      final ok = await widget.actions.saveFile(
        Uint8List.fromList(utf8.encode(json)),
        keyBackupFileName,
        mimeType: 'application/json',
      );
      if (ok) _snack('Key backup saved');
    }, 'Could not save the backup');
  }

  /// Parses a backup file; null if it is not a valid web2apk key file.
  SigningKey? _parse(Uint8List bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic> ||
          decoded['format'] != keyBackupFormat) {
        return null;
      }
      return SigningKey.fromJson(decoded);
    } on FormatException {
      return null;
    }
  }

  Future<void> _restore() async {
    await _guard(() async {
      final bytes = await _pick();
      if (bytes == null) return;
      final key = _parse(bytes);
      if (key == null) {
        _snack('Not a valid web2apk key file');
        return;
      }
      if (!await _confirm(_restoreWarning, 'Replace key')) return;
      await widget.replaceKey(key);
      if (!mounted) return;
      final reloaded = widget.loadKey();
      setState(() {
        _key = reloaded;
      });
      _snack('Signing key restored');
    }, 'Could not restore the key');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Signing key')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: FutureBuilder<SigningKey>(
            future: _key,
            builder: (context, snap) {
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'The signing key could not be read: ${snap.error}',
                  ),
                );
              }
              final key = snap.data;
              if (key == null) return const CircularProgressIndicator();
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Apps you generate are signed with this key. Back it up '
                    'to keep updating them in place.',
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Certificate SHA-256 fingerprint',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    key.certificateSha256,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    icon: const Icon(Icons.save_alt),
                    label: const Text('Back up key'),
                    onPressed: _busy ? null : () => _backup(key),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Restore key'),
                    onPressed: _busy ? null : _restore,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
