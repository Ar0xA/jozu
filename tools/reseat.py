"""For a stage no small change makes narrow enough (tools/tighten.py): another board takes its place.

    JOZU_ONLY=98,206 python tools/reseat.py      (then: python tools/build_levels.py)

The new board is one the generator made for the same chapter and the road never used: the same
techniques, the same rules, the same number of strokes to mastery (or the nearest there is), few
enough ways for where the stage stands, and every technique it grants needed. Of those, the one
with the most ways the allowance lets through. It goes in through tools/swaps.json, as a
tightened board does, so what a player earned on the old one stays at the station.
"""
import json, os, re, subprocess, sys, tempfile

sys.stdout.reconfigure(encoding='utf-8')
here = os.path.dirname(os.path.abspath(__file__))
GEN = os.path.join(here, 'gen', 'bin', 'Release', 'net8.0', 'gen.exe')
ALLOW = [[0, 12, 8], [2, 10, 5], [5, 8, 4], [10, 6, 3]]   # as in tools/tighten.py

def load(nm, default=None):
    p = os.path.join(here, nm)
    return json.load(open(p, encoding='utf-8')) if os.path.exists(p) else default

_s = open(os.path.join(here, '..', 'scripts', 'data.gd'), encoding='utf-8').read()
lv = []
for b in _s[_s.index('const LEVELS'):].split('\n\t{\n')[1:]:
    lv.append({'rows': re.findall(r'"(.*?)"', re.search(r'"rows": \[(.*?)\]', b, re.S).group(1)),
               'par': int(re.search(r'"par": (\d+)', b).group(1)),
               'waza': json.loads(re.search(r'"waza": (\[.*?\])', b).group(1)),
               'rules': json.loads(re.search(r'"rules": (\[.*?\])', b).group(1)),
               'ink': int(re.search(r'"ink": (\d+)', b).group(1)),
               'name': re.search(r'"name": "(.*?)"', b).group(1)})
STARTS = [int(x) for x in re.findall(r'^	\{"kanji".*?"from": (\d+)', _s, re.M)]

def want(i):
    c = max(k for k in range(len(STARTS)) if STARTS[k] <= i)
    end = STARTS[c + 1] if c + 1 < len(STARTS) else len(lv)
    p = (i - STARTS[c]) / max(1, end - STARTS[c] - 1)
    hi, lo = [(a[1], a[2]) for a in ALLOW if a[0] <= c][-1]
    return int(round(hi + (lo - hi) * p))

def solve(jobs):
    if not jobs:
        return {}
    with tempfile.TemporaryDirectory() as tmp:
        a, z = os.path.join(tmp, 'in.json'), os.path.join(tmp, 'out.json')
        json.dump(jobs, open(a, 'w', encoding='utf-8'))
        subprocess.run([GEN, 'solve', a, z], check=True, stdout=subprocess.DEVNULL)
        return {r['name']: r for r in json.load(open(z, encoding='utf-8'))}

key = lambda rows: ''.join(rows)
swaps = load('swaps.json', [])
retired = load('retired.json', {})
made = load('generated.json', []) + load('pool.json', [])
chapter_of = {key(g['rows']): g['chapter'] for g in made}
by_new = {key(b['rows']): b for b in swaps}
was = {new: old for old, new in retired.items()}

def chapter(k):
    """The generator's chapter a board on the road came from, through whatever it replaced."""
    seen = set()
    while k not in chapter_of and k not in seen:
        seen.add(k)
        k = by_new[k]['replaces'] if k in by_new and by_new[k]['replaces'] not in seen else was.get(k, k)
    return chapter_of.get(k, -1)

# boards already spoken for: the road, the koan, the temples, and everything a swap has touched
_x = open(os.path.join(here, '..', 'scripts', 'extra.gd'), encoding='utf-8').read()
taken = {key(l['rows']) for l in lv} | set(by_new) | {b['replaces'] for b in swaps} | set(retired) | set(load('extra_swaps.json', {}))
for nm in ('DAILY', 'HENRO'):
    body = _x[_x.index('const %s = [' % nm):]
    taken |= {key(json.loads(l.strip().rstrip(','))['rows']) for l in body[body.index('\n') + 1:body.index('\n]')].split('\n') if l.strip()}

only = [int(x) - 1 for x in os.environ.get('JOZU_ONLY', '').split(',') if x]
jobs, cands = [], {}
for i in only:
    c = chapter(key(lv[i]['rows']))
    fit = [g for g in made if g['chapter'] == c and key(g['rows']) not in taken and sorted(g['waza']) == sorted(lv[i]['waza'])
           and (g.get('rules') or []) == lv[i]['rules'] and 1 <= g.get('ways', 99) <= want(i) and g['par'] > 0]
    near = min([abs(g['par'] - lv[i]['par']) for g in fit] or [0])
    cands[i] = [g for g in fit if abs(g['par'] - lv[i]['par']) == near]
    for k, g in enumerate(cands[i]):
        b = {'rows': g['rows'], 'rules': g.get('rules') or [], 'ink': g.get('ink') or 4}
        jobs.append(dict(b, name='%d|%d|all' % (i, k), waza=g['waza']))
        for w in g['waza']:
            jobs.append(dict(b, name='%d|%d|%s' % (i, k, w), waza=[x for x in g['waza'] if x != w]))
res = solve(jobs)
for i in only:
    best = None
    for k, g in enumerate(cands[i]):
        r = res['%d|%d|all' % (i, k)]
        if r['trace'] == 'CAPPED' or r['par'] != g['par'] or not 1 <= r['ways'] <= want(i) or key(g['rows']) in taken:
            continue
        if any(res['%d|%d|%s' % (i, k, w)]['trace'] == 'CAPPED' or 0 < res['%d|%d|%s' % (i, k, w)]['par'] <= g['par'] for w in g['waza']):
            continue
        if best is None or r['ways'] > best[0]:
            best = (r['ways'], g, r['trace'])
    if not best:
        print('stage %3d  %-18s nothing to put in its place (%d looked at)' % (i + 1, lv[i]['name'][:18], len(cands[i])))
        continue
    g = best[1]
    old, new = key(lv[i]['rows']), key(g['rows'])
    taken.add(new)
    if old in by_new:
        e = by_new[old]
        e['rows'], e['trace'], e['par'], e['ink'] = g['rows'], best[2], g['par'], g.get('ink') or 4
        retired[old] = new
    else:
        swaps.append({'replaces': old, 'rows': g['rows'], 'waza': g['waza'], 'par': g['par'], 'trace': best[2],
                      'rules': g.get('rules') or [], 'ink': g.get('ink') or 4, 'chapter': -1})
    print('stage %3d  %-18s a new board: %d way%s (allowed %d), mastery in %d (was %d)' % (i + 1, lv[i]['name'][:18], best[0], '' if best[0] == 1 else 's', want(i), g['par'], lv[i]['par']))
json.dump(swaps, open(os.path.join(here, 'swaps.json'), 'w', encoding='utf-8', newline='\n'), ensure_ascii=False, indent=1)
json.dump(retired, open(os.path.join(here, 'retired.json'), 'w', encoding='utf-8', newline='\n'), ensure_ascii=False, indent=1)
