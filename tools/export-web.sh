#!/usr/bin/env bash
# Exports the browser build to build/web/ for playtesting on a phone without
# installing anything (docs/WEB_PREVIEW.md). Uses the "Web preview" preset
# (release template, single-threaded, so it needs no special server headers)
# and adds a rotate hint and a fullscreen button to the generated page.
# Usage: tools/export-web.sh   (uses `godot` from PATH, or $GODOT)
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT_DIR/build/web"

rm -rf "$OUT"
mkdir -p "$OUT"
"$GODOT" --headless --path "$ROOT_DIR/game" --import
"$GODOT" --headless --path "$ROOT_DIR/game" --export-release "Web preview" "$OUT/index.html"

for file in index.html index.js index.pck index.wasm; do
	[[ -s "$OUT/$file" ]] || { echo "Export failed: $OUT/$file is missing or empty." >&2; exit 1; }
done
# The exported data must still hold what the game needs (see the script).
"$GODOT" --headless --main-pack "$OUT/index.pck" --script "$ROOT_DIR/tools/check_export.gd"

python3 - "$OUT/index.html" "$ROOT_DIR/tools/web/preview_overlay.html" <<'PY'
import sys
page_path, overlay_path = sys.argv[1], sys.argv[2]
page = open(page_path, encoding="utf-8").read()
overlay = open(overlay_path, encoding="utf-8").read()
if "</body>" not in page:
    sys.exit("index.html has no </body>; the overlay was not added")
open(page_path, "w", encoding="utf-8").write(page.replace("</body>", overlay + "</body>", 1))
PY
# GitHub Pages would otherwise run the folder through Jekyll.
touch "$OUT/.nojekyll"
echo "Web build: $OUT/index.html"
du -sh "$OUT"
