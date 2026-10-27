# web2apk

Turn a website into an installable Android app. web2apk is a Flutter app that builds the APK **on your own device**, with no Android toolchain, Flutter or Gradle needed to use it. The generated app is a plain Android WebView (JavaScript on, links stay inside the app, back button walks the page history).

<!-- screenshot placeholder: docs/screenshot.png -->

## Download

Grab the latest build from the [Releases](https://github.com/devilAPI/web2apk/releases) page:

- `web2apk-android.apk` - the generator for Android 7.0+
- `web2apk-linux-x64.tar.gz` - the generator for Linux (extract and run `web2apk`)

## Using it

Fill in the form and tap **Generate**:

- **App name** - home-screen label and title-bar text
- **URL** - the site to show (`https://` is added if you leave it out)
- **Color** - title-bar color
- **Icon** - an image from your gallery/files (center-cropped to a square)
- **Fullscreen** - hides only the title bar; the Android status bar stays visible
- **Package** - shown as "Package: ... - tap to change". It is derived from the domain (`https://example.org` -> `org.example.web2apk`). Every app needs its own ID: two apps with the same ID replace each other, so change it if you build several apps for one domain.

When the APK is ready:

- **Install** (Android) opens the package installer
- **Save** stores the APK wherever you choose
- **Share** (Android) sends the APK to another app

Regenerating an app with the same package ID installs as an update over the old one.

On Linux, the file picker needs `zenity` installed.

### Back up your signing key

Open the key icon in the generator's app bar to see your signing key's SHA-256 fingerprint, save it with **Back up key** (a `web2apk-signing-key.json` file), or load a saved file with **Restore key**. Anyone with that file can publish updates to your apps, so keep it private. Restoring replaces the current key; apps signed with the old one can then no longer be updated in place unless you restore it again. On the web the key lives in the browser, so back it up before clearing site data.

### Signing key caveat

The generator creates a signing key on first use and stores it per install (shared preferences). Uninstalling or clearing the data of the generator **loses the key**. Apps regenerated afterwards are signed with a new key, so the old version of that app must be uninstalled before the new one can be installed.

## Building from source

Requirements: Flutter 3.47.5, JDK 17+ and the Android SDK (`ANDROID_HOME` set).

```bash
scripts/build_template.sh   # builds the template APK into assets/template.apk (gitignored)
flutter pub get
flutter test
flutter run                 # or: flutter build apk / flutter build linux
```

Tests that verify generated APKs use `apksigner`, `aapt2` and `zipalign` from the newest build-tools under `$ANDROID_HOME`.

## Maintainer: releases and CI

Every push to `master` runs `.github/workflows/dev-release.yml`: it tests, builds Android, Linux, Windows, macOS and the web app, and publishes a prerelease `dev-N` with all files plus `SHA256SUMS.txt`. The web app of the newest dev build is deployed to https://devilapi.github.io/web2apk/dev/.

To make a full release, open a `dev-N` prerelease on GitHub and uncheck "pre-release". This republishes the web app at https://devilapi.github.io/web2apk/ (`.github/workflows/pages.yml`). One-time setup: Settings -> Pages -> Source: **GitHub Actions**.

The Android APK is signed with your own key, supplied through repository secrets. Without them CI signs with a debug key (the release notes say so), and users must uninstall debug-signed builds before installing release-signed ones. Create a keystore with JDK 17-21:

```bash
keytool -genkeypair -v -keystore release.jks -keyalg RSA -keysize 4096 -validity 36500 -alias web2apk
base64 -w0 release.jks   # -> secret ANDROID_KEYSTORE_BASE64
```

Also set the secrets `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` (`web2apk` above) and `ANDROID_KEY_PASSWORD`.

**Back up `release.jks`.** Losing it means users must uninstall the generator before they can update it.

For a local release build, create `android/key.properties` (gitignored) with `storeFile` (relative to `android/app`), `storePassword`, `keyAlias`, `keyPassword`; all four are required. Without the file, release builds fall back to the debug key. The macOS app is unsigned: right-click -> Open the first time.

## Credits and v1

Made by devilAPI with <3 - https://github.com/devilAPI/web2apk

The original v1 (edit three variables in `main.dart`, build with Gradle) lives on the `legacy` branch.
