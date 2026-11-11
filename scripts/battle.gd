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
var b_bell
var b_end
var b_undo
var b_restart
var b_road
var b_hint
var b_shiki
# A board from outside the story (daily koan, pilgrimage, workshop) is passed in as `custom`,
# with what to do when it is won or lost and where "back" leads.
var custom = null
var kind_of = "story"   # story | daily | henro | custom
var label = ""
var on_win = Callable()
var on_fail = Callable()
var back = Callable()
var guide = false      # first visit to a chapter's opening stage: the master's line is shown unasked
var guide_msg = ""
var dng = {}
var undos = 0
var seal_mask = 0
var extra = []
var rules = []
var my_paths = []
var hint_path = []
var hint_marks = []
var hint_msg = ""
var ending = false

func setup():
	lv = custom if custom != null else Data.LEVELS[idx]
	rules = lv.get("rules", [])
	if not back.is_valid():
		back = main.show_map
	if custom == null:
		for c in Data.CHAPTERS:
			if c.from == idx and main.grade_of(idx) == "":
				guide = true
	b_leap = btn(Rect2(PX, 470, 172, 46), "Leap [1]", _mode.bind("leap"), "縮地")
	b_ward = btn(Rect2(PX + 184, 470, 172, 46), "Ward [2]", _mode.bind("ward"), "結界")
	b_katsu = btn(Rect2(PX + 368, 470, 172, 46), "Shout [3]", _katsu, "喝")
	b_bell = btn(Rect2(PX, 470, 172, 46), "Bell [5]", _bell, "鐘")
	b_end = btn(Rect2(PX, 526, 264, 50), "Sheathe  [Space]", _end, "納刀")
	b_undo = btn(Rect2(PX + 276, 526, 264, 50), "Undo  [Z]", _undo, "戻")
	b_hint = btn(Rect2(PX, 586, 264, 42), "Ask the master  [H]", _hint, "師")
	b_shiki = btn(Rect2(PX + 276, 586, 264, 42), "Set  [4]", _mode.bind("shiki"), "式神")
	b_restart = btn(Rect2(PX, 642, 264, 44), "Restart  [R]" if kind_of != "henro" else "Give up this temple", _retry)
	b_road = btn(Rect2(PX + 276, 642, 264, 44), "Back to the road" if custom == null else "Leave", _leave)
	_restart()
	for y in s.yokai:
		if not kinds.has(y.kind):
			kinds.append(y.kind)

# the Restart button and key: on the pilgrimage, starting a temple again costs a staff
# Walking out of a temple once a step has been painted is the same as giving it up.
func _leave():
	if kind_of == "henro" and not done and (s.turn > 0 or s.visited.size() > 1):
		main.henro_spend()
	back.call()

func _retry():
	if kind_of == "henro":
		on_fail.call()
	else:
		_restart()

func _restart():
	s = Sim.new_state(lv.rows, main.stats_for(idx) if custom == null else Data.base_stats(lv), rules)
	s["paths"] = []
	s["spent"] = 0
	undos = 0
	seal_mask = 0
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
	b_bell.show = lv.waza.has("bell")
	# the techniques this stage allows share the row evenly
	var row = [b_leap, b_ward, b_katsu, b_bell].filter(func(b): return b.show)
	for i in range(row.size()):
		var bw = (540.0 - 12.0 * (row.size() - 1)) / row.size() if row.size() > 3 else 172.0
		row[i].rect = Rect2(PX + i * (bw + 12.0), 470, bw, 46)
	var live = not done and s.ink > 0
	b_bell.on = live and s.bell > 0 and not s.stun
	b_bell.sel = s.stun
	b_leap.on = live and s.leap > 0
	b_ward.on = live and s.ward > 0
	b_katsu.on = live and s.katsu > 0
	b_leap.sel = mode == "leap"
	b_ward.sel = mode == "ward"
	b_end.on = not done
	b_hint.on = not done and kind_of != "henro" and lv.get("sol", "") != ""
	b_shiki.show = s.r_shiki
	b_shiki.on = live and not s.hand.is_empty()
	b_shiki.sel = mode == "shiki"
	var names = []
	for k in s.hand:
		names.append(Data.LEGEND[k][0].substr(0, 1))
	b_shiki.label = "Set  [4]   " + ("・".join(names) if not names.is_empty() else "—")
	dng = {} if done else Sim.danger(s)
	_guide_update()
	b_undo.on = not hist.is_empty() and grade != "jouzu" and grade != "ka" and kind_of != "henro"
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
	if quiet == "step":
		s.spent += 1
	var heard = false
	for e in s.events:
		if ["kill", "cut", "hit", "katsu", "ward", "leap", "bell"].has(e.t):
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
		elif e.t == "bell":
			fx.append({"k": "bell", "pos": Vector2(e.pos), "life": 1.4, "max": 1.4})
		elif e.t == "fall" or e.t == "eat":
			fx.append({"k": "kill", "pos": Vector2(e.pos), "life": 0.5, "max": 0.5, "quiet": true})
	if s.status != "play":
		_finish()
	_sync()

