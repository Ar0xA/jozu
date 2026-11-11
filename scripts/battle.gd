extends "res://scripts/screen_base.gd"
# One stage: the board, the stroke being painted, and the panel beside it.

const Sim = preload("res://scripts/sim.gd")
const TS = 84.0
const ORG = Vector2(56, 104)
const PX = 690.0

var idx = 0
var lv
var s
var hist = []
var mode = ""
var disp = {}
var hdisp = Vector2.ZERO
var fx = []
var shake = 0.0
var flash = 0.0
var last_drag = Vector2i(-9, -9)
var done = false
var grade = ""
var kinds = []
var b_leap
var b_ward
var b_katsu
var b_end
var b_undo
var b_restart
var b_road
var b_hint
var extra = []
var rules = []
var my_paths = []
var hint_path = []
var hint_marks = []
var hint_msg = ""
var ending = false

func setup():
	lv = Data.LEVELS[idx]
	rules = lv.get("rules", [])
	b_leap = btn(Rect2(PX, 470, 172, 46), "Leap [1]", _mode.bind("leap"), "縮地")
	b_ward = btn(Rect2(PX + 184, 470, 172, 46), "Ward [2]", _mode.bind("ward"), "結界")
	b_katsu = btn(Rect2(PX + 368, 470, 172, 46), "Shout [3]", _katsu, "喝")
	b_end = btn(Rect2(PX, 526, 264, 50), "Sheathe  [Space]", _end, "納刀")
	b_undo = btn(Rect2(PX + 276, 526, 264, 50), "Undo  [Z]", _undo, "戻")
	b_hint = btn(Rect2(PX, 586, 264, 42), "Ask the master  [H]", _hint, "師")
	b_restart = btn(Rect2(PX, 642, 264, 44), "Restart  [R]", _restart)
	b_road = btn(Rect2(PX + 276, 642, 264, 44), "Back to the road", main.show_map)
	_restart()
	for y in s.yokai:
		if not kinds.has(y.kind):
			kinds.append(y.kind)

func _restart():
	s = Sim.new_state(lv.rows, main.stats_for(idx), rules)
	s["paths"] = []
	_clear_hint()
	hist = []
	mode = ""
	done = false
	grade = ""
	fx = []
	hdisp = Vector2(s.hero)
	disp = {}
	for b in extra:
		btns.erase(b)
	extra = []
	_sync()

func _sync():
	b_leap.show = lv.waza.has("leap")
	b_ward.show = lv.waza.has("ward")
	b_katsu.show = lv.waza.has("katsu")
	var live = not done and s.ink > 0
	b_leap.on = live and s.leap > 0
	b_ward.on = live and s.ward > 0
	b_katsu.on = live and s.katsu > 0
	b_leap.sel = mode == "leap"
	b_ward.sel = mode == "ward"
	b_end.on = not done
	b_hint.on = not done
	b_undo.on = not hist.is_empty() and grade != "jouzu" and grade != "ka"
	b_restart.on = true

func _mode(m):
	mode = "" if mode == m else m
	_sync()

func _push():
	hist.append(s.duplicate(true))

func _after(ok, quiet = "step"):
	if not ok:
		hist.pop_back()
		return
	mode = ""
	var heard = false
	for e in s.events:
		if ["kill", "cut", "hit", "katsu", "ward", "leap"].has(e.t):
			main.sfx(e.t)
			heard = true
	if not heard:
		main.sfx(quiet)
	for e in s.events:
		if e.t == "kill":
			fx.append({"k": "kill", "pos": Vector2(e.pos), "life": 0.8, "max": 0.8})
		elif e.t == "cut":
			fx.append({"k": "cut", "pos": Vector2(e.pos), "life": 0.4, "max": 0.4, "n": e.dmg})
		elif e.t == "hit":
			fx.append({"k": "hit", "pos": Vector2(e.src), "life": 0.5, "max": 0.5})
			shake = 0.35
			flash = 0.5
		elif e.t == "katsu":
			fx.append({"k": "katsu", "pos": Vector2(e.pos), "life": 0.6, "max": 0.6})
			shake = 0.2
	if s.status != "play":
		_finish()
	_sync()

