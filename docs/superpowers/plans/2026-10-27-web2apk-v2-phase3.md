# web2apk v2 — Phase 3 (Saved apps + signing-key backup) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make updating generated apps reliable: remember every generated app so it can be regenerated with the same package ID in one tap, and let users back up / restore the signing key so updates survive reinstalling the generator, a new phone, or cleared browser data.

**Why (designer's call, owner delegated phase 3):** The two biggest ways phase 1–2 users lose the ability to update their apps are (a) re-typing settings and getting a different package ID, and (b) losing the per-install signing key (the spec's known limitation, worst on web). Phase 3 fixes both on the generator side only; the generated app is unchanged (spec non-goal: no new generated-app features).

**Architecture:** A `SavedApp` record list persisted in `shared_preferences` (works on all five platforms). A "My apps" page lists them and loads one back into the form. Key backup exports `SigningKey.toJson()` as a `.json` file through the existing save path; restore picks a file, validates with `SigningKey.fromJson`, confirms, and replaces the stored key.

**Tech Stack:** existing packages only.

**Spec:** `docs/superpowers/specs/2026-10-27-web2apk-v2-design.md` (Phase 3 section).

## Global Constraints

- All phase 1–2 Global Constraints apply.
- Saved apps prefs key: `saved_apps_v1` (JSON list). Upsert by `packageId`; newest first.
- Stored icon: the user's icon downscaled to a 192×192 PNG (keeps localStorage well under quota); regenerating uses this stored icon.
- Key backup file name: `web2apk-signing-key.json`; contents exactly `SigningKey.toJson()` plus `"format": "web2apk-signing-key-v1"`.
- Backup warning copy (shown before export): "Anyone with this file can publish updates to your apps. Keep it private."
- Restore warning copy: "This replaces your current signing key. Apps signed with the current key can then no longer be updated in place, unless you restore it again."
- Show the key's certificate SHA-256 fingerprint (uppercase hex, colon-separated) in the key dialog so users can tell keys apart; it must equal `apksigner verify --print-certs` "certificate SHA-256 digest" (case/colons aside).

## Review Focus

1. **Corrupt saved-apps value** → list treated as empty with an error SnackBar, value not overwritten until the user saves a new app. Task 1.
2. **Restoring a garbage/foreign JSON file** → clear error, current key untouched. Task 3.
3. **Same package ID generated twice** → one entry, updated, moved to top. Task 1.
4. **Large icon** (4000×4000) saved → stored PNG is 192×192. Task 1.
5. **Cancel at any confirm/save dialog** → nothing changes. Tasks 2–3.

---

### Task 1: SavedApp model and store

**Files:** Create: `lib/src/saved_apps.dart`, `test/saved_apps_test.dart`.

**Interfaces:**
- `class SavedApp { final String name; final String url; final int color; final bool fullscreen; final String packageId; final Uint8List? icon; final DateTime updatedAt; Map<String, dynamic> toJson(); factory SavedApp.fromJson(Map<String, dynamic>); AppSpec toSpec(); factory SavedApp.fromSpec(AppSpec spec, {DateTime? now}); }` — `fromSpec` downscales `icon` to 192×192 PNG via `package:image` (reuse cropping logic from `icons.dart` by extracting a shared `Uint8List squarePng(Uint8List source, int size)` there rather than duplicating).
- `class SavedAppsStore { SavedAppsStore(SharedPreferences prefs); List<SavedApp> load(); Future<void> upsert(SavedApp app); Future<void> remove(String packageId); }` — `load` throws `FormatException` on a corrupt value (caller shows error); `upsert`/`remove` on a corrupt stored value also throw and do not overwrite.

- [ ] **Step 1: Tests:** empty → `[]`; upsert two → newest first; upsert same packageId → one entry, updated fields, moved first; remove; JSON round-trip incl. icon bytes; `fromSpec` with 4000×4000 icon → stored icon decodes to 192×192; corrupt value → `load` throws `FormatException`, `upsert` throws and value preserved.
- [ ] **Step 2:** RED. **Step 3:** Implement. **Step 4:** GREEN (`flutter test test/saved_apps_test.dart test/apk/icons_test.dart`).
- [ ] **Step 5: Commit** `feat: saved apps store`.

