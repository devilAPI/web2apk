import 'package:flutter/material.dart';

import '../saved_apps.dart';

/// Lists remembered apps; tapping one hands it to [onOpen], the trailing
/// button deletes it after confirmation.
class MyAppsPage extends StatefulWidget {
  const MyAppsPage({super.key, required this.store, required this.onOpen});

  final SavedAppsStore store;
  final void Function(SavedApp) onOpen;

  @override
  State<MyAppsPage> createState() => _MyAppsPageState();
}

class _MyAppsPageState extends State<MyAppsPage> {
  List<SavedApp> _apps = const [];

  @override
  void initState() {
    super.initState();
    _reload(initial: true);
  }

  void _reload({bool initial = false}) {
    try {
      _apps = widget.store.load();
    } on FormatException {
      _apps = const [];
      // Context is not usable for a SnackBar until the first frame is built.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved apps could not be read')),
        );
      });
    }
    if (!initial) setState(() {});
  }

  Future<void> _delete(SavedApp app) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${app.name}?'),
        content: const Text('It is only removed from this list. The APK you installed is not affected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.store.remove(app.packageId);
    } on FormatException {
      // Corrupt store: nothing to remove; reload reports it.
    }
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My apps')),
      body: _apps.isEmpty
          ? const Center(child: Text('No saved apps yet'))
          : ListView(
              children: [
                for (final app in _apps)
                  ListTile(
                    key: ValueKey(app.packageId),
                    leading: _leading(app),
                    title: Text(app.name),
                    subtitle: Text(app.packageId),
                    onTap: () => widget.onOpen(app),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete',
                      onPressed: () => _delete(app),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _leading(SavedApp app) {
    final icon = app.icon;
    if (icon == null) {
      return CircleAvatar(backgroundColor: Color(app.color), radius: 20);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.memory(icon, width: 40, height: 40, fit: BoxFit.cover),
    );
  }
}
