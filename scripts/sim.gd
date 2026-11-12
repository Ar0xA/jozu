extends RefCounted
# Pure rules of Jozu. No randomness: every stage is a puzzle with a knowable answer.
# A turn is one brush stroke: a chain of steps/cuts/waza limited by ink, then the yokai answer.
#
# Terrain:  . floor   # stone   ~ water   i ice (you slide)   f fire (burns if you rest on it)
#           g torii gate (the goal of a gate stage)
#           m offering (walking yokai go to it instead of you, and eat instead of striking)
#           b plank bridge (planks you crossed fall in after the yokai's turn, with whatever is on them)
#           w spider's web (stepping in ends your stroke)
#           x a tile of the character to be written (write stages)
#
# Stage rules (optional):
#   koan    one stroke only, and nothing answers it: clear the board or begin again
#   wet     the stroke just painted stays wet for the yokai's turn: a wall to them and to wind
#   enso    end a stroke beside where it began and every yokai inside the loop is bound
#   garden  no yokai: rake every open tile in one stroke
#   gate    reach the torii; nothing need be cut
#   nocut   the brush cannot cut: bind, drown, or go around
#   stone   ink left unspent is kept for the next stroke, up to INK_CAP
#   shiki   a yokai bound by the circle becomes a shikigami you may place as an ally
#   wind:R  (L/U/D) each turn the wind carries light yokai one tile that way
#   rain    lanterns and fire are out; kappa leave the water
#   snow    all water is frozen to ice
#   night   (display only) you see near yourself and near light
#   order   the yokai are sealed in reading order: only the first one left can be harmed
#   write   paint every marked tile, over as many strokes as it takes; nothing need be cut
#
# Techniques: leap, ward, katsu, and bell (once: no yokai strikes or moves this turn)

const DIRS = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DEF = {
	"c": ["chochin", 1], "o": ["oni", 2], "O": ["oni", 3], "S": ["oni", 5],
	"t": ["tengu", 1], "T": ["tengu", 2], "k": ["kitsune", 1], "y": ["yurei", 1], "Q": ["tamamo", 5],
	"u": ["kasa", 1], "p": ["kappa", 2], "P": ["kappa", 4], "n": ["nurikabe", 3],
	"W": ["yukionna", 3], "G": ["gasha", 7],
	"d": ["daruma", 2], "a": ["tanuki", 1], "A": ["tanuki", 1], "e": ["hitodama", 1],
	"X": ["shinigami", 3], "K": ["kamaitachi", 1],
}
const GHOSTS = ["yurei", "yukionna", "shinigami"]
const HARMLESS = ["kitsune", "nurikabe", "tanuki", "hitodama"]
const LIGHT = ["chochin", "kasa", "yurei", "hitodama"]   # what the wind can carry
const MOVERS = ["oni", "yurei", "yukionna", "kasa", "kappa", "gasha", "shinigami", "kamaitachi"]
const WIND = {"R": Vector2i(1, 0), "L": Vector2i(-1, 0), "D": Vector2i(0, 1), "U": Vector2i(0, -1)}
const INK_CAP = 8
const HAND_MAX = 3

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
		"r_shiki": rules.has("shiki"), "r_rain": rules.has("rain"), "r_night": rules.has("night"),
		"wind": Vector2i.ZERO, "hand": [], "allies": [], "revive": [], "next_id": 0,
		"bell": stats.get("bell", 0), "stun": false, "r_order": rules.has("order"), "r_write": rules.has("write"),
		"inked": 0, "marks": 0,
	}
	for r in rules:
		if r.begins_with("wind:"):
			s.wind = WIND[r.substr(5)]
	var snow = rules.has("snow")
	var id = 0
	for y in range(rows.size()):
		var line = ""
		for x in range(rows[y].length()):
			var ch = rows[y][x]
			if ch == "H":
				s.hero = Vector2i(x, y)
				line += "."
			elif DEF.has(ch):
				s.yokai.append({"id": id, "ch": ch, "kind": DEF[ch][0], "hp": DEF[ch][1], "max": DEF[ch][1], "pos": Vector2i(x, y), "down": false})
				id += 1
				line += "~" if DEF[ch][0] == "kappa" else "."
			else:
				line += ch
		if snow:
			line = line.replace("~", "i")
		s.rows.append(line)
	s.next_id = id
	s.visited = [s.hero]
	for line in s.rows:
		for ch in line:
			if ch == "." or ch == "i":
				s.open += 1
			if ch == "x":
				s.marks += 1
	return s