---

### Task 2: "My apps" page and auto-save

**Files:** Create: `lib/src/ui/my_apps_page.dart`, `test/ui/my_apps_page_test.dart`; Modify: `lib/src/ui/generator_page.dart`, `lib/main.dart`, `test/ui/generator_page_test.dart`.

**Interfaces:**
- `GeneratorPage` gains `required SavedAppsStore savedApps` and an optional `SavedApp? initial` to prefill the form (package ID treated as manually set so it sticks).
- After a successful build, the generator upserts `SavedApp.fromSpec(spec)` before pushing `ResultPage`.
- `MyAppsPage({required SavedAppsStore store, required void Function(SavedApp) onOpen})` — list tiles: icon (or color swatch), name, package ID; tap → `onOpen` (generator fills form); trailing delete with confirm dialog.
- AppBar action "My apps" (icon `Icons.apps`) on the generator page.

- [ ] **Step 1: Tests:** generate once → store has one entry; open My apps → tile shows name + package; tap → form fields filled with that app, package line shows saved package even after URL edit; delete → confirm → removed; cancel → kept; corrupt store → SnackBar "Saved apps could not be read" and page shows empty state.
- [ ] **Step 2:** RED. **Step 3:** Implement. **Step 4:** full `flutter test` GREEN; `flutter build linux --debug` OK.
- [ ] **Step 5: Commit** `feat: My apps page with one-tap regenerate`.

---

### Task 3: Signing-key backup, restore, fingerprint

**Files:** Create: `lib/src/ui/key_page.dart`, `test/ui/key_page_test.dart`; Modify: `lib/src/apk/signing_key.dart` (add `String get certificateSha256` — uppercase hex with colons), `lib/src/key_store.dart` (add `Future<void> replaceSigningKey(SharedPreferences prefs, SigningKey key)`), `lib/src/apk_actions.dart` + implementations (generalize `save` to `Future<bool> saveFile(Uint8List bytes, String fileName, {String mimeType})`; `save` for APKs delegates to it), `lib/src/ui/generator_page.dart` (AppBar action "Signing key", icon `Icons.key`), tests.

**Interfaces:**
- `KeyPage({required Future<SigningKey> Function() loadKey, required Future<void> Function(SigningKey) replaceKey, required ApkActions actions, Future<Uint8List?> Function()? pickFile})` — shows fingerprint; "Back up key" → backup warning dialog → `saveFile(utf8(json), 'web2apk-signing-key.json', mimeType: 'application/json')`; "Restore key" → `pickFile` (default `FilePicker` with `withData: true`, `allowedExtensions: ['json']`) → parse: must have `format == 'web2apk-signing-key-v1'` and pass `SigningKey.fromJson`, else SnackBar "Not a valid web2apk key file" → restore warning dialog → `replaceKey` → SnackBar "Signing key restored".
- `generator_page` must re-load the key after a restore (don't cache a stale key).

- [ ] **Step 1: Tests:** `certificateSha256` equals apksigner's printed digest (VM, skip without SDK); backup writes JSON that round-trips through `SigningKey.fromJson` and has the format field; backup cancelled at warning → `saveFile` not called; restore garbage → error SnackBar, `replaceKey` not called; restore valid file → confirm → `replaceKey` called with matching modulus; restore cancelled at confirm → not called; generator uses restored key for the next build (fake key loader counts calls / returns new key).
- [ ] **Step 2:** RED. **Step 3:** Implement. **Step 4:** full `flutter test` GREEN; `flutter test --platform chrome` GREEN for browser-safe tests; `flutter build web` and `flutter build linux --debug` OK.
- [ ] **Step 5:** README section "Back up your signing key". **Commit** `feat: signing-key backup/restore and fingerprint`.
