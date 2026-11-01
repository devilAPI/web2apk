import 'package:flutter/material.dart';

import '../apk/app_options.dart';

/// The rarely needed settings of a generated app. Every change goes straight
/// to [onChanged], so leaving the page needs no confirmation.
class AdvancedSettingsPage extends StatefulWidget {
  const AdvancedSettingsPage({
    super.key,
    required this.initial,
    required this.fullscreen,
    required this.onChanged,
  });

  final AppOptions initial;

  /// Whether the app has no title bar, which the reload button lives in.
  final bool fullscreen;
  final ValueChanged<AppOptions> onChanged;

  @override
  State<AdvancedSettingsPage> createState() => _AdvancedSettingsPageState();
}

class _AdvancedSettingsPageState extends State<AdvancedSettingsPage> {
  late AppOptions _options = widget.initial;
  late final _userAgent = TextEditingController(text: _options.userAgent);
  late final _version = TextEditingController(text: _options.versionName);

  @override
  void dispose() {
    _userAgent.dispose();
    _version.dispose();
    super.dispose();
  }

  void _set(AppOptions options) {
    setState(() => _options = options);
    widget.onChanged(options);
  }

  void _resetAll() {
    _userAgent.clear();
    _version.clear();
    _set(const AppOptions());
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 4),
    child: Text(title, style: Theme.of(context).textTheme.titleSmall),
  );

  Widget _switch(
    String key,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool>? onChanged,
  ) => SwitchListTile(
    key: Key(key),
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    subtitle: Text(subtitle),
    value: value,
    onChanged: onChanged,
  );

  Widget _choice<T extends Enum>(
    String key,
    String title,
    String? subtitle,
    T value,
    Map<T, String> labels,
    ValueChanged<T> onChanged,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle),
    trailing: DropdownButton<T>(
      key: Key(key),
      value: value,
      underline: const SizedBox.shrink(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      items: [
        for (final e in labels.entries)
          DropdownMenuItem(value: e.key, child: Text(e.value)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final o = _options;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reset to defaults',
            onPressed: _resetAll,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              _section('Display'),
              _choice(
                'orientation',
                'Screen orientation',
                null,
                o.orientation,
                {for (final v in AppOrientation.values) v: v.label},
                (v) => _set(o.copyWith(orientation: v)),
              ),
              _choice(
                'dark-mode',
                'Dark mode for websites',
                'Android 13 and newer',
                o.darkMode,
                {for (final v in AppDarkMode.values) v: v.label},
                (v) => _set(o.copyWith(darkMode: v)),
              ),
              _switch(
                'hide-system-bars',
                'Hide status and navigation bars',
                'Swipe from the screen edge to show them',
                o.hideSystemBars,
                (v) => _set(o.copyWith(hideSystemBars: v)),
              ),
              _switch(
                'keep-screen-on',
                'Keep screen on',
                'For dashboards and kiosks',
                o.keepScreenOn,
                (v) => _set(o.copyWith(keepScreenOn: v)),
              ),
              _switch(
                'loading-color',
                'Color while loading',
                'Show the app color instead of white until the page appears',
                o.loadingColor,
                (v) => _set(o.copyWith(loadingColor: v)),
              ),
              _section('Browsing'),
              _switch(
                'external-links',
                'Open other sites in the browser',
                'Keep only links to this website in the app. May break '
                    'logins that run on another site',
                o.externalLinks,
                (v) => _set(o.copyWith(externalLinks: v)),
              ),
              _switch(
                'progress-bar',
                'Loading bar',
                'Thin bar at the top while a page loads',
                o.progressBar,
                (v) => _set(o.copyWith(progressBar: v)),
              ),
              _switch(
                'offline-page',
                'Offline page',
                'Show a Retry button when a page cannot be loaded',
                o.offlinePage,
                (v) => _set(o.copyWith(offlinePage: v)),
              ),
              _switch(
                'reload-button',
                'Reload button',
                widget.fullscreen
                    ? 'Needs the title bar: turn off Fullscreen'
                    : 'In the title bar',
                o.reloadButton && !widget.fullscreen,
                widget.fullscreen
                    ? null
                    : (v) => _set(o.copyWith(reloadButton: v)),
              ),
              _switch(
                'pinch-zoom',
                'Pinch to zoom',
                'Websites can still turn this off',
                o.pinchZoom,
                (v) => _set(o.copyWith(pinchZoom: v)),
              ),
              _section('Identity'),
              _switch(
                'desktop-mode',
                'Desktop mode',
                'Ask websites for their desktop version',
                o.desktopMode,
                (v) => _set(o.copyWith(desktopMode: v)),
              ),
              TextField(
                key: const Key('user-agent'),
                controller: _userAgent,
                onChanged: (v) => _set(o.copyWith(userAgent: v)),
                decoration: const InputDecoration(
                  labelText: 'Custom user agent',
                  helperText: 'Empty uses the default. Overrides Desktop mode',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('version-name'),
                controller: _version,
                maxLength: 50,
                onChanged: (v) => _set(o.copyWith(versionName: v)),
                decoration: const InputDecoration(
                  labelText: 'App version',
                  hintText: '1.0',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