static func key(s, full):
	var k = str(s.hero) + "|" + str(s.ki) + "|" + str(s.leap) + str(s.ward) + str(s.katsu) + "|" + str(s.wards)
	for y in s.yokai:
		k += "|" + y.ch + str(y.pos) + str(y.hp) + ("d" if y.down else "")
	if s.r_stone:
		k += "|i" + str(s.ink)
	if s.r_shiki:
		k += "|h" + str(s.hand) + str(s.allies)
	k += "|" + "".join(s.rows) + str(s.bell) + str(s.inked)
	if full:
		k += "|" + str(s.ink) + str(s.mom) + str(s.mom_dir) + str(s.visited) + str(s.revive) + str(s.stun)
	return k

static func inb(s, p):
	return p.x >= 0 and p.y >= 0 and p.x < s.w and p.y < s.h

static func ter(s, p):
	return s.rows[p.y][p.x]

# ground a person can stand on
static func walk(s, p):
	var c = s.rows[p.y][p.x]
	return c == "." or c == "i" or c == "f" or c == "g" or c == "m" or c == "b" or c == "w" or c == "x"

static func _put(s, p, ch):
	var row = s.rows[p.y]
	s.rows[p.y] = row.substr(0, p.x) + ch + row.substr(p.x + 1)

# under the order rule every yokai but the first one left is sealed: it cannot be harmed
static func is_sealed(s, yi):
	return s.r_order and yi > 0

# a walking yokai on an offering is busy eating
static func eating(s, y):
	return ter(s, y.pos) == "m" and not GHOSTS.has(y.kind)

static func yokai_at(s, p):
	for i in range(s.yokai.size()):
		if s.yokai[i].pos == p:
			return i
	return -1

static func ally_at(s, p):
	for i in range(s.allies.size()):
		if s.allies[i].pos == p:
			return i
	return -1

# a tanuki that has not yet shown itself is, to all appearances, a stone
static func hidden(y):
	return y.ch == "a"

# may a yokai of this kind move onto p?
static func can_stand(s, kind, p):
	if not inb(s, p):
		return false
	if kind == "kappa":
		if ter(s, p) != "~" and not (s.r_rain and walk(s, p)):
			return false
	elif not GHOSTS.has(kind) and not walk(s, p):
		return false
	if p == s.hero or s.wards.has(p) or s.wet.has(p):
		return false
	return yokai_at(s, p) < 0 and ally_at(s, p) < 0

static func cut_power(s, d):
	if d == s.mom_dir:
		return min(3, 1 + s.mom)
	return 1

# Is there a clear straight line from q to p? Stone, wards, wet ink, yokai and shikigami block it.
static func los(s, q, p):
	if p == q or (p.x != q.x and p.y != q.y):
		return false
	var d = Vector2i(sign(p.x - q.x), sign(p.y - q.y))
	var t = q + d
	while t != p:
		if ter(s, t) == "#" or s.wards.has(t) or s.wet.has(t) or yokai_at(s, t) >= 0 or ally_at(s, t) >= 0:
			return false
		t += d
	return true

# Does something of this kind standing on q reach tile p?
static func reaches(s, kind, q, p):
	if kind == "tengu":
		return los(s, q, p)
	if kind == "gasha":
		return p != q and abs(p.x - q.x) <= 1 and abs(p.y - q.y) <= 1
	return abs(p.x - q.x) + abs(p.y - q.y) == 1

