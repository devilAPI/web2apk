# web2apk v2 — Phase 1 (Android + Linux) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace v1 with a Flutter generator app (Android + Linux) that turns a name/URL/color/icon/fullscreen form into a signed, installable WebView APK, entirely in pure Dart.

**Architecture:** A tiny Java WebView app (`template/`) is built once with gradle into `assets/template.apk`. The Flutter generator loads it as an asset and, in pure Dart (`lib/src/apk/`), rewrites the ZIP: patches package + label strings in the binary `AndroidManifest.xml`, writes `assets/config.json`, swaps launcher PNGs, aligns, and signs with APK Signature Scheme v2 using a per-install RSA key kept in `shared_preferences`. No `dart:io` inside `lib/src/apk/` so phase 2 (web) reuses it unchanged.

**Tech Stack:** Flutter 3.47 / Dart 3, packages `archive` (deflate/inflate/crc32), `pointycastle` (RSA, ASN.1), `crypto` (SHA-256), `image` (PNG resize), `shared_preferences`, `file_picker`, `share_plus`, `path_provider`, `flutter_colorpicker`. Template: Java, Android Gradle Plugin, no AndroidX. Tests: `flutter test`, plus `apksigner`/`aapt2`/`zipalign` from `$ANDROID_HOME/build-tools`.

**Spec:** `docs/superpowers/specs/2026-10-27-web2apk-v2-design.md`

## Global Constraints

