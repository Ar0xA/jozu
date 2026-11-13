"""Tells the web build's service worker to keep the music and the long scrolls too.

    python tools/web_sw.py build/web        (run by tools/build_web.sh)

Godot's worker keeps the page, the engine and the game data, so the game opens without a network
once it has been played. The files fetched after the title (music/, art/) are not in its list; this
adds them to the ones kept when first fetched. The board generator (gen/) is left out: it is only
fetched on the unmapped road, and a file in the list that was never fetched would send every visit
back to the network.
"""
import json, os, re, sys

web = sys.argv[1]
p = os.path.join(web, 'index.service.worker.js')
s = open(p, encoding='utf-8').read()
m = re.search(r'const CACHEABLE_FILES = (\[.*?\]);', s)
assert m, 'the service worker has no list of files to keep'
files = json.loads(m.group(1))
for d in ('music', 'art'):
    for n in sorted(os.listdir(os.path.join(web, d))):
        if d + '/' + n not in files:
            files.append(d + '/' + n)
s = s[:m.start(1)] + json.dumps(files) + s[m.end(1):]
open(p, 'w', encoding='utf-8', newline='\n').write(s)
print('service worker keeps %d files when fetched' % len(files))