# Would yokai y strike a hero standing on p when the stroke ends?
static func threatens(s, y, p):
	if HARMLESS.has(y.kind) or s.stun or eating(s, y):
		return false
	if y.kind == "daruma" and y.down:
		return false
	if y.kind == "chochin" and s.r_rain:
		return false
	return reaches(s, y.kind, y.pos, p)

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
		if not is_sealed(s, i) and _inside(s.visited, s.yokai[i].pos):
			out.append(i)
	return out

# Tiles where sheathing the brush would cost a blow. Where Suzu stands now is exact: the turn
# is played out on a copy. Other tiles show the yokai's reach as things stand.
static func danger(s):
	var out = {}
	if s.r_koan or s.r_garden or s.status != "play":
		return out
	for y in range(s.h):
		for x in range(s.w):
			var p = Vector2i(x, y)
			if not walk(s, p) or p == s.hero:
				continue
			if ter(s, p) == "f":
				if not s.r_rain:
					out[p] = true
				continue
			if s.r_wet:
				s.wet = s.visited.filter(func(v): return v != p)
			for yk in s.yokai:
				if threatens(s, yk, p):
					out[p] = true
					break
	s.wet = []
	var c = s.duplicate(true)
	end_stroke(c)
	if c.hits > s.hits:
		out[s.hero] = true
	return out

static func _check_win(s):
	if s.r_gate or s.r_write:
		return  # a gate stage is won by arriving, a character by its last tile: both in _enter
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
	if ter(s, t) == "w":
		s.ink = 0   # caught in the web: the stroke ends here
	if s.r_write and ter(s, t) == "x":
		s.inked |= 1 << (t.y * s.w + t.x)
		var n = 0
		for i in range(s.w * s.h):
			if s.inked & (1 << i):
				n += 1
		if n >= s.marks and s.status == "play":
			s.status = "won"
			s.turn += 1

# A yokai has left the board, by whatever means.
static func _gone(s, y):
	if y.kind == "hitodama":
		s.revive.append(y.pos)   # while another soul-flame burns, this one will relight

# Hurt yokai yi. A daruma only ever topples, once per stroke. Returns true if it is gone.
static func _hurt(s, yi, dmg):
	var y = s.yokai[yi]
	if is_sealed(s, yi):
		return false
	if y.kind == "daruma":
		if y.down:
			return false
		dmg = 1
	y.hp -= dmg
	if y.hp <= 0:
		s.yokai.remove_at(yi)
		_gone(s, y)
		s.events.append({"t": "kill", "pos": y.pos, "kind": y.kind, "dmg": dmg})
		return true
	if y.kind == "daruma":
		y.down = true
	s.events.append({"t": "cut", "pos": y.pos, "dmg": dmg})
	return false

# Strike the yokai on tile t from direction d. Returns true if the hero moved into the tile.
static func _cut(s, yi, t, d):
	if _hurt(s, yi, cut_power(s, d)):
		if walk(s, t) and not s.visited.has(t):
			_enter(s, t, d, 1)
			return true
	s.mom = 0
	return false

# On ice you keep going, gathering momentum, until something stops you.
static func _slide(s, d):
	while s.status == "play" and ter(s, s.hero) == "i":
		var t = s.hero + d
		if not inb(s, t) or ally_at(s, t) >= 0:
			return
		var yi = yokai_at(s, t)
		if yi >= 0:
			if s.r_nocut or hidden(s.yokai[yi]) or is_sealed(s, yi) or not _cut(s, yi, t, d):
				return
			continue
		if not walk(s, t) or s.visited.has(t):
			return
		_enter(s, t, d, 1)

