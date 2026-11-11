extends RefCounted
# Pure rules of Jozu. No randomness: every stage is a puzzle with a knowable answer.
# A turn is one brush stroke: a chain of steps/cuts/waza limited by ink, then the yokai answer.
#
# Terrain:  . floor   # stone   ~ water   i ice (you slide)   f fire (burns if you rest on it)
#           g torii gate (the goal of a gate stage)
#
# Stage rules (optional):
#   koan  one stroke only, and nothing answers it: clear the board or begin again
#   wet   the stroke just painted stays wet for the yokai's turn: a wall to them and to wind
#   enso  end a stroke beside where it began and every yokai inside the loop is bound
#   garden  no yokai: rake every open tile in one stroke
#   gate  reach the torii; nothing need be cut
#   nocut  the brush cannot cut: bind, drown, or go around
#   stone  ink left unspent is kept for the next stroke, up to INK_CAP

const DIRS = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DEF = {
	"c": ["chochin", 1], "o": ["oni", 2], "O": ["oni", 3], "S": ["oni", 5],
	"t": ["tengu", 1], "T": ["tengu", 2], "k": ["kitsune", 1], "y": ["yurei", 1], "Q": ["tamamo", 5],
	"u": ["kasa", 1], "p": ["kappa", 2], "P": ["kappa", 4], "n": ["nurikabe", 3],
	"W": ["yukionna", 3], "G": ["gasha", 7],
}
const GHOSTS = ["yurei", "yukionna"]
const INK_CAP = 8

static func new_state(rows, stats, rules = []):
	var s = {
		"w": rows[0].length(), "h": rows.size(), "rows": [], "yokai": [], "wards": [],
		"turn": 0, "hits": 0, "status": "play", "events": [],
		"ki": stats.ki, "ink_max": stats.ink, "ink": stats.ink,
		"leap": stats.leap, "ward": stats.ward, "katsu": stats.katsu,
		"mom": 0, "mom_dir": Vector2i.ZERO, "hero": Vector2i.ZERO, "visited": [],
		"wet": [], "r_koan": rules.has("koan"), "r_wet": rules.has("wet"), "r_enso": rules.has("enso"),
		"r_garden": rules.has("garden"), "r_gate": rules.has("gate"), "r_nocut": rules.has("nocut"),
		"r_stone": rules.has("stone"), "open": 0,
	}
	var id = 0
	for y in range(rows.size()):
		var line = ""
		for x in range(rows[y].length()):
			var ch = rows[y][x]
			if ch == "H":
				s.hero = Vector2i(x, y)
				line += "."
			elif DEF.has(ch):
				s.yokai.append({"id": id, "ch": ch, "kind": DEF[ch][0], "hp": DEF[ch][1], "max": DEF[ch][1], "pos": Vector2i(x, y)})
				id += 1
				line += "~" if DEF[ch][0] == "kappa" else "."
			else:
				line += ch
		s.rows.append(line)
	s.visited = [s.hero]
	for line in s.rows:
		for ch in line:
			if ch == "." or ch == "i":
				s.open += 1
	return s

static func key(s, full):
	var k = str(s.hero) + "|" + str(s.ki) + "|" + str(s.leap) + str(s.ward) + str(s.katsu) + "|" + str(s.wards)
	for y in s.yokai:
		k += "|" + y.ch + str(y.pos) + str(y.hp)
	if s.r_stone:
		k += "|i" + str(s.ink)
	if full:
		k += "|" + str(s.ink) + str(s.mom) + str(s.mom_dir) + str(s.visited)
	return k

static func inb(s, p):
	return p.x >= 0 and p.y >= 0 and p.x < s.w and p.y < s.h

static func ter(s, p):
	return s.rows[p.y][p.x]

# ground a person can stand on
static func walk(s, p):
	var c = s.rows[p.y][p.x]
	return c == "." or c == "i" or c == "f" or c == "g"

static func yokai_at(s, p):
	for i in range(s.yokai.size()):
		if s.yokai[i].pos == p:
			return i
	return -1

# may a yokai of this kind move onto p?
static func can_stand(s, kind, p):
	if not inb(s, p):
		return false
	if kind == "kappa":
		if ter(s, p) != "~":
			return false
	elif not GHOSTS.has(kind) and not walk(s, p):
		return false
	if p == s.hero or s.wards.has(p) or s.wet.has(p):
		return false
	return yokai_at(s, p) < 0

static func cut_power(s, d):
	if d == s.mom_dir:
		return min(3, 1 + s.mom)
	return 1

