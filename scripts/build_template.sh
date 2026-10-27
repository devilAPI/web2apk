#!/usr/bin/env bash
# Builds the Java WebView template and copies the unsigned APK to assets/template.apk.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root/template"
./gradlew --no-daemon assembleRelease
mkdir -p "$root/assets"
cp app/build/outputs/apk/release/app-release-unsigned.apk "$root/assets/template.apk"
