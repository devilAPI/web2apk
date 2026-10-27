# web2apk v2 — Design

Date: 2026-10-27
Status: approved

## Intent

v1 is a Flutter project where the user edits three variables in `lib/main.dart`
(`appName`, `url`, `appColor`) and builds the APK themselves with gradle. That
requires a dev setup and is barebones.

v2 turns this into an **Android app (built with Flutter) that generates the APK
on the phone**. Audience: strangers / GitHub users who want their website as an
installable Android app without touching code or a build toolchain.

The **generated app** behaves the same as v1's output — one WebView with
JavaScript enabled, under a colored title bar — with one addition: a
**fullscreen toggle** that removes the title bar.

## Goals

- Flutter Android app ("generator") with a form:
  - **App name** — home-screen label and title-bar text
  - **App icon** — picked from the gallery/files
  - **URL**
  - **Color** — title-bar color
  - **Fullscreen** toggle — when on, the generated app has no title bar.
    It hides **only the title bar**; the Android status bar stays visible.
- Tapping **Generate** produces a signed, installable APK on-device.
- After generation, three actions:
  - **Install** — opens the Android package installer on the APK
  - **Save** — writes the APK to Downloads
  - **Share** — Android share sheet with the APK
- Multiple generated apps can be installed side by side.
- Regenerating an app (same package ID) installs as an update over the old one.

## Non-goals

- No compilation on the phone (no Flutter/gradle/aapt on device).
- The generated app is **not** a Flutter app.
- No iOS, no desktop, no web target for the generator.
- No feature additions to the generated app beyond fullscreen (and the back
  button behavior below): no offline mode, no push, no file upload handling,
  no custom user agent, no splash screen config, etc.
- No Play Store–grade signing management (key export/import) in this version.

## Anti-goals

- Generated APKs that are huge (a Flutter runtime per generated app).
- Generated APKs that fail to install, or that collide with each other because
  they share a package ID.
- Keeping v1 code around on `master`.

## Constraints

- Repository: v2 **replaces** the contents of `master` in this repo
  (`devilAPI/web2apk`). v1 is preserved on a `legacy` branch before removal.
- Local toolchain available: Flutter 3.47.5 stable, Java on PATH.
- Generator minimum Android version: **7.0 (API 24)** — builder's call,
  approved list below.
- Credit line "Made by devilAPI with <3 / https://github.com/devilAPI/web2apk"
  from v1 should be preserved somewhere visible in the generator (e.g. an About
  entry) and as a source comment.

## How it works (decided)

### Template APK

- A tiny native Android WebView app ("template"), written in **Java** (or
  Kotlin without the stdlib bloat — builder's call, Java preferred for size),
  no AndroidX/AppCompat, built once at dev/CI time with gradle.
- The prebuilt template APK is bundled as an **asset** in the generator.
- Template behavior:
  - Single Activity with a WebView filling the content area, JS enabled,
    DOM storage enabled, links stay inside the WebView.
  - Title bar (ActionBar/Toolbar from the platform theme) showing the app name
    in the chosen color, unless fullscreen is on.
  - Status bar visible in both modes.
  - **Back button**: navigates WebView history; exits only when there is no
    history left. (Change vs. v1, which closed the app. Approved as the
    builder's call — see list.)
  - Reads its runtime config (URL, color, fullscreen, title) from a file in
    its own `assets/` (e.g. `assets/config.json`).

### Generation pipeline (on device)

1. Copy template APK from generator assets.
2. Write `assets/config.json` with URL, color, fullscreen, app name.
3. Patch **package name** and **app label** into the binary
   `AndroidManifest.xml` (and/or `resources.arsc`) — Android binary XML editing.
4. Replace launcher icon resources with the user's image, resized to the
   required densities.
5. Zip-align and **sign** (APK Signature Scheme v2, plus v1 if needed for
   compatibility with API 24).
6. Hand result to Install / Save / Share.

Where steps 3–5 run (pure Dart vs. Kotlin in the generator's Android side via
a platform channel, e.g. using Google's `apksig` library) is the builder's
call. **Steps 3–5 are the main technical risk and must be proven with a
spike before building the generator UI.**

### Package ID

- Auto-derived from the URL's domain, reversed, with a fixed suffix:
  `https://example.org` → `org.example.web2apk`. Sanitized to a valid Java
  package name.
- Always shown in the form as a small line under the fields
  ("Package: org.example.web2apk — tap to change") so users notice it and
  can make it unique. `www.` is stripped; other subdomains are kept.
- Known limitation: two apps from the same domain get the same default ID and
  the second replaces the first unless the user changes it. No detection of
  already-installed packages (would need `QUERY_ALL_PACKAGES`).

### Signing key

- Generated on the generator's first run, stored in app-private storage, reused
  for every generated APK, so regenerated apps update in place.
- Not exportable in this version (known limitation: uninstalling the generator
  loses the key; future updates of previously generated apps then require
  uninstalling them first).

## Distribution (decided)

- The generator is distributed via **GitHub Releases**, built by a
  **GitHub Actions** workflow (user decision). Not on the Play Store, which
  restricts `REQUEST_INSTALL_PACKAGES` and would block the Install action.
- Release APK signed with the owner's **release keystore stored as GitHub repo
  secrets**. That key and the application ID must never change after the first
  release; otherwise users must uninstall the generator, losing the generated
  apps' signing key.
- Generator application ID: **`de.devilapi.web2apk`**.
- The workflow also builds the template APK and bundles it into the generator.
- The plan must include instructions for the owner to create the keystore and
  add the secrets.

## Git / repository (decided)

- Builder creates a `legacy` branch from current `master` and replaces
  `master`'s contents with v2 **locally**. Nothing is pushed to the remote
  without the owner's explicit go-ahead.

## Builder's calls (made by the designer, user may veto)

- Template is plain Java/Android, not Flutter (user hinted at this).
- Package ID derived from domain, always visible and editable in the form.
- Generator application ID `de.devilapi.web2apk`.
- Local-only git rewrite; push only on the owner's go-ahead.
- One persistent signing key per generator install.
- Back button navigates web history before exiting.
- Minimum Android 7.0 for the generator (and the generated apps).
- Default color when none is picked: blue (v1's default).

## Left to the builder

- Generator UI layout and visual design (Material 3, single screen is fine).
- Color picker widget, icon cropping/resizing approach.
- Exact config file format inside the template.
- Dart vs. platform-channel split for manifest patching and signing; library
  choices.
- How the template APK gets built and copied into generator assets (gradle
  task, script, CI).
- README rewrite for v2.
- Testing strategy, with at minimum: a generated APK installs and launches on
  an emulator/device, shows the right URL, name, icon, color, and fullscreen
  behavior; two generated apps with different domains coexist; regenerating
  updates in place.
