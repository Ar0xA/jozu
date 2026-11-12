extends "res://scripts/screen_base.gd"
# The workshop: lay out a board, clear it yourself, and it becomes a code to give away.

const Sim = preload("res://scripts/sim.gd")
const TS = 84.0
const ORG = Vector2(56, 104)
const PX = 700.0
const GROUND = [[".", "地", "floor"], ["#", "石", "stone"], ["~", "水", "water"], ["i", "氷", "ice"], ["f", "火", "fire"], ["g", "門", "gate"],
	["m", "供", "offering"], ["b", "橋", "plank bridge"], ["w", "巣", "web"], ["x", "字", "a tile to be written"]]
const PIECES = [
	["H", "鈴", "Suzu"], ["c", "灯", "lantern"], ["o", "鬼", "oni (2)"], ["O", "剛", "great oni (3)"], ["S", "王", "oni king (5)"],
	["t", "天", "tengu (1)"], ["T", "狗", "great tengu (2)"], ["k", "狐", "fox"], ["Q", "玉", "Tamamo (5)"], ["y", "霊", "ghost"],
	["u", "傘", "umbrella"], ["p", "河", "kappa (2)"], ["P", "伯", "kappa lord (4)"], ["n", "壁", "wall (3)"], ["W", "雪", "snow woman (3)"],
	["G", "骸", "skeleton (7)"], ["d", "磨", "daruma"], ["a", "狸", "tanuki"], ["e", "魂", "soul-flame"], ["X", "死", "shinigami (3)"],
	["K", "鼬", "kamaitachi"],
]
const RULES = [["koan", "公案"], ["garden", "石庭"], ["gate", "鳥居"], ["wet", "墨"], ["enso", "円相"], ["stone", "硯"],
	["nocut", "無刀"], ["shiki", "式神"], ["wind", "風"], ["rain", "雨"], ["snow", "雪"], ["night", "夜"], ["order", "封"], ["write", "書"]]
const WAZA = [["leap", "縮地"], ["ward", "結界"], ["katsu", "喝"], ["bell", "鐘"]]
const WINDS = ["", "R", "L", "D", "U"]
const ARROW = {"": "", "R": "→", "L": "←", "D": "↓", "U": "↑"}

var st = {}            # the board being made: rows, waza, rules, ink, par
var tool = "#"
var note = "stone"
var msg = ""
var line
var tool_btns = {}
var rule_btns = {}
var waza_btns = {}
var last_tile = Vector2i(-9, -9)
# On a phone the palette is four pages of large buttons, not one page of small ones.
const PAGES = [["地", "Ground"], ["妖", "Yokai"], ["則", "Rules"], ["渡", "Share"]]
var tab = 0
var tab_btns = []
var paged = []        # [button, the page it belongs to]
var b_minus
var b_plus

