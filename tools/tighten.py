"""Makes mastery a narrow thing: a stage that can be mastered in many ways is changed a little
(a stone or a water tile added or taken away, a yokai moved one tile) until few ways are left.

    python tools/tighten.py count            how many ways each stage on the road can be mastered
    python tools/tighten.py [first last]     tighten the stages in that range (1-based; default all)
    (then: python tools/build_levels.py)

A stage is left alone if it is hand-made (it has a lesson or a story), if the solver cannot finish
it, or if it has no more ways than its place on the road allows (ALLOW). A change is kept only if the mastery count stays what
it was and every technique the stage grants is still needed for it. The new board takes the old
one's place through tools/swaps.json; what a player earned on the old board stays at the station
(tools/retired.json, for boards that had themselves replaced another).
"""
import json, os, re, subprocess, sys, tempfile

sys.stdout.reconfigure(encoding='utf-8')
here = os.path.dirname(os.path.abspath(__file__))
GEN = os.path.join(here, 'gen', 'bin', 'Release', 'net8.0', 'gen.exe')
# How many ways a stage may have, by where it stands: the road forgives at first and asks more
# later, and each chapter asks most of its last stage. [first chapter it applies to, ways allowed
# at a chapter's first stage, ways allowed at its last]
ALLOW = [[0, 12, 8], [2, 10, 5], [5, 8, 4], [10, 6, 3]]
ROUNDS = 3        # changes tried one after another on a stubborn board
FIXED = 'H'       # never moved

def levels():
    s = open(os.path.join(here, '..', 'scripts', 'data.gd'), encoding='utf-8').read()
    out = []
    for b in s[s.index('const LEVELS'):].split('\n\t{\n')[1:]:
        out.append({'rows': re.findall(r'"(.*?)"', re.search(r'"rows": \[(.*?)\]', b, re.S).group(1)),
                    'par': int(re.search(r'"par": (\d+)', b).group(1)),
                    'waza': json.loads(re.search(r'"waza": (\[.*?\])', b).group(1)),
                    'rules': json.loads(re.search(r'"rules": (\[.*?\])', b).group(1)),
                    'ink': int(re.search(r'"ink": (\d+)', b).group(1)),
                    'name': re.search(r'"name": "(.*?)"', b).group(1),
                    'plain': '"hint": ""' in b and '"story": []' in b})
    return out

def solve(jobs):
    if not jobs:
        return {}
    with tempfile.TemporaryDirectory() as tmp:
        a, z = os.path.join(tmp, 'in.json'), os.path.join(tmp, 'out.json')
        json.dump(jobs, open(a, 'w', encoding='utf-8'))
        subprocess.run([GEN, 'solve', a, z], check=True, stdout=subprocess.DEVNULL)
        return {r['name']: r for r in json.load(open(z, encoding='utf-8'))}

def job(name, lv, rows=None, waza=None):
    return {'name': name, 'rows': rows or lv['rows'], 'waza': lv['waza'] if waza is None else waza, 'rules': lv['rules'], 'ink': lv['ink']}

def changes(rows):
    """Every board one small change away: {joined rows: what was changed}."""
    H, W = len(rows), len(rows[0])
    grid = [list(r) for r in rows]
    out = {}
    def add(g, what):
        key = ''.join(''.join(r) for r in g)
        if key != ''.join(rows):
            out.setdefault(key, what)
    for y in range(H):
        for x in range(W):
            c = grid[y][x]
            if c in '.#~':
                for to in '.#~':
                    if to != c:
                        g = [r[:] for r in grid]
                        g[y][x] = to
                        add(g, '%s to %s at %d,%d' % (c, to, x + 1, y + 1))
            elif c.isalpha() and c not in FIXED and c.lower() not in 'imbwfgx':
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < W and 0 <= ny < H and grid[ny][nx] == '.':
                        g = [r[:] for r in grid]
                        g[ny][nx] = c
                        g[y][x] = '.'
                        add(g, '%s moved from %d,%d to %d,%d' % (c, x + 1, y + 1, nx + 1, ny + 1))
    return out

lv = levels()
_s = open(os.path.join(here, '..', 'scripts', 'data.gd'), encoding='utf-8').read()
STARTS = [int(x) for x in re.findall(r'^	\{"kanji".*?"from": (\d+)', _s, re.M)]

def want(i):
    c = max(k for k in range(len(STARTS)) if STARTS[k] <= i)
    end = STARTS[c + 1] if c + 1 < len(STARTS) else len(lv)
    p = (i - STARTS[c]) / max(1, end - STARTS[c] - 1)
    hi, lo = [(a[1], a[2]) for a in ALLOW if a[0] <= c][-1]
    return int(round(hi + (lo - hi) * p))