# Would yokai y strike a hero standing on p when the stroke ends?
static func threatens(s, y, p):
	var k = y.kind
	var q = y.pos
	if k == "kitsune" or k == "nurikabe":
		return false
	if k == "tengu":
		if p == q or (p.x != q.x and p.y != q.y):
			return false
		var d = Vector2i(sign(p.x - q.x), sign(p.y - q.y))
		var t = q + d
		while t != p:
			if ter(s, t) == "#" or s.wards.has(t) or s.wet.has(t) or yokai_at(s, t) >= 0:
				return false
			t += d
		return true
	if k == "gasha":
		return p != q and abs(p.x - q.x) <= 1 and abs(p.y - q.y) <= 1
	return abs(p.x - q.x) + abs(p.y - q.y) == 1

# Even-odd test: is tile q inside the closed loop of tiles?
static func _inside(loop, q):
	var inside = false
	var n = loop.size()
	for i in range(n):
		var a = loop[i]
		var b = loop[(i + 1) % n]
		if (a.y > q.y) != (b.y > q.y):
			var xc = a.x + float(b.x - a.x) * float(q.y - a.y) / float(b.y - a.y)
			if q.x < xc:
				inside = not inside
	return inside

# Indices of the yokai the current stroke would bind if it were sheathed now.
static func enso_bound(s):
	var out = []
	var n = s.visited.size()
	if not s.r_enso or n < 4:
		return out
	var a = s.visited[0]
	var b = s.visited[n - 1]
	if abs(a.x - b.x) + abs(a.y - b.y) != 1:
		return out
	for i in range(s.yokai.size()):
		if _inside(s.visited, s.yokai[i].pos):
			out.append(i)
	return out

# Tiles where sheathing the brush would cost a blow. Exact for where Suzu stands now and for
# any tile one step away.
static func danger(s):
	var out = {}
	if s.r_koan or s.r_garden:
		return out
	var bound = enso_bound(s)
	for y in range(s.h):
		for x in range(s.w):
			var p = Vector2i(x, y)
			if not walk(s, p):
				continue
			if ter(s, p) == "f":
				out[p] = true
				continue
			if s.r_wet:
				s.wet = s.visited.filter(func(v): return v != p)
			for i in range(s.yokai.size()):
				if p == s.hero and bound.has(i):
					continue
				if threatens(s, s.yokai[i], p):
					out[p] = true
					break
	s.wet = []
	return out

static func _check_win(s):
	if s.r_gate:
		return  # a gate stage is won by arriving, in _enter
	if s.r_garden:
		if s.status == "play" and s.visited.size() >= s.open:
			s.status = "won"
			s.turn += 1
		return
	if s.yokai.is_empty() and s.status == "play":
		s.status = "won"
		s.turn += 1

static func _enter(s, t, d, gain):
	s.hero = t
	s.visited.append(t)
	if d == s.mom_dir:
		s.mom += gain
	else:
		s.mom_dir = d
		s.mom = gain
	# foxes walk in your footsteps
	for y in s.yokai:
		if y.kind == "kitsune" or y.kind == "tamamo":
			var m = y.pos + d
			if can_stand(s, y.kind, m):
				y.pos = m
	if s.r_gate and ter(s, t) == "g" and s.status == "play":
		s.status = "won"
		s.turn += 1

# Strike the yokai on tile t from direction d. Returns true if the hero moved into the tile.
static func _cut(s, yi, t, d):
	var dmg = cut_power(s, d)
	var y = s.yokai[yi]
	y.hp -= dmg
	if y.hp <= 0:
		s.yokai.remove_at(yi)
		s.events.append({"t": "kill", "pos": t, "kind": y.kind, "dmg": dmg})
		if walk(s, t) and not s.visited.has(t):
			_enter(s, t, d, 1)
			return true
		s.mom = 0
	else:
		s.events.append({"t": "cut", "pos": t, "dmg": dmg})
		s.mom = 0
	return false

# On ice you keep going, gathering momentum, until something stops you.
static func _slide(s, d):
	while s.status == "play" and ter(s, s.hero) == "i":
		var t = s.hero + d
		if not inb(s, t):
			return
		var yi = yokai_at(s, t)
		if yi >= 0:
			if s.r_nocut or not _cut(s, yi, t, d):
				return
			continue
		if not walk(s, t) or s.visited.has(t):
			return
		_enter(s, t, d, 1)

static func act_move(s, d):
	if s.status != "play" or s.ink <= 0:
		return false
	var t = s.hero + d
	if not inb(s, t):
		return false
	var yi = yokai_at(s, t)
	if yi >= 0:
		if s.r_nocut:
			return false
		s.events = []
		s.ink -= 1
		if _cut(s, yi, t, d):
			_slide(s, d)
		_check_win(s)
		return true
	if not walk(s, t) or s.visited.has(t):
		return false
	s.events = []
	s.ink -= 1
	_enter(s, t, d, 1)
	_slide(s, d)
	_check_win(s)
	return true

