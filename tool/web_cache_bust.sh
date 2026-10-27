#!/usr/bin/env bash
# Gives a built web app (build/web) per-build URLs, so browsers load a new
# deploy right away. GitHub Pages serves everything with a fixed 10 minute
# cache that cannot be changed; versioned URLs side-step it:
#   index.html          flutter_bootstrap.js -> flutter_bootstrap.js?v=<build>
#                       and its version check gets the build number
#   flutter_bootstrap.js main.dart.js       -> main.dart.js?v=<build>
# Usage: tool/web_cache_bust.sh <web build dir> <build number>
set -euo pipefail
dir="$1"
build="$2"
[[ "$build" =~ ^[0-9]+$ ]] || { echo "build number must be numeric: $build" >&2; exit 1; }

sed -i "s|src=\"flutter_bootstrap.js\"|src=\"flutter_bootstrap.js?v=${build}\"|" "$dir/index.html"
sed -i "s|__BUILD_NUMBER__|${build}|" "$dir/index.html"
sed -i "s|\"mainJsPath\":\"main.dart.js\"|\"mainJsPath\":\"main.dart.js?v=${build}\"|" "$dir/flutter_bootstrap.js"

# fail loudly if a Flutter update changed what is rewritten here
grep -q "flutter_bootstrap.js?v=${build}\"" "$dir/index.html"
grep -q "const build = '${build}'" "$dir/index.html"
grep -q "\"mainJsPath\":\"main.dart.js?v=${build}\"" "$dir/flutter_bootstrap.js"
echo "web build ${build}: versioned URLs set"