func _clear_hint():
	hint_path = []
	hint_marks = []
	hint_msg = ""

func _same_board(a, b):
	if a.hero != b.hero or a.yokai.size() != b.yokai.size() or a.wards != b.wards:
		return false
	for i in range(a.yokai.size()):
		if a.yokai[i].ch != b.yokai[i].ch or a.yokai[i].pos != b.yokai[i].pos or a.yokai[i].hp != b.yokai[i].hp:
			return false
	return true

func _play_tokens(st, stroke, track):
	for tok in stroke.split(" ", false):
		var d = Vector2i.ZERO
		if tok != "KATSU":
			d = {"R": Vector2i(1, 0), "L": Vector2i(-1, 0), "D": Vector2i(0, 1), "U": Vector2i(0, -1)}[tok.right(1)]
		if tok == "KATSU":
			Sim.act_katsu(st)
			if track:
				hint_marks.append([st.hero, "喝"])
		elif tok.begins_with("leap"):
			Sim.act_leap(st, d)
			if track:
				hint_marks.append([st.hero, "縮"])
		elif tok.begins_with("ward"):
			Sim.act_ward(st, d)
			if track:
				hint_marks.append([st.hero + d, "結"])
		else:
			var before = st.hero
			Sim.act_move(st, d)
			if track and st.hero == before:
				hint_marks.append([before + d, "斬"])
		if track and hint_path.back() != st.hero:
			hint_path.append(st.hero)

# The master shows the next stroke of a known solution, if you are still on its line.
func _hint():
	if done:
		return
	_clear_hint()
	if s.visited.size() > 1 or s.ink != s.ink_max:
		hint_msg = "Finish or undo this stroke first; the master shows whole strokes."
		return
	var strokes = lv.get("sol", "").split(" / ")
	var ref = Sim.new_state(lv.rows, Data.base_stats(lv), rules)
	for k in range(min(s.turn, strokes.size())):
		_play_tokens(ref, strokes[k], false)
		Sim.end_stroke(ref)
	if s.turn >= strokes.size() or ref.status != "play" or not _same_board(ref, s):
		hint_msg = "The master's line begins at the first stroke. Restart (R) to follow it."
		return
	hint_path = [s.hero]
	_play_tokens(s.duplicate(true), strokes[s.turn], true)
	if hint_path.size() == 1 and hint_marks.is_empty():
		hint_msg = "The master waits. Sheathe the brush without moving."
	main.sfx("click")

func _dir(d):
	if done:
		return
	_clear_hint()
	_push()
	if mode == "leap":
		_after(Sim.act_leap(s, d))
	elif mode == "ward":
		_after(Sim.act_ward(s, d))
	else:
		_after(Sim.act_move(s, d))

func _katsu():
	if done:
		return
	_clear_hint()
	_push()
	_after(Sim.act_katsu(s))

func _end():
	if done:
		return
	_clear_hint()
	_push()
	s.paths.append(s.visited.duplicate())
	Sim.end_stroke(s)
	ending = true
	_after(true, "sheathe")
	ending = false

func _undo():
	if hist.is_empty() or grade == "jouzu" or grade == "ka":
		return
	s = hist.pop_back()
	mode = ""
	_clear_hint()
	if done:
		done = false
		grade = ""
		for b in extra:
			btns.erase(b)
		extra = []
	_sync()

