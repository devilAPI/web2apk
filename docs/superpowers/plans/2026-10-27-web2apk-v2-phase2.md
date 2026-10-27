# web2apk v2 — Phase 2 (Web, macOS, Windows) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run the existing generator on web, macOS and Windows with the same pure-Dart APK pipeline, and ship them from CI (web on GitHub Pages, desktop zips on releases).

**Architecture:** Add the three Flutter platforms. Split `apk_actions.dart` into an IO implementation and a web implementation behind a conditional import, because `dart:io`/`path_provider` don't exist on web. On web, RSA key generation in dart2js BigInt is too slow, so key generation uses the browser's WebCrypto (`crypto.subtle.generateKey`, exported PKCS#8 parsed into `n,d,p,q`) behind a conditional import; signing stays in Dart. A deterministic "golden" pipeline test runs on both the VM and Chrome to prove byte-identical output.

**Tech Stack:** Flutter 3.47 (web, macos, windows), `package:web` + `dart:js_interop` (WebCrypto), existing packages. CI: `macos-latest`, `windows-latest`, `actions/deploy-pages`.

**Spec:** `docs/superpowers/specs/2026-10-27-web2apk-v2-design.md` (phase 2 = web, macOS, Windows). Phase 1 plan: `docs/superpowers/plans/2026-10-27-web2apk-v2-phase1.md`.

## Global Constraints

- All phase 1 Global Constraints still apply (app id `de.devilapi.web2apk`, `lib/src/apk/**` free of `dart:io`/Flutter, v2-only signing, etc.).
- Platform actions: Install only on Android. Share on Android and macOS. Save everywhere (web: browser download of `<name>.apk`).
- Web shows a persistent notice on the form: "Your signing key is stored in this browser. Clearing site data loses it, and apps you generated can then no longer be updated in place."
- Web is served from GitHub Pages at `/web2apk/` (`--base-href /web2apk/`).
- macOS build is unsigned; needs `com.apple.security.files.user-selected.read-write` entitlement (Debug and Release) for the save dialog and file picking.
- macOS and Windows cannot be built locally (Linux host); they are verified by CI config review only, plus `flutter analyze`.

## Review Focus

1. **Web int semantics** — the pipeline (CRC32, zip offsets, u64 lengths, AXML lengths) must produce identical bytes under dart2js. Covered by the golden test (Task 2) on `--platform chrome`.
2. **First-run on web is slow or hangs** — key generation must finish in a few seconds via WebCrypto; UI shows progress. Task 3.
3. **Web save** — download must use the `.apk` name and `application/vnd.android.package-archive` MIME. Task 4.
4. **Imports leaking `dart:io` into the web build** — `flutter build web` must succeed. Task 1/4.
5. **Desktop save cancelled** — cancelling the dialog must not show a success message. Task 4 widget test (fake returns false).

---

### Task 1: Add web, macOS, Windows platforms

**Files:** generated `web/`, `macos/`, `windows/`; Modify: `macos/Runner/DebugProfile.entitlements`, `macos/Runner/Release.entitlements`, `web/index.html` (title `web2apk`), `web/manifest.json` (name/short_name `web2apk`, theme `#2196F3`).

- [ ] **Step 1:** `flutter create --org de.devilapi --project-name web2apk --platforms web,macos,windows .` (restore any overwritten `README.md`/`lib/`/`test/` from HEAD; it should not touch them).
- [ ] **Step 2:** macOS entitlements: add `com.apple.security.files.user-selected.read-write` = true in both files. Set macOS bundle id to `de.devilapi.web2apk` in `macos/Runner/Configs/AppInfo.xcconfig` (`PRODUCT_BUNDLE_IDENTIFIER`).
- [ ] **Step 3: Verify** `flutter analyze` clean. `flutter build web --release` — expected to FAIL now if `apk_actions.dart` imports `dart:io` (fixed in Task 4); record the result.
- [ ] **Step 4: Commit** `chore: add web, macOS, Windows platforms`.

---

### Task 2: Cross-platform golden pipeline test

**Files:** Create: `test/apk/golden_pipeline_test.dart`, `test/fixtures/golden_key.json` (a fixed 2048-bit key in `SigningKey.toJson()` format, generated once on the VM), `test/fixtures/mini_template.dart` (builds a minimal template ZIP in memory: a binary manifest with the placeholder strings, `assets/config.json`, five `res/mipmap-<d>-v4/ic_launcher.png`, a STORED `resources.arsc` dummy).

**Interfaces:**
- Produces: `Uint8List buildMiniTemplate()` in `test/fixtures/mini_template.dart` — pure Dart, no `dart:io`. The binary manifest can be the template's real manifest bytes embedded as a base64 constant (copy from `assets/template.apk`), so it is realistic.
- `golden_key.json` is loaded via a Dart `const String` in a `.dart` fixture (not `dart:io`) so it works in Chrome.

- [ ] **Step 1: Test** `buildApk on mini template is byte-identical across platforms`: `buildApk(template: buildMiniTemplate(), spec: AppSpec(name: 'Golden ✓', url: 'https://example.org', color: 0xFF4CAF50, fullscreen: true, packageId: 'org.example.web2apk', icon: <64×64 PNG generated with package:image, solid blue>), key: SigningKey.fromJson(goldenKey))`; assert `sha256(apk)` equals a hard-coded hex constant. Get the constant by running on the VM first.
- [ ] **Step 2:** Run `flutter test test/apk/golden_pipeline_test.dart` (VM) → PASS after filling the constant. Run `flutter test --platform chrome test/apk/golden_pipeline_test.dart` → must PASS with the same constant. If it fails, find and fix the web int-semantics bug in `lib/src/apk/` (add a focused unit test for it).
- [ ] **Step 3:** Mark existing SDK/`dart:io` tests so `flutter test --platform chrome` skips them (`@TestOn('vm')` at the top of files that import `dart:io` or `test/support/sdk_tools.dart`).
- [ ] **Step 4: Commit** `test: cross-platform golden pipeline test (VM + Chrome)`.

---

### Task 3: WebCrypto key generation on web

**Files:** Create: `lib/src/keygen/keygen.dart` (conditional export), `lib/src/keygen/keygen_io.dart`, `lib/src/keygen/keygen_web.dart`, `test/keygen_web_test.dart`; Modify: `lib/src/apk/signing_key.dart` (add `factory SigningKey.fromRsaParts({required BigInt n, required BigInt d, required BigInt p, required BigInt q})` that builds the self-signed certificate), `lib/src/key_store.dart` (default generator → `generateSigningKey()`).

**Interfaces:**
- Produces: `Future<SigningKey> generateSigningKey()` — IO: `compute` around `SigningKey.generate` (existing behavior). Web: `crypto.subtle.generateKey({name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: [1,0,1], hash: 'SHA-256'}, true, ['sign'])`, `exportKey('pkcs8')`, parse PKCS#8 → RSAPrivateKey ASN.1 (`n, e, d, p, q`) with pointycastle ASN.1, then `SigningKey.fromRsaParts`.
- `SigningKey.generate()` reuses `fromRsaParts` internally (no duplicated cert code).

- [ ] **Step 1: Tests** (`@TestOn('browser')` file): `generateSigningKey()` completes in < 15 s, result survives `SigningKey.fromJson(k.toJson())`, `publicKey.exponent == 65537`. VM test in `signer_test.dart`: `fromRsaParts` from a generated key's parts gives same modulus and a certificate apksigner accepts (reuse existing apksigner test by signing with the rebuilt key).
- [ ] **Step 2:** RED on chrome (`flutter test --platform chrome test/keygen_web_test.dart`).
- [ ] **Step 3:** Implement; conditional export `export 'keygen_io.dart' if (dart.library.js_interop) 'keygen_web.dart';`.
- [ ] **Step 4:** Both platforms GREEN; full VM suite GREEN.
- [ ] **Step 5: Commit** `feat: WebCrypto signing-key generation on web`.

---

### Task 4: Platform actions for web, macOS, Windows + web key notice

**Files:** Create: `lib/src/actions/apk_actions_io.dart`, `lib/src/actions/apk_actions_web.dart`; Modify: `lib/src/apk_actions.dart` (keeps `ApkActions`, `InstallResult`; exports `PlatformApkActions` via conditional import), `lib/src/ui/generator_page.dart` (web notice), tests in `test/ui/`.

**Interfaces:**
- `PlatformApkActions` (IO): `canInstall` = Android; `canShare` = Android || macOS; save via `FilePicker.platform.saveFile` (on desktop, write `bytes` to the returned path if the plugin does not write it itself — check plugin behavior per platform).
- `PlatformApkActions` (web): `canInstall = false`, `canShare = false`, `save` triggers a download via `package:web` (`Blob([bytes], {type: 'application/vnd.android.package-archive'})`, object URL, anchor `download=fileName`, click, revoke) and returns true.
- Generator page shows the web key notice (exact text in Global Constraints) only when `kIsWeb`.

- [ ] **Step 1: Tests:** widget test `web notice hidden on VM` (not shown when `kIsWeb` false — inject a `bool showWebKeyNotice` constructor flag defaulting to `kIsWeb` so both states are testable) and `notice shown when flag true` with the exact text; `save cancelled shows no success SnackBar` (fake save returns false).
- [ ] **Step 2:** RED. **Step 3:** Implement. **Step 4:** `flutter test` GREEN, `flutter build web --release --base-href /web2apk/` succeeds, `flutter build linux --debug` and `flutter build apk --debug` still succeed.
- [ ] **Step 5: Commit** `feat: web/macOS/Windows platform actions and web key notice`.

---

### Task 5: CI for web, macOS, Windows

**Files:** Modify: `.github/workflows/build.yml`, `README.md`.

- [ ] **Step 1:** Add to the `test` job: `flutter test --platform chrome` (Chrome is preinstalled on ubuntu-latest).
- [ ] **Step 2:** Jobs (all `needs: test`, download the template artifact into `assets/`):
  - `web`: `flutter build web --release --base-href /web2apk/`; `actions/upload-pages-artifact` with `build/web`; on tags, job `deploy-pages` (`actions/deploy-pages`, `permissions: pages: write, id-token: write`, `environment: github-pages`). Also zip `build/web` as `web2apk-web.zip` for the release.
  - `windows` (`windows-latest`): `flutter build windows --release`; zip `build/windows/x64/runner/Release` → `web2apk-windows-x64.zip`.
  - `macos` (`macos-latest`): `flutter build macos --release`; `ditto -c -k --keepParent build/macos/Build/Products/Release/web2apk.app web2apk-macos.zip`.
  - `release` job: also attach the three new files.
- [ ] **Step 3:** README: platform table (Android, Linux, Windows, macOS, Web link `https://devilapi.github.io/web2apk/`), macOS Gatekeeper note (right-click → Open), web key notice, "enable GitHub Pages → Source: GitHub Actions" maintainer step.
- [ ] **Step 4: Verify** YAML parses; `actionlint` if available.
- [ ] **Step 5: Commit** `ci: web (Pages), Windows, macOS builds`.
