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
# the board generator, compiled to WebAssembly, sits beside the game (see tools/genweb)
if command -v dotnet >/dev/null 2>&1 && dotnet workload list 2>/dev/null | grep -q wasm-tools; then
	rm -rf tools/genweb/bin/Release/net10.0/publish
	dotnet publish -c Release tools/genweb 2>&1 | grep -E " error " || true
	OUT="$PWD/build/web/gen"
	mkdir -p "$OUT"
	(cd tools/genweb/bin/Release/net10.0/publish/wwwroot && find . -type f ! -name "*.br" ! -name "*.gz" -exec cp --parents {} "$OUT/" \;)
	du -sh build/web/gen | awk '{print $1 "  build/web/gen (the generator)"}'
else
	echo "dotnet with the wasm-tools workload not found: the unmapped road will use its shelf of boards only." >&2
fi
ls -la build/web/index.pck build/web/index.wasm | awk '{printf "%.1f MB  %s\n", $5 / 1e6, $9}'
