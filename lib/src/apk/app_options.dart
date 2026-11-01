/// Screen orientation of the generated app.
enum AppOrientation {
  auto('Automatic'),
  portrait('Portrait'),
  landscape('Landscape');

  const AppOrientation(this.label);
  final String label;
}

/// When the generated app shows websites dark (Android 13 and newer).
enum AppDarkMode {
  off('Off'),
  system('Follow the system'),
  always('Always');

  const AppDarkMode(this.label);
  final String label;
}

/// The advanced settings of a generated app. Everything but [versionName]
/// goes to the template through `assets/config.json`.
class AppOptions {
  final AppOrientation orientation;
  final AppDarkMode darkMode;

  /// Links to other sites open in the browser instead of the app.
  final bool externalLinks;
  final bool progressBar;

  /// Show a page with a Retry button when a page cannot be loaded.
  final bool offlinePage;

  /// A reload button in the title bar, so it needs the title bar.
  final bool reloadButton;
  final bool hideSystemBars;
  final bool keepScreenOn;
  final bool pinchZoom;

  /// Show the app color instead of white until the first page is drawn.
  final bool loadingColor;
  final bool desktopMode;

  /// Replaces the WebView's user agent; empty keeps it.
  final String userAgent;

  /// Version name shown in Android's app info; empty keeps the template's.
  final String versionName;

  const AppOptions({
    this.orientation = AppOrientation.auto,
    this.darkMode = AppDarkMode.off,
    this.externalLinks = false,
    this.progressBar = false,
    this.offlinePage = true,
    this.reloadButton = false,
    this.hideSystemBars = false,
    this.keepScreenOn = false,
    this.pinchZoom = false,
    this.loadingColor = false,
    this.desktopMode = false,
    this.userAgent = '',
    this.versionName = '',
  });

  AppOptions copyWith({
    AppOrientation? orientation,
    AppDarkMode? darkMode,
    bool? externalLinks,
    bool? progressBar,
    bool? offlinePage,
    bool? reloadButton,
    bool? hideSystemBars,
    bool? keepScreenOn,
    bool? pinchZoom,
    bool? loadingColor,
    bool? desktopMode,
    String? userAgent,
    String? versionName,
  }) => AppOptions(
    orientation: orientation ?? this.orientation,
    darkMode: darkMode ?? this.darkMode,
    externalLinks: externalLinks ?? this.externalLinks,
    progressBar: progressBar ?? this.progressBar,
    offlinePage: offlinePage ?? this.offlinePage,
    reloadButton: reloadButton ?? this.reloadButton,
    hideSystemBars: hideSystemBars ?? this.hideSystemBars,
    keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    pinchZoom: pinchZoom ?? this.pinchZoom,
    loadingColor: loadingColor ?? this.loadingColor,
    desktopMode: desktopMode ?? this.desktopMode,
    userAgent: userAgent ?? this.userAgent,
    versionName: versionName ?? this.versionName,
  );

  /// Reads [toJson]'s output. Missing keys, as in apps saved by older
  /// versions, and unknown enum values fall back to the defaults.
  factory AppOptions.fromJson(Map<String, dynamic> json) {
    const d = AppOptions();
    T pick<T extends Enum>(List<T> values, String key, T fallback) =>
        values.asNameMap()[json[key]] ?? fallback;
    return AppOptions(
      orientation: pick(AppOrientation.values, 'orientation', d.orientation),
      darkMode: pick(AppDarkMode.values, 'darkMode', d.darkMode),
      externalLinks: json['externalLinks'] as bool? ?? d.externalLinks,
      progressBar: json['progressBar'] as bool? ?? d.progressBar,
      offlinePage: json['offlinePage'] as bool? ?? d.offlinePage,
      reloadButton: json['reloadButton'] as bool? ?? d.reloadButton,
      hideSystemBars: json['hideSystemBars'] as bool? ?? d.hideSystemBars,
      keepScreenOn: json['keepScreenOn'] as bool? ?? d.keepScreenOn,
      pinchZoom: json['pinchZoom'] as bool? ?? d.pinchZoom,
      loadingColor: json['loadingColor'] as bool? ?? d.loadingColor,
      desktopMode: json['desktopMode'] as bool? ?? d.desktopMode,
      userAgent: json['userAgent'] as String? ?? d.userAgent,
      versionName: json['versionName'] as String? ?? d.versionName,
    );
  }

  Map<String, dynamic> toJson() => {
    'orientation': orientation.name,
    'darkMode': darkMode.name,
    'externalLinks': externalLinks,
    'progressBar': progressBar,
    'offlinePage': offlinePage,
    'reloadButton': reloadButton,
    'hideSystemBars': hideSystemBars,
    'keepScreenOn': keepScreenOn,
    'pinchZoom': pinchZoom,
    'loadingColor': loadingColor,
    'desktopMode': desktopMode,
    'userAgent': userAgent.trim(),
    'versionName': versionName.trim(),
  };
}