# Shukuchi: leap over one tile of anything.
static func act_leap(s, d):
	if s.status != "play" or s.ink <= 0 or s.leap <= 0:
		return false
	var t = s.hero + d * 2
	if not inb(s, t) or not walk(s, t) or s.visited.has(t) or yokai_at(s, t) >= 0:
		return false
	s.events = [{"t": "leap", "pos": t}]
	s.ink -= 1
	s.leap -= 1
	_enter(s, t, d, 1)
	_slide(s, d)
	_check_win(s)
	return true

# Kekkai: paste a ward beside you. Yokai cannot enter it, tengu wind cannot pass it.
static func act_ward(s, d):
	if s.status != "play" or s.ink <= 0 or s.ward <= 0:
		return false
	var t = s.hero + d
	if not inb(s, t) or ter(s, t) != "." or s.wards.has(t) or yokai_at(s, t) >= 0:
		return false
	s.events = [{"t": "ward", "pos": t}]
	s.ink -= 1
	s.ward -= 1
	s.mom = 0
	s.wards.append(t)
	return true

# Katsu: a shout that hurls every yokai beside you one tile away.
static func act_katsu(s):
	if s.status != "play" or s.ink <= 0 or s.katsu <= 0:
		return false
	var any = false
	for d in DIRS:
		if inb(s, s.hero + d) and yokai_at(s, s.hero + d) >= 0:
			any = true
	if not any:
		return false
	s.events = [{"t": "katsu", "pos": s.hero}]
	s.ink -= 1
	s.katsu -= 1
	s.mom = 0
	for d in DIRS:
		var yi = yokai_at(s, s.hero + d)
		if yi < 0:
			continue
		var y = s.yokai[yi]
		var t = y.pos + d
		var swims = y.kind == "kappa" or GHOSTS.has(y.kind)
		if y.kind == "nurikabe":
			pass  # a wall does not move; it only cracks
		elif inb(s, t) and ter(s, t) == "~" and not swims and yokai_at(s, t) < 0:
			s.yokai.remove_at(yi)
			s.events.append({"t": "kill", "pos": t, "kind": y.kind, "dmg": 0})
			continue
		elif can_stand(s, y.kind, t):
			y.pos = t
			continue
		y.hp -= 1
		if y.hp <= 0:
			s.yokai.remove_at(yi)
			s.events.append({"t": "kill", "pos": y.pos, "kind": y.kind, "dmg": 1})
		else:
			s.events.append({"t": "cut", "pos": y.pos, "dmg": 1})
	_check_win(s)
	return true

static func _chase(s, y):
	var dx = s.hero.x - y.pos.x
	var dy = s.hero.y - y.pos.y
	var a = Vector2i(sign(dx), 0)
	var b = Vector2i(0, sign(dy))
	var order = [a, b]
	if abs(dy) > abs(dx):
		order = [b, a]
	if y.kind == "kasa":
		# the umbrella hops two tiles, clean over whatever is between
		for d in order:
			if d != Vector2i.ZERO and can_stand(s, y.kind, y.pos + d * 2):
				y.pos += d * 2
				return
	for d in order:
		if d == Vector2i.ZERO:
			continue
		if can_stand(s, y.kind, y.pos + d):
			y.pos += d
			return

const MOVERS = ["oni", "yurei", "yukionna", "kasa", "kappa", "gasha"]

# Sheathe the brush: all yokai strike first (exactly what the red wash showed), then move.
static func end_stroke(s):
	if s.status != "play":
		return
	s.events = []
	if s.r_koan or s.r_garden:
		# a koan has no second stroke; neither does a garden
		s.turn += 1
		s.status = "lost"
		return
	if s.r_enso:
		var bound = enso_bound(s)
		bound.reverse()
		for i in bound:
			var y = s.yokai[i]
			s.yokai.remove_at(i)
			s.events.append({"t": "kill", "pos": y.pos, "kind": y.kind, "dmg": 0})
		if s.yokai.is_empty():
			s.status = "won"
			s.turn += 1
			return
	if s.r_wet:
		s.wet = s.visited.filter(func(v): return v != s.hero)
	var struck = []
	for y in s.yokai:
		if threatens(s, y, s.hero):
			s.ki -= 1
			s.hits += 1
			struck.append(y.id)
			s.events.append({"t": "hit", "src": y.pos})
	if ter(s, s.hero) == "f":
		s.ki -= 1
		s.hits += 1
		s.events.append({"t": "hit", "src": s.hero})
	for y in s.yokai:
		if MOVERS.has(y.kind) and not struck.has(y.id):
			_chase(s, y)
	s.wet = []
	s.turn += 1
	s.ink = min(INK_CAP, s.ink_max + s.ink) if s.r_stone else s.ink_max
	s.mom = 0
	s.mom_dir = Vector2i.ZERO
	s.visited = [s.hero]
	if s.ki <= 0:
		s.status = "lost"
