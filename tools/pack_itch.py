"""Packs the web build for itch.io: build/jozu-<version>-itch.zip, to upload as an HTML game.

    bash tools/build_web.sh        (first: the build this is made from)
    python tools/pack_itch.py

It is the web build as published, without the parts that make it an installable app: itch.io
shows the game inside its own page, where a service worker would only keep players on an old
build after an update. On itch.io: kind of project "HTML", tick "This file will be played in the
browser", viewport 1280 x 720, and turn on "Mobile friendly" and the fullscreen button.
"""
import os, re, shutil, sys, zipfile

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
web, out = os.path.join(root, 'build', 'web'), os.path.join(root, 'build', 'itch')
if not os.path.exists(os.path.join(web, 'index.html')):
    sys.exit('No web build: run tools/build_web.sh first.')
ver = re.search(r'config/version="(.*?)"', open(os.path.join(root, 'project.godot'), encoding='utf-8').read()).group(1)
shutil.rmtree(out, ignore_errors=True)
shutil.copytree(web, out)
for nm in ('index.service.worker.js', 'index.offline.html', 'index.manifest.json'):
    os.remove(os.path.join(out, nm))
p = os.path.join(out, 'index.html')
s = open(p, encoding='utf-8').read()
s, n1 = re.subn(r'"serviceWorker":"[^"]*",?', '', s)
s, n2 = re.subn(r'<link rel="manifest"[^>]*>\n?', '', s)
assert n1 == 1 and n2 == 1, 'the page is not laid out as expected'
open(p, 'w', encoding='utf-8', newline='\n').write(s)
z = os.path.join(root, 'build', 'jozu-%s-itch.zip' % ver)
files = 0
with zipfile.ZipFile(z, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
    for d, _, fs in os.walk(out):
        for f in fs:
            full = os.path.join(d, f)
            zf.write(full, os.path.relpath(full, out).replace(os.sep, '/'))
            files += 1
print('%s: %d files, %.1f MB' % (os.path.relpath(z, root), files, os.path.getsize(z) / 1e6))