func setup():
	st = main.board_from_code(main.data.mine)
	if st.is_empty():
		st = main.blank_board()
	for i in range(GROUND.size()):
		tool_btns[GROUND[i][0]] = btn(Rect2(PX + i * 50, 92, 46, 38), GROUND[i][1], _tool.bind(GROUND[i][0], GROUND[i][2]))
	for i in range(PIECES.size()):
		tool_btns[PIECES[i][0]] = btn(Rect2(PX + (i % 11) * 49, 162 + (i / 11) * 44, 45, 38), PIECES[i][1], _tool.bind(PIECES[i][0], PIECES[i][2]))
	for i in range(RULES.size()):
		rule_btns[RULES[i][0]] = btn(Rect2(PX + (i % 7) * 77, 282 + (i / 7) * 42, 73, 36), RULES[i][1], _rule.bind(RULES[i][0]))
	for i in range(WAZA.size()):
		waza_btns[WAZA[i][0]] = btn(Rect2(PX + i * 80, 398, 76, 36), WAZA[i][1], _waza.bind(WAZA[i][0]))
	b_minus = btn(Rect2(PX + 330, 398, 40, 36), "−", _ink.bind(-1))
	b_plus = btn(Rect2(PX + 446, 398, 40, 36), "+", _ink.bind(1))
	var b_play = btn(Rect2(PX, 494, 264, 50), "Play it", _test, "試")
	var b_wipe = btn(Rect2(PX + 276, 494, 264, 50), "Wipe the board", _clear, "消")
	var b_copy = btn(Rect2(PX, 602, 264, 40), "Copy the code", _copy, "写")
	var b_load = btn(Rect2(PX + 276, 602, 264, 40), "Load a code", _load, "読")
	var b_back = btn(Rect2(PX + 276, 656, 264, 44), "Back", main.show_hub, "道")
	if main.touch:
		for k in range(PAGES.size()):
			tab_btns.append(btn(Rect2(PX + k * 137, 26, 129, 56), PAGES[k][1], _tab.bind(k)))
		for i in range(GROUND.size()):
			var b = tool_btns[GROUND[i][0]]
			b.rect = Rect2(PX + (i % 5) * 110, 100 + (i / 5) * 72, 100, 62)
			paged.append([b, 0])
		for i in range(PIECES.size()):
			var b = tool_btns[PIECES[i][0]]
			b.rect = Rect2(PX + (i % 5) * 110, 100 + (i / 5) * 68, 100, 58)
			paged.append([b, 1])
		for i in range(RULES.size()):
			var b = rule_btns[RULES[i][0]]
			b.rect = Rect2(PX + (i % 5) * 110, 100 + (i / 5) * 68, 100, 58)
			paged.append([b, 2])
		for i in range(WAZA.size()):
			var b = waza_btns[WAZA[i][0]]
			b.rect = Rect2(PX + i * 137, 318, 129, 58)
			paged.append([b, 2])
		b_minus.rect = Rect2(PX + 250, 392, 90, 58)
		b_plus.rect = Rect2(PX + 450, 392, 90, 58)
		paged.append([b_minus, 2])
		paged.append([b_plus, 2])
		b_wipe.rect = Rect2(PX, 100, 264, 66)
		b_wipe.label = "Wipe it"
		b_copy.label = "Copy code"
		b_load.label = "Load code"
		b_copy.rect = Rect2(PX, 250, 264, 66)
		b_load.rect = Rect2(PX + 276, 250, 264, 66)
		for b in [b_wipe, b_copy, b_load]:
			paged.append([b, 3])
		b_play.rect = Rect2(PX, 632, 264, 70)
		b_back.rect = Rect2(PX + 276, 632, 264, 70)
	line = LineEdit.new()
	line.position = Vector2(PX, 556)
	line.size = Vector2(540, 38)
	line.placeholder_text = "a board's code appears here; paste someone else's and press Load"
	line.add_theme_font_override("font", main.font)
	line.add_theme_font_size_override("font_size", 15)
	if main.touch:
		line.position = Vector2(PX, 184)
		line.size = Vector2(540, 54)
		line.placeholder_text = "the code appears here; paste one and tap Load"
		line.add_theme_font_size_override("font_size", 22)
	add_child(line)
	_tab(0)
	_sync()

func _tab(k):
	tab = k
	if not main.touch:
		return
	for i in range(tab_btns.size()):
		tab_btns[i].sel = i == k
	for e in paged:
		e[0].show = e[1] == k
	line.visible = k == 3

# the palette side of the page, as a phone draws it
func _draw_phone(f):
	if tab == 2:
		Ink.text(self, f, Vector2(PX, 430), "Ink in a stroke", 24, Ink.a(Ink.SUMI, 0.75))
		Ink.text(self, f, Vector2(PX + 340, 434), str(int(st.ink)), 38, Ink.SUMI, HORIZONTAL_ALIGNMENT_CENTER, 110)
	if tab <= 1:
		Ink.text(self, f, Vector2(PX, 492 if tab == 1 else 280), "Brush: " + note + ".  Tap or drag on the board.", 24, Ink.SHU)
	var status = msg
	if status == "":
		status = "Cleared in %d stroke%s. Its code is on the Share page." % [int(st.par), "" if int(st.par) == 1 else "s"] if int(st.par) > 0 else "Ready. Play it and clear it to turn it into a code."
	Ink.para(self, f, Vector2(PX, 548), status, 22, Ink.a(Ink.SHU, 0.95), 540)

func _wind():
	for r in st.rules:
		if r.begins_with("wind:"):
			return r.substr(5)
	return ""