- Generator application ID: `de.devilapi.web2apk` (never changes).
- Generator platforms in this phase: `android`, `linux` only (`flutter create --platforms android,linux`).
- Min Android 7.0 (API 24) for generator and generated apps. Template `targetSdk 34`.
- Template: Java, no AndroidX/AppCompat/Kotlin stdlib, no R8/resource shrinking.
- Template placeholders: package `de.devilapi.web2apk.template`, label `WEB2APK_TEMPLATE_LABEL`, activity class `de.devilapi.web2apk.template.MainActivity` (fully qualified in manifest).
- Config file in generated APK: `assets/config.json` = `{"url": String, "title": String, "color": "#RRGGBB", "fullscreen": bool}`.
- Default color: Material blue `#2196F3` (v1's `Colors.blue`).
- Package ID default: reversed host, `www.` stripped, suffix `.web2apk` (`https://example.org` → `org.example.web2apk`).
- Signing: APK Signature Scheme v2 only (minSdk 24), RSA 2048, SHA256withRSA (v2 algorithm id `0x0103`).
- `lib/src/apk/**` must not import `dart:io` or `package:flutter/*` (web reuse in phase 2).
- Credit "Made by devilAPI with <3 — https://github.com/devilAPI/web2apk" in `lib/main.dart` header comment and in the generator's About dialog.
- Local gradle runs use `JAVA_HOME=/usr/lib/jvm/java-21-openjdk` (system default JDK 27 is too new for AGP); CI uses Temurin 17.
- Never push to the remote; commits are local.

## Review Focus

1. **Non-ASCII / long app names** ("Café 🚀", 60 chars) → label shows correctly on the home screen; string pool encodes UTF-8 and UTF-16 pools correctly. Test in Task 4 and Task 7.
2. **Sloppy URLs** (`example.org`, `HTTP://Example.org:8080/path`, `  https://www.x.de  `, `ftp://x`, `https://`) → normalized to http(s) with scheme added, or rejected with a message; package ID still valid. Test in Task 6.
3. **Hostnames that aren't valid Java segments** (`1und1.de`, `my-site.com`, `192.168.0.10`, `xn--mnchen-3ya.de`, `münchen.de`) → valid package ID (each segment `[a-z][a-z0-9_]*`). Test in Task 6.
4. **Odd icon files** (non-square 4000×1000 JPEG, transparent PNG, a `.txt` renamed `.png`) → center-cropped square icons, transparency kept, clear error for undecodable input rather than a crash. Test in Task 6.
5. **Stored signing key unreadable** (corrupted prefs value) → error surfaced, key **not** silently regenerated (that would break in-place updates). Test in Task 8.

---

## File Structure

```
template/                         Java WebView template (own gradle project)
  settings.gradle, build.gradle, gradle.properties, gradlew*, gradle/wrapper/*
  app/build.gradle
  app/src/main/AndroidManifest.xml
  app/src/main/java/de/devilapi/web2apk/template/MainActivity.java
  app/src/main/assets/config.json
  app/src/main/res/mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png   (from v1, legacy branch)
scripts/build_template.sh         builds template, copies unsigned APK → assets/template.apk
assets/template.apk               build output, gitignored
lib/main.dart                     app entry, credit comment
lib/src/apk/template_contract.dart  placeholder constants + icon path/density table
lib/src/apk/zip.dart              ZIP read/write with STORED-entry alignment
lib/src/apk/axml.dart             binary XML string-pool read/replace
lib/src/apk/signing_key.dart      RSA key + self-signed X.509 cert, JSON (de)serialization
lib/src/apk/v2_signer.dart        APK Signature Scheme v2
lib/src/apk/icons.dart            launcher icon rendering
lib/src/apk/app_spec.dart         AppSpec + normalizeUrl + packageIdFromUrl + isValidPackageId
lib/src/apk/apk_builder.dart      buildApk: glue
lib/src/key_store.dart            loadOrCreateSigningKey (shared_preferences)
lib/src/apk_actions.dart          ApkActions interface + PlatformApkActions
lib/src/ui/generator_page.dart    form
lib/src/ui/result_page.dart       install/save/share
android/app/src/main/kotlin/de/devilapi/web2apk/MainActivity.kt   install channel
android/app/src/main/res/xml/file_paths.xml
test/support/sdk_tools.dart       locate build-tools; load template
test/apk/*_test.dart, test/key_store_test.dart, test/ui/*_test.dart
.github/workflows/build.yml
README.md
```

---

### Task 1: Replace v1 with a Flutter skeleton

**Files:**
- Delete: every tracked v1 file except `README.md`, `docs/`, `.gitignore` (v1 lives on branch `legacy`, already created)
- Create: Flutter project via `flutter create`
- Modify: `.gitignore`, `lib/main.dart`, `test/widget_test.dart` → delete

- [ ] **Step 1: Remove v1 files**

```bash
git rm -r -q .metadata .vscode android ios lib pubspec.yaml pubspec.lock
```

- [ ] **Step 2: Create project**

```bash
flutter create --org de.devilapi --project-name web2apk --platforms android,linux .
```
Then verify `android/app/build.gradle.kts` has `applicationId = "de.devilapi.web2apk"` and set `minSdk = 24`.

- [ ] **Step 3: Replace `lib/main.dart`** with a `MaterialApp` (Material 3, seed color `0xFF2196F3`, title `web2apk`) whose home is a placeholder `Scaffold`; header comment:
```dart
// Made by devilAPI with <3
// https://github.com/devilAPI/web2apk
```
Delete the generated `test/widget_test.dart`. Add to `.gitignore`: `/assets/template.apk`, `/android/key.properties`, `*.jks`, `template/**/build/`, `template/.gradle/`, `template/local.properties`.

- [ ] **Step 4: Verify**

Run: `flutter analyze && flutter build linux --debug`
Expected: no issues; build succeeds.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "chore: replace v1 with Flutter v2 skeleton (android, linux)"
```

---

### Task 2: Template WebView app + build script

**Files:**
- Create: everything under `template/`, `scripts/build_template.sh`
- Icons: `git show legacy:android/app/src/main/res/mipmap-<d>/ic_launcher.png > template/app/src/main/res/mipmap-<d>/ic_launcher.png` for d in mdpi hdpi xhdpi xxhdpi xxxhdpi

**Interfaces:**
- Produces: `assets/template.apk` (unsigned release APK) whose binary manifest contains strings `de.devilapi.web2apk.template` and `WEB2APK_TEMPLATE_LABEL`, entries `assets/config.json` and `res/mipmap-*dpi*/ic_launcher.png`.

- [ ] **Step 1: Gradle project.** Use the same AGP and Gradle versions as the Flutter-generated `android/settings.gradle.kts` / `android/gradle/wrapper/gradle-wrapper.properties`; generate the wrapper with `gradle wrapper --gradle-version <that version>` inside `template/`. `app/build.gradle`: `namespace` and `applicationId` `de.devilapi.web2apk.template`, `minSdk 24`, `targetSdk 34`, `compileSdk 34`, `versionCode 1`, `versionName "1.0"`, release `minifyEnabled false`, `shrinkResources false`, no `signingConfig`. No dependencies.

- [ ] **Step 2: Manifest.** `INTERNET` permission; `<application android:label="WEB2APK_TEMPLATE_LABEL" android:icon="@mipmap/ic_launcher" android:theme="@android:style/Theme.Material.Light.DarkActionBar" android:usesCleartextTraffic="true">`; one activity `android:name="de.devilapi.web2apk.template.MainActivity"`, `exported="true"`, `configChanges` same list as v1 (`orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode`), `windowSoftInputMode="adjustResize"`, MAIN/LAUNCHER filter. No roundIcon, no adaptive icon.

- [ ] **Step 3: `config.json`** default: `{"url":"https://www.example.org/","title":"MyAppName","color":"#2196F3","fullscreen":false}`.

- [ ] **Step 4: `MainActivity.java`** (`android.app.Activity`):
  - Read `assets/config.json` with `org.json.JSONObject`.
  - `int color = Color.parseColor(config.color)`; `getWindow().setStatusBarColor(darker)` where darker = each RGB channel × 0.8.
  - If `fullscreen`: `getActionBar().hide()`. Else: `getActionBar().setBackgroundDrawable(new ColorDrawable(color))`, title = `title` wrapped in a `SpannableString` with `ForegroundColorSpan` white if `Color.luminance(color) < 0.5` else black.
  - WebView as content view: JS on, DOM storage on; `WebViewClient.shouldOverrideUrlLoading`: return `false` for `http`/`https`; otherwise try `startActivity(new Intent(ACTION_VIEW, uri))`, catch `ActivityNotFoundException`, return `true`.
  - `onBackPressed`: `webView.canGoBack() ? webView.goBack() : super.onBackPressed()`.
  - Load `url` only when `savedInstanceState == null`, else `webView.restoreState`.

- [ ] **Step 5: `scripts/build_template.sh`** (`set -euo pipefail`): `cd template && ./gradlew --no-daemon assembleRelease`, copy `app/build/outputs/apk/release/app-release-unsigned.apk` to `../assets/template.apk`. Respect an existing `JAVA_HOME`. Add `assets/template.apk` under `flutter: assets:` in `pubspec.yaml`.

- [ ] **Step 6: Verify the contract**

Run:
```bash
JAVA_HOME=/usr/lib/jvm/java-21-openjdk scripts/build_template.sh
/opt/android-sdk/build-tools/36.0.0/aapt2 dump badging assets/template.apk | head -5
unzip -l assets/template.apk | grep -E 'config.json|ic_launcher'
```
Expected: `package: name='de.devilapi.web2apk.template'`, `application-label:'WEB2APK_TEMPLATE_LABEL'`, `sdkVersion:'24'`, `targetSdkVersion:'34'`; `assets/config.json` and five `ic_launcher.png` entries listed. If the label line shows a resource reference instead of the literal, the label must be inlined in the manifest (no `@string`).

- [ ] **Step 7: Commit**

```bash
git add template scripts pubspec.yaml .gitignore && git commit -m "feat: add Java WebView template app and build script"
```

---

### Task 3: ZIP reader/writer with alignment

**Files:**
- Create: `lib/src/apk/zip.dart`, `test/support/sdk_tools.dart`, `test/apk/zip_test.dart`

**Interfaces:**
- Produces:
  - `class ZipEntry { final String name; final int method; /* 0 stored, 8 deflated */ final Uint8List rawData; final int crc32; final int uncompressedSize; Uint8List get data; factory ZipEntry.stored(String name, Uint8List data); factory ZipEntry.deflated(String name, Uint8List data); }`
  - `List<ZipEntry> readZip(Uint8List bytes)` — driven by the central directory (sizes/CRC from CD, works with data descriptors); keeps entry order.
  - `Uint8List writeZip(List<ZipEntry> entries, {int alignment = 4})` — no data descriptors, fixed DOS time 1981-01-01 00:00, data of every STORED entry starts at an offset that is a multiple of `alignment` (pad via local-header extra field), entries' raw data copied without recompression.
  - `test/support/sdk_tools.dart`: `String? buildTool(String name)` (newest dir under `$ANDROID_HOME/build-tools`, null if absent); `Uint8List loadTemplate()` (reads `assets/template.apk`, fails with "run scripts/build_template.sh" if missing); `Future<ProcessResult> runTool(String name, List<String> args)`.

- [ ] **Step 1: Write failing tests** in `test/apk/zip_test.dart`:
  - `round-trips template entries`: `readZip(writeZip(readZip(t)))` has same names, methods, and `data` per entry as `readZip(t)`.
  - `stored entry data is 4-byte aligned`: write `[ZipEntry.deflated('a.txt', ...3 bytes), ZipEntry.stored('b.bin', ...)]`, find `b.bin` local header, assert `(headerOffset + 30 + nameLen + extraLen) % 4 == 0`.
  - `deflated factory compresses and data inflates back`.
  - `zipalign accepts output` (skip if `buildTool('zipalign') == null`): write template round-trip to a temp file, `zipalign -c -P 16 4 <file>` exits 0.

- [ ] **Step 2: Run, verify fail.** `flutter test test/apk/zip_test.dart` → FAIL (`readZip` undefined).

- [ ] **Step 3: Implement** `zip.dart` with `ByteData` little-endian parsing; deflate/inflate/CRC from `package:archive` (`Deflate`, `Inflate`, `getCrc32`) — raw deflate, no zlib header.

- [ ] **Step 4: Run, verify pass.** `flutter test test/apk/zip_test.dart` → PASS.

- [ ] **Step 5: Commit** `feat: pure-Dart zip reader/writer with alignment`.

---

### Task 4: Binary XML string patcher

**Files:**
- Create: `lib/src/apk/axml.dart`, `lib/src/apk/template_contract.dart`, `test/apk/axml_test.dart`

**Interfaces:**
- Produces:
  - `List<String> readXmlStrings(Uint8List axml)`
  - `Uint8List replaceXmlStrings(Uint8List axml, Map<String, String> replacements)` — replaces string-pool entries whose value equals a key exactly; throws `FormatException` if any key is absent.
  - `template_contract.dart`: `const kTemplatePackage = 'de.devilapi.web2apk.template'; const kTemplateLabel = 'WEB2APK_TEMPLATE_LABEL'; const kConfigPath = 'assets/config.json'; const kManifestPath = 'AndroidManifest.xml'; final kIconPath = RegExp(r'^res/mipmap-(mdpi|hdpi|xhdpi|xxhdpi|xxxhdpi)(-v4)?/ic_launcher\.png$'); const kIconSizes = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192};`

- [ ] **Step 1: Failing tests** (manifest taken from `readZip(loadTemplate())`):
  - `template manifest contains placeholders`: `readXmlStrings` contains `kTemplatePackage`, `kTemplateLabel`, `'de.devilapi.web2apk.template.MainActivity'`.
  - `replaces package and label`: after replacing with `{'org.example.web2apk', 'Café 🚀'}`, strings contain new values, not placeholders, and still contain the activity class name unchanged.
  - `long name`: 60-char label round-trips.
  - `missing key throws FormatException`.
  - `aapt2 reads patched manifest` (skip without `aapt2`): put patched manifest back into the template zip via `writeZip`, write temp file, `aapt2 dump badging` output contains `package: name='org.example.web2apk'` and `application-label:'Café 🚀'`.

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement.** Layout: file = `ResChunk_header`(type `0x0003`, headerSize, size) followed by chunks; the string pool chunk (type `0x0001`, headerSize 28: `stringCount, styleCount, flags, stringsStart, stylesStart`) is first. Re-encode every string in the pool's own encoding (`flags & 0x100` = UTF-8: char-length in UTF-16 units then byte-length, each 1 byte or 2 bytes with high bit `0x80`, bytes, `0x00`; UTF-16: length u16 or two u16 with `0x8000`, code units, `0x0000`), rebuild the offset table, pad strings to 4 bytes, copy style data verbatim after it, clear the `SORTED` flag (`0x1`), fix the pool's `size`/`stylesStart` and the outer chunk's `size`. All other chunks are copied unchanged (they reference strings by index).

- [ ] **Step 4: Run, verify pass.**

- [ ] **Step 5: Commit** `feat: binary XML string-pool patcher`.

---

### Task 5: Signing key and APK Signature Scheme v2

**Files:**
- Create: `lib/src/apk/signing_key.dart`, `lib/src/apk/v2_signer.dart`, `test/apk/signer_test.dart`

**Interfaces:**
- Produces:
  - `class SigningKey { final RSAPrivateKey privateKey; final RSAPublicKey publicKey; final Uint8List certificateDer; static SigningKey generate(); Map<String, String> toJson(); factory SigningKey.fromJson(Map<String, dynamic> json); }` — `fromJson` throws `FormatException` on malformed input.
  - `Uint8List signApkV2(Uint8List zip, SigningKey key)` — input is an unsigned ZIP from `writeZip`.

- [ ] **Step 1: Failing tests**
  - `json round-trip`: `SigningKey.fromJson(k.toJson())` has same modulus, private exponent, and certificate bytes.
  - `fromJson rejects garbage`: `{'n': 'zz'}` → `FormatException`.
  - `apksigner verifies v2 signature` (skip without `apksigner`): `signApkV2(writeZip(readZip(loadTemplate())), key)` → temp file → `apksigner verify --verbose --min-sdk-version 24 <file>` exits 0 and stdout contains `Verified using v2 scheme (APK Signature Scheme v2): true`.
  - `same key gives same certificate digest`: `apksigner verify --print-certs` SHA-256 digest equal for two APKs signed with the same key, different for a new key.
  - Generate one key in `setUpAll` (keygen is slow).

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement `SigningKey`.** Keygen: pointycastle `RSAKeyGenerator` (2048 bits, e = 65537) seeded from `FortunaRandom` with `Random.secure()`. Certificate: X.509 v3 self-signed DER built with pointycastle's ASN.1 classes; subject = issuer = `CN=web2apk`; positive random 63-bit serial; signature algorithm `sha256WithRSAEncryption` (`1.2.840.113549.1.1.11`, NULL params); validity notBefore = now − 1 day (UTCTime), notAfter = now + 30 years (GeneralizedTime — after 2049 UTCTime is invalid). JSON: `n, d, p, q` as hex strings, `cert` as base64.

- [ ] **Step 4: Implement `signApkV2`** per https://source.android.com/docs/security/features/apksigning/v2:
  - Split input into entries section `[0, cdOffset)`, central directory, EOCD.
  - Digest: 1 MiB chunks over the three sections (EOCD digested as-is, its CD offset is the original `cdOffset`); each chunk `SHA-256(0xa5 ‖ u32le len ‖ chunk)`; top `SHA-256(0x5a ‖ u32le count ‖ chunk digests)`.
  - `signed data` = digests seq [(`0x0103`, digest)], certificates seq [cert DER], additional attributes seq (empty); all length-prefixed (u32le) per spec.
  - Signature = RSA PKCS#1 v1.5 SHA-256 (pointycastle `Signer('SHA-256/RSA')`) over `signed data`.
  - Signer = signed data ‖ signatures seq [(`0x0103`, sig)] ‖ public key (SubjectPublicKeyInfo DER).
  - Block = u64 size ‖ pair(id `0x7109871a`, signers seq [signer]) ‖ u64 size ‖ `"APK Sig Block 42"`. Output = entries ‖ block ‖ CD ‖ EOCD with CD offset += block length.

- [ ] **Step 5: Run, verify pass.**

- [ ] **Step 6: Commit** `feat: RSA signing key and APK Signature Scheme v2 signer`.

---

### Task 6: App spec, URL/package rules, icons

**Files:**
- Create: `lib/src/apk/app_spec.dart`, `lib/src/apk/icons.dart`, `test/apk/app_spec_test.dart`, `test/apk/icons_test.dart`

**Interfaces:**
- Produces:
  - `String normalizeUrl(String input)` — trims; adds `https://` when no scheme; lowercases scheme and host; throws `FormatException` for non-http(s) schemes or empty host.
  - `String packageIdFromUrl(String url)` — from normalized URL; host lowercased, `www.` stripped, split on `.`, reversed, each segment: chars outside `[a-z0-9_]` → `_`, prefixed with `x` if it does not start with `[a-z]`; append `web2apk`.
  - `bool isValidPackageId(String id)` — `^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$`.
  - `class AppSpec { final String name; final String url; final int color; final bool fullscreen; final String packageId; final Uint8List? icon; String configJson(); }` — `color` is ARGB; `configJson()` emits keys `url, title, color ("#RRGGBB" uppercase), fullscreen`.
  - `Map<String, Uint8List> renderLauncherIcons(Uint8List source, Iterable<String> iconPaths)` — path → PNG, size from `kIconSizes` by density captured by `kIconPath`; center-crop to square, `Interpolation.cubic`, alpha kept; throws `FormatException('Not a supported image')` if undecodable.

