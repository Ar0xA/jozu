extends SceneTree
# Headless stage checker:  godot --headless --path . -s tools/solve.gd
# Proves every stage is solvable at base stats and reports the fewest strokes
# (with and without taking a blow). "par" in data.gd should equal the no-blow figure.

const Sim = preload("res://scripts/sim.gd")
const Data = preload("res://scripts/data.gd")
const NAMES = {Vector2i(1, 0): "R", Vector2i(-1, 0): "L", Vector2i(0, 1): "D", Vector2i(0, -1): "U"}

const BEAM = 250

var out = {}
var seen = {}
var approx = false

func score(s):
	var hp = 0
	var near = 99
	for y in s.yokai:
		hp += y.hp
		near = min(near, abs(y.pos.x - s.hero.x) + abs(y.pos.y - s.hero.y))
	return hp * 100 + s.yokai.size() * 40 - s.ki * 60 - (s.leap + s.ward + s.katsu) * 15 + near

func _init():
	var only = -1
	for a in OS.get_cmdline_user_args():
		only = int(a)
	for i in range(Data.LEVELS.size()):
		if only >= 0 and i != only - 1:
			continue
		var lv = Data.LEVELS[i]
		var st = Data.base_stats(lv)
		var a = solve(lv, st, false)
		var b = solve(lv, st, true)
		var flag = "" if b[0] == lv.par else "   <-- par in data is %d" % lv.par
		var ex = "(beam, upper bound)" if approx else "(exact)"
		print("%2d %-10s any=%s  clean=%s %s%s" % [i + 1, lv.kanji, str(a[0]), str(b[0]), ex, flag])
		print("      clean: ", b[1])
	quit()

func solve(lv, st, clean):
	var s0 = Sim.new_state(lv.rows, st)
	s0["trace"] = ""
	var frontier = [s0]
	var visited = {Sim.key(s0, false): true}
	approx = false
	for depth in range(1, 13):
		var nxt = []
		for s in frontier:
			out = {}
			seen = {}
			_strokes(s, clean)
			if out.has("WON"):
				return [depth, out["WON"].trace]
			for k in out:
				if not visited.has(k):
					visited[k] = true
					nxt.append(out[k])
		if nxt.is_empty() or visited.size() > 400000:
			return [-1, "no solution (" + str(visited.size()) + " states)"]
		if nxt.size() > BEAM:
			approx = true
			nxt.sort_custom(func(p, q): return score(p) < score(q))
			nxt.resize(BEAM)
		frontier = nxt
	return [-1, "too deep"]

func _strokes(s, clean):
	if out.has("WON"):
		return
	var e = s.duplicate(true)
	Sim.end_stroke(e)
	if e.status == "play" and not (clean and e.hits > 0):
		e.trace += " / "
		var k = Sim.key(e, false)
		if not out.has(k):
			out[k] = e
	if s.ink <= 0:
		return
	for d in Sim.DIRS:
		_try(s, clean, "move", d)
		if s.leap > 0:
			_try(s, clean, "leap", d)
		if s.ward > 0:
			_try(s, clean, "ward", d)
	if s.katsu > 0:
		_try(s, clean, "katsu", Vector2i.ZERO)

func _try(s, clean, kind, d):
	var c = s.duplicate(true)
	var ok = false
	var tag = ""
	if kind == "move":
		ok = Sim.act_move(c, d)
		tag = NAMES[d]
	elif kind == "leap":
		ok = Sim.act_leap(c, d)
		tag = "leap" + NAMES[d]
	elif kind == "ward":
		ok = Sim.act_ward(c, d)
		tag = "ward" + NAMES[d]
	else:
		ok = Sim.act_katsu(c)
		tag = "KATSU"
	if not ok:
		return
	c.trace += tag + " "
	if c.status == "won":
		out["WON"] = c
		return
	var k = Sim.key(c, true)
	if seen.has(k):
		return
	seen[k] = true
	_strokes(c, clean)
