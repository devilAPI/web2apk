import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../apk/apk_builder.dart';
import '../apk/app_spec.dart';
import '../apk/icons.dart';
import '../apk/signing_key.dart';
import '../apk/template_contract.dart';
import '../apk_actions.dart';
import '../saved_apps.dart';
import 'key_page.dart';
import 'my_apps_page.dart';
import 'result_page.dart';

const _credit = 'Made by devilAPI with <3';
const _repoUrl = 'https://github.com/devilAPI/web2apk';
const _webKeyNotice =
    'Your signing key is stored in this browser. Clearing site data loses it, '
    'and apps you generated can then no longer be updated in place.';
const _defaultColor = Color(0xFF2196F3);

/// Everything the build isolate needs, sent through [compute] as one message.
class _BuildJob {
  const _BuildJob(this.template, this.spec, this.key);
  final Uint8List template;
  final AppSpec spec;
  final SigningKey key;
}

Uint8List _buildInIsolate(_BuildJob job) =>
    buildApk(template: job.template, spec: job.spec, key: job.key);

/// Decodes [bytes] as an icon; returns the error message, or null if usable.
String? _iconProblem(Uint8List bytes) {
  try {
    squarePng(bytes, kIconSizes['mdpi']!);
    return null;
  } on FormatException catch (e) {
    return e.message;
  }
}

/// An image file picked by the user.
typedef PickedImage = ({Uint8List bytes, String name});

Future<PickedImage?> _pickImageFile() async {
  final file = await FilePicker.pickFile(type: FileType.image);
  if (file == null) return null;
  return (bytes: await file.readAsBytes(), name: file.name);
}

/// App name with characters outside `[A-Za-z0-9 _-]` removed, plus `.apk`.
String apkFileName(String name) {
  final clean = name.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
  return '${clean.isEmpty ? 'app' : clean}.apk';
}

class GeneratorPage extends StatefulWidget {
  const GeneratorPage({
    super.key,
    required this.actions,
    required this.loadKey,
    required this.replaceKey,
    required this.savedApps,
    this.initial,
    this.loadTemplate,
    this.pickIcon = _pickImageFile,
    this.showWebKeyNotice = kIsWeb,
  });

  final ApkActions actions;
  final Future<SigningKey> Function() loadKey;
  final Future<void> Function(SigningKey) replaceKey;
  final SavedAppsStore savedApps;

  /// A remembered app to prefill the form with.
  final SavedApp? initial;
  final Future<Uint8List> Function()? loadTemplate;

  /// Lets the user choose an icon image; null if cancelled.
  final Future<PickedImage?> Function() pickIcon;

  /// Whether to warn that the signing key lives in browser storage.
  final bool showWebKeyNotice;

  @override
  State<GeneratorPage> createState() => _GeneratorPageState();
}