func _clear_hint():
	hint_path = []
	hint_marks = []
	hint_msg = ""

func _same_board(a, b):
	if a.hero != b.hero or a.yokai.size() != b.yokai.size() or a.wards != b.wards or a.rows != b.rows or a.inked != b.inked or a.bell != b.bell:
		return false
	for i in range(a.yokai.size()):
		if a.yokai[i].ch != b.yokai[i].ch or a.yokai[i].pos != b.yokai[i].pos or a.yokai[i].hp != b.yokai[i].hp:
			return false
	return true

func _play_tokens(st, stroke, track):
	for tok in stroke.split(" ", false):
		var d = Vector2i.ZERO
		if tok != "KATSU" and tok != "BELL":
			d = {"R": Vector2i(1, 0), "L": Vector2i(-1, 0), "D": Vector2i(0, 1), "U": Vector2i(0, -1)}[tok.right(1)]
		if tok == "BELL":
			Sim.act_bell(st)
			if track:
				hint_marks.append([st.hero, "鐘"])
		elif tok == "KATSU":
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
		elif tok.begins_with("shiki"):
			Sim.act_shiki(st, d)
			if track:
				hint_marks.append([st.hero + d, "式"])
		else:
			var before = st.hero
			Sim.act_move(st, d)
			if track and st.hero == before:
				hint_marks.append([before + d, "斬"])
		if track and hint_path.back() != st.hero:
			hint_path.append(st.hero)

# The next stroke of the known solution, if the board is still on its line. Returns a reason
# when it cannot be shown.
func _master_line():
	_clear_hint()
	if s.visited.size() > 1 or s.ink != s.ink_max:
		return "Finish or undo this stroke first; the master shows whole strokes."
	var strokes = lv.get("sol", "").split(" / ")
	var ref = Sim.new_state(lv.rows, Data.base_stats(lv), rules)
	for k in range(min(s.turn, strokes.size())):
		_play_tokens(ref, strokes[k], false)
		Sim.end_stroke(ref)
	if s.turn >= strokes.size() or ref.status != "play" or not _same_board(ref, s):
		return "The master's line begins at the first stroke. Restart (R) to follow it."
	hint_path = [s.hero]
	_play_tokens(s.duplicate(true), strokes[s.turn], true)
	if hint_path.size() == 1 and hint_marks.is_empty():
		return "The master waits. Sheathe the brush without moving."
	return ""

func _hint():
	if done:
		return
	hint_msg = _master_line()
	main.sfx("click")

# While guiding, say what to do next in plain words.
func _guide_update():
	guide_msg = ""
	if not guide or done:
		return
	if s.visited.size() == 1 and s.ink == s.ink_max:
		var why = _master_line()
		if why == "":
			guide_msg = "Paint the dotted stroke: click or drag from tile to tile, or use the arrow keys."
		elif why.begins_with("The master waits"):
			guide_msg = "Here the master waits. Sheathe the brush without moving: Space, or 納刀."
		else:
			guide_msg = "You have left the master's line. Carry on, or restart (R) to see it again."
		return
	if hint_path.size() > 1 and s.hero == hint_path.back():
		guide_msg = "Now sheathe the brush to end the stroke: Space, or 納刀. The yokai move after you."
	elif hint_path.size() > 1:
		guide_msg = "Follow the dots to the ring. Right-click or Z takes a step back."

func _dir(d):
	if done:
		return
	if not guide:
		_clear_hint()
	_push()
	if mode == "leap":
		_after(Sim.act_leap(s, d))
	elif mode == "ward":
		_after(Sim.act_ward(s, d))
	elif mode == "shiki":
		_after(Sim.act_shiki(s, d))
	else:
		_after(Sim.act_move(s, d))

