"""Assembles scripts/data.gd's LEVELS from the hand-written story stages and the generated boards.

    python tools/build_levels.py <hand_blocks.json> <hand_solved.json> <generated.json> [pool.json]

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
pool = json.load(open(sys.argv[4], encoding='utf-8')) if len(sys.argv) > 4 else []
import math

MAX_PER_STYLE = 18   # the most stages a style chapter may hold
STYLE_FROM = 10      # chapters from here on are single-style ladders

def n_yokai(g):
    return sum(ch in 'coOStTkyQupPnWGdaAeX' for r in g['rows'] for ch in r)

def difficulty(g):
    """How hard a board is to master. Strokes needed count most; then how much there is to search
    (more dead ends), how few optimal answers exist, and how crowded the board is."""
    rules = g.get('rules') or []
    search = math.log2(g.get('states', 1) + 1)
    if 'koan' in rules or 'garden' in rules:
        return (g.get('ink') or 4) * 2 + search * 3 + n_yokai(g) - min(g.get('ways', 1), 6)
    return g['par'] * 10 + search * 1.2 - math.log2(g.get('ways', 1) + 1) * 1.5 + n_yokai(g) * 0.5

def ladder(c):
    """Every distinct board found for a style chapter, as an evenly rising run of difficulty."""
    seen_rows, seen_sol, out = set(), set(), []
    for g in sorted([x for x in gen + pool if x['chapter'] == c], key=difficulty):
        k = ''.join(g['rows'])
        if k in seen_rows or g['trace'] in seen_sol:
            continue   # the same board, or a different board with the very same answer
        seen_rows.add(k)
        seen_sol.add(g['trace'])
        out.append(g)
    if len(out) > MAX_PER_STYLE:
        idx = sorted(set(round(i * (len(out) - 1) / (MAX_PER_STYLE - 1)) for i in range(MAX_PER_STYLE)))
        out = [out[i] for i in idx]
    return out

NUM = ['一', '二', '三', '四', '五', '六', '七', '八', '九', '十', '十一', '十二', '十三', '十四', '十五', '十六', '十七', '十八', '十九', '二十']


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
    ('禅寺', 'Zen Temple'), ('石庭', 'Stone Garden'), ('鳥居', 'The Gate'), ('墨染', 'Wet Ink'), ('円相', 'Ensō'), ('硯', 'Ink Stone'), ('無刀', 'No Sword'),
    ('達磨', 'Daruma'), ('狸', 'Tanuki'), ('赤い糸', 'Red Thread'), ('風', 'Wind'), ('雨', 'Rain'), ('雪', 'Deep Snow'), ('夜', 'Night'),
    ('式神', 'Shikigami'), ('死神', 'Shinigami'),
]

# The order the chapters are played in (the shinigami comes before the shikigami, which ends the game).
ORDER = list(range(24)) + [25, 24]

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
    10: ['G0', 'G0', 'G0', 'G0', 'G1', 'G1', 'G1', 'G2', 'G2', 'G2'],
    11: ['G0', 'G0', 'G0', 'G0', 'G1', 'G1', 'G1', 'G2', 'G2', 'G2'],
    12: ['G0', 'G0', 'G0', 'G0', 'G1', 'G1', 'G1', 'G2', 'G2', 'G2'],
    13: ['G0', 'G0', 'G0', 'G0', 'G1', 'G1', 'G1', 'G2', 'G2', 'G2'],
    14: ['G0', 'G0', 'G0', 'G0', 'G1', 'G1', 'G1', 'G2', 'G2', 'G2'],
    15: ['G0', 'G0', 'G0', 'G0', 'G1', 'G1', 'G1', 'G2', 'G2', 'G2'],
    16: ['G0', 'G0', 'G0', 'G0', 'G1', 'G1', 'G1', 'G2', 'G2', 'G2'],
}

# In the later chapters the story rides on generated boards: (chapter, segment) -> story stage
STORY_ON = {
    (5, 0): '薄氷', (5, 1): '傘', (5, 2): '吹雪', (5, 3): '雪女',
    (6, 0): '河童', (6, 1): '相撲', (6, 2): '瀬', (6, 3): '河伯',
    (7, 0): '鬼火', (7, 1): '関', (8, 0): '恐山', (9, 0): '行列', (9, 2): '百鬼', (9, 3): '餓者髑髏',
    (10, 0): '公案', (11, 0): '石庭', (12, 0): '鳥居', (13, 0): '墨染', (14, 0): '円相', (15, 0): '硯', (16, 0): '無刀',
    (17, 0): '達磨', (18, 0): '狸', (19, 0): '赤い糸', (20, 0): '風', (21, 0): '雨', (22, 0): '雪', (23, 0): '夜', (24, 0): '式神', (25, 0): '死神',
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
    10: [('無', 'Mu'), ('一', 'One'), ('只管', 'Just This'), ('喫茶去', 'Have Some Tea'), ('柏樹子', 'The Oak in the Garden'), ('隻手', 'One Hand'), ('本来', 'Original Face'), ('風幡', 'Wind and Flag'), ('月', 'The Moon')],
    13: [('滲み', 'Bleed'), ('筆跡', 'Brush Trace'), ('垣', 'The Hedge'), ('雨垂れ', 'Raindrops'), ('墨流し', 'Marbling'), ('影', 'Shadow'), ('橋', 'The Bridge'), ('濡れ縁', 'The Wet Veranda'), ('余白', 'Blank Space')],
    14: [('輪', 'The Ring'), ('満月', 'Full Moon'), ('井戸', 'The Well'), ('茶碗', 'The Tea Bowl'), ('車', 'The Wheel'), ('蛇の目', "Snake's Eye"), ('環', 'The Loop'), ('空', 'Emptiness'), ('始終', 'Beginning and End')],
    11: [('砂紋', 'Ripples in Sand'), ('苔', 'Moss'), ('飛石', 'Stepping Stones'), ('蹲', 'The Water Basin'), ('竹垣', 'The Bamboo Fence'), ('白砂', 'White Gravel'), ('十五石', 'Fifteen Stones'), ('借景', 'Borrowed Scenery'), ('箒目', 'Broom Marks')],
    12: [('参道', 'The Approach'), ('注連縄', 'The Sacred Rope'), ('狛犬', 'The Guardian Dogs'), ('千本鳥居', 'A Thousand Gates'), ('手水', 'Purification'), ('鎮守', 'The Village Shrine'), ('石段', 'The Stone Steps'), ('神域', 'Sacred Ground'), ('奥宮', 'The Inner Shrine')],
    15: [('磨墨', 'Grinding Ink'), ('墨池', 'The Ink Pool'), ('水滴', 'The Water Dropper'), ('濃淡', 'Dark and Pale'), ('墨色', 'The Colour of Ink'), ('筆洗', 'The Brush Washer'), ('硯海', 'The Sea of the Inkstone'), ('松煙', 'Pine Soot'), ('古墨', 'Old Ink')],
    16: [('空手', 'Empty Hands'), ('鞘', 'The Scabbard'), ('柔', 'Yielding'), ('受け', 'Receiving'), ('間', 'The Interval'), ('不動', 'Unmoving'), ('合気', 'Meeting'), ('捨て身', 'Letting Go'), ('収め', 'The Sheathing')],
    9: [('太鼓', 'The Drum'), ('提灯行列', 'The Lantern Parade'), ('付喪神', 'Tsukumogami'), ('朱雀大路', 'Suzaku Avenue'), ('丑三つ', 'The Hour of the Ox'), ('鉦', 'The Gong'), ('夜明け前', 'Before Dawn')],
}


# Traditional sayings shown on stages that have no story of their own: proverbs (kotowaza),
# Zen phrases and koan, lines of haiku, and words from Buddhist teachers, samurai and chronicles.
# (Japanese, reading, meaning, chapters it belongs to, what it is about)
# "About" tags are matched against each stage's own board and solution:
#   yokai   chochin oni bigoni tengu kitsune yurei kasa kappa nurikabe yukionna gasha
#   ground  water ice fire rock
#   answer  wait (a stroke spent standing still)  leap ward katsu (technique the answer uses)
#           long (7+ strokes)  short (3 or fewer)  twins (two or more of one kind)  crowd (7+ yokai)
#   rule    koan wet enso   (a saying with a rule tag is used only on stages with that rule)
SAY = [
    # ---- lanterns
    ('灯台下暗し', 'Tōdai moto kurashi', 'It is darkest at the foot of the lamp.', [], ['chochin']),
    ('一隅を照らす', 'Ichigū o terasu', 'Light up one corner. Whoever does is a treasure of the nation. — Saichō, founder of Tendai', [], ['chochin']),
    # ---- oni
    ('鬼の目にも涙', 'Oni no me ni mo namida', "Even an oni's eye can hold a tear.", [], ['oni']),
    ('渡る世間に鬼はなし', 'Wataru seken ni oni wa nashi', 'In the world we walk through, there are no real oni.', [], ['oni']),
    ('鬼に金棒', 'Oni ni kanabō', 'An iron club for an oni: strength given to the already strong.', [], ['bigoni']),
    ('柔よく剛を制す', 'Jū yoku gō o seisu', 'Softness, used well, overcomes hardness.', [], ['bigoni']),
    ('一刀両断', 'Ittō ryōdan', 'One stroke of the sword, and it is in two.', [], ['bigoni', 'short']),
    ('驕れる人も久しからず', 'Ogoreru hito mo hisashikarazu', 'The proud do not endure; they are like a dream on a spring night. — The Tale of the Heike', [0, 3], ['bigoni']),
    ('善人なおもて往生をとぐ、いわんや悪人をや', 'Zennin nao mote ōjō o togu, iwanya akunin o ya', 'Even the good are reborn in the Pure Land; how much more so the wicked. — Shinran', [4], ['oni', 'yurei']),
    # ---- tengu and wind
    ('柳に風', 'Yanagi ni kaze', 'A willow in the wind: it bends, and is not broken.', [], ['tengu']),
    ('明日は明日の風が吹く', 'Ashita wa ashita no kaze ga fuku', "Tomorrow, tomorrow's wind will blow.", [], ['tengu']),
    ('能ある鷹は爪を隠す', 'Nō aru taka wa tsume o kakusu', 'The hawk with real skill hides its talons.', [1], ['tengu']),
    ('風林火山', 'Fū rin ka zan', "Swift as wind, silent as forest, fierce as fire, immovable as mountain. — Takeda Shingen's banner", [3], ['tengu', 'fire']),
    ('観の目強く、見の目弱く', 'Kan no me tsuyoku, ken no me yowaku', 'Perceive strongly; look only lightly. — Miyamoto Musashi', [9], ['tengu', 'crowd']),
    # ---- foxes and mirrors
    ('狐につままれる', 'Kitsune ni tsumamareru', 'To be pinched by a fox: to be utterly bewildered.', [], ['kitsune']),
    ('人のふり見て我がふり直せ', 'Hito no furi mite waga furi naose', "Watch another's manner, and mend your own.", [], ['kitsune']),
    ('明鏡止水', 'Meikyō shisui', 'A bright mirror, still water: a mind that reflects without distortion.', [], ['kitsune', 'water']),
    # ---- the dead
    ('南無阿弥陀仏', 'Namu Amida Butsu', 'I take refuge in Amida Buddha: the nembutsu, said for the dying and the dead.', [], ['yurei']),
    ('死人に口なし', 'Shinin ni kuchi nashi', 'The dead have no mouths.', [], ['yurei']),
    ('露の世は露の世ながらさりながら', 'Tsuyu no yo wa / tsuyu no yo nagara / sari nagara', 'This world of dew is a world of dew, and yet, and yet. — Issa', [4, 8], ['yurei']),
    ('門松は冥土の旅の一里塚', 'Kadomatsu wa meido no tabi no ichirizuka', "The New Year's pine is a milestone on the road to the next world. — the Zen monk Ikkyū", [8], ['yurei']),
    ('骨折り損のくたびれ儲け', 'Honeori-zon no kutabire-mōke', 'Bones broken for nothing, and only weariness earned.', [], ['gasha']),
    # ---- water
    ('水に流す', 'Mizu ni nagasu', 'Let the water carry it away.', [], ['katsu', 'water']),
    ('覆水盆に返らず', 'Fukusui bon ni kaerazu', 'Spilled water does not return to the tray.', [], ['water']),
    ('石橋を叩いて渡る', 'Ishibashi o tataite wataru', 'Tap even a stone bridge before you cross it.', [], ['water', 'rock']),
    ('行雲流水', 'Kōun ryūsui', 'Drifting cloud, flowing water: the life of a wandering Zen monk, who is called unsui for it.', [], ['water']),
    ('立つ鳥跡を濁さず', 'Tatsu tori ato o nigosazu', 'A bird taking flight does not muddy the water it leaves.', [], ['water']),
    ('古池や蛙飛びこむ水の音', 'Furuike ya / kawazu tobikomu / mizu no oto', 'An old pond: a frog jumps in, the sound of water. — Bashō', [6], ['water', 'kappa']),
    ('河童の川流れ', 'Kappa no kawa-nagare', 'Even a kappa can be carried off by the river.', [], ['kappa']),
    ('井の中の蛙大海を知らず', 'I no naka no kawazu taikai o shirazu', 'The frog in the well knows nothing of the great sea.', [], ['kappa']),
    ('やせ蛙まけるな一茶これにあり', 'Yasegaeru / makeru na Issa / kore ni ari', 'Skinny frog, do not give up: Issa is here. — Issa', [6], ['kappa']),
    # ---- ice and snow
    ('薄氷を踏む', 'Hakuhyō o fumu', 'To tread on thin ice.', [], ['ice']),
    ('雪とけて村いっぱいの子どもかな', 'Yuki tokete / mura ippai no / kodomo kana', 'The snow melts, and the village is brimming over with children. — Issa', [5], ['ice']),
    ('看脚下', 'Kankyakka', 'Look beneath your own feet: written at the entrance of Zen temples.', [], ['ice', 'fire']),
    # ---- fire
    ('火のない所に煙は立たぬ', 'Hi no nai tokoro ni kemuri wa tatanu', 'Where there is no fire, no smoke rises.', [], ['fire']),
    ('飛んで火に入る夏の虫', 'Tonde hi ni iru natsu no mushi', 'A summer insect, flying into the flame.', [], ['fire']),
    ('敵は本能寺にあり', 'Teki wa Honnō-ji ni ari', 'The enemy is at Honnō-ji: Akechi Mitsuhide, turning his army on his own lord Nobunaga, who died in the burning temple, 1582.', [7], ['fire']),
    ('人間五十年、下天の内をくらぶれば、夢幻の如くなり', 'Ningen gojūnen, geten no uchi o kurabureba, yume maboroshi no gotoku nari', "Man's fifty years, beside the ages of heaven, are a dream, an illusion. — from Atsumori, the verse Oda Nobunaga loved", [7], ['fire']),
    ('地獄で仏', 'Jigoku de hotoke', 'To meet a Buddha in hell.', [8], ['fire']),
    # ---- walls and stone
    ('壁に耳あり障子に目あり', 'Kabe ni mimi ari, shōji ni me ari', 'The walls have ears; the paper doors have eyes.', [], ['nurikabe']),
    ('人は城、人は石垣、人は堀', 'Hito wa shiro, hito wa ishigaki, hito wa hori', 'People are the castle, people the stone walls, people the moat. — Takeda Shingen', [3], ['nurikabe', 'water']),
    ('閑さや岩にしみ入る蝉の声', 'Shizukasa ya / iwa ni shimiiru / semi no koe', "Stillness: sinking into the rocks, the cicadas' cry. — Bashō, at the mountain temple Risshaku-ji", [8], ['rock']),
    # ---- answers that begin by waiting
    ('急がば回れ', 'Isogaba maware', 'If you are in a hurry, go the long way round.', [], ['wait']),
    ('鳴かぬなら鳴くまで待とう時鳥', 'Nakanu nara naku made matō hototogisu', 'If the cuckoo will not sing, wait until it does: the patience of Tokugawa Ieyasu.', [], ['wait']),
    ('待てば海路の日和あり', 'Mateba kairo no hiyori ari', 'Wait, and fair weather for the crossing will come.', [], ['wait', 'water']),
    ('石の上にも三年', 'Ishi no ue ni mo sannen', 'Sit on a stone for three years and even it grows warm.', [], ['wait', 'rock']),
    ('負けるが勝ち', 'Makeru ga kachi', 'To yield is to win.', [], ['wait']),
    ('急いては事を仕損じる', 'Seite wa koto o shisonjiru', 'Hurry, and you will spoil the work.', [], ['wait']),
    ('後の先', 'Go no sen', 'To take the initiative after the other has moved.', [], ['wait']),
    # ---- techniques
    ('鶴の一声', 'Tsuru no hitokoe', 'A single cry of the crane settles the matter.', [], ['katsu']),
    ('虎穴に入らずんば虎子を得ず', 'Koketsu ni irazunba koji o ezu', "Unless you enter the tiger's den, you will not take its cub.", [], ['leap']),
    ('転ばぬ先の杖', 'Korobanu saki no tsue', 'A staff before you stumble.', [], ['ward']),
    # ---- the shape of the answer
    ('二兎を追う者は一兎をも得ず', 'Nito o ou mono wa itto o mo ezu', 'Chase two hares and you will catch neither.', [], ['twins']),
    ('一石二鳥', 'Isseki nichō', 'One stone, two birds.', [], ['twins', 'short']),
    ('人の一生は重荷を負うて遠き道を行くがごとし', 'Hito no isshō wa omoni o ōte tōki michi o yuku ga gotoshi', "A life is like walking a long road with a heavy load. Do not hurry. — Tokugawa Ieyasu's precept", [], ['long']),
    ('千日の稽古を鍛とし万日の稽古を錬とす', 'Sennichi no keiko o tan to shi, mannichi no keiko o ren to su', 'A thousand days of practice to forge; ten thousand to temper. — Miyamoto Musashi, The Book of Five Rings', [9], ['long']),
    ('塵も積もれば山となる', 'Chiri mo tsumoreba yama to naru', 'Even dust, piled up, becomes a mountain.', [], ['long']),
    ('千里の道も一歩から', 'Senri no michi mo ippo kara', 'A road of a thousand ri begins with a single step.', [0], ['long']),
    # ---- places
    ('祇園精舎の鐘の声、諸行無常の響きあり', 'Gion shōja no kane no koe, shogyō mujō no hibiki ari', 'The bell of the Gion monastery sounds the impermanence of all things. — The Tale of the Heike', [0], []),
    ('判官贔屓', 'Hōgan-biiki', 'Sympathy for the Hōgan: the love people still bear Yoshitsune, the brilliant general his own brother destroyed.', [1], []),
    ('弁慶の立往生', 'Benkei no tachi-ōjō', "Benkei's standing death: the warrior monk died on his feet, full of arrows, still guarding his lord.", [1], []),
    ('知らぬが仏', 'Shiranu ga hotoke', 'Not knowing is to be a Buddha.', [2], []),
    ('勝って兜の緒を締めよ', 'Katte kabuto no o o shimeyo', 'After the victory, tighten your helmet cord.', [3], []),
    ('武士は食わねど高楊枝', 'Bushi wa kuwanedo takayōji', 'A samurai, though he has not eaten, holds his toothpick high.', [3], []),
    ('旅に病んで夢は枯野をかけ廻る', 'Tabi ni yande / yume wa kareno o / kakemeguru', 'Sick on a journey, my dreams go wandering over withered fields. — Bashō, his last poem', [4], []),
    ('一寸先は闇', 'Issun saki wa yami', 'One inch ahead, all is darkness.', [4], []),
    ('敵に塩を送る', 'Teki ni shio o okuru', 'To send salt to your enemy, as Uesugi Kenshin did for Takeda Shingen: wars are won with swords, not hunger.', [5], []),
    ('諸行無常', 'Shogyō mujō', 'All things are impermanent: the first mark of existence in Buddhist teaching.', [7], []),
    ('因果応報', 'Inga ōhō', 'Cause and effect, answered in kind: what is done returns.', [7], []),
    ('夏草や兵どもが夢の跡', 'Natsukusa ya / tsuwamono-domo ga / yume no ato', "Summer grasses: all that is left of the warriors' dreams. — Bashō, at Hiraizumi where Yoshitsune died", [7, 9], []),
    ('露と落ち露と消えにし我が身かな', 'Tsuyu to ochi / tsuyu to kienishi / waga mi kana', "I fell as dew and as dew I vanish. Even Osaka was a dream within a dream. — Toyotomi Hideyoshi's death poem", [8], []),
    ('仏道をならふといふは、自己をならふなり', 'Butsudō o narau to iu wa, jiko o narau nari', 'To study the Buddha Way is to study the self. To study the self is to forget the self. — Dōgen', [8], []),
    ('この道や行く人なしに秋の暮', 'Kono michi ya / yuku hito nashi ni / aki no kure', 'This road: no one travels it. Autumn evening. — Bashō', [8], []),
    ('一期一会', 'Ichi-go ichi-e', 'One lifetime, one meeting: from the tea ceremony. This gathering will never come again.', [8], []),
    ('武士道と云ふは死ぬ事と見付けたり', 'Bushidō to iu wa shinu koto to mitsuketari', 'The Way of the warrior, I have found, is to die. — Yamamoto Tsunetomo, Hagakure', [9], []),
    ('剣禅一如', 'Ken zen ichinyo', 'The sword and Zen are one.', [9], []),
    ('残心', 'Zanshin', 'The mind that remains: awareness held after the stroke is finished.', [9], []),
    ('仏神は貴し、仏神をたのまず', 'Busshin wa tōtoshi, busshin o tanomazu', 'Honour the buddhas and the gods; do not depend on them. — Musashi, Dokkōdō', [9], []),
    ('初心忘るべからず', 'Shoshin wasuru bekarazu', "Never forget the beginner's mind. — Zeami, master of Noh", [9], []),
    # ---- on skill itself (上手, jōzu)
    ('好きこそ物の上手なれ', 'Suki koso mono no jōzu nare', 'What you love, you become skilled at.', [], []),
    ('上手の手から水が漏る', 'Jōzu no te kara mizu ga moru', 'Even from the hands of the skilled, water leaks.', [], ['water']),
    ('習うより慣れろ', 'Narau yori narero', 'Rather than being taught, get used to it.', [], []),
    ('芸は身を助く', 'Gei wa mi o tasuku', 'An art, once learned, will keep you.', [], []),
    ('青は藍より出でて藍より青し', 'Ao wa ai yori idete ai yori aoshi', 'Blue comes from indigo and is bluer than indigo: the pupil surpasses the teacher.', [], []),
    ('画竜点睛', 'Garyō tensei', "Dotting the eyes of the painted dragon: the last stroke that brings the whole to life.", [], ['short']),
    ('百里を行く者は九十を半ばとす', 'Hyakuri o yuku mono wa kujū o nakaba to su', 'Whoever travels a hundred ri should count ninety as halfway.', [], ['long']),
    ('有終の美', 'Yūshū no bi', 'The beauty of finishing well.', [], ['long']),
    # ---- Buddhist turns of phrase
    ('釈迦に説法', 'Shaka ni seppō', 'Preaching to the Buddha.', [], []),
    ('馬の耳に念仏', 'Uma no mimi ni nenbutsu', "The nembutsu, chanted into a horse's ear.", [], []),
    ('嘘も方便', 'Uso mo hōben', 'Even a lie may be a skilful means. — from the parables of the Lotus Sutra', [], ['kitsune']),
    ('袖振り合うも多生の縁', 'Sode furiau mo tashō no en', 'Even sleeves brushing in passing is a bond from other lives.', [], []),
    ('三人寄れば文殊の知恵', 'Sannin yoreba Monju no chie', 'Three together have the wisdom of the bodhisattva Monju.', [], ['crowd']),
    # ---- colours and seasons
    ('朱に交われば赤くなる', 'Shu ni majiwareba akaku naru', 'Mix with vermilion and you turn red.', [], ['fire']),
    ('月に叢雲、花に風', 'Tsuki ni murakumo, hana ni kaze', 'Clouds over the moon, wind upon the blossoms: nothing fine is left alone for long.', [], ['tengu']),
    ('雀百まで踊り忘れず', 'Suzume hyaku made odori wasurezu', 'A sparrow does not forget its dance though it live to a hundred.', [], []),
    ('郷に入っては郷に従え', 'Gō ni itte wa gō ni shitagae', 'Entering a village, follow the village.', [], []),
    ('縁の下の力持ち', 'En no shita no chikaramochi', 'The strong one under the veranda: strength that works unseen.', [], ['nurikabe']),
    ('泣きっ面に蜂', 'Nakittsura ni hachi', 'A bee to the crying face: trouble on top of trouble.', [], ['crowd']),
    ('終わり良ければ全て良し', 'Owari yokereba subete yoshi', 'If the end is good, all is good.', [], []),
    ('論より証拠', 'Ron yori shōko', 'Proof over argument.', [], []),
    ('類は友を呼ぶ', 'Rui wa tomo o yobu', 'Like calls to like.', [], ['twins']),
    # ---- anywhere
    ('雨降って地固まる', 'Ame futte ji katamaru', 'After the rain, the ground is firmer.', [], []),
    ('出る杭は打たれる', 'Deru kui wa utareru', 'The stake that stands out is hammered down.', [], []),
    ('継続は力なり', 'Keizoku wa chikara nari', 'To continue is itself strength.', [], []),
    ('弘法筆を選ばず', 'Kōbō fude o erabazu', 'Kōbō Daishi does not choose his brush.', [], []),
    # ---- koan: one stroke
    ('無', 'Mu', 'A monk asked Jōshū: has a dog Buddha-nature? Jōshū said: Mu.', [], ['koan']),
    ('非風非幡', 'Hifū hiban', 'It is not the wind that moves, nor the flag. It is your mind. — the Sixth Patriarch', [], ['koan', 'kitsune']),
    ('本来の面目', 'Honrai no menmoku', 'What was your original face, before your parents were born?', [], ['koan', 'kitsune']),
    ('庭前の柏樹子', 'Teizen no hakujushi', 'Why did the Patriarch come from the West? The oak tree in the garden. — Jōshū', [], ['koan', 'rock']),
    ('隻手の声', 'Sekishu no koe', 'You know the sound of two hands clapping. What is the sound of one? — Hakuin', [], ['koan']),
    ('喫茶去', 'Kissako', 'Jōshū said to the newcomer and to the old hand alike: have some tea.', [], ['koan']),
    ('放下着', 'Hōgejaku', 'I have brought nothing, said the monk. Then put it down, said Jōshū.', [], ['koan']),
    ('平常心是道', 'Heijōshin kore dō', 'Ordinary mind is the Way. — Nansen', [], ['koan']),
    ('只管打坐', 'Shikantaza', 'Just sitting: nothing sought, nothing added. — Dōgen', [], ['koan']),
    ('月を指す指', 'Tsuki o sasu yubi', 'The finger pointing at the moon is not the moon.', [], ['koan']),
    # ---- the stone garden
    ('一に掃除、二に信心', 'Ichi ni sōji, ni ni shinjin', 'First, sweeping. Second, faith. — a Zen temple saying', [], ['garden']),
    ('歩歩是道場', 'Hoho kore dōjō', 'Every step is the place of practice.', [], ['garden']),
    ('本来無一物', 'Honrai muichimotsu', 'From the first, not one thing exists. Where could dust gather? — the Sixth Patriarch', [], ['garden']),
    ('山是山、水是水', 'Yama kore yama, mizu kore mizu', 'Mountains are mountains; waters are waters.', [], ['garden', 'water']),
    ('脚下照顧', 'Kyakka shōko', 'Shine the light on the ground beneath your own feet.', [], ['garden']),
    ('閑坐聴松風', 'Kanza shite shōfū o kiku', 'Sit quietly and listen to the wind in the pines.', [], ['garden']),
    ('柳緑花紅', 'Ryūryoku kakō', 'The willow is green, the flower is red: things as they are.', [], ['garden']),
    ('白雲自去来', 'Hakuun onozukara kyorai', 'White clouds come and go of themselves.', [], ['garden']),
    ('直心是道場', 'Jikishin kore dōjō', 'The straightforward mind is the place of practice. — the Vimalakīrti Sutra', [], ['garden']),
    # ---- the gate: arriving, not fighting
    ('三十六計逃げるに如かず', 'Sanjūrokkei nigeru ni shikazu', 'Of the thirty-six stratagems, none is better than running.', [], ['gate']),
    ('逃げるが勝ち', 'Nigeru ga kachi', 'To run is to win.', [], ['gate']),
    ('君子危うきに近寄らず', 'Kunshi ayauki ni chikayorazu', 'The wise do not go near danger.', [], ['gate']),
    ('触らぬ神に祟りなし', 'Sawaranu kami ni tatari nashi', 'A god you do not touch lays no curse on you.', [], ['gate']),
    ('戦わずして勝つ', 'Tatakawazu shite katsu', 'To win without fighting: the height of strategy, from Sun Tzu, whom every samurai studied.', [], ['gate']),
    ('旅は道連れ世は情け', 'Tabi wa michizure, yo wa nasake', 'On a journey, a companion; in life, kindness.', [], ['gate']),
    ('かわいい子には旅をさせよ', 'Kawaii ko ni wa tabi o saseyo', 'Send the child you love on a journey.', [], ['gate']),
    ('門前の小僧習わぬ経を読む', 'Monzen no kozō narawanu kyō o yomu', 'The boy at the temple gate chants sutras no one taught him.', [], ['gate']),
    ('笑う門には福来る', 'Warau kado ni wa fuku kitaru', 'Fortune comes in at the gate where there is laughter.', [], ['gate']),
    # ---- the ink stone: saving, waiting, preparing
    ('墨を磨るは病夫の如く', 'Sumi o suru wa byōfu no gotoku', 'Grind the ink like an invalid; wield the brush like a warrior.', [], ['stone']),
    ('文房四宝', 'Bunbō shihō', 'The Four Treasures of the Study: brush, ink, paper, inkstone.', [], ['stone']),
    ('墨に五彩あり', 'Sumi ni gosai ari', 'In ink there are five colours.', [], ['stone']),
    ('備えあれば憂いなし', 'Sonae areba urei nashi', 'If you are prepared, you have nothing to fear.', [], ['stone']),
    ('果報は寝て待て', 'Kahō wa nete mate', 'Good fortune: sleep, and wait for it.', [], ['stone', 'wait']),
    ('雨垂れ石を穿つ', 'Amadare ishi o ugatsu', 'Dripping rain wears through stone.', [], ['stone']),
    ('大器晩成', 'Taiki bansei', 'A great vessel is long in the making.', [], ['stone']),
    ('腹八分目', 'Hara hachibunme', 'Eat until you are eight parts full.', [], ['stone']),
    ('一銭を笑う者は一銭に泣く', 'Issen o warau mono wa issen ni naku', 'Whoever laughs at one sen will weep over one sen.', [], ['stone']),
    # ---- no sword
    ('無刀取り', 'Mutō-dori', 'Taking the sword with no sword: the art Yagyū Muneyoshi showed Tokugawa Ieyasu in 1594.', [], ['nocut']),
    ('無手勝流', 'Mutekatsu-ryū', "The school of winning with no hands: Tsukahara Bokuden's answer to a braggart, whom he left stranded on an island.", [], ['nocut', 'water']),
    ('鞘の内', 'Saya no uchi', 'Victory while the blade is still in the scabbard.', [], ['nocut']),
    ('抜かぬ太刀の高名', 'Nukanu tachi no kōmyō', 'The renown of the sword that is never drawn.', [], ['nocut']),
    ('不殺生', 'Fusesshō', 'Not to take life: the first of the Buddhist precepts.', [], ['nocut']),
    ('和を以て貴しとなす', 'Wa o motte tōtoshi to nasu', "Harmony is to be valued above all. — Prince Shōtoku's constitution, 604", [], ['nocut']),
    ('剣は心なり', 'Ken wa kokoro nari', 'The sword is the mind. If the mind is not right, the sword cannot be. — Shimada Toranosuke', [], ['nocut']),
    ('仏の顔も三度', 'Hotoke no kao mo sando', "Even a Buddha's patience lasts only three times.", [], ['nocut']),
    ('情けは人の為ならず', 'Nasake wa hito no tame narazu', "Kindness is not only for the other's sake: it comes back.", [], ['nocut']),
    # ---- daruma
    ('七転び八起き', 'Nana korobi ya oki', 'Fall seven times; rise eight.', [], ['daruma']),
    ('面壁九年', 'Menpeki kunen', 'Nine years facing the wall: Bodhidharma at Shaolin, and any long, single-minded effort since.', [], ['daruma']),
    ('達磨さんが転んだ', 'Daruma-san ga koronda', "'Daruma fell down': the children's game where you may move only while the caller's back is turned.", [], ['daruma']),
    ('不識', 'Fushiki', "The emperor asked: who is it that stands before me? Bodhidharma said: I don't know.", [], ['daruma']),
    ('廓然無聖', 'Kakunen mushō', 'What is the first principle of the holy teaching? Vast emptiness, and nothing holy. — Bodhidharma', [], ['daruma']),
    ('不立文字', 'Furyū monji', 'No reliance on words and letters: the Zen that Bodhidharma carried.', [], ['daruma']),
    ('直指人心', 'Jikishi ninshin', 'Pointing directly at the human mind.', [], ['daruma']),
    ('見性成仏', 'Kenshō jōbutsu', 'See your own nature, and become Buddha.', [], ['daruma']),
    # ---- tanuki
    ('捕らぬ狸の皮算用', "Toranu tanuki no kawazan'yō", 'Counting the pelts of tanuki you have not yet caught.', [], ['tanuki']),
    ('狸寝入り', 'Tanuki neiri', 'Tanuki sleep: pretending to be asleep.', [], ['tanuki']),
    ('化けの皮が剥がれる', 'Bake no kawa ga hagareru', 'The skin of the disguise peels away.', [], ['tanuki']),
    ('同じ穴の狢', 'Onaji ana no mujina', 'Badgers of the same hole: they are in it together.', [], ['tanuki']),
    ('狐と狸の化かし合い', 'Kitsune to tanuki no bakashiai', 'A fox and a tanuki trying to out-trick each other.', [], ['tanuki', 'kitsune']),
    ('人は見かけによらぬもの', 'Hito wa mikake ni yoranu mono', 'People are not what they appear.', [], ['tanuki']),
    ('分福茶釜', 'Bunbuku chagama', 'The tea kettle that grew a tail: a tanuki who repaid a kindness by turning himself into a kettle for the temple Morin-ji.', [], ['tanuki']),
    # ---- soul-flames and the red thread
    ('運命の赤い糸', 'Unmei no akai ito', 'The red thread of fate, tied between two who are meant to meet.', [], ['hitodama']),
    ('一蓮托生', 'Ichiren takushō', 'To be reborn together on one lotus: to share a fate, whatever it is.', [], ['hitodama']),
    ('比翼連理', 'Hiyoku renri', 'Birds that share a wing; trees whose branches have grown together.', [], ['hitodama']),
    ('縁は異なもの味なもの', 'En wa ina mono, aji na mono', 'The ties between people are strange things, and delightful ones.', [], ['hitodama']),
    ('会うは別れの始め', 'Au wa wakare no hajime', 'To meet is the beginning of parting.', [], ['hitodama']),
    ('腐れ縁', 'Kusare-en', 'A bond that has gone bad and still will not break.', [], ['hitodama']),
    # ---- the death god
    ('生者必滅', 'Shōja hitsumetsu', 'All that lives must perish.', [], ['shinigami']),
    ('会者定離', 'Esha jōri', 'Those who meet must part.', [], ['shinigami']),
    ('九死に一生を得る', 'Kyūshi ni isshō o eru', 'Nine deaths and one life: the narrowest of escapes.', [], ['shinigami']),
    ('命あっての物種', 'Inochi atte no monodane', 'Life is the seed of everything: while you have it, the rest can follow.', [], ['shinigami']),
    ('散る桜残る桜も散る桜', 'Chiru sakura / nokoru sakura mo / chiru sakura', 'Falling blossoms. Those still on the branch are falling blossoms too. — Ryōkan', [], ['shinigami']),
    ('無常迅速', 'Mujō jinsoku', 'Impermanence is swift.', [], ['shinigami']),
    ('一寸の虫にも五分の魂', 'Issun no mushi ni mo gobu no tamashii', 'Even an inch-long insect has half an inch of soul.', [], ['shinigami']),
    ('虎は死して皮を留め人は死して名を残す', 'Tora wa shishite kawa o todome, hito wa shishite na o nokosu', 'A tiger dies and leaves its skin; a man dies and leaves his name.', [], ['shinigami']),
    # ---- wind
    ('風前の灯火', 'Fūzen no tomoshibi', 'A lamp before the wind.', [], ['wind', 'chochin']),
    ('神風', 'Kamikaze', 'The divine wind: the typhoons that wrecked the Mongol fleets in 1274 and 1281.', [], ['wind']),
    ('疾風に勁草を知る', 'Shippū ni keisō o shiru', 'In a gale you learn which grass is strong.', [], ['wind']),
    ('順風満帆', 'Junpū manpan', 'A fair wind and a full sail.', [], ['wind']),
    ('馬耳東風', 'Baji tōfū', "The east wind in a horse's ear.", [], ['wind']),
    ('風が吹けば桶屋が儲かる', 'Kaze ga fukeba okeya ga mōkaru', 'When the wind blows, the cooper profits: everything is connected, at some remove.', [], ['wind']),
    ('物言えば唇寒し秋の風', 'Mono ieba / kuchibiru samushi / aki no kaze', 'When I speak, my lips are cold: the autumn wind. — Bashō', [], ['wind']),
    # ---- rain
    ('雨降って地固まる', 'Ame futte ji katamaru', 'After the rain, the ground is firmer.', [], ['rain']),
    ('五月雨を集めて早し最上川', 'Samidare o / atsumete hayashi / Mogami-gawa', 'Gathering all the rains of early summer, how swift it runs: the Mogami river. — Bashō', [], ['rain']),
    ('晴耕雨読', 'Seikō udoku', 'Plough when it is fine; read when it rains.', [], ['rain']),
    ('雨後の筍', 'Ugo no takenoko', 'Bamboo shoots after rain: one thing after another, all at once.', [], ['rain']),
    ('遣らずの雨', 'Yarazu no ame', 'The rain that will not let a guest leave.', [], ['rain']),
    ('干天の慈雨', 'Kanten no jiu', 'Merciful rain from a dry sky.', [], ['rain']),
    ('春雨じゃ、濡れて参ろう', 'Harusame ja, nurete mairō', 'It is spring rain. Let us go and get wet. — the swordsman Tsukigata Hanpeita, on the stage', [], ['rain']),
    # ---- snow
    ('柳に雪折れなし', 'Yanagi ni yukiore nashi', 'The willow is never broken by snow.', [], ['snow']),
    ('是がまあつひの栖か雪五尺', 'Kore ga maa / tsui no sumika ka / yuki goshaku', 'So this is to be my last home? Five feet of snow. — Issa', [], ['snow']),
    ('初雪や水仙の葉のたわむまで', 'Hatsuyuki ya / suisen no ha no / tawamu made', 'First snow: just enough to bend the leaves of the narcissus. — Bashō', [], ['snow']),
    ('蛍雪の功', 'Keisetsu no kō', 'What is won by study in the light of fireflies and of snow.', [], ['snow']),
    ('雪月花', 'Setsugetsuka', 'Snow, moon, flowers: the three beauties of the turning year.', [], ['snow']),
    ('雪中の松柏', 'Setchū no shōhaku', 'Pine and cypress in the snow: constancy shows in hard weather.', [], ['snow']),
    # ---- night
    ('闇夜の提灯', 'Yamiyo no chōchin', 'A lantern on a dark night: help when you most wanted it.', [], ['night', 'chochin']),
    ('月夜に提灯', 'Tsukiyo ni chōchin', 'A lantern on a moonlit night: something you did not need.', [], ['night', 'chochin']),
    ('闇夜に鉄砲', 'Yamiyo ni teppō', 'A gun fired on a dark night: a shot at nothing.', [], ['night']),
    ('明けない夜はない', 'Akenai yoru wa nai', 'There is no night that does not end.', [], ['night']),
    ('名月を取ってくれろと泣く子かな', 'Meigetsu o / totte kurero to / naku ko kana', 'Fetch me the harvest moon! cries the child. — Issa', [], ['night']),
    ('夜目遠目笠の内', 'Yome tōme kasa no uchi', 'Seen by night, from far off, or under a hat: everything looks fairer.', [], ['night']),
    # ---- shikigami
    ('毒を以て毒を制す', 'Doku o motte doku o seisu', 'Use poison to master poison.', [], ['shiki']),
    ('昨日の敵は今日の友', 'Kinō no teki wa kyō no tomo', "Yesterday's enemy is today's friend.", [], ['shiki']),
    ('急急如律令', 'Kyūkyū nyo ritsuryō', 'Swiftly, as the law commands: the words that close an onmyōji\'s spell.', [], ['shiki']),
    ('適材適所', 'Tekizai tekisho', 'The right timber in the right place.', [], ['shiki']),
    ('餅は餅屋', 'Mochi wa mochiya', 'For rice cakes, go to the rice-cake maker.', [], ['shiki']),
    ('虎の威を借る狐', 'Tora no i o karu kitsune', "The fox who borrows the tiger's majesty.", [], ['shiki']),
    ('飼い犬に手を噛まれる', 'Kaiinu ni te o kamareru', 'To have your hand bitten by your own dog.', [], ['shiki']),
    # ---- wet ink: the brush
    ('弘法も筆の誤り', 'Kōbō mo fude no ayamari', "Even Kōbō Daishi's brush sometimes slips: Kūkai, founder of Shingon and Japan's most revered calligrapher.", [], ['wet']),
    ('余白の美', 'Yohaku no bi', 'The beauty of what is left blank.', [], ['wet']),
    ('不動智', 'Fudōchi', 'Immovable wisdom: the mind that stops nowhere, and so is everywhere. — Takuan, writing to the swordsman Yagyū', [], ['wet', 'wait']),
    ('活人剣', 'Katsujinken', 'The sword that gives life: skill great enough that it need not kill. — Yagyū Munenori', [], ['wet', 'bigoni']),
    ('守破離', 'Shu ha ri', 'Keep the form. Break the form. Leave the form.', [], ['wet']),
    ('和敬清寂', 'Wa kei sei jaku', 'Harmony, respect, purity, tranquillity: the four principles of tea. — Sen no Rikyū', [], ['wet']),
    ('日日是好日', 'Nichinichi kore kōnichi', 'Every day is a good day. — Unmon', [], ['wet']),
    ('無心', 'Mushin', 'No-mind: the hand moves and nothing stands between it and the stroke.', [], ['wet']),
    ('一日作さざれば一日食らわず', 'Ichinichi nasazareba ichinichi kurawazu', 'A day without work is a day without eating. — Hyakujō', [], ['wet', 'long']),
    # ---- enso: the circle
    ('円相', 'Ensō', 'A circle drawn in one breath. Nothing is lacking; nothing is in excess.', [], ['enso']),
    ('吾唯足知', 'Ware tada taru o shiru', 'I know only what is enough. — carved on the water basin at Ryōan-ji', [], ['enso', 'water']),
    ('色即是空', 'Shiki soku ze kū', 'Form is emptiness. — the Heart Sutra', [], ['enso']),
    ('空即是色', 'Kū soku ze shiki', 'Emptiness is form. — the Heart Sutra', [], ['enso']),
    ('無念無想', 'Munen musō', 'No thought, no reflection: a mind with nothing in the way.', [], ['enso']),
    ('先の先', 'Sen no sen', 'To move before the other has decided to.', [], ['enso', 'short']),
    ('一行三昧', 'Ichigyō zanmai', 'Whole absorption in a single act.', [], ['enso']),
    ('万法一に帰す', 'Manbō ichi ni kisu', 'The ten thousand things return to the one.', [], ['enso', 'crowd']),
    ('朝顔に釣瓶とられてもらい水', 'Asagao ni / tsurube torarete / morai mizu', 'A morning glory has taken my well-bucket. I go to borrow water. — Chiyo-ni', [], ['enso', 'water']),
]
RULE_TAGS = ('koan', 'wet', 'enso', 'garden', 'gate', 'stone', 'nocut', 'wind', 'rain', 'snow', 'night', 'shiki')
# the more particular a stage's rule, the more its own sayings are preferred
RULE_WEIGHT = {'wet': 4, 'enso': 5, 'koan': 6, 'garden': 6, 'gate': 6, 'stone': 7, 'nocut': 7, 'wind': 8, 'rain': 8, 'snow': 8, 'night': 8, 'shiki': 9}
KINDS = {'d': 'daruma', 'a': 'tanuki', 'A': 'tanuki', 'e': 'hitodama', 'X': 'shinigami',
         'c': 'chochin', 'o': 'oni', 'O': 'bigoni', 'S': 'bigoni', 't': 'tengu', 'T': 'tengu', 'k': 'kitsune', 'y': 'yurei',
         'u': 'kasa', 'p': 'kappa', 'P': 'kappa', 'n': 'nurikabe', 'W': 'yukionna', 'G': 'gasha', 'Q': 'kitsune'}
used_says = {}     # saying index -> the chapters it has been used in
MAX_USES = 3       # a saying may appear three times in the whole game, never twice in one chapter

def features(b, trace):
    """What a stage is about: its yokai, its ground, and the shape of its answer."""
    text = ''.join(b['rows'])
    f = set(KINDS[ch] for ch in text if ch in KINDS)
    for ch, name in (('~', 'water'), ('i', 'ice'), ('f', 'fire'), ('#', 'rock')):
        if ch in text:
            f.add(name)
    counts = {}
    for ch in text:
        if ch in KINDS:
            counts[ch] = counts.get(ch, 0) + 1
    if any(v >= 2 for v in counts.values()):
        f.add('twins')
    if sum(counts.values()) >= 7:
        f.add('crowd')
    strokes = [s.strip() for s in trace.split('/')]
    if any(s == '' for s in strokes):
        f.add('wait')
    for w in ('leap', 'ward'):
        if w in trace:
            f.add(w)
    if 'KATSU' in trace:
        f.add('katsu')
    if b['par'] >= 7:
        f.add('long')
    if b['par'] <= 3:
        f.add('short')
    f.update('wind' if r.startswith('wind') else r for r in (b.get('rules') or []))
    return f

def pick_saying(b, trace, chapter):
    """The unused saying that fits this stage best: its board and answer first, its place second."""
    f = features(b, trace)
    best, best_score = None, 0
    for i, (jp, ro, en, chs, tags) in enumerate(SAY):
        seen = used_says.get(i, [])
        if len(seen) >= MAX_USES or chapter in seen:
            continue
        rule = [t for t in tags if t in RULE_TAGS]
        if rule and not any(t in f for t in rule):
            continue
        if not rule and any(t in f for t in RULE_TAGS):
            continue   # the epilogue chapters speak only in their own voice
        # common ground (stone, water) says less about a stage than its yokai or its answer
        weight = {'rock': 1, 'water': 2}
        hits = sum(1 for t in tags if t in f and t not in RULE_TAGS)
        score = sum(weight.get(t, 3) for t in tags if t in f and t not in RULE_TAGS) + (2 if chapter in chs else 0) + max([RULE_WEIGHT[t] for t in rule if t in f] or [0])
        if chs and chapter not in chs and hits == 0:
            continue
        if not chs and not tags:
            score = 0.5
        score -= 1.5 * len(seen)   # prefer one not yet heard
        if score > best_score:
            best, best_score = i, score
    if best is None and any(t in f for t in RULE_TAGS):
        # this style's own sayings are all spoken for: fall back on the common stock
        for i, (jp, ro, en, chs, tags) in enumerate(SAY):
            seen = used_says.get(i, [])
            if len(seen) >= MAX_USES or chapter in seen or chs or any(t in RULE_TAGS for t in tags):
                continue
            score = sum(3 for t in tags if t in f) + 0.5
            if score > best_score:
                best, best_score = i, score
    if best is None:
        return []
    used_says.setdefault(best, []).append(chapter)
    return list(SAY[best][:3])

# A line of history or legend about each chapter's place, shown on the road map.
NOTES = [
    'Rashōmon was the great southern gate of Heian-kyō, today\'s Kyoto. By the tenth century it stood in ruins, and legend says the warrior Watanabe no Tsuna cut off an oni\'s arm there.',
    'Mount Kurama rises north of Kyoto. The boy Ushiwakamaru, later the general Minamoto no Yoshitsune, is said to have learned the sword there from Sōjōbō, king of the tengu.',
    'Shinoda is a forest in old Izumi province. In legend the white fox Kuzunoha lived there, and her son became Abe no Seimei (921–1005), the great diviner of the Heian court.',
    'Mount Ōe was the stronghold of the oni king Shuten-dōji, who in legend was slain by Minamoto no Raikō and his four retainers, Watanabe no Tsuna among them, after they drugged his wine.',
    'On Nasu moor stands the Sesshō-seki, the Killing Stone, said to be the body of the nine-tailed fox Tamamo-no-Mae. Tradition says the monk Gennō split it in 1385.',
    'The snow country lies along the Japan Sea, buried each winter. There the Yuki-onna, the snow woman, is said to appear to travellers lost in blizzards.',
    'Kappa-buchi is a stream at Tōno in the north, long said to be full of kappa. They love cucumbers and sumo, and lose their strength if the water in the dish on their head is spilled.',
    'Adashino, west of Kyoto, was a burial ground where the dead were once left in the open. Some eight thousand stone markers for the unmourned now stand at Adashino Nenbutsu-ji.',
    'Osore-zan, in the far north, is one of Japan\'s three great sacred mountains: a sulphurous caldera held to be an entrance to the afterlife, with its own Sanzu River to cross.',
    'Hyakki Yagyō, the night parade of a hundred demons, was dreaded in Heian Kyoto. On the nights it was expected, the nobility stayed indoors rather than meet it.',
    'Zen took root in Japan in the 12th and 13th centuries with the monks Eisai and Dōgen. A kōan is a question set by a teacher that reasoning alone cannot answer.',
    'The dry garden, karesansui, uses raked gravel for water and stones for mountains. The most famous, at Ryōan-ji in Kyoto, has fifteen stones laid so that one is always hidden from view.',
    'A torii marks the boundary between the everyday world and sacred ground at a Shinto shrine. At Fushimi Inari in Kyoto, thousands of vermilion gates line the mountain path.',
    'Ink painting came to Japan with Zen. Its masters, among them Sesshū (1420–1506), whose Long Scroll hangs above this road, prized the stroke that cannot be corrected.',
    'The ensō is a circle brushed in a single movement by Zen monks, both as practice and as a portrait of the mind at that moment.',
    'Brush, ink, paper and inkstone are the Four Treasures of the Study. Ink is a solid stick, ground with water on the stone before each sitting, and the grinding itself was held to settle the mind.',
    'Mutō, no sword, was the pride of the Yagyū Shinkage school: disarming a swordsman with bare hands. Yagyū Muneyoshi showed it to Tokugawa Ieyasu in 1594, and his family became sword teachers to the shoguns.',
    'Daruma dolls are modelled on Bodhidharma, who carried Zen from India to China and is said to have sat facing a wall for nine years. Weighted to right themselves, they are sold without eyes: one is painted in when a wish is made, the other when it comes true.',
    'The tanuki, or raccoon dog, is a real animal and a famous shapeshifter of folklore, changing form with a leaf on its head. In the tale Bunbuku Chagama one turns itself into a tea kettle at the temple Morin-ji.',
    'Hitodama are pale balls of fire said to be souls leaving the body. The red thread of fate, a belief shared across East Asia, joins two people who are destined to meet.',
    'Typhoons destroyed the Mongol invasion fleets of 1274 and 1281 off Kyushu. The storms were named kamikaze, the divine wind.',
    'Tsuyu, the plum rains, soak Japan for about six weeks each early summer. Rivers rise, and in the old stories the kappa rise with them.',
    'The snow country along the Japan Sea can lie under several metres each winter. The poet Issa, who was born and died in it, wrote: so this is my last home? Five feet of snow.',
    'Before electric light, travellers carried paper lanterns painted with their house crest. In the game Hyakumonogatari a hundred ghost stories were told through the night, and one light put out after each.',
    'Onmyōdō, the Way of Yin and Yang, was the court science of divination and protection in Heian Japan. Its most famous master, Abe no Seimei (921–1005), is said to have commanded twelve shikigami.',
    'The shinigami, a spirit that draws people toward death, appears in Edo-period puppet plays about lovers\' suicides and in the 1841 picture book Ehon Hyaku Monogatari.',
]

# A few words between Suzu and her master at the middle and the end of each style chapter.
T, Z = 'Tessai', 'Suzu'
BEATS = {
    10: ([[T, 'A monk asked Jōshū whether a dog has Buddha-nature. Jōshū said 無. Monks have sat with that one word for a thousand years.'], [Z, 'What does it mean?'], [T, 'It means stop asking and paint.']],
         [[T, 'The last case. 百尺竿頭一歩を進む: from the top of a hundred-foot pole, take one step more.'], [Z, 'There is no more pole.'], [T, 'Yes.']]),
    11: ([[Z, "I keep leaving one stone's shadow unraked."], [T, 'Then you began in the wrong place. 脚下照顧. Look at where you are standing before you look at where you are going.']],
         [[T, 'Musō Soseki, who laid out the great temple gardens, taught that whoever tells the garden apart from the practice has not found the Way.'], [Z, 'Then this is the practice.'], [T, 'It was the practice ten gardens ago. Go on.']]),
    12: ([[Z, 'Running feels like losing.'], [T, 'Sun Tzu wrote: 百戦百勝は善の善なる者に非ず. To win a hundred battles in a hundred is not the highest skill. To prevail without fighting is.']],
         [[T, 'The last gate. A torii has no doors. Nothing has ever been keeping you out.'], [Z, 'Only what stands in front of it.'], [T, 'Only that.']]),
    13: ([[T, 'Sesshū was tied to a temple pillar as a boy, for drawing when he should have been chanting. He drew a mouse on the floor in his own tears, with his toe, so well that the abbot let him paint.'], [Z, 'Wet ink.'], [T, 'The wettest.']],
         [[T, '一期一会. This stroke, on this paper, once. Let the last one be a wall you are glad to have built.']]),
    14: ([[Z, 'My circles do not close cleanly.'], [T, 'Nor do mine. An ensō left a little open is still an ensō. The gap is where the rest of the world gets in.']],
         [[T, 'Draw the last one as if it were the only one.'], [Z, 'It is the only one.'], [T, 'Now you sound like a monk. Go.']]),
    15: ([[T, 'Good ink sticks are kept for decades before anyone uses them. 古墨. The old ones grind smoother.'], [Z, 'Then waiting improves it.'], [T, 'Waiting improves most things that are not soup.']],
         [[T, '惜墨如金. Treasure ink like gold. One last time: spend nothing you do not have to, and then spend all of it at once.']]),
    16: ([[T, 'Tsukahara Bokuden was challenged on a ferry by a loud young swordsman. He proposed an island, let the man leap ashore first, and pushed the boat back out.'], [Z, 'He never drew.'], [T, 'He called it 無手勝流.']],
         [[T, 'The last of the empty-handed ones. 活人剣: the sword that gives life. Yours has not left its scabbard all chapter.']]),
    17: ([[Z, 'It got up again.'], [T, 'It will always get up again. That is not the daruma being difficult. That is the daruma showing you how.']],
         [[T, "When a daruma's wish is granted, its second eye is painted in. Let us see whether these have earned theirs."]]),
    18: ([[Z, 'Now I do not trust any of the stones.'], [T, 'Good. 人は見かけによらぬもの: nothing is what it appears. But most stones are stones. Do not spend your whole life checking.']],
         [[T, 'In the old tale the tea-kettle tanuki danced on a tightrope to make his poor master rich, and was honoured for it ever after. They are not wicked. They are only bored.']]),
    19: ([[Z, 'If I stand where one fell, it cannot come back.'], [T, '会うは別れの始め. To meet is the beginning of parting. You are only hurrying it along.']],
         [[T, 'The last pair. Be gentle. They have been looking for each other longer than the scroll has existed.']]),
    20: ([[T, 'Bashō wrote that the wind that moves the clouds had got into him, and he could not stop thinking of the road. 片雲の風にさそはれて.'], [Z, 'So he followed it.'], [T, 'For fifteen hundred miles. You need only follow it a tile at a time.']],
         [[T, '疾風に勁草を知る. In a gale you learn which grass is strong. Last gale.']]),
    21: ([[Z, 'The kappa are slower on land.'], [T, "Everyone is slower away from home. Remember that, the next time you are in someone else's water."]],
         [[T, 'After this the rains end. 梅雨明け. Finish before the lanterns dry out.']]),
    22: ([[T, 'Issa lost his mother at two, was sent away at thirteen, and came home to this snow country to die. He still wrote: 雪とけて村いっぱいの子どもかな.'], [Z, 'The snow melts, and the village is full of children.'], [T, 'He never stopped noticing.']],
         [[T, '雪中の松柏. Pine and cypress stay green in the snow. Be one of those.']]),
    23: ([[Z, 'I put out the lantern and lost the whole corner.'], [T, '月夜に提灯 is a lantern you did not need. 闇夜の提灯 is one you did. Learn to tell which night it is.']],
         [[T, 'In the game of a hundred tales, when the last light is put out, something is supposed to come. Put it out anyway.']]),
    24: ([[T, "Seimei's wife could not bear the faces of his shikigami, so he kept them under the Modori bridge, and not in the house."], [Z, 'That seems unkind to them.'], [T, 'You have met them. Would you want one in the kitchen?']],
         [[T, 'Last board. Everything you have bound, everything you have learned, and no blade. 適材適所: the right one in the right place.']]),
    25: ([[Z, 'It never hurries.'], [T, 'It does not have to. 無常迅速. It is you who are quick, and getting quicker.']],
         [[T, 'Ryōkan wrote, near the end: 散る桜 残る桜も 散る桜. Go and meet it once more, and then let us have some tea.']]),
}

levels, sols, chapters, bosses = [], {}, [], []
NCH = len(CHAPTERS)
for c in ORDER:
    chapters.append({'kanji': CHAPTERS[c][0], 'name': CHAPTERS[c][1], 'from': len(levels), 'note': NOTES[c]})
    pools = {}
    for g in gen:
        if g['chapter'] == c:
            pools.setdefault(g['seg'], []).append(g)
    for k in pools:
        pools[k].sort(key=lambda g: (g['par'], g.get('ink', 4), g['score']))
    names = list(NAMES.get(c, []))
    started = set()
    rungs = ladder(c) if c >= STYLE_FROM else []
    slots = ['L%d' % k for k in range(len(rungs))] if c >= STYLE_FROM else LAYOUT[c]
    for slot in slots:
        if slot[0] == 'H':
            b = dict(hand[slot[1:]])
            b['rules'], b['ink'] = [], 4
            key = ''.join(b['rows'])
            if slot[1:] in BEAM:
                b['par'], trace = BEAM[slot[1:]]
            else:
                assert solved[key]['par'] > 0, slot
                b['par'], trace = solved[key]['par'], solved[key]['trace']
        else:
            seg = int(slot[1:])
            if slot[0] == 'L':
                g, seg = rungs[seg], 0
            elif not pools.get(seg):
                print('!! chapter %d segment %d ran out of boards' % (c, seg))
                continue
            else:
                g = pools[seg].pop(0)
            b = {'kanji': '', 'name': '', 'par': g['par'], 'waza': g['waza'], 'rows': g['rows'], 'hint': '', 'story': [], 'after': [],
                 'rules': g.get('rules') or [], 'ink': g.get('ink') or 4}
            trace = g['trace']
            st = STORY_ON.get((c, seg))
            if st and seg not in started:
                h = hand[st]
                b.update(kanji=h['kanji'], name=h['name'], hint=h['hint'], story=h['story'], after=h['after'])
            else:
                if names:
                    b['kanji'], b['name'] = names.pop(0)
                else:
                    # past the named ones, stages are numbered, as the cases of a koan collection are
                    k = len(levels) - chapters[-1]['from']
                    b['kanji'] = ('第%s則' if c == 10 else '其の%s') % NUM[k]
                    b['name'] = ('Case %d' if c == 10 else CHAPTERS[c][1] + ' %d') % (k + 1)
                b['say'] = pick_saying(b, trace, c)
            started.add(seg)
        b['sol'] = trace
        b.setdefault('say', [])
        b = {k: b[k] for k in ('kanji', 'name', 'par', 'waza', 'rules', 'ink', 'rows', 'hint', 'say', 'story', 'after', 'sol')}
        sols[b['kanji'] + '|' + ''.join(b['rows'])] = trace
        levels.append(b)
    if c in BEATS:
        first = chapters[-1]['from']
        n = len(levels) - first
        if n >= 4:
            mid, end = BEATS[c]
            if not levels[first + n // 2]['story']:
                levels[first + n // 2]['story'] = mid
            if not levels[-1]['story']:
                levels[-1]['story'] = end
    if c < 10 or c == ORDER[-1]:
        bosses.append(len(levels) - 1)

# the last board of all carries the ending
levels[-1]['after'] = [
    ['', 'Suzu closes the last circle. Inside it there is nothing at all: only paper, which is where everything was before it was anything.'],
    ['Tessai', 'Now you can paint.'],
]

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
for k, c in enumerate(ORDER):
    a = chapters[k]['from']
    b = chapters[k + 1]['from'] if k < NCH - 1 else len(levels)
    pars = [l['par'] for l in levels[a:b]]
    ny = [sum(ch in 'coOStTkyQupPnWGdaAeX' for r in l['rows'] for ch in r) for l in levels[a:b]]
    if not pars:
        continue
    print('  %-12s pars %s  mean %.1f   yokai mean %.1f' % (CHAPTERS[c][1], pars, sum(pars) / len(pars), sum(ny) / len(ny)))