- [ ] **Step 1: Failing tests** (`app_spec_test.dart`):
  - `normalizeUrl`: `'example.org'` → `'https://example.org'`; `'  HTTP://Example.org:8080/path  '` → `'http://example.org:8080/path'`; `'ftp://x'` throws; `'https://'` throws.
  - `packageIdFromUrl`: `https://example.org` → `org.example.web2apk`; `https://www.blog.example.org` → `org.example.blog.web2apk`; `https://1und1.de` → `de.x1und1.web2apk`; `https://my-site.com` → `com.my_site.web2apk`; `http://192.168.0.10` → `x10.x0.x168.x192.web2apk`; `https://münchen.de` result passes `isValidPackageId`.
  - `isValidPackageId`: true for `org.example.web2apk`; false for `example`, `1a.b`, `a..b`, `a.b-c`.
  - `configJson`: `AppSpec(name:'My', url:'https://x.de', color:0xFF2196F3, fullscreen:true, …).configJson()` decodes to `{'url':'https://x.de','title':'My','color':'#2196F3','fullscreen':true}`.

  (`icons_test.dart`, sources generated in-test with `package:image`):
  - 4000×1000 opaque image → five outputs, each decodes square at 48/72/96/144/192.
  - Transparent PNG input → output pixel (0,0) alpha 0.
  - `utf8.encode('hello')` → `FormatException`.