func _katsu():
	if done:
		return
	if not guide:
		_clear_hint()
	_push()
	_after(Sim.act_katsu(s))

func _bell():
	if done:
		return
	if not guide:
		_clear_hint()
	_push()
	_after(Sim.act_bell(s))

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
	if hist.is_empty() or grade == "jouzu" or grade == "ka" or kind_of == "henro":
		return   # a pilgrim does not take a step back
	s = hist.pop_back()
	undos += 1
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
		var master = 0
		for st in lv.get("sol", "").split("/"):
			master += st.split(" ", false).size()
		seal_mask = (1 if grade == "jouzu" else 0) | (2 if grade == "jouzu" and undos == 0 else 0) | (4 if s.hits == 0 and s.spent <= master else 0)
		if custom != null:
			var nxt2 = on_win.call(grade, seal_mask, s.turn)   # returns where "Onward" leads
			extra.append(btn(Rect2(250, 470, 200, 50), "Onward", nxt2 if nxt2 is Callable else back, "進"))
			if kind_of != "henro":
				extra.append(btn(Rect2(250, 526, 200, 44), "Try again", _restart))
			return
		main.record(idx, grade, my_paths, seal_mask)
		var nxt = main.show_map
		if first:
			nxt = main.show_story.bind(lv.after, main.show_map)
		extra.append(btn(Rect2(250, 470, 200, 50), "Onward", nxt, "進"))
		extra.append(btn(Rect2(250, 526, 200, 44), "Try again", _restart))
	else:
		grade = "lost"
		main.sfx("lose")
		if kind_of == "henro":
			extra.append(btn(Rect2(250, 440, 200, 54), "Rise", on_fail, "起"))
			return
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
		KEY_R: _retry()
		KEY_H: _hint()
		KEY_1:
			if b_leap.show and b_leap.on: _mode("leap")
		KEY_2:
			if b_ward.show and b_ward.on: _mode("ward")
		KEY_3:
			if b_katsu.show and b_katsu.on: _katsu()
		KEY_4:
			if b_shiki.show and b_shiki.on: _mode("shiki")
		KEY_5:
			if b_bell.show and b_bell.on: _bell()
		KEY_ESCAPE:
			if mode != "":
				_mode(mode)
			else:
				_leave()

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
	Ink.text(self, f, Vector2(140 + 44 * lv.kanji.length(), 48), ("Station %d" % (idx + 1)) if custom == null else label, 16, Ink.a(Ink.SUMI, 0.6))
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
	if rules.has("shiki"):
		rl.append("式神 what you bind, you may set down")
	if s.wind != Vector2i.ZERO:
		rl.append("風 the wind carries lanterns, umbrellas and ghosts " + {Vector2i(1, 0): "→", Vector2i(-1, 0): "←", Vector2i(0, 1): "↓", Vector2i(0, -1): "↑"}[s.wind])
	if rules.has("rain"):
		rl.append("雨 lanterns and fire are out; kappa come ashore")
	if rules.has("snow"):
		rl.append("雪 all water is ice")
	if rules.has("night"):
		rl.append("夜 you see only near yourself and near light")
	var ground = "".join(lv.rows)
	if rules.has("order"):
		rl.append("封 only the lowest number can be harmed")
	if rules.has("write"):
		var left = s.marks
		for i in range(s.w * s.h):
			if s.inked & (1 << i):
				left -= 1
		rl.append("書 paint every grey tile  (%d left)" % left)
	if ground.contains("m"):
		rl.append("供 walking yokai go to an offering, and eat")
	if ground.contains("b"):
		rl.append("橋 planks you cross fall after the yokai move")
	if ground.contains("w"):
		rl.append("巣 a web ends your stroke")
	if s.stun:
		rl.append("鐘 the bell is ringing: nothing strikes, nothing moves")
	if rl.size() >= 3:
		# with many rules in force, name each in a word or two so the line stays over the board
		var brief = {"公": "公案 one stroke", "墨": "墨 wet wall", "円": "円相 circle binds", "石": "石庭 rake all", "鳥": "鳥居 reach it",
			"無": "無刀 no cut", "硯": "硯 ink kept", "式": "式神 set allies", "風": "風 wind", "雨": "雨 rain", "雪": "雪 ice", "夜": "夜 night",
			"封": "封 in order", "書": "書 write it", "供": "供 offerings lure", "橋": "橋 planks fall", "巣": "巣 webs stop you", "鐘": "鐘 all still"}
		for k in range(rl.size()):
			rl[k] = brief.get(rl[k].substr(0, 1), rl[k])
	if not rl.is_empty():
		Ink.text(self, f, Vector2(124, 96), "  ·  ".join(rl), 14, Ink.SHU)

	# board
	var br = Rect2(ORG, Vector2(s.w, s.h) * TS)
	draw_rect(br, Ink.a(Ink.GOFUN, 0.40))
	var lit = _lit()
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
			elif ch == "m":
				Ink.offering(self, r.get_center(), TS)
			elif ch == "b":
				Ink.water(self, r, time)
				Ink.bridge(self, r, s.visited.has(p) and p != s.hero)
			elif ch == "w":
				Ink.web(self, r.get_center(), TS)
			elif ch == "x":
				Ink.mark(self, r, (s.inked & (1 << (y * s.w + x))) != 0)
			if s.r_garden and (ch == "." or ch == "i") and not s.visited.has(p):
				# gravel not yet raked
				for k in range(3):
					draw_circle(r.position + Vector2(TS * (0.3 + 0.2 * k), TS * (0.4 + 0.12 * ((x + y + k) % 3))), 1.6, Ink.a(Ink.SUMI, 0.35))
			if dng.has(p) and ch != "f" and (lit.is_empty() or lit.has(p)):
				Ink.blot(self, r.get_center(), TS * 0.66, TS * 0.66, Ink.SHU, 0.52 + 0.08 * sin(time * 4.0))
			if not lit.is_empty() and not lit.has(p):
				draw_rect(r, Color(0.06, 0.06, 0.12, 0.62))
	for i in range(s.w + 1):
		draw_line(ORG + Vector2(i * TS, 0), ORG + Vector2(i * TS, s.h * TS), Ink.a(Ink.SUMI, 0.28), 1.2)
	for i in range(s.h + 1):
		draw_line(ORG + Vector2(0, i * TS), ORG + Vector2(s.w * TS, i * TS), Ink.a(Ink.SUMI, 0.28), 1.2)
	Ink.frame(self, br, 6.0, Ink.SUMI)

	for w in s.wards:
		Ink.ward(self, f, ctr(w), TS)
	for al in s.allies:
		Ink.shiki(self, f, ctr(al.pos), TS, Data.LEGEND[al.kind][0].substr(0, 1))

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
			if Sim.ally_at(s, t) >= 0 or (yi >= 0 and (Sim.hidden(s.yokai[yi]) or s.r_nocut or Sim.is_sealed(s, yi))):
				continue
			if mode == "" and yi >= 0:
				var c = ctr(t)
				Ink.enso(self, c, TS * 0.44, 5.0, Ink.a(Ink.SHU, 0.85))
				Ink.text(self, f, c + Vector2(TS * 0.2, -TS * 0.24), str(Sim.cut_power(s, d)), 22, Ink.SHU)
			elif yi < 0 and (((mode == "ward" or mode == "shiki") and Sim.ter(s, t) == "." and not s.wards.has(t)) or (mode != "ward" and mode != "shiki" and Sim.walk(s, t) and not s.visited.has(t))):
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
	# the red thread between soul-flames
	var flames = []
	for y in s.yokai:
		if y.kind == "hitodama":
			flames.append(ORG + (disp.get(y.id, Vector2(y.pos)) + Vector2(0.5, 0.5)) * TS)
	for i in range(1, flames.size()):
		var th = []
		for k in range(13):
			var u = k / 12.0
			th.append(flames[i - 1].lerp(flames[i], u) + Vector2(0, sin(u * PI) * 14.0 + sin(time * 2.0 + u * 6.0) * 3.0))
		Ink.brush(self, th, 3.0, Ink.a(Ink.SHU, 0.9))
	for e in cast:
		if e[3] == null:
			main.piece(self, "hero", e[2], TS)
			continue
		var y = e[3]
		var dark = not lit.is_empty() and not lit.has(y.pos)
		if Sim.hidden(y):
			Ink.rock(self, e[2], TS, y.id * 17 + 5)
			if not dark:
				Ink.leaf(self, e[2] + Vector2(0, -TS * 0.30), TS)
			continue
		var mod = Color.WHITE
		if dark:
			mod = Color(0.05, 0.05, 0.08, 0.85)   # a shape in the dark, nothing more
		elif y.down:
			mod = Color(1, 1, 1, 0.4)
		main.piece(self, e[1], e[2], TS, time + y.id, y.max >= 3 or y.ch == "T", false, {"S": 1.3, "G": 1.45, "P": 1.25}.get(y.ch, 1.0), mod)
		if y.down:
			Ink.text(self, f, e[2] + Vector2(-TS * 0.5, TS * 0.1), "倒", 26, Ink.SHU, HORIZONTAL_ALIGNMENT_CENTER, TS)
	for y in s.yokai:
		if Sim.hidden(y) or (not lit.is_empty() and not lit.has(y.pos)):
			continue
		Ink.hp_pips(self, ORG + (disp.get(y.id, Vector2(y.pos)) + Vector2(0.5, 0.5)) * TS, TS, y.hp, y.max)
	if s.r_order:
		var num = ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十", "十一", "十二", "十三", "十四", "十五", "十六"]
		for i in range(s.yokai.size()):
			var y = s.yokai[i]
			if not lit.is_empty() and not lit.has(y.pos):
				continue
			Ink.tag(self, f, ORG + (disp.get(y.id, Vector2(y.pos)) + Vector2(0.5, 0.5)) * TS, TS, num[min(y.id, 15)], i == 0)
	_weather(br)

	for e in fx:
		var u = 1.0 - e.life / e.max
		var c = ctr(e.pos)
		if e.k == "bell":
			for ring in range(3):
				var uu = clamp(u * 1.6 - ring * 0.22, 0.0, 1.0)
				draw_arc(c, TS * (0.4 + 3.2 * uu), 0, TAU, 48, Ink.a(Ink.KIN, (1.0 - uu) * 0.9), 6.0, true)
			Ink.text(self, f, c + Vector2(-28, -40 - 20 * u), "鐘", 56, Ink.a(Ink.KIN, 1.0 - u))
		elif e.k == "kill" and e.has("quiet"):
			draw_arc(c, TS * (0.2 + 0.4 * u), 0, TAU, 32, Ink.a(Ink.AI, 1.0 - u), 4.0, true)
		elif e.k == "kill":
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
	if guide_msg != "":
		Ink.text(self, f, Vector2(ORG.x, 713), "手本  " + guide_msg, 15, Ink.SHU)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if flash > 0.0:
		draw_rect(Rect2(0, 0, 1280, 720), Ink.a(Ink.SHU, flash * 0.35))
	if done:
		_result(f)
	draw_btns()