func _finish():
	done = true
	if s.status == "won":
		grade = "jouzu" if (s.hits == 0 and s.turn <= lv.par) else "ka"
		main.sfx("win")
		var first = main.grade_of(idx) == ""
		my_paths = s.paths.duplicate()
		if not ending:
			my_paths.append(s.visited.duplicate())
		main.record(idx, grade, my_paths)
		var nxt = main.show_map
		if first:
			nxt = main.show_story.bind(lv.after, main.show_map)
		extra.append(btn(Rect2(250, 452, 200, 54), "Onward", nxt, "進"))
		extra.append(btn(Rect2(250, 516, 200, 46), "Try again", _restart))
	else:
		grade = "lost"
		main.sfx("lose")
		extra.append(btn(Rect2(250, 440, 200, 54), "Take it back", _undo, "戻"))
		extra.append(btn(Rect2(250, 506, 200, 46), "Restart", _restart))

func tile_at(pos):
	var p = (pos - ORG) / TS
	return Vector2i(int(floor(p.x)), int(floor(p.y)))

func _try_tile(t):
	if done or not Sim.inb(s, t):
		return
	var d = t - s.hero
	if d == Vector2i.ZERO or (d.x != 0 and d.y != 0):
		return
	var n = abs(d.x) + abs(d.y)
	var dir = Vector2i(sign(d.x), sign(d.y))
	if n == 1 or (n == 2 and mode == "leap"):
		_dir(dir)

func on_click(pos, button):
	if button == MOUSE_BUTTON_RIGHT:
		_undo()
		return
	if button == MOUSE_BUTTON_LEFT:
		last_drag = tile_at(pos)
		_try_tile(last_drag)

func on_motion(pos, held):
	if not held or mode != "":
		return
	var t = tile_at(pos)
	if t != last_drag:
		last_drag = t
		_try_tile(t)

func on_key(code):
	match code:
		KEY_RIGHT, KEY_D: _dir(Vector2i(1, 0))
		KEY_LEFT, KEY_A: _dir(Vector2i(-1, 0))
		KEY_DOWN, KEY_S: _dir(Vector2i(0, 1))
		KEY_UP, KEY_W: _dir(Vector2i(0, -1))
		KEY_SPACE, KEY_ENTER: _end()
		KEY_Z, KEY_BACKSPACE: _undo()
		KEY_R: _restart()
		KEY_H: _hint()
		KEY_1:
			if b_leap.show and b_leap.on: _mode("leap")
		KEY_2:
			if b_ward.show and b_ward.on: _mode("ward")
		KEY_3:
			if b_katsu.show and b_katsu.on: _katsu()
		KEY_ESCAPE:
			if mode != "":
				_mode(mode)
			else:
				main.show_map()

func tick(dt):
	var k = 1.0 - exp(-dt * 18.0)
	hdisp = hdisp.lerp(Vector2(s.hero), k)
	for y in s.yokai:
		if not disp.has(y.id):
			disp[y.id] = Vector2(y.pos)
		disp[y.id] = disp[y.id].lerp(Vector2(y.pos), k)
	shake = max(0.0, shake - dt)
	flash = max(0.0, flash - dt)
	for e in fx:
		e.life -= dt
	fx = fx.filter(func(e): return e.life > 0.0)

func ctr(p):
	return ORG + (Vector2(p) + Vector2(0.5, 0.5)) * TS