- [ ] **Step 2: Run, verify fail.**
- [ ] **Step 3: Implement** both files.
- [ ] **Step 4: Run, verify pass.**
- [ ] **Step 5: Commit** `feat: app spec, url/package-id rules, launcher icon rendering`.

---

### Task 7: `buildApk` pipeline

**Files:**
- Create: `lib/src/apk/apk_builder.dart`, `test/apk/apk_builder_test.dart`

**Interfaces:**
- Consumes: `readZip`, `writeZip`, `ZipEntry` (Task 3); `replaceXmlStrings`, contract constants (Task 4); `SigningKey`, `signApkV2` (Task 5); `AppSpec`, `renderLauncherIcons` (Task 6).
- Produces: `Uint8List buildApk({required Uint8List template, required AppSpec spec, required SigningKey key})` — throws `ArgumentError` if `spec.name.trim()` is empty or `!isValidPackageId(spec.packageId)`.

- [ ] **Step 1: Failing tests** (one key from `setUpAll`, spec `name: 'Café 🚀'`, `url: 'https://example.org'`, `color: 0xFFFFEB3B`, `fullscreen: true`, `packageId: 'org.example.web2apk'`, `icon`: generated 512×512 red PNG):
  - `config.json`: `readZip(apk)` entry `assets/config.json` decodes to the spec's `configJson()`.
  - `icons replaced`: every `kIconPath` entry decodes to a red image of the density size.
  - `no icon keeps template icons`: with `icon: null`, icon entries byte-equal the template's.
  - `badging` (skip without SDK): `aapt2 dump badging` shows `package: name='org.example.web2apk'`, `application-label:'Café 🚀'`; `apksigner verify --min-sdk-version 24` exits 0; `zipalign -c -P 16 4` exits 0.
  - `empty name` / `bad package id` → `ArgumentError`.

