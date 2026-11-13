#!/usr/bin/env bash
# Builds the web version into build/web.  Run from anywhere:  bash tools/build_web.sh
#
# 1. trims the typeface to the characters the game's text uses now (tools/subset_font.py)
# 2. re-imports, so the trimmed font and any changed assets are picked up
# 3. exports the "Web" preset, on the trimmed engine in tools/engine (see tools/build_engine.sh)
# 4. puts the stage music and the long scrolls beside it, to be fetched after the title, and lists
#    them for the service worker, so the game opens offline once it has been played
# 5. compiles the board generator to WebAssembly beside it (tools/genweb)
#
# Needs Godot 4.7 with the web export templates, Python with fonttools, and the .NET 10 SDK with
# the wasm-tools workload (dotnet workload install wasm-tools). Set GODOT or PYTHON if they are
# not on PATH as `godot` and `python`. SKIP_GEN=1 builds without the generator: the unmapped road
# then draws from its shelf of boards only.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
if ! command -v "$GODOT" >/dev/null 2>&1; then
	found="$(ls "${LOCALAPPDATA:-}"/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_*/Godot_v*_console.exe 2>/dev/null | head -1 || true)"
	if [ -n "$found" ]; then GODOT="$found"; else echo "Godot not found; set GODOT." >&2; exit 1; fi
fi

PYTHONIOENCODING=utf-8 "${PYTHON:-python}" tools/subset_font.py
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true   # exits non-zero on warnings alone
rm -rf build/web
mkdir -p build/web
"$GODOT" --headless --path . --export-release "Web" build/web/index.html 2>&1 | { grep -E "^ERROR" || true; }
if [ ! -s build/web/index.pck ] || [ ! -s build/web/index.wasm ]; then
	echo "The web export failed: is the Web export template installed?" >&2
	exit 1
fi

# the stage music is left out of the pck (see the Web preset's exclude filter) and fetched once the
# title is up: scripts/main.gd, _fetch_music
mkdir -p build/web/music build/web/art
for n in battle boss boss2 road2 road3 zen; do cp "audio/$n.ogg" build/web/music/; done
# so are the two long scrolls, as WebP (the trimmed engine reads WebP, not JPEG)
"${PYTHON:-python}" - <<'EOF'
from PIL import Image
for n in ('sesshu_0', 'sesshu_1', 'hyakki_0', 'hyakki_1'):
    Image.open('art/%s.jpg' % n).save('build/web/art/%s.webp' % n, quality=82, method=6)
EOF

# offline: the service worker keeps what it is told to (see tools/web_sw.py)
"${PYTHON:-python}" tools/web_sw.py build/web

if [ "${SKIP_GEN:-0}" != 1 ]; then
	if ! command -v dotnet >/dev/null 2>&1 || ! dotnet workload list 2>/dev/null | grep -q wasm-tools; then
		echo "dotnet with the wasm-tools workload not found; install it or set SKIP_GEN=1." >&2
		exit 1
	fi
	rm -rf tools/genweb/bin/Release
	dotnet publish -c Release tools/genweb 2>&1 | { grep -E " error " || true; }
	pub="$(ls -d tools/genweb/bin/Release/net*/publish/wwwroot 2>/dev/null | head -1 || true)"
	if [ -z "$pub" ] || [ ! -f "$pub/worker.js" ]; then
		echo "The generator did not build." >&2
		exit 1
	fi
	OUT="$PWD/build/web/gen"
	mkdir -p "$OUT"
	(cd "$pub" && find . -type f ! -name "*.br" ! -name "*.gz" -exec cp --parents {} "$OUT/" \;)
	du -sh build/web/gen | awk '{print $1 "  build/web/gen (the generator)"}'
fi
ls -la build/web/index.pck build/web/index.wasm | awk '{printf "%.1f MB  %s\n", $5 / 1e6, $9}'
