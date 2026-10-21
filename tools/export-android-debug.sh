#!/usr/bin/env bash
# Exports a debug APK to build/android/ashenbound-debug.apk and verifies its
# signature. See docs/BUILD_ANDROID.md for the one-time toolchain setup.
# Usage: tools/export-android-debug.sh   (uses `godot` from PATH, or $GODOT)
#   PRESET=<name> exports another preset instead of "Android" and APK=<path>
#   says where it lands, e.g. the x86_64 build for the CI emulator:
#   PRESET="Android x86_64 (CI emulator)" APK=build/android/ashenbound-debug-x86_64.apk
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PRESET="${PRESET:-Android}"
APK="${APK:-$ROOT_DIR/build/android/ashenbound-debug.apk}"

mkdir -p "$(dirname "$APK")"
"$GODOT" --headless --path "$ROOT_DIR/game" --import
"$GODOT" --headless --path "$ROOT_DIR/game" --export-debug "$PRESET" "$APK"

# Godot exits non-zero on export errors (set -e stops above); this also guards
# against an empty output file.
if [[ ! -s "$APK" ]]; then
	echo "Export failed: $APK was not created." >&2
	exit 1
fi

if command -v apksigner > /dev/null; then
	apksigner verify --verbose "$APK"
else
	echo "apksigner not on PATH; skipped signature check." >&2
fi
echo "Debug APK: $APK"
