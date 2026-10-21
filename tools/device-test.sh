#!/usr/bin/env bash
# Installs the game on a connected Android device, plays a scripted session
# through adb taps and swipes, and collects what is needed to judge it:
# screenshots, the full log, frame statistics (PerfLog's PERF lines), errors
# and crashes. Everything goes to build/device-test/<timestamp>/, with a
# summary.md on top. See docs/DEVICE_TESTING.md.
#
# Usage: tools/device-test.sh [path/to/game.apk]
#   The APK defaults to build/android/ashenbound-debug.apk; it must be a debug
#   build, since only those print PERF lines.
#   ANDROID_SERIAL   picks the device when several are connected.
#   SAFE_LEFT/SAFE_RIGHT  screen pixels the HUD is inset by on a phone with a
#                    camera cutout (default 0). Check the first screenshot.
#   SOAK_SECONDS     length of the final walk-around for frame statistics
#                    (default 40).
#
# Exit code: 0 when the game ran to the end without crashing, 1 otherwise.
# Logged errors are listed in the summary but do not fail the run.
set -euo pipefail

PACKAGE="com.ashenbound.game"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APK="${1:-$ROOT_DIR/build/android/ashenbound-debug.apk}"
OUT="$ROOT_DIR/build/device-test/$(date +%Y%m%d-%H%M%S)"
SAFE_LEFT="${SAFE_LEFT:-0}"
SAFE_RIGHT="${SAFE_RIGHT:-0}"
SOAK_SECONDS="${SOAK_SECONDS:-40}"

# The HUD is laid out on a 1280×720 canvas, stretched with "expand": the
# canvas scales by the smaller of the two ratios and grows along the other
# axis. Control positions below are canvas units from a screen corner; they
# match ui/hud/hud.tscn.
CANVAS_W=1280
CANVAS_H=720
JOYSTICK=(280 210)    # From the bottom-left corner: middle of the stick zone.
ATTACK=(158 158)      # From the bottom-right corner.
DODGE=(373 158)
CLEAVE=(334 281)
GUARD=(232 360)
BRAND=(102 366)
PAUSE=(80 72)         # From the top-right corner.

fail() { echo "device-test: $*" >&2; exit 1; }

command -v adb > /dev/null || fail "adb not found. Install Android platform-tools (docs/DEVICE_TESTING.md)."
[[ -s "$APK" ]] || fail "no APK at $APK. Pass a path, or export one with tools/export-android-debug.sh."
[[ "$(adb get-state 2> /dev/null || true)" == "device" ]] \
	|| fail "no authorized device. Run 'adb devices': the phone must be listed as 'device' (accept the USB debugging prompt on the phone)."

mkdir -p "$OUT"
QUIET=0  # During the soak, steps go to steps.txt only.
step() {
	local line
	line="$(date +%H:%M:%S)  $*"
	echo "$line" >> "$OUT/steps.txt"
	(( QUIET )) || echo "$line"
}
prop() { adb shell getprop "$1" | tr -d '\r'; }

# --- Device ------------------------------------------------------------------
ABIS="$(prop ro.product.cpu.abilist)"
[[ "$ABIS" == *arm64-v8a* ]] || fail "this device does not run 64-bit ARM apps (ABIs: $ABIS); the APK is arm64-v8a only."
SIZE="$(adb shell wm size | tr -d '\r' | awk -F': ' '/Override size/ {o=$2} /Physical size/ {p=$2} END {print (o != "" ? o : p)}')"
SIZE_A="${SIZE%x*}"
SIZE_B="${SIZE#*x}"
# Landscape: the long side is the width.
SCREEN_W=$(( SIZE_A > SIZE_B ? SIZE_A : SIZE_B ))
SCREEN_H=$(( SIZE_A > SIZE_B ? SIZE_B : SIZE_A ))
SCALE="$(awk -v w="$SCREEN_W" -v h="$SCREEN_H" -v cw="$CANVAS_W" -v ch="$CANVAS_H" \
	'BEGIN { s = w / cw; if (h / ch < s) s = h / ch; printf "%.4f", s }')"