- [ ] **Step 2: Run, verify fail.**
- [ ] **Step 3: Implement**: read entries → patch manifest (`{kTemplatePackage: packageId, kTemplateLabel: name.trim()}`, keep its method) → replace/insert `kConfigPath` as deflated → if `icon != null` replace each `kIconPath` entry as stored → drop any `META-INF/*.SF|*.RSA|*.DSA|*.EC|MANIFEST.MF` → `writeZip` → `signApkV2`.
- [ ] **Step 4: Run, verify pass.**
- [ ] **Step 5: Commit** `feat: buildApk pipeline`.

---

### Task 8: Signing key storage

**Files:**
- Create: `lib/src/key_store.dart`, `test/key_store_test.dart`

**Interfaces:**
- Consumes: `SigningKey` (Task 5).
- Produces: `Future<SigningKey> loadOrCreateSigningKey(SharedPreferences prefs, {Future<SigningKey> Function()? generate})` — prefs key `'signing_key_v1'` (JSON string). Default `generate` runs `SigningKey.generate` via `compute`. Throws `StateError('Stored signing key is unreadable')` on a corrupt value and leaves it untouched.

- [ ] **Step 1: Failing tests** (`SharedPreferences.setMockInitialValues`, fake `generate` returning a fixed key built once in `setUpAll`):
  - `creates and stores when empty`: generate called once; prefs now contain `signing_key_v1`.
  - `reuses stored key`: second call returns same modulus, generate not called.
  - `corrupt value throws and is preserved`: initial `{'signing_key_v1': 'not json'}` → `StateError`; value still `'not json'`.