func _draw():
	var f = main.font
	var off = Vector2.ZERO
	if shake > 0.0:
		off = Vector2(sin(time * 90.0), cos(time * 70.0)) * shake * 14.0
	draw_set_transform(off, 0.0, Vector2.ONE)

	# header
	Ink.seal(self, f, Vector2(84, 52), 24, "上手")
	Ink.text(self, f, Vector2(124, 62), lv.kanji, 44, Ink.SUMI)
	Ink.text(self, f, Vector2(140 + 44 * lv.kanji.length(), 48), "Station %d" % (idx + 1), 16, Ink.a(Ink.SUMI, 0.6))
	Ink.text(self, f, Vector2(140 + 44 * lv.kanji.length(), 72), lv.name, 22, Ink.SUMI)
	var rl = []
	if rules.has("koan"):
		rl.append("公案 one stroke only")
	if rules.has("wet"):
		rl.append("墨 your last stroke is a wall")
	if rules.has("enso"):
		rl.append("円相 close a circle to bind")
	if rules.has("garden"):
		rl.append("石庭 rake every tile in one stroke  (%d left)" % max(0, s.open - s.visited.size()))
	if rules.has("gate"):
		rl.append("鳥居 reach the gate")
	if rules.has("nocut"):
		rl.append("無刀 no cutting")
	if rules.has("stone"):
		rl.append("硯 unspent ink is kept (to %d)" % Sim.INK_CAP)
	if not rl.is_empty():
		Ink.text(self, f, Vector2(124, 96), "  ·  ".join(rl), 14, Ink.SHU)

	# board
	var br = Rect2(ORG, Vector2(s.w, s.h) * TS)
	draw_rect(br, Ink.a(Ink.GOFUN, 0.40))
	var dng = {}
	if not done:
		dng = Sim.danger(s)
	for y in range(s.h):
		for x in range(s.w):
			var p = Vector2i(x, y)
			var r = Rect2(ORG + Vector2(x, y) * TS, Vector2(TS, TS))
			var ch = Sim.ter(s, p)
			if ch == "~":
				Ink.water(self, r, time)
			elif ch == "#":
				Ink.rock(self, r.get_center(), TS, x * 31 + y * 7 + 3)
			elif ch == "i":
				Ink.ice(self, r)
			elif ch == "f":
				Ink.fire(self, r, time + x + y)
			elif ch == "g":
				Ink.torii(self, r)
			if s.r_garden and (ch == "." or ch == "i") and not s.visited.has(p):
				# gravel not yet raked
				for k in range(3):
					draw_circle(r.position + Vector2(TS * (0.3 + 0.2 * k), TS * (0.4 + 0.12 * ((x + y + k) % 3))), 1.6, Ink.a(Ink.SUMI, 0.35))
			if dng.has(p) and ch != "f":
				Ink.blot(self, r.get_center(), TS * 0.66, TS * 0.66, Ink.SHU, 0.52 + 0.08 * sin(time * 4.0))
	for i in range(s.w + 1):
		draw_line(ORG + Vector2(i * TS, 0), ORG + Vector2(i * TS, s.h * TS), Ink.a(Ink.SUMI, 0.28), 1.2)
	for i in range(s.h + 1):
		draw_line(ORG + Vector2(0, i * TS), ORG + Vector2(s.w * TS, i * TS), Ink.a(Ink.SUMI, 0.28), 1.2)
	Ink.frame(self, br, 6.0, Ink.SUMI)

	for w in s.wards:
		Ink.ward(self, f, ctr(w), TS)

	# where the next step may go
	if not done and s.ink > 0:
		for d in Sim.DIRS:
			var t = s.hero + d
			var dist = 1
			if mode == "leap":
				t = s.hero + d * 2
				dist = 2
			if not Sim.inb(s, t):
				continue
			var yi = Sim.yokai_at(s, t)
			if mode == "" and yi >= 0:
				var c = ctr(t)
				Ink.enso(self, c, TS * 0.44, 5.0, Ink.a(Ink.SHU, 0.85))
				Ink.text(self, f, c + Vector2(TS * 0.2, -TS * 0.24), str(Sim.cut_power(s, d)), 22, Ink.SHU)
			elif yi < 0 and ((mode == "ward" and Sim.ter(s, t) == "." and not s.wards.has(t)) or (mode != "ward" and Sim.walk(s, t) and not s.visited.has(t))):
				draw_circle(ctr(t), 7.0 if dist == 1 else 10.0, Ink.a(Ink.AI if mode != "" else Ink.SUMI, 0.45))

	# the stroke before this one, drying
	if not s.paths.is_empty() and not done:
		var old = []
		for v in s.paths.back():
			old.append(ctr(v))
		if old.size() > 1:
			Ink.brush(self, old, 18.0, Ink.a(Ink.AI if rules.has("wet") else Ink.SUMI, 0.16))

	# the master's line
	if hint_path.size() > 1:
		for i in range(1, hint_path.size()):
			var a = ctr(hint_path[i - 1])
			var b = ctr(hint_path[i])
			var n = int(a.distance_to(b) / 14.0)
			for k in range(n + 1):
				draw_circle(a.lerp(b, k / float(max(1, n))), 3.5, Ink.a(Ink.SHU, 0.75))
		Ink.enso(self, ctr(hint_path.back()), TS * 0.2, 4.0, Ink.SHU)
	for m in hint_marks:
		Ink.text(self, f, ctr(m[0]) + Vector2(-TS * 0.5, -TS * 0.12), m[1], 22, Ink.SHU, HORIZONTAL_ALIGNMENT_CENTER, TS)

	# a closing circle shows what it would bind
	var bound = Sim.enso_bound(s)
	if not bound.is_empty() and not done:
		var lp = [ctr(s.visited.back()), ctr(s.visited[0])]
		draw_line(lp[0], lp[1], Ink.a(Ink.KIN, 0.9), 6.0, true)
		for i in bound:
			Ink.enso(self, ctr(s.yokai[i].pos), TS * 0.46, 7.0, Ink.KIN)

	# the stroke so far
	var trail = []
	for v in s.visited:
		trail.append(ctr(v))
	if trail.size() > 1:
		Ink.brush(self, trail, 20.0, Color(0.2, 0.18, 0.17))
		for i in range(1, trail.size()):
			var m = (trail[i - 1] + trail[i]) * 0.5
			var n = (trail[i] - trail[i - 1]).orthogonal().normalized()
			draw_line(m + n * 13, trail[i] + n * 12, Ink.a(Ink.SUMI, 0.25), 1.5, true)

	# figures stand on their tiles; paint the far rows first so nearer ones overlap them
	var cast = [[hdisp.y + 0.01, "hero", ORG + (hdisp + Vector2(0.5, 0.5)) * TS, null]]
	for y in s.yokai:
		var dp = disp.get(y.id, Vector2(y.pos))
		cast.append([dp.y, y.kind, ORG + (dp + Vector2(0.5, 0.5)) * TS, y])
	cast.sort_custom(func(p, q): return p[0] < q[0])
	for e in cast:
		if e[3] == null:
			main.piece(self, "hero", e[2], TS)
		else:
			main.piece(self, e[1], e[2], TS, time + e[3].id, e[3].max >= 3 or e[3].ch == "T", false, {"S": 1.3, "G": 1.45, "P": 1.25}.get(e[3].ch, 1.0))
	for y in s.yokai:
		Ink.hp_pips(self, ORG + (disp.get(y.id, Vector2(y.pos)) + Vector2(0.5, 0.5)) * TS, TS, y.hp, y.max)

	for e in fx:
		var u = 1.0 - e.life / e.max
		var c = ctr(e.pos)
		if e.k == "kill":
			draw_arc(c, TS * (0.2 + 0.5 * u), 0, TAU, 32, Ink.a(Ink.SUMI, 1.0 - u), 6.0 * (1.0 - u) + 1.0, true)
			for i in range(7):
				var ang = i * 0.9 + 0.3
				draw_circle(c + Vector2(cos(ang), sin(ang)) * TS * (0.25 + 0.5 * u), 5.0 * (1.0 - u), Ink.a(Ink.SUMI, 1.0 - u))
			Ink.text(self, f, c + Vector2(-20, 14 - 30 * u), "祓", 40, Ink.a(Ink.SHU, 1.0 - u))
		elif e.k == "cut":
			draw_line(c + Vector2(-30, -30), c + Vector2(-30 + 60 * min(1.0, u * 2.5), -30 + 60 * min(1.0, u * 2.5)), Ink.a(Ink.GOFUN, 1.0 - u), 7.0, true)
			draw_line(c + Vector2(-30, -30), c + Vector2(-30 + 60 * min(1.0, u * 2.5), -30 + 60 * min(1.0, u * 2.5)), Ink.a(Ink.SHU, 1.0 - u), 3.0, true)
		elif e.k == "hit":
			draw_line(c, ORG + (hdisp + Vector2(0.5, 0.5)) * TS, Ink.a(Ink.SHU, 1.0 - u), 8.0 * (1.0 - u), true)
		elif e.k == "katsu":
			draw_arc(c, TS * (0.3 + 1.2 * u), 0, TAU, 40, Ink.a(Ink.SHU, 1.0 - u), 5.0, true)
			Ink.text(self, f, c + Vector2(-28, -40 - 20 * u), "喝", 56, Ink.a(Ink.SHU, 1.0 - u))

	_panel(f)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if flash > 0.0:
		draw_rect(Rect2(0, 0, 1280, 720), Ink.a(Ink.SHU, flash * 0.35))
	if done:
		_result(f)
	draw_btns()