class _GeneratorPageState extends State<GeneratorPage> {
  final _name = TextEditingController();
  final _url = TextEditingController();
  Color _color = _defaultColor;
  bool _fullscreen = false;
  Uint8List? _icon;
  String? _iconName;
  String? _iconError;
  String? _manualPackage;
  String? _progress;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) _fill(initial);
  }

  /// Fills the form from [app]; its package id is kept even if the URL changes.
  void _fill(SavedApp app) {
    _name.text = app.name;
    _url.text = app.url;
    _color = Color(app.color);
    _fullscreen = app.fullscreen;
    _icon = app.icon;
    _iconName = app.icon == null ? null : 'Saved icon';
    _iconError = null;
    _manualPackage = app.packageId;
  }

  Future<void> _openMyApps() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => MyAppsPage(
          store: widget.savedApps,
          onOpen: (app) {
            Navigator.of(ctx).pop();
            setState(() => _fill(app));
          },
        ),
      ),
    );
  }

  Future<void> _openKeyPage() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => KeyPage(
        loadKey: widget.loadKey,
        replaceKey: widget.replaceKey,
        actions: widget.actions,
      ),
    ),
  );

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  String? get _normalizedUrl {
    try {
      return normalizeUrl(_url.text);
    } on FormatException {
      return null;
    }
  }

  String? get _urlError {
    if (_url.text.trim().isEmpty) return null;
    try {
      normalizeUrl(_url.text);
      return null;
    } on FormatException catch (e) {
      return e.message;
    }
  }

  String? get _packageId {
    if (_manualPackage != null) return _manualPackage;
    final u = _normalizedUrl;
    return u == null ? null : packageIdFromUrl(u);
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      _normalizedUrl != null &&
      _packageId != null &&
      isValidPackageId(_packageId!);

  Future<void> _pickColor() async {
    var picked = _color;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Color'),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: _color,
            onColorChanged: (c) => picked = c,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (ok == true) setState(() => _color = picked);
  }

  Future<void> _pickIcon() async {
    final PickedImage image;
    final String? problem;
    try {
      final picked = await widget.pickIcon();
      if (picked == null) return;
      image = picked;
      // Decoding a large image takes a while: keep it off the UI isolate.
      problem = await compute(_iconProblem, image.bytes);
    } catch (e) {
      if (mounted) setState(() => _iconError = 'Could not open the image: $e');
      return;
    }
    if (!mounted) return;
    setState(() {
      _iconError = problem;
      if (problem == null) {
        _icon = image.bytes;
        _iconName = image.name;
      }
    });
  }

  Future<void> _editPackage() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _PackageDialog(initial: _packageId ?? ''),
    );
    if (result != null) setState(() => _manualPackage = result);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _generate() async {
    final name = _name.text.trim();
    final spec = AppSpec(
      name: name,
      url: _normalizedUrl!,
      color: _color.toARGB32(),
      fullscreen: _fullscreen,
      packageId: _packageId!,
      icon: _icon,
    );
    try {
      setState(() => _progress = 'Preparing…');
      final key = await widget.loadKey();
      final template =
          await (widget.loadTemplate ??
              () async =>
                  (await rootBundle.load('assets/template.apk')).buffer
                      .asUint8List())();
      if (mounted) setState(() => _progress = 'Building APK…');
      final apk = await compute(
        _buildInIsolate,
        _BuildJob(template, spec, key),
      );
      try {
        await widget.savedApps.upsert(SavedApp.fromSpec(spec));
      } catch (e) {
        // The APK is built; a failed save must not keep it from the user.
        _showError('The app could not be saved to My apps: $e');
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ResultPage(
            apk: apk,
            fileName: apkFileName(name),
            actions: widget.actions,
          ),
        ),
      );
    } catch (e) {
      _showError('Could not build the APK: $e');
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  void _about() {
    showAboutDialog(
      context: context,
      applicationName: 'web2apk',
      applicationLegalese: '$_credit\n$_repoUrl',
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _progress != null;
    final pkg = _packageId;
    return Scaffold(
      appBar: AppBar(
        title: const Text('web2apk'),
        actions: [
          IconButton(
            icon: const Icon(Icons.apps),
            tooltip: 'My apps',
            onPressed: _openMyApps,
          ),
          IconButton(
            icon: const Icon(Icons.key),
            tooltip: 'Signing key',
            onPressed: _openKeyPage,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About',
            onPressed: _about,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.showWebKeyNotice) ...[
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(_webKeyNotice),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                key: const Key('name-field'),
                controller: _name,
                maxLength: 50,
                enabled: !busy,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'App name'),
              ),
              TextField(
                key: const Key('url-field'),
                controller: _url,
                enabled: !busy,
                keyboardType: TextInputType.url,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Website URL',
                  errorText: _urlError,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Color'),
                trailing: CircleAvatar(backgroundColor: _color, radius: 14),
                enabled: !busy,
                onTap: _pickColor,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Icon'),
                subtitle: Text(_iconError ?? _iconName ?? 'Default icon'),
                trailing: _icon == null
                    ? const Icon(Icons.image_outlined)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.memory(
                          _icon!,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                      ),
                enabled: !busy,
                onTap: _pickIcon,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Fullscreen'),
                subtitle: const Text('Hide the title bar'),
                value: _fullscreen,
                onChanged: busy ? null : (v) => setState(() => _fullscreen = v),
              ),
              ListTile(
                key: const Key('package-tile'),
                contentPadding: EdgeInsets.zero,
                title: Text('Package: ${pkg ?? '—'} — tap to change'),
                enabled: !busy,
                onTap: _editPackage,
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('generate'),
                onPressed: _valid && !busy ? _generate : null,
                child: busy
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                          Flexible(child: Text(_progress!)),
                        ],
                      )
                    : const Text('Generate'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PackageDialog extends StatefulWidget {
  const _PackageDialog({required this.initial});
  final String initial;

  @override
  State<_PackageDialog> createState() => _PackageDialogState();
}

class _PackageDialogState extends State<_PackageDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text.trim();
    final ok = isValidPackageId(text);
    return AlertDialog(
      title: const Text('Package name'),
      content: TextField(
        key: const Key('package-field'),
        controller: _controller,
        autofocus: true,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          errorText: ok
              ? null
              : 'Use dot-separated segments like org.example.app',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: ok ? () => Navigator.pop(context, text) : null,
          child: const Text('OK'),
        ),
      ],
    );
  }
}