- [ ] **Step 2: Run, verify fail.** · **Step 3: Implement.** · **Step 4: Run, verify pass.**
- [ ] **Step 5: Commit** `feat: persist signing key in shared_preferences`.

---

### Task 9: Generator UI and platform actions

**Files:**
- Create: `lib/src/apk_actions.dart`, `lib/src/ui/generator_page.dart`, `lib/src/ui/result_page.dart`, `android/app/src/main/res/xml/file_paths.xml`, `test/ui/generator_page_test.dart`, `test/ui/result_page_test.dart`
- Modify: `lib/main.dart`, `android/app/src/main/kotlin/de/devilapi/web2apk/MainActivity.kt`, `android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Consumes: `buildApk` (Task 7), `loadOrCreateSigningKey` (Task 8), `normalizeUrl`, `packageIdFromUrl`, `isValidPackageId`, `AppSpec` (Task 6).
- Produces:
  - `abstract class ApkActions { bool get canInstall; bool get canShare; Future<InstallResult> install(Uint8List apk, String fileName); Future<bool> save(Uint8List apk, String fileName); Future<void> share(Uint8List apk, String fileName); }`, `enum InstallResult { started, needsPermission }`.
  - `class PlatformApkActions implements ApkActions` — `canInstall`/`canShare` true only on Android in this phase; install/share write to `getTemporaryDirectory()`; install calls `MethodChannel('de.devilapi.web2apk/install').invokeMethod<String>('install', {'path': path})` and maps `'needs_permission'`; save uses `FilePicker.platform.saveFile(fileName: fileName, bytes: apk)` and returns whether a path/uri came back; share uses `SharePlus` with an `XFile`.
  - `GeneratorPage({required ApkActions actions, required Future<SigningKey> Function() loadKey, Future<Uint8List> Function()? loadTemplate})` — default template loader `rootBundle.load('assets/template.apk')`.
  - `ResultPage({required Uint8List apk, required String fileName, required ApkActions actions})`.

- [ ] **Step 1: Failing widget tests** (fake `ApkActions` recording calls, fake `loadKey` returning a pre-generated key, `loadTemplate` returning `loadTemplate()` from test support):
  - `package line follows URL`: entering `example.org` shows `org.example.web2apk`.
  - `manual package edit sticks`: after editing package to `org.example.shop` via its dialog, changing URL does not overwrite it.
  - `invalid URL disables Generate` (`ftp://x`) and shows an error text.
  - `generate navigates to result`: name `Test`, URL `example.org`, tap Generate, `pumpAndSettle` → `ResultPage` found; fake save receives a non-empty byte list when Save tapped; file name `Test.apk`.
  - `result page hides Install/Share when unsupported` (fake with both false) and shows them when true; `needsPermission` shows a SnackBar containing `Allow installs from web2apk`.
  - `About shows credit`: dialog contains `Made by devilAPI with <3`.

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Add packages:** `flutter pub add archive pointycastle crypto image shared_preferences file_picker share_plus path_provider flutter_colorpicker`.

