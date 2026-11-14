"""Mastery by grade, for the boards off the road: the daily koan and the 88 temples.

    python tools/tighten_extra.py count      how many ways each board can be mastered, by grade
    python tools/tighten_extra.py            tighten every board with more ways than its grade allows
    python tools/tighten_extra.py trade      a board still over changes places with one of a lower grade
    (then: python tools/build_levels.py)

Four grades, and how many ways to mastery each allows (GRADES). The daily koan is graded by its
weekday (Monday and Tuesday easy, Wednesday and Thursday normal, Friday and Saturday hard, Sunday
expert); a temple by its province (Awa easy, Tosa normal, Iyo hard, Sanuki expert).

A board with too many ways is changed a little, as tools/tighten.py does on the road: a stone or
a water tile added or taken away, a yokai moved one tile. A change is kept only if mastery asks
the same number of strokes, every technique the board grants is still needed, and (for the koan)
the board still suits the same season. The board keeps its place: tools/extra_swaps.json says
what each one became, and tools/build_levels.py puts it there.
"""
import json, os, subprocess, sys, tempfile

sys.stdout.reconfigure(encoding='utf-8')
here = os.path.dirname(os.path.abspath(__file__))
GEN = os.path.join(here, 'gen', 'bin', 'Release', 'net8.0', 'gen.exe')
GRADES = [['easy', 10], ['normal', 5], ['hard', 3], ['expert', 1]]
WEEKDAY = [0, 0, 1, 1, 2, 2, 3]          # the grade of each day's koan, Monday first
PROVINCE = [0, 23, 39, 65]               # the temple each province begins at (main.gd PROVINCES)
ROUNDS = 4
CHUNK = 3000
FIXED = 'H'

def consts():
    s = open(os.path.join(here, '..', 'scripts', 'extra.gd'), encoding='utf-8').read()
    out = {}
    for nm in ('DAILY', 'HENRO', 'RANDOM'):
        body = s[s.index('const %s = [' % nm):]
        body = body[body.index('\n') + 1:body.index('\n]')]
        out[nm] = [json.loads(l.strip().rstrip(',')) for l in body.split('\n') if l.strip()]
    return out

def solve(jobs):
    out = {}
    for a0 in range(0, len(jobs), CHUNK):
        with tempfile.TemporaryDirectory() as tmp:
            a, z = os.path.join(tmp, 'in.json'), os.path.join(tmp, 'out.json')
            json.dump(jobs[a0:a0 + CHUNK], open(a, 'w', encoding='utf-8'))
            subprocess.run([GEN, 'solve', a, z], check=True, stdout=subprocess.DEVNULL)
            for r in json.load(open(z, encoding='utf-8')):
                out[r['name']] = r
    return out

def job(name, b, rows=None, waza=None):
    return {'name': name, 'rows': rows or b['rows'], 'waza': b['waza'] if waza is None else waza, 'rules': b['rules'], 'ink': b['ink']}

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

def season(key):
    """What main.gd's _in_season looks at: a changed koan must still suit the days it was given."""
    return ('i' in key, '~' in key, 'k' in key)