func _sync():
	for k in tool_btns:
		tool_btns[k].sel = k == tool
	for k in rule_btns:
		rule_btns[k].sel = st.rules.has(k) or (k == "wind" and _wind() != "")
	rule_btns["wind"].label = "風" + ARROW[_wind()]
	for k in waza_btns:
		waza_btns[k].sel = st.waza.has(k)
	msg = _problem()
	line.text = main.board_code(st) if (msg == "" and int(st.par) > 0) else ""
	main.data.mine = main.board_code(st)
	main.write_save()

func _changed():
	st.par = 0   # a changed board must be cleared again before it can be given away
	_sync()

func _tool(t, what):
	tool = t
	note = what
	_sync()

func _rule(r):
	if r == "wind":
		var w = WINDS[(WINDS.find(_wind()) + 1) % WINDS.size()]
		st.rules = st.rules.filter(func(x): return not x.begins_with("wind:"))
		if w != "":
			st.rules.append("wind:" + w)
	elif st.rules.has(r):
		st.rules.erase(r)
	else:
		st.rules.append(r)
	_changed()

func _waza(w):
	if st.waza.has(w):
		st.waza.erase(w)
	else:
		st.waza.append(w)
	_changed()

func _ink(d):
	st.ink = clamp(int(st.ink) + d, 2, 12)
	_changed()

func _clear():
	st = main.blank_board()
	_changed()

func _copy():
	if line.text == "":
		msg = "Nothing to copy yet: clear your board first."
		return
	DisplayServer.clipboard_set(line.text)
	msg = "Copied. Anyone can paste it here to play your board."

func _load():
	var got = main.board_from_code(line.text.strip_edges())
	if got.is_empty():
		msg = "That is not a board code."
		return
	st = got
	_sync()
	msg = "Loaded. Mastery asks %d stroke%s. Press Play it." % [int(st.par), "" if int(st.par) == 1 else "s"]

# what stops this board being played, or "" if nothing does
func _problem():
	var text = "".join(st.rows)
	if text.count("H") != 1:
		return "Place Suzu (鈴) on the board."
	var yokai = 0
	for ch in text:
		if Sim.DEF.has(ch):
			yokai += 1
	if st.rules.has("garden"):
		if yokai > 0:
			return "A stone garden has no yokai in it."
	elif st.rules.has("gate"):
		if text.count("g") < 1:
			return "A gate stage needs a torii (門)."
	elif st.rules.has("write"):
		if text.count("x") < 1:
			return "A writing stage needs tiles to be written (字)."
	elif yokai == 0:
		return "Place at least one yokai."
	if st.rules.has("koan") and st.rules.has("garden"):
		return "Kōan and stone garden cannot both be set."
	return ""

func _test():
	msg = _problem()
	if msg != "":
		return
	var lv = main.board_level(st)
	lv["kanji"] = "自作"
	lv["name"] = "A board from the workshop"
	lv["hint"] = "Clear it and it can be given away as a code. Your stroke count becomes its mastery target."
	if int(st.par) > 0:
		lv["hint"] = "Mastery here asks %d stroke%s, unharmed." % [int(st.par), "" if int(st.par) == 1 else "s"]
	main.show_custom(lv, "custom", "Workshop", main.mine_won, Callable(), main.show_editor)

func _paint(pos):
	var t = Vector2i(int(floor((pos.x - ORG.x) / TS)), int(floor((pos.y - ORG.y) / TS)))
	if t.x < 0 or t.y < 0 or t.x > 6 or t.y > 6 or t == last_tile:
		return
	last_tile = t
	if tool == "H":
		for y in range(7):
			st.rows[y] = st.rows[y].replace("H", ".")
	var row = st.rows[t.y]
	if row[t.x] == tool:
		return
	st.rows[t.y] = row.substr(0, t.x) + tool + row.substr(t.x + 1)
	_changed()

func on_click(pos, button):
	if button == MOUSE_BUTTON_LEFT:
		last_tile = Vector2i(-9, -9)
		_paint(pos)

func on_motion(pos, held):
	if held:
		_paint(pos)

func on_key(code):
	if code == KEY_ESCAPE and not line.has_focus():
		main.show_hub()

