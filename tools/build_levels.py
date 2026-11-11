"""Assembles scripts/data.gd's LEVELS from the hand-written story stages and the generated boards.

    python tools/build_levels.py <hand_blocks.json> <hand_solved.json> <generated.json>

hand_blocks.json  - the hand-written stages (kanji, name, waza, rows, hint, story, after)
hand_solved.json  - the same boards solved by tools/gen (par, trace)
generated.json    - output of `tools/gen gen`
Writes scripts/data.gd (LEVELS, CHAPTERS, BOSSES, WAZA_FROM) and tools/solutions.json.
"""
import json, re, sys, os

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
hand = {b['kanji']: b for b in json.load(open(sys.argv[1], encoding='utf-8'))}
solved = {''.join(l['rows']): l for l in json.load(open(sys.argv[2], encoding='utf-8'))}
gen = json.load(open(sys.argv[3], encoding='utf-8'))

# solutions the in-engine beam solver found for boards too large for the exact solver
BEAM = {
    '信太': (4, 'U L U U / R U L L / L U U R / R R leapR R'),
    '喝': (5, 'KATSU U leapR U / R D D D / L L L L / L L U U / R U'),
    '怨霊': (4, 'U U U U / R D L KATSU / R U U U / L U'),
    '玉藻前': (5, 'U U U U / U U U leapR / R U L L / L L L KATSU / wardR L L'),
    '酒呑童子': (6, 'U U U U / U U U R / D D L L / R U U R / R R U L / L L leapL L'),
}

CHAPTERS = [
    ('羅生門', 'Rashōmon'), ('鞍馬山', 'Kurama'), ('信太の森', 'Shinoda'), ('大江山', 'Mount Ōe'), ('那須野', 'Nasu'),
    ('雪国', 'Snow Country'), ('河童淵', 'Kappa Pool'), ('化野', 'Adashino'), ('恐山', 'Mount Osore'), ('百鬼夜行', 'Night Parade'),
]

# H = a hand-made board; G = the next generated board of that segment
LAYOUT = {
    0: ['H一筆', 'H間合', 'G0', 'H挟撃', 'G1', 'G1', 'G1', 'G1', 'G1', 'H茨木'],
    1: ['H松風', 'G0', 'G0', 'H縮地', 'G1', 'H団扇', 'G2', 'G2', 'G2', 'H僧正'],
    2: ['H狐火', 'G0', 'G0', 'H葛の葉', 'G1', 'H化かし', 'G2', 'G2', 'G2', 'H信太'],
    3: ['H鬼の門', 'G0', 'G0', 'H谷風', 'G1', 'G1', 'H酒宴', 'G2', 'G2', 'H酒呑童子'],
    4: ['H殺生石', 'G0', 'G0', 'H喝', 'G1', 'G1', 'H怨霊', 'G2', 'G2', 'H玉藻前'],
    5: ['G0', 'G0', 'G0', 'G1', 'G1', 'G1', 'G2', 'G2', 'G2', 'G3'],
    6: ['G0', 'G0', 'G0', 'G1', 'G1', 'G1', 'G2', 'G2', 'G2', 'G3'],
    7: ['G0', 'G0', 'G0', 'G0', 'G1', 'G1', 'G1', 'G1', 'G1', 'G2'],
    8: ['G0', 'G0', 'G0', 'G0', 'G0', 'G1', 'G1', 'G1', 'G1', 'G1'],
    9: ['G0', 'G0', 'G0', 'G0', 'G1', 'G1', 'G1', 'G1', 'G2', 'G3'],
}

# In the later chapters the story rides on generated boards: (chapter, segment) -> story stage
STORY_ON = {
    (5, 0): '薄氷', (5, 1): '傘', (5, 2): '吹雪', (5, 3): '雪女',
    (6, 0): '河童', (6, 1): '相撲', (6, 2): '瀬', (6, 3): '河伯',
    (7, 0): '鬼火', (7, 1): '関', (8, 0): '恐山', (9, 0): '行列', (9, 2): '百鬼', (9, 3): '餓者髑髏',
}

NAMES = {
    0: [('灯影', 'Lantern Shadows'), ('石畳', 'The Flagstones'), ('夜警', 'Night Watch'), ('朱門', 'The Vermilion Gate'), ('辻', 'The Crossroads'), ('鬼哭', "The Oni's Wail")],
    1: [('杉木立', 'The Cedar Stand'), ('山道', 'The Mountain Path'), ('羽音', 'Wingbeats'), ('谷渡り', 'Crossing the Gorge'), ('木霊', 'Echo'), ('天狗礫', 'Tengu Stones')],
    2: [('影踏み', 'Shadow-Stepping'), ('化け比べ', 'A Contest of Tricks'), ('稲荷', 'Inari'), ('狐の嫁入り', "The Fox's Wedding"), ('楠', 'The Camphor Tree'), ('鏡', 'The Mirror')],
    3: [('山門', 'The Mountain Gate'), ('金棒', 'Iron Clubs'), ('岩屋', 'The Rock Hall'), ('酒の香', 'The Smell of Wine'), ('鬼の宴', 'Ogres at Table'), ('首塚', 'The Mound of Heads')],
    4: [('枯野', 'The Withered Field'), ('鳥落ち', 'Where Birds Fall'), ('毒気', 'Miasma'), ('夜泣き', 'Night Weeping'), ('石の影', 'Shadow of the Stone'), ('無明', 'No Light')],
    5: [('霜', 'Frost'), ('氷柱', 'Icicles'), ('雪明り', 'Snowlight'), ('凍て道', 'The Frozen Road'), ('樹氷', 'Rime'), ('白魔', 'The White Devil')],
    6: [('淵', 'The Deep'), ('葦', 'Reeds'), ('胡瓜', 'Cucumbers'), ('尻子玉', 'Shirikodama'), ('水鏡', 'Water Mirror'), ('渦', 'The Whirlpool')],
    7: [('卒塔婆', 'Grave Markers'), ('無縁仏', 'The Unmourned'), ('灯籠', 'Stone Lanterns'), ('焼け野', 'The Burnt Field'), ('壁', 'Walls'), ('六道', 'The Six Roads'), ('辻風', 'Crossroads Wind'), ('煙', 'Smoke')],
    8: [('三途', 'The Sanzu River'), ('賽の河原', 'The Riverbank of Stones'), ('硫黄', 'Sulphur'), ('風車', 'Pinwheels'), ('血の池', 'The Pond of Blood'), ('地獄谷', 'Hell Valley'), ('極楽浜', 'Paradise Shore'), ('口寄せ', 'The Summoning'), ('宇曽利', 'Lake Usori')],
    9: [('太鼓', 'The Drum'), ('提灯行列', 'The Lantern Parade'), ('付喪神', 'Tsukumogami'), ('朱雀大路', 'Suzaku Avenue'), ('丑三つ', 'The Hour of the Ox'), ('鉦', 'The Gong'), ('夜明け前', 'Before Dawn')],
}

