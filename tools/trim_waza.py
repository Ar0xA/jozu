"""Takes away every technique a board grants but mastery does not need.

    python tools/trim_waza.py        (then: python tools/build_levels.py)

A board that offers the leap, the ward, the shout or the bell must need it to be mastered. Each
board in tools/*.json is solved again without each of its techniques in turn (`tools/gen solve`);
where the mastery stroke count can still be reached, the technique is removed and the stored
solution replaced by one that does not use it. This repeats until every technique left is needed.
A board the solver cannot finish without a technique keeps it. Run it after generating boards.
"""
import json, os, subprocess, sys, tempfile

sys.stdout.reconfigure(encoding='utf-8')
here = os.path.dirname(os.path.abspath(__file__))
GEN = os.path.join(here, 'gen', 'bin', 'Release', 'net8.0', 'gen.exe')
FILES = ['generated.json', 'pool.json', 'daily_pool.json', 'hand_solved.json']
# hand-made boards whose stored solution came from the beam solver: too large to decide here
BEAM = {'信太', '喝', '怨霊', '玉藻前', '酒呑童子'}

def load(n):
    p = os.path.join(here, n)
    return json.load(open(p, encoding='utf-8')) if os.path.exists(p) else None

def save(n, d):
    json.dump(d, open(os.path.join(here, n), 'w', encoding='utf-8', newline='\n'), ensure_ascii=False, indent=1)

data = {n: load(n) for n in FILES}
story = load('story_stages.json')
by_rows = {''.join(b['rows']): b for b in story}
skip = {''.join(b['rows']) for b in story if b['kanji'] in BEAM}

boards = []   # every board that grants something and can be decided
for n in FILES:
    for b in data[n] or []:
        if b.get('waza') and b.get('par', 0) > 0 and ''.join(b['rows']) not in skip and b.get('trace') not in (None, '', 'CAPPED'):
            boards.append(b)
tested = {}    # id(board) -> techniques shown to be needed with its present set
dropped = 0
todo = boards
rnd = 0
while todo:
    rnd += 1
    jobs = []
    for k, b in enumerate(todo):
        for w in b['waza']:
            if w not in tested.setdefault(id(b), set()):
                jobs.append({'name': '%d|%s' % (k, w), 'rows': b['rows'], 'waza': [x for x in b['waza'] if x != w],
                             'rules': b.get('rules') or [], 'ink': b.get('ink') or 4})
    if not jobs:
        break
    with tempfile.TemporaryDirectory() as tmp:
        a, z = os.path.join(tmp, 'in.json'), os.path.join(tmp, 'out.json')
        json.dump(jobs, open(a, 'w', encoding='utf-8'))
        subprocess.run([GEN, 'solve', a, z], check=True, stdout=subprocess.DEVNULL)
        res = json.load(open(z, encoding='utf-8'))
    again, moved = [], set()
    for r in res:
        k, w = r['name'].split('|')
        b = todo[int(k)]
        if w not in b['waza']:
            continue
        if r['par'] > 0 and r['trace'] != 'CAPPED' and r['par'] <= b['par'] and id(b) not in moved:
            # not needed: take it away, and what is left must be shown needed afresh
            b['waza'] = [x for x in b['waza'] if x != w]
            # the board keeps its place on the road: build_levels.py ranks it by what it had
            b.setdefault('par0', b['par'])
            b.setdefault('trace0', b['trace'])
            b['par'], b['trace'] = r['par'], r['trace']
            tested[id(b)] = set()
            moved.add(id(b))
            dropped += 1
            if b['waza']:
                again.append(b)
        elif id(b) not in moved:
            tested[id(b)].add(w)
    print('round %d: %d solved, %d techniques taken away so far' % (rnd, len(jobs), dropped))
    todo = again

# the hand-made stages keep their techniques in story_stages.json
for b in data['hand_solved.json'] or []:
    h = by_rows.get(''.join(b['rows']))
    if h and h['waza'] != b['waza']:
        print('hand-made: %s  %s -> %s' % (h['name'], h['waza'], b['waza']))
        h['waza'] = b['waza']
for n in FILES:
    if data[n] is not None:
        save(n, data[n])
save('story_stages.json', story)
print('%d boards looked at, %d techniques taken away' % (len(boards), dropped))