REFRESH="$(adb shell dumpsys display | tr -d '\r' | grep -o -m1 'refreshRate=[0-9.]*' || true)"
{
	echo "model: $(prop ro.product.manufacturer) $(prop ro.product.model)"
	echo "android: $(prop ro.build.version.release) (SDK $(prop ro.build.version.sdk))"
	echo "abis: $ABIS"
	echo "screen: ${SCREEN_W}x${SCREEN_H} px, density $(adb shell wm density | tr -d '\r' | awk -F': ' '{d=$2} END {print d}') dpi, ${REFRESH:-refreshRate unknown}"
	echo "hud scale: $SCALE screen px per canvas unit; safe insets left $SAFE_LEFT, right $SAFE_RIGHT"
	echo "apk: $APK"
} > "$OUT/device.txt"
step "device: $(head -1 "$OUT/device.txt" | cut -d' ' -f2-)"

# Screen position of a HUD control, from canvas units off a corner.
from_bottom_left() { awk -v x="$1" -v y="$2" -v s="$SCALE" -v l="$SAFE_LEFT" -v h="$SCREEN_H" \
	'BEGIN { printf "%d %d", l + x * s, h - y * s }'; }
from_bottom_right() { awk -v x="$1" -v y="$2" -v s="$SCALE" -v r="$SAFE_RIGHT" -v w="$SCREEN_W" -v h="$SCREEN_H" \
	'BEGIN { printf "%d %d", w - r - x * s, h - y * s }'; }
from_top_right() { awk -v x="$1" -v y="$2" -v s="$SCALE" -v r="$SAFE_RIGHT" -v w="$SCREEN_W" \
	'BEGIN { printf "%d %d", w - r - x * s, y * s }'; }

tap() {  # tap NAME X Y
	step "tap $1"
	adb shell input tap $2 $3
}
# Holds the stick for `ms` milliseconds, pushed `dx`,`dy` canvas units from
# its centre (screen axes: +x right, +y down).
stick() {  # stick DX DY MS LABEL
	local from to
	from="$(from_bottom_left "${JOYSTICK[0]}" "${JOYSTICK[1]}")"
	to="$(from_bottom_left $(( JOYSTICK[0] + $1 )) $(( JOYSTICK[1] - $2 )))"
	step "stick $4 for $3 ms"
	adb shell input swipe $from $to "$3"
}
shot() {
	adb exec-out screencap -p > "$OUT/$1.png"
	step "screenshot $1.png"
}
running() { [[ -n "$(adb shell pidof "$PACKAGE" | tr -d '\r')" ]]; }

# --- Install and launch ------------------------------------------------------
step "installing $(basename "$APK")"
if ! adb install -r "$APK" > "$OUT/install.txt" 2>&1; then
	cat "$OUT/install.txt" >&2
	fail "install failed. If it says INSTALL_FAILED_UPDATE_INCOMPATIBLE, a build signed with another key is installed: adb uninstall $PACKAGE"
fi
adb shell am force-stop "$PACKAGE"
adb logcat -c
adb logcat -v time > "$OUT/logcat.txt" 2>&1 &
LOGCAT_PID=$!
trap 'kill $LOGCAT_PID 2> /dev/null || true' EXIT

step "launching"
adb shell monkey -p "$PACKAGE" -c android.intent.category.LAUNCHER 1 > /dev/null
for _ in $(seq 1 30); do
	grep -q "PERF fps=" "$OUT/logcat.txt" 2> /dev/null && break
	grep -q "Godot Engine" "$OUT/logcat.txt" 2> /dev/null && running && break
	sleep 1
done
running || fail "the game is not running after launch; see $OUT/logcat.txt"
sleep 4  # Scene load.
STARTED=$(date +%s)
shot 01-start

# --- Scripted session --------------------------------------------------------
read -r AX AY <<< "$(from_bottom_right "${ATTACK[@]}")"
read -r DX DY <<< "$(from_bottom_right "${DODGE[@]}")"
read -r CX CY <<< "$(from_bottom_right "${CLEAVE[@]}")"
read -r GX GY <<< "$(from_bottom_right "${GUARD[@]}")"
read -r BX BY <<< "$(from_bottom_right "${BRAND[@]}")"
read -r PX PY <<< "$(from_top_right "${PAUSE[@]}")"