# Night: what Suzu can see. Empty when it is not night.
func _lit():
	var lit = {}
	if not s.r_night:
		return lit
	var src = [[s.hero, 2]]
	for y in s.yokai:
		if y.kind == "chochin" or y.kind == "hitodama":
			src.append([y.pos, 1])
	for al in s.allies:
		src.append([al.pos, 1])
	for yy in range(s.h):
		for xx in range(s.w):
			if s.rows[yy][xx] == "f":
				src.append([Vector2i(xx, yy), 1])
	for e in src:
		for dy in range(-e[1], e[1] + 1):
			for dx in range(-e[1], e[1] + 1):
				if abs(dx) + abs(dy) <= e[1]:
					lit[e[0] + Vector2i(dx, dy)] = true
	return lit

# rain, snow and wind are painted over the board; they change nothing by themselves
func _weather(br):
	var w = br.size.x
	var h = br.size.y
	if rules.has("rain"):
		for k in range(46):
			var p = br.position + Vector2(fmod(k * 97.0 + time * 60.0, w), fmod(k * 53.0 + time * 420.0, h))
			draw_line(p, p + Vector2(-5, 18), Ink.a(Ink.AI, 0.38), 1.3, true)
	if rules.has("snow"):
		for k in range(40):
			var p = br.position + Vector2(fmod(k * 83.0 + sin(time * 0.7 + k) * 14.0 + w, w), fmod(k * 61.0 + time * 34.0, h))
			draw_circle(p, 2.0 + (k % 3), Ink.a(Ink.GOFUN, 0.85))
	if s.wind != Vector2i.ZERO:
		var d = Vector2(s.wind)
		for k in range(9):
			var along = fmod(k * 131.0 + time * 150.0, w + 160.0) - 80.0
			var across = fmod(k * 71.0 + 30.0, h)
			var a = br.position + (Vector2(along, across) if d.x != 0 else Vector2(across, along))
			if d.x < 0 or d.y < 0:
				a = br.position + (Vector2(w - along, across) if d.x != 0 else Vector2(across, h - along))
			var pts = []
			for j in range(6):
				pts.append(a + d * j * 14.0 + d.orthogonal() * sin(j * 1.1 + k) * 3.0)
			if br.grow(-4).has_point(pts[0]) and br.grow(-4).has_point(pts[5]):
				Ink.brush(self, pts, 3.5, Ink.a(Ink.SUMI, 0.22))

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
		wz += "喝 %d   " % s.katsu
	if lv.waza.has("bell"):
		wz += "鐘 %d" % s.bell
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
	elif mode == "shiki":
		hint = "式神 — choose a tile beside you for the shikigami. Esc cancels."
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
	if not s.r_shiki:
		Ink.text(self, f, Vector2(PX + 282, 604), "click, drag or arrows to paint", 13, Ink.a(Ink.SUMI, 0.55))
		Ink.text(self, f, Vector2(PX + 282, 622), "right-click undoes", 13, Ink.a(Ink.SUMI, 0.55))

