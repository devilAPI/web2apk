import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const _defaultIconColor = Color(0xFF2196F3);

/// Status bar color the template uses: each channel of [color] times 0.8.
Color statusBarColor(Color color) => Color.fromARGB(
  255,
  (color.r * 255 * 0.8).toInt(),
  (color.g * 255 * 0.8).toInt(),
  (color.b * 255 * 0.8).toInt(),
);

/// Title color the template uses: white on dark colors, black on light ones
/// (Android's `Color.luminance(color) < 0.5`).
Color titleColor(Color color) =>
    color.computeLuminance() < 0.5 ? Colors.white : Colors.black;

/// A sketch of the generated app: a phone showing the app screen, and the
/// home-screen icon with its label below. Mirrors the template's
/// MainActivity (status bar, title bar, fullscreen), not the website itself.
class AppPreview extends StatelessWidget {
  const AppPreview({
    super.key,
    required this.name,
    required this.url,
    required this.color,
    required this.fullscreen,
    this.icon,
  });

  final String name;

  /// Normalized URL, or null while the URL field is empty or invalid.
  final String? url;
  final Color color;
  final bool fullscreen;
  final Uint8List? icon;

  @override
  Widget build(BuildContext context) {
    final title = name.trim().isEmpty ? 'App name' : name.trim();
    final onBar = titleColor(statusBarColor(color));
    final host = url == null ? null : Uri.tryParse(url!)?.host;
    return Column(
      children: [
        Container(
          width: 200,
          height: 340,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF202124),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: ColoredBox(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    key: const Key('preview-status-bar'),
                    height: 20,
                    color: statusBarColor(color),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Text(
                          '12:00',
                          style: TextStyle(color: onBar, fontSize: 10),
                        ),
                        const Spacer(),
                        Icon(Icons.signal_cellular_alt, color: onBar, size: 11),
                        const SizedBox(width: 3),
                        Icon(Icons.battery_full, color: onBar, size: 11),
                      ],
                    ),
                  ),
                  if (!fullscreen)
                    Container(
                      key: const Key('preview-title-bar'),
                      height: 40,
                      color: color,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: titleColor(color),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.language,
                              size: 40,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              host ?? 'Your website',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: icon == null
              ? Container(
                  width: 48,
                  height: 48,
                  color: _defaultIconColor,
                  child: const Icon(Icons.language, color: Colors.white),
                )
              : Image.memory(icon!, width: 48, height: 48, fit: BoxFit.cover),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 80,
          child: Text(
            title,
            key: const Key('preview-label'),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