- [ ] **Step 4: Implement UI.** Generator page fields: App name, Website URL, Color (tile showing swatch; dialog with `BlockPicker`, default `0xFF2196F3`), Icon (tile with preview; `FilePicker.platform.pickFiles(type: FileType.image, withData: true)`; validated by trying `renderLauncherIcons` once and showing its error), Fullscreen `SwitchListTile` with subtitle "Hide the title bar", package line `Package: <id> — tap to change` (dialog validated with `isValidPackageId`). Generate button: disabled while invalid; on tap shows progress, `await loadKey()`, runs `buildApk` via `compute` with a top-level function, pushes `ResultPage`. File name: name with characters outside `[A-Za-z0-9 _-]` removed, trimmed, falling back to `app`, + `.apk`. AppBar action: About (`showAboutDialog`, legalese with credit line + repo URL). Errors (key/template/build) → SnackBar with the message. `main.dart`: `GeneratorPage(actions: PlatformApkActions(), loadKey: () async => loadOrCreateSigningKey(await SharedPreferences.getInstance()))`.

- [ ] **Step 5: Implement Android install.** Manifest: `REQUEST_INSTALL_PACKAGES` permission; `<provider android:name="androidx.core.content.FileProvider" android:authorities="de.devilapi.web2apk.fileprovider" android:exported="false" android:grantUriPermissions="true">` with `file_paths.xml` = `<cache-path name="cache" path="."/>` (add `androidx.core:core` dependency if not already transitively present). `MainActivity.kt`: on `install`, if API ≥ 26 and `!packageManager.canRequestPackageInstalls()`, start `Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES` with `package:de.devilapi.web2apk` and return `"needs_permission"`; else `ACTION_VIEW` with FileProvider URI, type `application/vnd.android.package-archive`, `FLAG_GRANT_READ_URI_PERMISSION | FLAG_ACTIVITY_NEW_TASK`, return `"started"`.