levels, sols, chapters, bosses = [], {}, [], []
for c in range(10):
    chapters.append({'kanji': CHAPTERS[c][0], 'name': CHAPTERS[c][1], 'from': len(levels)})
    pools = {}
    for g in gen:
        if g['chapter'] == c:
            pools.setdefault(g['seg'], []).append(g)
    for k in pools:
        pools[k].sort(key=lambda g: (g['par'], g['score']))
    names = list(NAMES[c])
    started = set()
    for slot in LAYOUT[c]:
        if slot[0] == 'H':
            b = dict(hand[slot[1:]])
            key = ''.join(b['rows'])
            if slot[1:] in BEAM:
                b['par'], trace = BEAM[slot[1:]]
            else:
                assert solved[key]['par'] > 0, slot
                b['par'], trace = solved[key]['par'], solved[key]['trace']
        else:
            seg = int(slot[1:])
            if not pools.get(seg):
                print('!! chapter %d segment %d ran out of boards' % (c, seg))
                continue
            g = pools[seg].pop(0)
            b = {'kanji': '', 'name': '', 'par': g['par'], 'waza': g['waza'], 'rows': g['rows'], 'hint': '', 'story': [], 'after': []}
            trace = g['trace']
            st = STORY_ON.get((c, seg))
            if st and seg not in started:
                h = hand[st]
                b.update(kanji=h['kanji'], name=h['name'], hint=h['hint'], story=h['story'], after=h['after'])
            else:
                b['kanji'], b['name'] = names.pop(0)
            started.add(seg)
        b = {k: b[k] for k in ('kanji', 'name', 'par', 'waza', 'rows', 'hint', 'story', 'after')}
        sols[b['kanji'] + '|' + ''.join(b['rows'])] = trace
        levels.append(b)
    bosses.append(len(levels) - 1)

waza_from = {w: next(i for i, l in enumerate(levels) if w in l['waza']) for w in ('leap', 'ward', 'katsu')}

def gd(v, ind=1):
    t = '\t' * ind
    if isinstance(v, dict):
        return '{\n' + ''.join('%s\t%s: %s,\n' % (t, json.dumps(k), gd(x, ind + 1)) for k, x in v.items()) + t + '}'
    if isinstance(v, list) and v and isinstance(v[0], (list, dict)) or (isinstance(v, list) and len(v) == 7 and isinstance(v[0], str) and len(v[0]) == 7):
        return '[\n' + ''.join('%s\t%s,\n' % (t, gd(x, ind + 1) if isinstance(x, dict) else json.dumps(x, ensure_ascii=False)) for x in v) + t + ']'
    return json.dumps(v, ensure_ascii=False)

p = os.path.join(root, 'scripts', 'data.gd')
s = open(p, encoding='utf-8').read()
head = s[:s.index('const LEVELS = [')]
head = re.sub(r'const WAZA_FROM = \{[^\n]*\}[^\n]*', 'const WAZA_FROM = %s  # first stage index that grants each waza' % json.dumps(waza_from), head)
i, j = head.index('const CHAPTERS = ['), head.index('const LEGEND')
ch = 'const CHAPTERS = [\n' + ''.join('\t%s,\n' % json.dumps(c, ensure_ascii=False) for c in chapters) + ']\nconst BOSSES = %s\n\n' % json.dumps(bosses)
head = head[:i] + ch + head[j:]
body = 'const LEVELS = [\n' + ''.join('\t' + gd(l) + ',\n' for l in levels) + ']\n'
open(p, 'w', encoding='utf-8').write(head + body)
json.dump(sols, open(os.path.join(root, 'tools', 'solutions.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)

print('%d stages' % len(levels))
for c in range(10):
    a = chapters[c]['from']
    b = chapters[c + 1]['from'] if c < 9 else len(levels)
    pars = [l['par'] for l in levels[a:b]]
    ny = [sum(ch in 'coOStTkyQupPnWG' for r in l['rows'] for ch in r) for l in levels[a:b]]
    print('  %-12s pars %s  mean %.1f   yokai mean %.1f' % (CHAPTERS[c][1], pars, sum(pars) / len(pars), sum(ny) / len(ny)))
