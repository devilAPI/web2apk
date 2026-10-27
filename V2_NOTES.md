# web2apk v2 — what you need to know

**State:** all work is on local branch `v2`. v1 is kept on local branch `legacy`. Nothing has been pushed.

## What it is
A Flutter app for Android, Linux, Windows, macOS and the web. Users fill in name, URL, color, icon and fullscreen (fullscreen hides only the title bar) and get a signed **~12 KB** Android APK. The APK is built on the device itself, in pure Dart, with no compiler. Under the hood it patches a tiny Java WebView template (`template/`).
Extras: **My apps** (one-tap regenerate with the same package ID, which installs as an update) and **Signing key** (backup, restore and fingerprint).

## To publish (your steps)
1. `git push origin v2 legacy`, then merge `v2` into `master` (or `git push origin v2:master --force`; `legacy` keeps v1).
2. **Release key (do this before the first release; it can never change afterwards):**
   `keytool -genkeypair -v -keystore release.jks -keyalg RSA -keysize 4096 -validity 36500 -alias web2apk`
   Add these repo secrets: `ANDROID_KEYSTORE_BASE64` (from `base64 -w0 release.jks`), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`. **Back up `release.jks`.** Without these secrets, CI signs with a debug key and says so in the release notes.
3. Settings → Pages → Source: **GitHub Actions**.
4. Every push to `master` creates a `dev-N` prerelease (Android, Linux, Windows, macOS, web zip) and deploys the web version to `devilapi.github.io/web2apk/dev/`. Untick "pre-release" on a release and it goes live at `/web2apk/`. The workflows are adapted from stonerspots.

## Verified
- About 110 VM tests and 49 Chrome tests, including Google's `apksigner` and `aapt2` checks, and a test that web and native produce byte-identical APKs.
- Android 14 emulator: the full flow works. Generate → Install → "allow from this source" → installed. The custom icon, label, title-bar color, fullscreen and back button all work. Two apps install side by side, and regenerating installs as an update. The key fingerprint matches `apksigner`.

## Not verified
- The GitHub workflows have never run.
- macOS and Windows builds (can't be built on Linux).
- A real phone.

## Decisions I made for you (change any you dislike)
- Package ID = reversed domain + `.web2apk` (`example.org` → `org.example.web2apk`), editable in the form.
- Min Android 7.0. Template targets SDK 34, which avoids Android 15's forced edge-to-edge.
- Back button goes back in page history first, then exits (v1 just exited).
- Generated apps allow `http://` sites. Links like mailto: and tel: open in the system app.
- Signing: v2 scheme only. One key per generator install, generated with WebCrypto on the web.
- **Phase 3 was my idea:** My apps plus key backup/restore. This undoes the earlier "no key export" decision.
- A corrupted My apps list is replaced on the next save. A corrupted signing key is never replaced; the app shows an error instead.
- CI uses JDK 21 and Flutter 3.47.5, and falls back to the debug key when the secrets are missing.
- New original globe icon (`tool/make_icons.py`) for the generator and as the default icon for generated apps.

## Known limits
- Two apps from the same domain get the same default package ID, so the second replaces the first unless you change the ID.
- On the web, the key lives in browser storage for `devilapi.github.io`. Clearing that site's data loses it, so back it up.
- First build on the web takes about 10 s (key creation).

## Leftovers
- Emulator image (~2 GB): `~/.android/avd/w2a34*` and `/opt/android-sdk/system-images/android-34`. Delete them if you don't want them.
- Spec and plans are in `docs/superpowers/` (delete them if you don't want them on master).