- [ ] **Step 6: Run, verify pass.** `flutter test` → all PASS; `flutter analyze` → no issues; `flutter build apk --debug` and `flutter build linux --debug` succeed.

- [ ] **Step 7: Commit** `feat: generator UI, result actions, Android installer channel`.

---

### Task 10: CI/release workflow, release signing, README

**Files:**
- Create: `.github/workflows/build.yml`
- Modify: `android/app/build.gradle.kts`, `README.md`

- [ ] **Step 1: Release signing.** In `build.gradle.kts`, load `android/key.properties` (`storeFile, storePassword, keyAlias, keyPassword`) if it exists into a `release` signing config; if absent: use debug signing, except when env `CI == "true"` and the task graph contains a release task → fail with "android/key.properties missing".

- [ ] **Step 2: Workflow** `build.yml`, triggers: push to `master`, pull requests, tags `v*`.
  - `test` (ubuntu-latest): checkout; `actions/setup-java` Temurin 17; `subosito/flutter-action` channel stable; `scripts/build_template.sh`; `flutter analyze`; `flutter test` (SDK tool tests run because the runner has `ANDROID_HOME`); upload `assets/template.apk` as artifact.
  - `android` (needs test): download template artifact into `assets/`; if tag: write `android/app/release.jks` from `secrets.ANDROID_KEYSTORE_BASE64` and `android/key.properties` from `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`; `flutter build apk --release` (on non-tag runs, `--debug`); upload `web2apk-android.apk`.
  - `linux` (needs test): apt `clang cmake ninja-build pkg-config libgtk-3-dev`; template artifact; `flutter build linux --release`; tar `build/linux/x64/release/bundle` → `web2apk-linux-x64.tar.gz`; upload.
  - `release` (needs android, linux; only on tags): `softprops/action-gh-release` with both files; `permissions: contents: write`.

- [ ] **Step 3: README** rewrite: what it is (screenshot placeholder), download from Releases, using it (form fields, fullscreen, package ID, Install/Save/Share), the signing-key caveat ("uninstalling the generator loses the key; regenerated apps then need the old app uninstalled first"), building from source (`scripts/build_template.sh`, `flutter run`), maintainer release setup:
```bash
keytool -genkeypair -v -keystore release.jks -keyalg RSA -keysize 4096 -validity 36500 -alias web2apk
base64 -w0 release.jks   # → secret ANDROID_KEYSTORE_BASE64
```
plus secrets `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, and "back up release.jks — losing it means users must uninstall to update". Keep the credit line and v1 pointer (`legacy` branch).

- [ ] **Step 4: Verify.** `actionlint .github/workflows/build.yml` if available (otherwise YAML parse with `python3 -c 'import yaml,sys;yaml.safe_load(open(sys.argv[1]))'`); `flutter build apk --release` locally succeeds with debug fallback.

- [ ] **Step 5: Commit** `ci: build/test/release workflow; README for v2`.

---

### Task 11: End-to-end verification

No new code unless a defect is found (then fix with a regression test in the owning task's test file).

- [ ] **Step 1: Linux.** `flutter run -d linux`; generate `Example` / `example.org` / yellow / custom icon / fullscreen on; Save to `~/web2apk-test/example.apk`; `apksigner verify --min-sdk-version 24` and `aapt2 dump badging` on it pass and show `org.example.web2apk` / `Example`.
- [ ] **Step 2: Android device** (no emulator installed; needs the owner's phone via `adb devices`, or install an emulator image with `sdkmanager` if the owner prefers). Install generator debug APK; generate, tap Install; check: label + icon on home screen, page loads, title bar color/text readable, fullscreen hides only the title bar, back navigates history then exits.
- [ ] **Step 3: Coexistence and update.** Generate a second app for `wikipedia.org` → both installed side by side. Regenerate the first with a different color → installs as update (no "conflicts with existing package").
- [ ] **Step 4: Report** results to the owner; do not push.
