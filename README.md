# web2apk

<img src="docs/icon.png" alt="" width="96" align="right">

Turn a website into an installable Android app. web2apk is a Flutter app that builds the APK **on your own device** (Android, iOS, Linux, Windows, macOS or in the browser), with no Android toolchain, Flutter or Gradle needed to use it. The generated app is a plain Android WebView (JavaScript on, links stay inside the app, back button walks the page history).

<!-- screenshot placeholder: docs/screenshot.png -->

## Download

**Web:** use it in the browser at https://devilapi.github.io/web2apk/ (newest development build: https://devilapi.github.io/web2apk/dev/).

**Apps:** grab a build from the [Releases](https://github.com/devilAPI/web2apk/releases) page (`N` is the build number):

- `web2apk-dev-N-android.apk` - Android 7.0+
- `web2apk-dev-N-linux-x64.tar.gz` - Linux (extract and run `web2apk`; the file picker needs `zenity`)
- `web2apk-dev-N-windows-x64.zip` - Windows (extract and run `web2apk.exe`)
- `web2apk-dev-N-macos.zip` - macOS (unsigned: right-click -> Open the first time)
- `web2apk-dev-N-ios-unsigned.ipa` - iOS 15+ for sideloading (AltStore, Sideloadly, ...); not on the App Store. An iPhone cannot install the APK, so use Save or Share to get it onto an Android device
- `web2apk-dev-N-web.zip` - the web app, to host yourself
- `SHA256SUMS.txt` - checksums of the files above

## Using it

Fill in the form and tap **Generate**:

- **App name** - home-screen label and title-bar text
- **URL** - the site to show (`https://` is added if you leave it out)
- **Color** - title-bar color
- **Icon** - an image from your gallery/files (center-cropped to a square); without one the app gets the web2apk globe icon
- **Fullscreen** - hides only the title bar; the Android status bar stays visible
- **Preview** - a live sketch of the app screen and home-screen icon (beside the form on wide screens)
- **Package** - shown as "Package: ... - tap to change". It is derived from the domain (`https://example.org` -> `org.example.web2apk`). Every app needs its own ID: two apps with the same ID replace each other, so change it if you build several apps for one domain.

When the APK is ready:

- **Install** (Android) opens the package installer
- **Save** stores the APK wherever you choose (a download in the browser)
- **Share** (Android, iOS, macOS) sends the APK to another app

Regenerating an app with the same package ID installs as an update over the old one.

### My apps

Every generated app is remembered under **My apps** (the grid icon in the app bar) with its settings and a small copy of its icon. Tap one to load it back into the form, change what you like and tap **Generate** again: it keeps its package ID, so the new APK installs as an update. Deleting an entry only removes it from the list.

### Back up your signing key

Open the key icon in the generator's app bar to see your signing key's SHA-256 fingerprint, save it with **Back up key** (a `web2apk-signing-key.json` file), or load a saved file with **Restore key**. Anyone with that file can publish updates to your apps, so keep it private. Restoring replaces the current key; apps signed with the old one can then no longer be updated in place unless you restore it again. On the web the key lives in the browser, so back it up before clearing site data.

### Web notes

- The web key is stored per browser **and** per origin. `devilapi.github.io` is shared with other GitHub Pages apps, so clearing that site's data, or another app on the origin clearing its storage, deletes the key. Back it up.
- Open only one tab on your first visit, so two tabs do not each create a key.
- Self-hosting the web build needs HTTPS (WebCrypto requires a secure context).

### Signing key caveat

The generator creates a signing key on first use and stores it per install (shared preferences; browser storage on the web). Uninstalling or clearing the data of the generator **loses the key** unless Android's automatic backup restores it on reinstall or a new phone (it is enabled, but do not rely on it): back the key up via **Signing key** to be safe. Apps regenerated afterwards are signed with a new key, so the old version of that app must be uninstalled before the new one can be installed.

## Building from source

Requirements: Flutter 3.47.5, JDK 17-21 (newer JDKs are too new for the Android Gradle plugin) and the Android SDK (`ANDROID_HOME` set).

```bash
scripts/build_template.sh   # builds the template APK into assets/template.apk (gitignored)
flutter pub get
flutter test
flutter run                 # or: flutter build apk / ios / linux / windows / macos / web
```

Tests that verify generated APKs use `apksigner`, `aapt2` and `zipalign` from the newest build-tools under `$ANDROID_HOME`; `flutter test --platform chrome` runs the browser-compatible tests. The icons are drawn by `tool/make_icons.py` (Pillow); rerun it and `scripts/build_template.sh` after changing the icon.

## Maintainer: releases and CI

Every push to `master` runs `.github/workflows/dev-release.yml`: it tests, builds Android, iOS, Linux, Windows, macOS and the web app, and publishes a prerelease `dev-N` with all files plus `SHA256SUMS.txt`. The web app of the newest dev build is deployed to https://devilapi.github.io/web2apk/dev/.

Android version codes come from the workflow run number. Do not rename or recreate `dev-release.yml`: the counter would restart and new builds would count as downgrades.

To make a full release, run **Actions -> Release -> Run workflow** (`.github/workflows/release.yml`) with a version like `2.1.0`. It copies the files of the newest `dev-N` build (or the one you name) into a release `v2.1.0`, so it ships exactly the binaries CI tested, and republishes the web app at https://devilapi.github.io/web2apk/. Bump `version:` in `pubspec.yaml` first so the apps report the same version. Release the newest dev build: `github.token` cannot tag an older commit whose workflow files differ from master's. One-time setup: Settings -> Pages -> Source: **GitHub Actions**.

The Android APK is signed with your own key, supplied through repository secrets. Without them CI signs with a debug key (the release notes say so), and users must uninstall debug-signed builds before installing release-signed ones. Create a keystore with JDK 17-21:

```bash
keytool -genkeypair -v -keystore release.jks -keyalg RSA -keysize 4096 -validity 36500 -alias web2apk
base64 -w0 release.jks   # -> secret ANDROID_KEYSTORE_BASE64
```

Also set the secrets `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` (`web2apk` above) and `ANDROID_KEY_PASSWORD`.

**Back up `release.jks`.** Losing it means users must uninstall the generator before they can update it.

For a local release build, create `android/key.properties` (gitignored) with `storeFile` (relative to `android/app`), `storePassword`, `keyAlias`, `keyPassword`; all four are required. Without the file, release builds fall back to the debug key. The macOS app is unsigned: right-click -> Open the first time. The iOS `.ipa` is unsigned too (`--no-codesign`); sideloading tools sign it with the user's own Apple ID.

## Credits and v1

Made by devilAPI with <3 - https://github.com/devilAPI/web2apk

The original v1 (edit three variables in `main.dart`, build with Gradle) lives on the `legacy` branch.