static func act_move(s, d):
	if s.status != "play" or s.ink <= 0:
		return false
	var t = s.hero + d
	if not inb(s, t) or ally_at(s, t) >= 0:
		return false
	var yi = yokai_at(s, t)
	if yi >= 0:
		if s.r_nocut or hidden(s.yokai[yi]) or is_sealed(s, yi):
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
	if not inb(s, t) or not walk(s, t) or s.visited.has(t) or yokai_at(s, t) >= 0 or ally_at(s, t) >= 0:
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
	if not inb(s, t) or ter(s, t) != "." or s.wards.has(t) or yokai_at(s, t) >= 0 or ally_at(s, t) >= 0:
		return false
	s.events = [{"t": "ward", "pos": t}]
	s.ink -= 1
	s.ward -= 1
	s.mom = 0
	s.wards.append(t)
	return true

# Shikigami: set the oldest bound yokai on a tile beside you. It holds that tile and strikes
# the yokai within its reach at the start of their turn.
static func act_shiki(s, d):
	if s.status != "play" or s.ink <= 0 or not s.r_shiki or s.hand.is_empty():
		return false
	var t = s.hero + d
	if not inb(s, t) or ter(s, t) != "." or s.wards.has(t) or yokai_at(s, t) >= 0 or ally_at(s, t) >= 0:
		return false
	s.events = [{"t": "ward", "pos": t}]
	s.ink -= 1
	s.mom = 0
	s.allies.append({"kind": s.hand.pop_front(), "pos": t})
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
		if hidden(y):
			y.ch = "A"   # startled out of its disguise
		var t = y.pos + d
		var swims = y.kind == "kappa" or GHOSTS.has(y.kind)
		if y.kind == "nurikabe":
			pass  # a wall does not move; it only cracks
		elif inb(s, t) and ter(s, t) == "~" and not swims and yokai_at(s, t) < 0 and not is_sealed(s, yi):
			s.yokai.remove_at(yi)
			_gone(s, y)
			s.events.append({"t": "kill", "pos": t, "kind": y.kind, "dmg": 0})
			continue
		elif can_stand(s, y.kind, t):
			y.pos = t
			continue
		_hurt(s, yi, 1)
	_check_win(s)
	return true

# Bonsho: ring the temple bell. Until the next stroke no yokai strikes and none moves.
static func act_bell(s):
	if s.status != "play" or s.ink <= 0 or s.bell <= 0 or s.stun:
		return false
	s.events = [{"t": "bell", "pos": s.hero}]
	s.ink -= 1
	s.bell -= 1
	s.mom = 0
	s.stun = true
	return true

# where a yokai is heading: the nearest offering if it walks and one is laid out, else Suzu
static func _goal(s, y):
	var best = s.hero
	if GHOSTS.has(y.kind):
		return best
	var far = 999
	for ty in range(s.h):
		for tx in range(s.w):
			if s.rows[ty][tx] == "m":
				var dist = abs(tx - y.pos.x) + abs(ty - y.pos.y)
				if dist < far:
					far = dist
					best = Vector2i(tx, ty)
	return best

static func _chase(s, y):
	if eating(s, y):
		_put(s, y.pos, ".")   # it eats, and that is its whole turn
		s.events.append({"t": "eat", "pos": y.pos})
		return
	var goal = _goal(s, y)
	for step in range(3 if y.kind == "kamaitachi" else 1):
		if step > 0 and (abs(s.hero.x - y.pos.x) + abs(s.hero.y - y.pos.y) == 1 or eating(s, y)):
			return
		var was = y.pos
		_step(s, y, goal)
		if y.pos != was:
			s.events.append({"t": "move", "id": y.id, "to": y.pos, "kind": y.kind})

static func _step(s, y, goal):
	var dx = goal.x - y.pos.x
	var dy = goal.y - y.pos.y
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

static func _won(s):
	s.wet = []
	s.status = "won"
	s.turn += 1