args = [a for a in sys.argv[1:] if a != 'count']
first = int(args[0]) if args else 1
last = int(args[1]) if len(args) > 1 else len(lv)
todo = [i for i in range(first - 1, last) if lv[i]['plain']]
base = solve([job(str(i), lv[i]) for i in todo])
ways = {}
for i in todo:
    r = base[str(i)]
    if r['trace'] != 'CAPPED' and r['par'] == lv[i]['par']:
        ways[i] = r['ways']
loose = [i for i in ways if ways[i] > want(i)]
print('%d stages looked at, %d decided by the solver, %d with more ways than their place allows' % (len(todo), len(ways), len(loose)))
if 'count' in sys.argv:
    hist = {}
    for i in ways:
        k = '1' if ways[i] <= 1 else '2-4' if ways[i] <= 4 else '5-20' if ways[i] <= 20 else '21-100' if ways[i] <= 100 else '100+'
        hist[k] = hist.get(k, 0) + 1
    print(hist)
    sys.exit()

sp, rp = os.path.join(here, 'swaps.json'), os.path.join(here, 'retired.json')
swaps = json.load(open(sp, encoding='utf-8'))
retired = json.load(open(rp, encoding='utf-8')) if os.path.exists(rp) else {}
by_new = {''.join(b['rows']): b for b in swaps}
taken = {''.join(l['rows']) for l in lv} | set(by_new)
now = {i: {'rows': lv[i]['rows'], 'ways': ways[i], 'trace': None, 'what': []} for i in loose}
for rnd in range(ROUNDS):
    work = [i for i in now if now[i]['ways'] > want(i)]
    if not work:
        break
    jobs, cands = [], {}
    for i in work:
        cands[i] = changes(now[i]['rows'])
        W = len(lv[i]['rows'][0])
        for k, key in enumerate(cands[i]):
            if key in taken:
                continue
            rr = [key[j * W:(j + 1) * W] for j in range(len(lv[i]['rows']))]
            jobs.append(job('%d|%d|all' % (i, k), lv[i], rr))
            for w in lv[i]['waza']:
                jobs.append(job('%d|%d|%s' % (i, k, w), lv[i], rr, [x for x in lv[i]['waza'] if x != w]))
    res = solve(jobs)
    better = 0
    for i in work:
        best = None
        W = len(lv[i]['rows'][0])
        for k, key in enumerate(cands[i]):
            r = res.get('%d|%d|all' % (i, k))
            if r is None or r['trace'] == 'CAPPED' or r['par'] != lv[i]['par'] or r['ways'] < 1:
                continue
            ok = True
            for w in lv[i]['waza']:
                q = res['%d|%d|%s' % (i, k, w)]
                if q['trace'] == 'CAPPED' or 0 < q['par'] <= lv[i]['par']:
                    ok = False
            # the change that comes nearest the allowance from below; failing that, the tightest found
            if ok and r['ways'] < now[i]['ways']:
                fits = r['ways'] <= want(i)
                if best is None or (fits and (not best[4] or r['ways'] > best[0])) or (not fits and not best[4] and r['ways'] < best[0]):
                    best = (r['ways'], key, r['trace'], cands[i][key], fits)
        if best:
            now[i] = {'rows': [best[1][j * W:(j + 1) * W] for j in range(len(lv[i]['rows']))], 'ways': best[0], 'trace': best[2], 'what': now[i]['what'] + [best[3]]}
            better += 1
    print('round %d: %d boards worked on, %d made tighter, %d boards solved' % (rnd + 1, len(work), better, len(jobs)))

changed = 0
for i in sorted(now):
    n = now[i]
    if n['trace'] is None:
        continue
    old = ''.join(lv[i]['rows'])
    new = ''.join(n['rows'])
    taken.add(new)
    if old in by_new:
        # the board being replaced had itself replaced another: that entry now leads to the new one
        e = by_new[old]
        e['rows'], e['trace'] = n['rows'], n['trace']
        retired[old] = new
    else:
        swaps.append({'replaces': old, 'rows': n['rows'], 'waza': lv[i]['waza'], 'par': lv[i]['par'], 'trace': n['trace'],
                      'rules': lv[i]['rules'], 'ink': lv[i]['ink'], 'chapter': -1})
    changed += 1
    print('stage %3d  %-18s %6d -> %-3d ways (allowed %d)   %s' % (i + 1, lv[i]['name'][:18], ways[i], n['ways'], want(i), '; '.join(n['what'])))
json.dump(swaps, open(sp, 'w', encoding='utf-8', newline='\n'), ensure_ascii=False, indent=1)
json.dump(retired, open(rp, 'w', encoding='utf-8', newline='\n'), ensure_ascii=False, indent=1)
left = [i + 1 for i in now if now[i]['ways'] > want(i)]
print('%d stages changed; %d still have more ways than allowed: %s' % (changed, len(left), left))