func _result(f):
	var box = Rect2(150, 200, 400, 380)
	draw_rect(box, Ink.a(Ink.PAPER, 0.9))
	Ink.slip(self, box, 5.0)
	if grade == "jouzu":
		Ink.seal(self, f, Vector2(232, 296), 50, "上手")
		_my_scroll()
		_seals(f)
		Ink.text(self, f, Vector2(150, 408), "Mastered in %d stroke%s, unharmed." % [s.turn, "" if s.turn == 1 else "s"], 19, Ink.SUMI, HORIZONTAL_ALIGNMENT_CENTER, 400)
	elif grade == "ka":
		Ink.seal(self, f, Vector2(232, 290), 58, "可", Ink.AI)
		_my_scroll()
		_seals(f)
		var why = "%d strokes; mastery asks %d." % [s.turn, lv.par]
		if s.hits > 0:
			why = "%d strokes, %d blow%s taken." % [s.turn, s.hits, "" if s.hits == 1 else "s"]
		Ink.text(self, f, Vector2(150, 402), "Passed. " + why, 17, Ink.SUMI, HORIZONTAL_ALIGNMENT_CENTER, 400)
		Ink.text(self, f, Vector2(150, 422), "上手 needs %d strokes and no blows." % lv.par, 14, Ink.a(Ink.SUMI, 0.7), HORIZONTAL_ALIGNMENT_CENTER, 400)
	else:
		Ink.text(self, f, Vector2(150, 320), "無念", 84, Ink.SUMI, HORIZONTAL_ALIGNMENT_CENTER, 400)
		var why = "The ink runs. Nothing is lost but a stroke."
		if rules.has("koan"):
			why = "A kōan has no second stroke. Begin again."
		elif rules.has("garden"):
			why = "The garden is not yet raked. Begin again."
		elif rules.has("write") and s.ki > 0:
			why = "The character is not finished."
		Ink.text(self, f, Vector2(150, 384), why, 18, Ink.SUMI, HORIZONTAL_ALIGNMENT_CENTER, 400)
		Ink.text(self, f, Vector2(150, 416), "七転び八起き  —  fall seven times, rise eight", 15, Ink.a(Ink.SHU, 0.9), HORIZONTAL_ALIGNMENT_CENTER, 400)

# the three seals, lit if this clear earned them
func _seals(f):
	for k in range(main.SEALS.size()):
		var sl = main.SEALS[k]
		var c = Vector2(250 + k * 100, 446)
		if seal_mask & sl[0]:
			Ink.seal(self, f, c, 11, sl[1])
		else:
			Ink.text(self, f, Vector2(c.x - 40, c.y + 6), sl[1], 15, Ink.a(Ink.SUMI, 0.28), HORIZONTAL_ALIGNMENT_CENTER, 80)

# what you painted to clear this stage, as it will hang in the scroll
func _my_scroll():
	var r = Rect2(318, 222, 196, 160)
	draw_rect(r, Ink.a(Ink.GOFUN, 0.9))
	Ink.frame(self, r, 2.5, Ink.a(Ink.SUMI, 0.7))
	Ink.calligraphy(self, r.grow(-10), my_paths, s.w, s.h)
