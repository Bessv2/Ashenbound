#!/usr/bin/env bash
# Imports the project and runs the headless test suite.
# Usage: tools/test.sh            (uses `godot` from PATH, or $GODOT)
set -euo pipefail

GODOT="${GODOT:-godot}"
PROJECT_DIR="$(cd "$(dirname "$0")/../game" && pwd)"

# Import first so a fresh clone has its class cache and imported assets.
"$GODOT" --headless --path "$PROJECT_DIR" --import
"$GODOT" --headless --path "$PROJECT_DIR" --fixed-fps 60 --script res://tests/run_tests.gd
