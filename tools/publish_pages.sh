#!/usr/bin/env bash
# Publishes Jozu to GitHub and GitHub Pages.  Run from anywhere:  bash tools/publish_pages.sh
#
# 1. creates the public repository (if it does not exist) and pushes the source
# 2. pushes the web build in build/web to the gh-pages branch
# 3. turns on GitHub Pages for that branch
#
# Needs the GitHub CLI signed in (gh auth status) and a web build:
#   godot --headless --path . --export-release "Web" build/web/index.html
set -euo pipefail
cd "$(dirname "$0")/.."

REPO="Ar0xA/jozu"
URL="https://github.com/$REPO.git"

if [ ! -f build/web/index.html ]; then
	echo "No web build found in build/web. Export it first (see the top of this script)." >&2
	exit 1
fi

if gh repo view "$REPO" >/dev/null 2>&1; then
	echo "Repository $REPO exists; pushing source."
	git remote get-url origin >/dev/null 2>&1 || git remote add origin "$URL"
	git push -u origin main
else
	echo "Creating public repository $REPO and pushing source."
	gh repo create "$REPO" --public --source . --remote origin --push \
		--description "Jozu 上手: a puzzle game of single brush strokes among the yokai of old Japan (Godot 4)"
fi

echo "Publishing the web build to the gh-pages branch."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp -r build/web/. "$tmp"
touch "$tmp/.nojekyll"
git -C "$tmp" init -q -b gh-pages
git -C "$tmp" add -A
git -C "$tmp" -c user.name="$(git config user.name)" -c user.email="$(git config user.email)" commit -q -m "Web build"
git -C "$tmp" push -q -f "$URL" gh-pages

echo "Turning on GitHub Pages."
gh api -X POST "repos/$REPO/pages" -f "source[branch]=gh-pages" -f "source[path]=/" >/dev/null 2>&1 \
	|| gh api -X PUT "repos/$REPO/pages" -f "source[branch]=gh-pages" -f "source[path]=/" >/dev/null 2>&1 \
	|| echo "Pages may already be on; check the repository's Settings > Pages."

echo
echo "Done. The game will be live in a minute or two at:"
echo "  https://ar0xa.github.io/jozu/"
