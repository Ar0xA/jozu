#!/usr/bin/env bash
# Builds the web version into build/web.  Run from anywhere:  bash tools/build_web.sh
#
# 1. trims the typeface to the characters the game's text uses now (tools/subset_font.py)
# 2. re-imports, so the trimmed font and any changed assets are picked up
# 3. exports the "Web" preset
#
# Set GODOT to the Godot 4 console executable if it is not on PATH as `godot`.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
if ! command -v "$GODOT" >/dev/null 2>&1; then
	found="$(ls "$LOCALAPPDATA"/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_*/Godot_v*_console.exe 2>/dev/null | head -1 || true)"
	if [ -n "$found" ]; then GODOT="$found"; else echo "Godot not found; set GODOT." >&2; exit 1; fi
fi

PYTHONIOENCODING=utf-8 python tools/subset_font.py
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
rm -rf build/web
mkdir -p build/web
"$GODOT" --headless --path . --export-release "Web" build/web/index.html 2>&1 | grep -E "^ERROR" || true
ls -la build/web/index.pck build/web/index.wasm | awk '{printf "%.1f MB  %s\n", $5 / 1e6, $9}'