func _pips(f, y, kanji, label, n, mx, col):
	Ink.text(self, f, Vector2(PX, y), kanji, 26, Ink.SUMI)
	Ink.text(self, f, Vector2(PX + 36, y - 2), label, 17, Ink.a(Ink.SUMI, 0.7))
	for i in range(mx):
		# long brushes wrap onto a tighter row so they never run into the text beside them
		var step = 30.0 if mx <= 8 else 240.0 / mx
		var c = Vector2(PX + 150 + i * step, y - 9)
		var rad = min(10.0, step * 0.36)
		if i < n:
			draw_circle(c, rad, col)
		draw_arc(c, rad, 0, TAU, 20, Ink.SUMI, 1.8, true)

func _panel(f):
	Ink.brush(self, [Vector2(PX - 22, 30), Vector2(PX - 23, 250), Vector2(PX - 21, 470), Vector2(PX - 22, 690)], 4.0, Ink.a(Ink.SUMI, 0.45))
	Ink.text(self, f, Vector2(PX, 52), "Stroke %d" % (s.turn + (0 if done else 1)), 26, Ink.SUMI)
	Ink.text(self, f, Vector2(PX + 150, 52), "上手 mastery: within %d, unharmed" % lv.par, 17, Ink.SHU if (s.turn < lv.par and s.hits == 0) else Ink.a(Ink.SUMI, 0.5))
	_pips(f, 96, "気", "Ki", s.ki, s.ki + s.hits, Ink.SHU)
	_pips(f, 134, "墨", "Ink", s.ink, Sim.INK_CAP if s.r_stone else max(s.ink_max, s.ink), Ink.SUMI)
	_pips(f, 172, "勢", "Momentum", min(2, s.mom), 2, Ink.AI)
	Ink.text(self, f, Vector2(PX + 230, 170), "a straight cut now deals %d" % min(3, 1 + s.mom), 16, Ink.a(Ink.SUMI, 0.7))
	var wz = ""
	if lv.waza.has("leap"):
		wz += "縮地 %d   " % s.leap
	if lv.waza.has("ward"):
		wz += "結界 %d   " % s.ward
	if lv.waza.has("katsu"):
		wz += "喝 %d" % s.katsu
	if wz != "":
		Ink.text(self, f, Vector2(PX, 206), "Waza left:  " + wz, 18, Ink.SUMI)
	var y = 226.0
	for k in kinds:
		var L = Data.LEGEND[k]
		main.piece(self, k, Vector2(PX + 18, y + 16), 40, 0.0, false, true)
		var nm = L[0] + " " + L[1]
		Ink.text(self, f, Vector2(PX + 46, y + 24), nm, 17, Ink.SUMI)
		var nx = max(PX + 190.0, PX + 46.0 + f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 14.0)
		Ink.text(self, f, Vector2(nx, y + 24), L[2], 15, Ink.a(Ink.SUMI, 0.75))
		y += 34.0
	var hint = lv.hint
	if mode == "leap":
		hint = "縮地 — choose a direction to leap two tiles. Esc cancels."
	elif mode == "ward":
		hint = "結界 — choose a tile beside you for the ward. Esc cancels."
	if hint_msg != "":
		hint = hint_msg
	var hy = max(y + 24.0, 388.0)
	var say = lv.get("say", [])
	if hint == "" and say.size() == 3:
		# a stage with no lesson of its own carries an old saying instead
		hy = max(y + 30.0, 372.0)
		Ink.text(self, f, Vector2(PX, hy), say[0], 22 if say[0].length() <= 14 else 17, Ink.SUMI)
		Ink.text(self, f, Vector2(PX, hy + 21), say[1], 13, Ink.a(Ink.SUMI, 0.55))
		Ink.para(self, f, Vector2(PX, hy + 44), say[2], 15, Ink.a(Ink.AI, 0.95), 545)
	else:
		Ink.para(self, f, Vector2(PX, hy), hint, 15, Ink.a(Ink.SHU if hint_msg != "" else Ink.AI, 0.95), 545)
	Ink.text(self, f, Vector2(PX + 282, 604), "click, drag or arrows to paint", 13, Ink.a(Ink.SUMI, 0.55))
	Ink.text(self, f, Vector2(PX + 282, 622), "right-click undoes", 13, Ink.a(Ink.SUMI, 0.55))

