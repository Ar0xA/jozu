#!/usr/bin/env bash
# Compiles the web engine Jozu ships with: Godot built without the parts the game never uses (3D,
# physics, navigation, XR, the advanced GUI nodes, and every module but GDScript, text, Ogg Vorbis
# and WebP). The result is about half the size of the stock web template.
#
#   bash tools/build_engine.sh <godot source dir>
#
# The source must be the same version as the editor that exports the game (4.7.2-stable), and
# Emscripten 4.0.20 must be active (emsdk_env) with SCons installed. It writes
# tools/engine/web_nothreads_release.zip, which the Web export preset uses as its custom template.
# This only needs running again when the engine version changes.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
src="${1:?give the Godot source directory}"
cd "$src"
"${PYTHON:-python}" -m SCons platform=web target=template_release threads=no production=yes \
	optimize=size lto=full deprecated=no \
	disable_3d=yes disable_advanced_gui=yes disable_xr=yes \
	disable_physics_2d=yes disable_physics_3d=yes disable_navigation_2d=yes disable_navigation_3d=yes \
	modules_enabled_by_default=no module_gdscript_enabled=yes module_freetype_enabled=yes \
	module_text_server_adv_enabled=yes module_ogg_enabled=yes module_vorbis_enabled=yes module_webp_enabled=yes \
	-j"$(nproc 2>/dev/null || echo 4)"
mkdir -p "$here/engine"
cp bin/godot.web.template_release.wasm32.nothreads.zip "$here/engine/web_nothreads_release.zip"
ls -la "$here/engine/web_nothreads_release.zip"