C = consts()
boards = []   # [set, index, board, grade]
slice_ = len(C['DAILY']) // 7
for i, b in enumerate(C['DAILY']):
    boards.append(['koan', i, b, WEEKDAY[i // slice_]])
for i, b in enumerate(C['HENRO']):
    boards.append(['temple', i, b, max(k for k in range(4) if PROVINCE[k] <= i)])

base = solve([job(str(n), x[2]) for n, x in enumerate(boards)])
ways = {}
for n, x in enumerate(boards):
    r = base[str(n)]
    if r['trace'] != 'CAPPED' and r['par'] == x[2]['par']:
        ways[n] = r['ways']
want = lambda n: GRADES[boards[n][3]][1]
loose = [n for n in ways if ways[n] > want(n)]
print('%d boards looked at, %d decided by the solver, %d with more ways than their grade allows' % (len(boards), len(ways), len(loose)))
for st in ('koan', 'temple'):
    for g in range(4):
        ns = [n for n in ways if boards[n][0] == st and boards[n][3] == g]
        over = [n for n in ns if ways[n] > GRADES[g][1]]
        print('  %-6s %-6s (at most %2d): %3d boards, %3d over, most ways %d' % (st, GRADES[g][0], GRADES[g][1], len(ns), len(over), max([ways[n] for n in ns] or [0])))
if 'count' in sys.argv:
    sys.exit()

xp = os.path.join(here, 'extra_swaps.json')
swaps = json.load(open(xp, encoding='utf-8')) if os.path.exists(xp) else {}
first = {''.join(v['rows']): k for k, v in swaps.items()}     # what a changed board was to begin with

if 'trade' in sys.argv:
    # A board no small change brings down to its grade changes places with one of a lower grade
    # that has few enough ways: the last such board of that grade, and for a koan one that suits
    # the same season, so that no other day's board moves.
    used = set()
    for n in sorted(loose):
        st, g = boards[n][0], boards[n][3]
        key = lambda m: ''.join(boards[m][2]['rows'])
        fit = [m for m in ways if boards[m][0] == st and boards[m][3] < g and ways[m] <= want(n) and ways[n] <= want(m) and m not in used
               and (st != 'koan' or season(key(m)) == season(key(n)))]
        if not fit:
            print('%s %d: nothing to trade with' % (st, boards[n][1] + 1))
            continue
        m = max(fit, key=lambda m: (boards[m][3], boards[m][1]))
        used.add(m)
        full = lambda q: dict(boards[q][2])
        ka, kb = first.get(key(n), key(n)), first.get(key(m), key(m))
        swaps[ka], swaps[kb] = full(m), full(n)
        print('%s %d (%d ways) trades places with %s %d (%d way)' % (st, boards[n][1] + 1, ways[n], st, boards[m][1] + 1, ways[m]))
    json.dump(swaps, open(xp, 'w', encoding='utf-8', newline=chr(10)), ensure_ascii=False, indent=1)
    sys.exit()
_d = open(os.path.join(here, '..', 'scripts', 'data.gd'), encoding='utf-8').read()
taken = {''.join(b['rows']) for nm in C for b in C[nm]} | set(swaps)
now = {n: {'rows': boards[n][2]['rows'], 'ways': ways[n], 'trace': None, 'what': []} for n in loose}
for rnd in range(ROUNDS):
    work = [n for n in now if now[n]['ways'] > want(n)]
    if not work:
        break
    jobs, cands = [], {}
    for n in work:
        b = boards[n][2]
        cands[n] = changes(now[n]['rows'])
        W = len(b['rows'][0])
        for k, key in enumerate(cands[n]):
            if key in taken or key in _d or (boards[n][0] == 'koan' and season(key) != season(''.join(b['rows']))):
                continue
            rr = [key[j * W:(j + 1) * W] for j in range(len(b['rows']))]
            jobs.append(job('%d|%d|all' % (n, k), b, rr))
            for w in b['waza']:
                jobs.append(job('%d|%d|%s' % (n, k, w), b, rr, [x for x in b['waza'] if x != w]))
    res = solve(jobs)
    better = 0
    for n in work:
        b = boards[n][2]
        best = None
        W = len(b['rows'][0])
        for k, key in enumerate(cands[n]):
            r = res.get('%d|%d|all' % (n, k))
            if r is None or r['trace'] == 'CAPPED' or r['par'] != b['par'] or r['ways'] < 1:
                continue
            ok = True
            for w in b['waza']:
                q = res['%d|%d|%s' % (n, k, w)]
                if q['trace'] == 'CAPPED' or 0 < q['par'] <= b['par']:
                    ok = False
            # the change that comes nearest the allowance from below; failing that, the tightest found
            if ok and r['ways'] < now[n]['ways']:
                fits = r['ways'] <= want(n)
                if best is None or (fits and (not best[4] or r['ways'] > best[0])) or (not fits and not best[4] and r['ways'] < best[0]):
                    best = (r['ways'], key, r['trace'], cands[n][key], fits)
        if best:
            now[n] = {'rows': [best[1][j * W:(j + 1) * W] for j in range(len(b['rows']))], 'ways': best[0], 'trace': best[2], 'what': now[n]['what'] + [best[3]]}
            better += 1
    print('round %d: %d boards worked on, %d made tighter, %d boards solved' % (rnd + 1, len(work), better, len(jobs)), flush=True)

changed = 0
for n in sorted(now):
    v = now[n]
    if v['trace'] is None:
        continue
    old, new = ''.join(boards[n][2]['rows']), ''.join(v['rows'])
    taken.add(new)
    swaps[first.get(old, old)] = {'rows': v['rows'], 'sol': v['trace']}
    changed += 1
    print('%-6s %3d  %-6s %5d -> %-3d ways (allowed %d)   %s' % (boards[n][0], boards[n][1] + 1, GRADES[boards[n][3]][0], ways[n], v['ways'], want(n), '; '.join(v['what'])))
json.dump(swaps, open(xp, 'w', encoding='utf-8', newline='\n'), ensure_ascii=False, indent=1)
left = ['%s %d (%d, allowed %d)' % (boards[n][0], boards[n][1] + 1, now[n]['ways'], want(n)) for n in sorted(now) if now[n]['ways'] > want(n)]
print('%d boards changed; %d still have more ways than allowed: %s' % (changed, len(left), '; '.join(left)))