stick 120 0 1500 right
stick 0 -120 2500 up
shot 02-moved
for _ in 1 2 3 4; do tap attack "$AX" "$AY"; sleep 0.35; done
shot 03-attack
tap dodge "$DX" "$DY"
sleep 0.1
shot 04-dodge
sleep 1
tap cleave "$CX" "$CY"
sleep 0.25
shot 05-cleave
sleep 1
tap guard "$GX" "$GY"
sleep 0.2
shot 06-guard
sleep 1.5
tap brand "$BX" "$BY"
sleep 1
shot 07-brand

tap pause "$PX" "$PY"
sleep 1
shot 08-paused
step "key BACK (resume)"
adb shell input keyevent KEYCODE_BACK
sleep 1
shot 09-resumed

step "key HOME (app to background)"
adb shell input keyevent KEYCODE_HOME
sleep 2
step "relaunching"
adb shell monkey -p "$PACKAGE" -c android.intent.category.LAUNCHER 1 > /dev/null
sleep 2
shot 10-after-home
step "key BACK (resume)"
adb shell input keyevent KEYCODE_BACK
sleep 1

step "soak: walking a square, attacking at each corner, for about ${SOAK_SECONDS} s"
SOAK_END=$(( $(date +%s) + SOAK_SECONDS ))
QUIET=1
while (( $(date +%s) < SOAK_END )); do
	stick 120 0 2000 right
	tap attack "$AX" "$AY"
	stick 0 -120 2000 up
	tap cleave "$CX" "$CY"
	stick -120 0 2000 left
	tap attack "$AX" "$AY"
	stick 0 120 2000 down
	tap dodge "$DX" "$DY"
	running || break
done
QUIET=0
shot 11-end
ENDED=$(date +%s)
sleep 6  # One more PerfLog interval.
kill $LOGCAT_PID 2> /dev/null || true

# --- Results -----------------------------------------------------------------
CRASHED=no
running || CRASHED=yes
grep -E "PERF fps=" "$OUT/logcat.txt" | sed 's/.*PERF /PERF /' > "$OUT/perf.txt" || true
grep -E "E/godot|SCRIPT ERROR|FATAL EXCEPTION|AndroidRuntime.*FATAL|Fatal signal" "$OUT/logcat.txt" > "$OUT/errors.txt" || true
PERF_STATS="$(awk '{
		for (i = 1; i <= NF; i++) { split($i, kv, "="); v[kv[1]] = kv[2] }
		n++; sum += v["fps"]
		if (n == 1 || v["fps"] < low) low = v["fps"]
		if (v["worst_ms"] > worst) worst = v["worst_ms"]
		if (v["draw_calls"] > draws) draws = v["draw_calls"]
		mem = v["static_mb"]
	} END {
		if (n == 0) { print "no PERF lines (is this a debug build?)"; exit }
		printf "%d samples: average %.1f FPS, lowest 5 s average %.1f FPS, slowest frame %.1f ms, up to %d draw calls, %.1f MB static memory at the end", n, sum / n, low, worst, draws, mem
	}' "$OUT/perf.txt")"

{
	echo "# Device test $(basename "$OUT")"
	echo
	sed 's/^/- /' "$OUT/device.txt"
	echo
	echo "- **Ran for:** $(( ENDED - STARTED )) s of scripted play"
	echo "- **Crashed:** $CRASHED"
	echo "- **Frame statistics:** $PERF_STATS"
	echo "- **Logged errors:** $(wc -l < "$OUT/errors.txt" | tr -d ' ') (see errors.txt)"
	echo
	echo "Screenshots:"
	for png in "$OUT"/*.png; do echo "- $(basename "$png")"; done
	echo
	echo "Files: steps.txt (what was done when), perf.txt, errors.txt, logcat.txt (everything)."
} > "$OUT/summary.md"

cat "$OUT/summary.md"
echo
echo "Results: $OUT"
[[ "$CRASHED" == no ]]