func _draw():
	var f = main.font
	Ink.seal(self, f, Vector2(84, 52), 24, "工房")
	Ink.text(self, f, Vector2(124, 62), "The Workshop", 40, Ink.SUMI)
	var br = Rect2(ORG, Vector2(7, 7) * TS)
	draw_rect(br, Ink.a(Ink.GOFUN, 0.40))
	for y in range(7):
		for x in range(7):
			var ch = st.rows[y][x]
			var r = Rect2(ORG + Vector2(x, y) * TS, Vector2(TS, TS))
			var c = r.get_center()
			var kind = Sim.DEF[ch][0] if Sim.DEF.has(ch) else ""
			if ch == "~" or kind == "kappa":
				Ink.water(self, r, time)
			elif ch == "#":
				Ink.rock(self, c, TS, x * 31 + y * 7 + 3)
			elif ch == "i":
				Ink.ice(self, r)
			elif ch == "f":
				Ink.fire(self, r, time + x + y)
			elif ch == "g":
				Ink.torii(self, r)
			elif ch == "m":
				Ink.offering(self, c, TS)
			elif ch == "b":
				Ink.water(self, r, time)
				Ink.bridge(self, r, false)
			elif ch == "w":
				Ink.web(self, c, TS)
			elif ch == "x":
				Ink.mark(self, r, false)
	for i in range(8):
		draw_line(ORG + Vector2(i * TS, 0), ORG + Vector2(i * TS, 7 * TS), Ink.a(Ink.SUMI, 0.28), 1.2)
		draw_line(ORG + Vector2(0, i * TS), ORG + Vector2(7 * TS, i * TS), Ink.a(Ink.SUMI, 0.28), 1.2)
	Ink.frame(self, br, 6.0, Ink.SUMI)
	for y in range(7):
		for x in range(7):
			var ch = st.rows[y][x]
			var c = ORG + (Vector2(x, y) + Vector2(0.5, 0.5)) * TS
			if ch == "H":
				main.piece(self, "hero", c, TS)
			elif ch == "a":
				Ink.rock(self, c, TS, 77)
				Ink.leaf(self, c + Vector2(0, -TS * 0.30), TS)
			elif Sim.DEF.has(ch):
				main.piece(self, Sim.DEF[ch][0], c, TS, time, Sim.DEF[ch][1] >= 3 or ch == "T", false, {"S": 1.3, "G": 1.45, "P": 1.25}.get(ch, 1.0))
				Ink.hp_pips(self, c, TS, Sim.DEF[ch][1], Sim.DEF[ch][1])
	Ink.brush(self, [Vector2(PX - 22, 30), Vector2(PX - 23, 250), Vector2(PX - 21, 470), Vector2(PX - 22, 690)], 4.0, Ink.a(Ink.SUMI, 0.45))
	if main.touch:
		_draw_phone(f)
		draw_btns()
		return
	Ink.text(self, f, Vector2(PX, 80), "Ground", 16, Ink.a(Ink.SUMI, 0.7))
	Ink.text(self, f, Vector2(PX + 320, 118), "brush: " + note, 16, Ink.SHU)
	Ink.text(self, f, Vector2(PX, 152), "Suzu and the yokai  (click or drag on the board to place)", 16, Ink.a(Ink.SUMI, 0.7))
	Ink.text(self, f, Vector2(PX, 272), "Rules of the stage", 16, Ink.a(Ink.SUMI, 0.7))
	Ink.text(self, f, Vector2(PX, 388), "Techniques", 16, Ink.a(Ink.SUMI, 0.7))
	Ink.text(self, f, Vector2(PX + 330, 388), "Ink in a stroke", 16, Ink.a(Ink.SUMI, 0.7))
	Ink.text(self, f, Vector2(PX + 370, 424), str(int(st.ink)), 24, Ink.SUMI, HORIZONTAL_ALIGNMENT_CENTER, 76)
	var status = msg
	if status == "":
		status = "Cleared in %d stroke%s. The code below is ready to give away." % [int(st.par), "" if int(st.par) == 1 else "s"] if int(st.par) > 0 else "Ready. Play it and clear it to turn it into a code."
	Ink.para(self, f, Vector2(PX, 462), status, 16, Ink.a(Ink.SHU, 0.95), 540)
	draw_btns()