# Sheathe the brush. In order: the circle binds; soul-flames relight; shikigami strike; the
# yokai strike (exactly what the red wash showed); the yokai move; the wind blows.
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
			if is_sealed(s, i):
				continue
			s.yokai.remove_at(i)
			_gone(s, y)
			if s.r_shiki and s.hand.size() < HAND_MAX:
				s.hand.append(y.kind)
			s.events.append({"t": "kill", "pos": y.pos, "kind": y.kind, "dmg": 0})
	# a soul-flame put out relights, so long as another still burns
	if not s.revive.is_empty():
		var alive = false
		for y in s.yokai:
			if y.kind == "hitodama":
				alive = true
		s.revive.sort_custom(func(p, q): return p.y * s.w + p.x < q.y * s.w + q.x)
		for p in s.revive:
			if alive and p != s.hero and yokai_at(s, p) < 0 and ally_at(s, p) < 0:
				s.yokai.append({"id": s.next_id, "ch": "e", "kind": "hitodama", "hp": 1, "max": 1, "pos": p, "down": false})
				s.next_id += 1
		s.revive = []
	if s.yokai.is_empty() and not s.r_write and not s.r_gate:
		_won(s)
		return
	if s.r_wet:
		s.wet = s.visited.filter(func(v): return v != s.hero)
	# rest beside a tanuki and it gives itself away
	for y in s.yokai:
		if hidden(y) and abs(y.pos.x - s.hero.x) + abs(y.pos.y - s.hero.y) == 1:
			y.ch = "A"
			s.events.append({"t": "cut", "pos": y.pos, "dmg": 0})
	# shikigami strike what stands within their reach
	for al in s.allies:
		for i in range(s.yokai.size() - 1, -1, -1):
			if reaches(s, al.kind, al.pos, s.yokai[i].pos):
				_hurt(s, i, 1)
	if s.yokai.is_empty() and not s.r_write and not s.r_gate:
		_won(s)
		return
	var struck = []
	for y in s.yokai:
		if threatens(s, y, s.hero):
			s.ki = 0 if y.kind == "shinigami" else s.ki - 1   # the death god needs only one touch
			s.hits += 1
			struck.append(y.id)
			s.events.append({"t": "hit", "src": y.pos})
	if ter(s, s.hero) == "f" and not s.r_rain:
		s.ki -= 1
		s.hits += 1
		s.events.append({"t": "hit", "src": s.hero})
	for y in s.yokai:
		y.down = false   # a daruma always gets back up
	for y in s.yokai:
		if MOVERS.has(y.kind) and not struck.has(y.id) and not s.stun:
			_chase(s, y)
	if s.wind != Vector2i.ZERO:
		for y in s.yokai:
			if LIGHT.has(y.kind) and can_stand(s, y.kind, y.pos + s.wind):
				y.pos += s.wind
				s.events.append({"t": "move", "id": y.id, "to": y.pos, "kind": "wind"})
	s.wet = []
	s.stun = false
	# the planks Suzu crossed this stroke give way, and take whatever stands on them
	var fell = false
	for v in s.visited:
		if v != s.hero and ter(s, v) == "b":
			_put(s, v, "~")
			fell = true
			s.events.append({"t": "fall", "pos": v})
			var yi = yokai_at(s, v)
			if yi >= 0 and s.yokai[yi].kind != "kappa" and not GHOSTS.has(s.yokai[yi].kind) and not is_sealed(s, yi):
				var y = s.yokai[yi]
				s.yokai.remove_at(yi)
				_gone(s, y)
				s.events.append({"t": "kill", "pos": v, "kind": y.kind, "dmg": 0})
	if fell and s.yokai.is_empty() and not s.r_write and not s.r_gate and s.ki > 0:
		_won(s)
		return
	s.turn += 1
	s.ink = min(INK_CAP, s.ink_max + s.ink) if s.r_stone else s.ink_max
	s.mom = 0
	s.mom_dir = Vector2i.ZERO
	s.visited = [s.hero]
	if s.ki <= 0:
		s.status = "lost"
