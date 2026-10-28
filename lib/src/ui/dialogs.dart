import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../apk/app_spec.dart';

const _ownPackageId = 'de.devilapi.web2apk';

/// Preset swatches, with a toggle to a free HSV picker and hex input.
class ColorDialog extends StatefulWidget {
  const ColorDialog({super.key, required this.initial});
  final Color initial;

  @override
  State<ColorDialog> createState() => _ColorDialogState();
}

class _ColorDialogState extends State<ColorDialog> {
  late Color _picked = widget.initial;
  bool _custom = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Color'),
      content: SingleChildScrollView(
        child: _custom
            ? ColorPicker(
                pickerColor: _picked,
                onColorChanged: (c) => _picked = c,
                enableAlpha: false,
                hexInputBar: true,
                labelTypes: const [],
                pickerAreaHeightPercent: 0.7,
              )
            : BlockPicker(
                pickerColor: _picked,
                onColorChanged: (c) => setState(() => _picked = c),
              ),
      ),
      actions: [
        TextButton(
          key: const Key('custom-color'),
          onPressed: () => setState(() => _custom = !_custom),
          child: Text(_custom ? 'Presets' : 'Custom'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _picked.withAlpha(0xFF)),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

class PackageDialog extends StatefulWidget {
  const PackageDialog({super.key, required this.initial});
  final String initial;

  @override
  State<PackageDialog> createState() => _PackageDialogState();
}

class _PackageDialogState extends State<PackageDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text.trim();
    final own = text == _ownPackageId;
    final ok = isValidPackageId(text) && !own;
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
              : own
              ? 'This ID belongs to web2apk itself'
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