func _result(f):
	var box = Rect2(150, 200, 400, 380)
	draw_rect(box, Ink.a(Ink.PAPER, 0.9))
	Ink.slip(self, box, 5.0)
	if grade == "jouzu":
		Ink.seal(self, f, Vector2(232, 296), 50, "上手")
		_my_scroll()
		Ink.text(self, f, Vector2(150, 408), "Mastered in %d stroke%s, unharmed." % [s.turn, "" if s.turn == 1 else "s"], 19, Ink.SUMI, HORIZONTAL_ALIGNMENT_CENTER, 400)
	elif grade == "ka":
		Ink.seal(self, f, Vector2(232, 290), 58, "可", Ink.AI)
		_my_scroll()
		var why = "%d strokes; mastery asks %d." % [s.turn, lv.par]
		if s.hits > 0:
			why = "%d strokes, %d blow%s taken." % [s.turn, s.hits, "" if s.hits == 1 else "s"]
		Ink.text(self, f, Vector2(150, 400), "Passed. " + why, 18, Ink.SUMI, HORIZONTAL_ALIGNMENT_CENTER, 400)
		Ink.text(self, f, Vector2(150, 424), "上手 needs %d strokes and no blows." % lv.par, 15, Ink.a(Ink.SUMI, 0.7), HORIZONTAL_ALIGNMENT_CENTER, 400)
	else:
		Ink.text(self, f, Vector2(150, 320), "無念", 84, Ink.SUMI, HORIZONTAL_ALIGNMENT_CENTER, 400)
		var why = "The ink runs. Nothing is lost but a stroke."
		if rules.has("koan"):
			why = "A kōan has no second stroke. Begin again."
		elif rules.has("garden"):
			why = "The garden is not yet raked. Begin again."
		Ink.text(self, f, Vector2(150, 384), why, 18, Ink.SUMI, HORIZONTAL_ALIGNMENT_CENTER, 400)
		Ink.text(self, f, Vector2(150, 416), "七転び八起き  —  fall seven times, rise eight", 15, Ink.a(Ink.SHU, 0.9), HORIZONTAL_ALIGNMENT_CENTER, 400)

# what you painted to clear this stage, as it will hang in the scroll
func _my_scroll():
	var r = Rect2(318, 222, 196, 160)
	draw_rect(r, Ink.a(Ink.GOFUN, 0.9))
	Ink.frame(self, r, 2.5, Ink.a(Ink.SUMI, 0.7))
	Ink.calligraphy(self, r.grow(-10), my_paths, s.w, s.h)
