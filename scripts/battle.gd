extends "res://scripts/screen_base.gd"
# One stage: the board, the stroke being painted, and the panel beside it.

const Sim = preload("res://scripts/sim.gd")
const TS = 84.0
const MA = 0.3         # 間: the stillness after the brush lifts, before anything answers
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
var walk = []          # the yokai's turn, played out a step at a time: [{id, to, at}]
var walk_t = 0.0
var aim = {}           # where each yokai is being drawn towards while it walks
var later = []         # sounds waiting for their moment: [{at, nm}]
var last_inked = 0
var ki_max = 0
var rule_line = ""     # these three follow the board, and are worked out when it changes (_sync)
var lit = {}
var bound = []
const WIND_ARROW = {Vector2i(1, 0): "→", Vector2i(-1, 0): "←", Vector2i(0, 1): "↓", Vector2i(0, -1): "↑"}
const RULE_BRIEF = {"公": "公案 one stroke", "墨": "墨 wet wall", "円": "円相 circle binds", "石": "石庭 rake all", "鳥": "鳥居 reach it",
	"無": "無刀 no cut", "硯": "硯 ink kept", "式": "式神 set allies", "風": "風 wind", "雨": "雨 rain", "雪": "雪 ice", "夜": "夜 night",
	"封": "封 in order", "書": "書 write it", "供": "供 offerings lure", "橋": "橋 planks fall", "巣": "巣 webs stop you", "鐘": "鐘 all still"}

# The card laid over the board when a stage opens: what must be done, and anything met here for
# the first time. It goes by itself after a while, or at a touch.
var card = []          # [[text, size, colour]]
var card_t = 0.0
var card_len = 0.0
const RULE_NOTE = {
	"wet": "墨 Wet ink: the stroke you have just painted is a wall to the yokai for their turn.",
	"enso": "円相 End a stroke beside where it began, and every yokai inside the loop is bound.",
	"nocut": "無刀 The brush cannot cut here: bind, drown, or go around.",
	"stone": "硯 Ink you do not spend is kept for the next stroke.",
	"shiki": "式神 A yokai you bind can be set down beside you as an ally.",
	"wind": "風 Each turn the wind carries lanterns, umbrellas and ghosts one tile.",
	"rain": "雨 Lanterns and fire are out, and the kappa come ashore.",
	"snow": "雪 All water is frozen to ice.",
	"night": "夜 You see only near yourself and near light.",
	"order": "封 Only the lowest number still on the board can be harmed.",
	"m": "供 Walking yokai go to an offering instead of to you, and stop to eat it.",
	"b": "橋 Planks you cross fall in after the yokai move, with whatever stands on them.",
	"w": "巣 Step into a web and your stroke ends there.",
	"i": "氷 On ice you slide until something stops you.",
	"f": "火 Fire burns you if you end a stroke standing on it.",
	"bell": "鐘 The bell, once: no yokai strikes or moves for a turn.",
	"leap": "縮地 Leap: jump over one tile of anything.",
	"ward": "結界 Ward: paste a seal beside you that no yokai can enter.",
	"katsu": "喝 Shout: hurl every yokai beside you one tile away. Into water, they are gone.",
}
var born_t = 0.0       # when the stage was last begun: the yokai gather out of the ink from then
var done_t = 0.0       # when the stage ended, for the seal and the replay of your strokes
var share_note = ""    # what became of the day's card when it was passed on
var flash = 0.0
var last_drag = Vector2i(-9, -9)
var done = false
var grade = ""
var kinds = []
var new_kinds = []     # the yokai not met before this stage: the only ones the spare panel explains
var b_leap
var b_ward
var b_katsu
var b_bell
var b_goal
var b_end
var b_undo
var b_restart
var b_road
var b_shiki
# A board from outside the story (daily koan, pilgrimage, workshop) is passed in as `custom`,
# with what to do when it is won or lost and where "back" leads.
var custom = null
var kind_of = "story"   # story | daily | henro | custom | random
var label = ""
var on_win = Callable()
var on_fail = Callable()
var back = Callable()
var guide = false      # the very first stage, until it is cleared: the stroke to paint is shown dotted
var guide_msg = ""
var dng = {}
var undos = 0
var starts = 0         # how many times the stage has been begun since it was entered
var seal_mask = 0
var extra = []
var rules = []
var my_paths = []
var hint_path = []
var hint_marks = []
var ending = false

func setup():
	rest = 1.0 / 15.0
	lv = custom if custom != null else Data.LEVELS[idx]
	rules = lv.get("rules", [])
	if not back.is_valid():
		back = main.show_map
	guide = custom == null and idx == 0 and main.grade_of(0) == ""
	b_leap = btn(Rect2(PX, 470, 172, 46), "Leap [1]", _mode.bind("leap"), "縮地")
	b_ward = btn(Rect2(PX + 184, 470, 172, 46), "Ward [2]", _mode.bind("ward"), "結界")
	b_katsu = btn(Rect2(PX + 368, 470, 172, 46), "Shout [3]", _katsu, "喝")
	b_bell = btn(Rect2(), "Bell [5]", _bell, "鐘")   # _sync lays out the row of techniques
	b_goal = btn(Rect2(536, 34, 108, 40), "Goal", func(): _brief(false), "問")
	b_end = btn(Rect2(PX, 526, 264, 50), "Lift  [Space]", _end, "収筆")
	b_undo = btn(Rect2(PX + 276, 526, 264, 50), "Undo  [Z]", _undo, "戻")
	b_shiki = btn(Rect2(PX, 586, 264, 42), "Set  [4]", _mode.bind("shiki"), "式神")
	b_restart = btn(Rect2(PX, 642, 264, 44), "Restart  [R]" if kind_of != "henro" else "Give up this temple", _retry)
	b_road = btn(Rect2(PX + 276, 642, 264, 44), "Back to the road" if custom == null else "Leave", _leave)
	if main.touch:
		# a phone's panel: a few things, large. The legend, the lesson and the saying live in the card (問).
		b_end.rect = Rect2(PX, 436, 264, 70)
		b_undo.rect = Rect2(PX + 276, 436, 264, 70)
		b_goal.rect = Rect2(PX, 518, 540, 62)
		b_goal.label = "Goal and notes"
		b_restart.rect = Rect2(PX, 594, 264, 62)
		b_road.rect = Rect2(PX + 276, 594, 264, 62)
		b_road.label = "Leave"
	_restart()
	for y in s.yokai:
		if not kinds.has(y.kind):
			kinds.append(y.kind)
	_brief(true)

# Walking out of a temple that is lost, or begun and not won, is the same as giving it up.
func _leave():
	if kind_of == "henro" and s.status != "won" and (done or s.turn > 0 or not hist.is_empty()):
		main.henro_spend()
	back.call()

# Lay out the card. first = the stage is opening (new things are noted as met); otherwise it has
# been asked for again, and shows everything.
func _brief(first):
	if done:
		return
	var big = main.touch
	var goal = "Fell every yokai."
	if rules.has("koan"):
		goal = "Clear the board in one stroke."
	elif rules.has("garden"):
		goal = "Rake every open tile in one stroke."
	elif rules.has("gate"):
		goal = "Reach the torii. Nothing need be cut."
	elif rules.has("write"):
		goal = "Paint every grey tile. Nothing need be cut."
	card = [["目当て  The goal", 20 if big else 15, Ink.a(Ink.SHU, 0.9)], [goal, 40 if big else 26, Ink.SUMI],
		["上手 mastery: within %d stroke%s, unharmed." % [lv.par, "" if lv.par == 1 else "s"], 24 if big else 16, Ink.a(Ink.SUMI, 0.7)]]
	# what is here: yokai, rules, ground and techniques
	var here = []
	for k in kinds:
		here.append(["y:" + k, "%s %s: %s  To fell it: %s" % [Data.LEGEND[k][0], Data.LEGEND[k][1], Data.LEGEND[k][2], Data.LEGEND[k][3]]])
	var ground = "".join(lv.rows)
	for r in rules:
		var key = "wind" if r.begins_with("wind") else r
		if RULE_NOTE.has(key):
			here.append(["r:" + key, RULE_NOTE[key]])
	for g in ["i", "f", "m", "b", "w"]:
		if ground.contains(g):
			here.append(["g:" + g, RULE_NOTE[g]])
	for w in lv.waza:
		if RULE_NOTE.has(w):
			here.append(["w:" + w, RULE_NOTE[w]])
	var fresh = []
	if first and starts <= 1:
		new_kinds = kinds.filter(func(k): return not main.data.met.has("y:" + k))
	for e in here:
		if not main.data.met.has(e[0]):
			fresh.append(e[1])
			if first and custom == null:
				main.data.met[e[0]] = 1
	if first and custom == null and not fresh.is_empty():
		main.write_save()
	var notes = []
	if lv.hint != "":
		notes = [main.touch_words(lv.hint)]   # the stage's own lesson says it better than the stock lines
	elif first:
		notes = fresh
	if not first and (lv.hint == "" or not big):
		# asked for: everything that is here, since the spare panel no longer lists it
		for e in here:
			notes.append(e[1])
	if not notes.is_empty():
		card.append(["", 10, Ink.SUMI])
		if first and lv.hint == "":
			card.append(["初  New here", 20 if big else 15, Ink.a(Ink.SHU, 0.9)])
	var chars = 0
	for n in notes:
		card.append([n, 27 if big else 17, Ink.a(Ink.AI, 0.95)])
		chars += n.length()
	var say = lv.get("say", [])
	if big and say.size() == 3:
		# on a phone the stage's saying is read here, not squeezed into the panel
		card.append(["", 10, Ink.SUMI])
		card.append([say[0], 30, Ink.SUMI])
		card.append([say[1], 18, Ink.a(Ink.SUMI, 0.55)])
		card.append([say[2], 24, Ink.a(Ink.AI, 0.95)])
		chars += say[2].length() + 30
		notes = notes + [say[2]]
	card_t = 0.0
	card_len = 3.5 if notes.is_empty() else min(24.0, 6.0 + chars * 0.05)
	if not first:
		card_len = 120.0   # asked for: it stays until it is sent away

# Upright, the card is cut out and shown alone, so it is drawn narrow, and its writing a little smaller.
func _card_k():
	return 0.86 if main.tall else 1.0

func tall_parts(_h):
	if not card.is_empty() and not done:
		return [{"src": [_card_rect(main.font)], "s": 1.05}]
	return [{"src": [Rect2(0, 30, 668, 672)], "s": 1.078}, {"src": [Rect2(676, 14, 604, 646)], "s": 1.19}]

func tall_modal():
	return not card.is_empty() and not done

func _card_rect(f):
	var w = 680.0 if main.tall else 1120.0 if main.touch else 540.0
	var h = 30.0
	for line in card:
		h += f.get_multiline_string_size(line[0], HORIZONTAL_ALIGNMENT_LEFT, w - 60.0, int(line[1] * _card_k())).y + 8.0 if line[0] != "" else line[1]
	h += 30.0
	if main.tall:
		return Rect2(Vector2(10.0, max(8.0, 360.0 - h * 0.5)), Vector2(w, h))
	return Rect2(Vector2(640.0 - w * 0.5, max(16.0, 360.0 - h * 0.5)) if main.touch else Vector2(ORG.x + 24, max(ORG.y + 16.0, ORG.y + 294.0 - h * 0.5)), Vector2(w, h))

func _draw_card(f):
	var r = _card_rect(f)
	var fade = clamp(card_t / 0.25, 0.0, 1.0) * clamp((card_len - card_t) / 0.4, 0.0, 1.0)
	draw_rect(r, Ink.a(Ink.PAPER, 0.97 * fade))
	if main.spare():
		draw_rect(Rect2(r.position.x, r.position.y, 5.0, r.size.y), Ink.a(Ink.SHU, 0.85 * fade))   # one red rule down the edge
	else:
		draw_rect(r.grow(-6), Ink.a(Ink.GOFUN, 0.5 * fade))
		Ink.frame(self, r, 4.0, Ink.a(Ink.SUMI, 0.85 * fade))
	var y = r.position.y + 30.0
	for line in card:
		if line[0] == "":
			y += line[1]
			continue
		var ts = int(line[1] * _card_k())
		var sz = f.get_multiline_string_size(line[0], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 60.0, ts)
		Ink.para(self, f, Vector2(r.position.x + 30.0, y + ts * 0.85), line[0], ts, Ink.a(line[2], line[2].a * fade), r.size.x - 60.0)
		y += sz.y + 8.0
	# how long it will stay, and how to send it away
	draw_rect(Rect2(r.position.x + 30.0, r.end.y - 14.0, (r.size.x - 60.0) * clamp(1.0 - card_t / card_len, 0.0, 1.0), 4.0), Ink.a(Ink.SHU, 0.7 * fade))
	Ink.text(self, f, Vector2(r.position.x, r.end.y - 20.0), "tap to close" if main.touch else "any key or click", 18 if main.touch else 12, Ink.a(Ink.SUMI, 0.5 * fade), HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 30.0)

# The Restart button and key. On the pilgrimage, starting a temple again costs a staff.
func _retry():
	if kind_of == "henro":
		if s.status != "won":
			on_fail.call()
	else:
		_restart()

func _restart():
	s = Sim.new_state(lv.rows, main.stats_for(idx) if custom == null else Data.base_stats(lv), rules)
	s["paths"] = []
	s["spent"] = 0
	ki_max = s.ki
	last_inked = s.inked
	walk = []
	aim = {}
	later = []
	shake = 0.0
	flash = 0.0
	undos = 0
	starts += 1
	born_t = time
	if starts == 1:
		main.sfx("ki2")   # the two cracks of the wooden clappers that open a scene
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
	if main.touch and s.r_shiki:
		row.append(b_shiki)   # on a phone the shikigami button shares the row of techniques
	for i in range(row.size()):
		var bw = (540.0 - 12.0 * (row.size() - 1)) / row.size() if row.size() > 3 else 172.0
		row[i].rect = Rect2(PX + i * (bw + 12.0), 360 if main.touch else 470, bw, 64 if main.touch else 46)
	var live = not done and s.ink > 0
	b_bell.on = live and s.bell > 0 and not s.stun
	b_bell.sel = s.stun
	b_leap.on = live and s.leap > 0
	b_ward.on = live and s.ward > 0
	b_katsu.on = live and s.katsu > 0
	b_leap.sel = mode == "leap"
	b_ward.sel = mode == "ward"
	b_end.on = not done
	b_shiki.show = s.r_shiki
	b_shiki.on = live and not s.hand.is_empty()
	b_shiki.sel = mode == "shiki"
	var names = []
	for k in s.hand:
		names.append(Data.LEGEND[k][0].substr(0, 1))
	b_shiki.label = "Set  [4]   " + ("・".join(names) if not names.is_empty() else "—")
	dng = {} if done else Sim.danger(s)
	rule_line = _rule_line()
	lit = _lit()
	bound = Sim.enso_bound(s)
	_guide_update()
	b_undo.on = _can_undo()
	b_goal.on = not done
	b_restart.on = not (kind_of == "henro" and s.status == "won")

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
		if ["kill", "cut", "hit", "katsu", "ward", "leap", "bell"].has(e.t) and not (ending and e.t == "kill" and e.dmg == 0):
			main.sfx(e.t)
			heard = true
			if e.t == "kill" and e.dmg > 0:
				main.sfx("pon", 1.0, -9.0)   # the hand-drum answers a yokai's fall
			if e.t == "kill" or e.t == "hit":
				main.buzz(40 if e.t == "hit" else 14)
	if not heard and quiet == "step" and main.spare():
		# the brush on the paper: lower and longer the further the stroke has run
		main.sfx("brush", clamp(1.30 - 0.09 * s.visited.size(), 0.72, 1.3))
	elif not heard:
		main.sfx(quiet)
	# the stroke plays a phrase: a note higher with each step, and home to the low string when the brush is lifted
	if quiet == "step":
		main.koto(s.visited.size() - 2 + (s.turn % 2) * 2)
	elif quiet == "sheathe" and s.status == "play":
		main.koto(-5, -13.0)
	if quiet == "step":
		if Sim.ter(s, s.hero) == "w" and s.ink == 0:
			main.sfx("web")
		if s.inked != last_inked:
			main.sfx("ink")
	last_inked = s.inked
	# the yokai's turn is shown one mover after another; what happens after they move waits for them
	walk = []
	aim = {}
	walk_t = 0.0
	later = []
	var cursor = 0.0
	if ending and main.data.opts.motion:
		var moves = s.events.filter(func(e): return e.t == "move")
		if not moves.is_empty():
			cursor = MA
		var gap = min(0.16, 1.1 / max(1, moves.size()))
		var sung = {}
		for e in s.events:
			if e.t == "move":
				if not aim.has(e.id):
					aim[e.id] = disp.get(e.id, Vector2(e.to))
				walk.append({"id": e.id, "to": Vector2(e.to), "at": cursor})
				if e.kind == "kamaitachi" and not sung.has(e.id):
					sung[e.id] = true
					later.append({"at": cursor, "nm": "kama"})
				cursor += gap
			elif e.t == "eat":
				later.append({"at": cursor, "nm": "eat"})
			elif e.t == "fall":
				cursor += 0.12
				later.append({"at": cursor, "nm": "splash"})
	else:
		for e in s.events:
			if e.t == "eat" or e.t == "fall":
				main.sfx("eat" if e.t == "eat" else "splash")
				break
	var seen_move = false
	var wait = 0.0
	for e in s.events:
		if e.t == "move":
			seen_move = true
			continue
		if ending and seen_move:
			wait = cursor
		if e.t == "kill":
			fx.append({"k": "kill", "pos": Vector2(e.pos), "life": 0.8, "max": 0.8, "wait": wait})
		elif e.t == "cut":
			fx.append({"k": "cut", "pos": Vector2(e.pos), "life": 0.4, "max": 0.4})
		elif e.t == "hit":
			fx.append({"k": "hit", "pos": Vector2(e.src), "life": 0.5, "max": 0.5})
			if main.data.opts.motion:
				shake = 0.35
				flash = 0.5
		elif e.t == "katsu":
			fx.append({"k": "katsu", "pos": Vector2(e.pos), "life": 0.6, "max": 0.6})
			if main.data.opts.motion:
				shake = 0.2
		elif e.t == "bell":
			fx.append({"k": "bell", "pos": Vector2(e.pos), "life": 1.4, "max": 1.4})
		elif e.t == "fall" or e.t == "eat":
			fx.append({"k": "kill", "pos": Vector2(e.pos), "life": 0.5, "max": 0.5, "quiet": true, "wait": wait})
	if s.status != "play":
		_finish()
	_sync()

func _clear_hint():
	hint_path = []
	hint_marks = []

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

# The next stroke of the known solution, if the board is still on its line: shown only as the
# lesson of the first stage (`guide`), never on asking. Returns a reason when it cannot
# be shown.
func _master_line():
	_clear_hint()
	if not hist.is_empty():
		return "The stroke is already begun."
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
		return "The master waits. Lift the brush without moving."
	return ""

# While guiding, say what to do next in plain words.
func _guide_update():
	guide_msg = ""
	if not guide or done:
		return
	if hist.is_empty():
		var why = _master_line()
		if why == "":
			guide_msg = "Paint the dotted stroke: click or drag from tile to tile, or use the arrow keys."
		elif why.begins_with("The master waits"):
			guide_msg = "Here the master waits. Lift the brush without moving: Space, or 収筆."
		else:
			guide_msg = "You have left the master's line. Carry on, or restart (R) to see it again."
		return
	if hint_path.size() > 1 and s.hero == hint_path.back():
		guide_msg = "Now lift the brush to end the stroke: Space, or 収筆. The yokai move after you."
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
	hist = []   # a finished stroke is committed: nothing before it can be taken back
	s.paths.append(s.visited.duplicate())
	if s.visited.size() > 1 and main.data.opts.motion:
		var tip = s.visited[s.visited.size() - 1]
		fx.append({"k": "flick", "pos": Vector2(tip), "dir": Vector2(tip - s.visited[s.visited.size() - 2]), "life": 0.5, "max": 0.5})
	Sim.end_stroke(s)
	ending = true
	_after(true, "sheathe")
	ending = false

# May the last thing done be taken back? Only within the stroke in hand (`hist` holds that stroke
# alone). With the Undo setting at "never", not at all; and a pilgrim does not take a step back.
func _can_undo():
	return not hist.is_empty() and s.status == "play" and kind_of != "henro" and int(main.data.opts.undo) != 2

func _undo():
	if not _can_undo():
		return
	s = hist.pop_back()
	undos += 1
	mode = ""
	last_inked = s.inked
	if not guide:
		_clear_hint()
	_sync()

func _finish():
	done = true
	done_t = time
	if s.status == "won" and rules.has("write") and main.data.opts.motion:
		# the finished character is shown whole before the result is laid over it
		fx.append({"k": "glyph", "pos": Vector2(3, 3), "life": 1.7, "max": 1.7})
		done_t = time + 1.5
	if s.status == "won":
		grade = "jouzu" if (s.hits == 0 and s.turn <= lv.par) else "ka"
		main.sfx("ki")
		main.sfx("win")
		var first = main.grade_of(idx) == ""
		my_paths = s.paths.duplicate()
		if not ending:
			my_paths.append(s.visited.duplicate())
		var master = 0
		for st in lv.get("sol", "").split("/"):
			master += st.split(" ", false).size()
		seal_mask = (1 if grade == "jouzu" else 0) | (2 if grade == "jouzu" and undos == 0 and starts == 1 else 0) | (4 if s.hits == 0 and s.spent <= master else 0)
		if custom != null:
			var nxt2 = on_win.call(grade, seal_mask, s.turn)   # returns where "Onward" leads
			extra.append(btn(Rect2(250, 470, 200, 50), "Onward" if kind_of != "random" else "Another", nxt2 if nxt2 is Callable else back, "進"))
			if lv.has("code"):
				extra.append(btn(Rect2(160, 526, 170, 44), "Try again", _restart))
				extra.append(btn(Rect2(346, 526, 196, 44), "Copy its link", func(): DisplayServer.clipboard_set(main.board_link(lv.code)), "写"))
			elif kind_of != "henro":
				extra.append(btn(Rect2(250, 526, 200, 44), "Try again", _restart))
			if kind_of == "daily":
				# the day's answer as a picture to pass on
				extra.append(btn(Rect2(250, 580, 200, 44), "Share", _share, "写"))
			return
		main.record(idx, grade, my_paths, seal_mask)
		var nxt = main.show_map
		if first:
			nxt = main.show_story.bind(lv.after, main.show_map)
			if idx == Data.BOSSES[0] and main.data.gago == "":
				nxt = main.show_story.bind(lv.after + [
					["Tessai", "落款. A finished piece is signed, and sealed in red. Until today you have pressed my seal on your work: 筆剣, brush and sword."],
					["Tessai", "A chapter of the scroll is yours now. Cut a seal of your own. One character or two; choose what you would be known by."],
				], main.show_seal.bind(main.show_map))
		extra.append(btn(Rect2(250, 470, 200, 50), "Onward", nxt, "進"))
		extra.append(btn(Rect2(250, 526, 200, 44), "Try again", _restart))
	else:
		grade = "lost"
		main.sfx("lose")
		if kind_of == "daily":
			main.daily_fail(lv.get("day", main.today()))
		if kind_of == "henro":
			extra.append(btn(Rect2(250, 440, 200, 54), "Rise", on_fail, "起"))
			return
		extra.append(btn(Rect2(250, 452, 200, 60), "Begin again", _restart, "再"))

func _share():
	share_note = "…"
	share_note = await main.share_daily(lv.get("day", main.today()), my_paths, s.w, s.h)

# Is mastery still within reach (or, once the stage is done, was it kept)?
func _on_par():
	return s.hits == 0 and s.turn + (0 if done else 1) <= lv.par

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

# The card over the stage takes the press that puts it away, so that no button or tile under it
# is pressed by the same touch. On a phone it covers the page, so any touch is the card's; with a
# mouse, only a click on the card itself.
func swallow(pos, _button):
	if card.is_empty() or done:
		return false
	var mine = main.touch or _card_rect(main.font).has_point(pos)
	card = []
	return mine

func on_click(pos, button):
	card = []
	if button == MOUSE_BUTTON_RIGHT:
		_undo()
		return
	if button == MOUSE_BUTTON_LEFT:
		painting = true
		last_drag = tile_at(pos)
		_try_tile(last_drag)

func on_motion(pos, held):
	if not held or not painting or mode != "":
		return
	var t = tile_at(pos)
	if t != last_drag:
		last_drag = t
		_try_tile(t)

func on_key(code):
	if not card.is_empty() and not done:
		card = []
		return   # the key that puts the card away does nothing else
	match code:
		KEY_RIGHT, KEY_D: _dir(Vector2i(1, 0))
		KEY_LEFT, KEY_A: _dir(Vector2i(-1, 0))
		KEY_DOWN, KEY_S: _dir(Vector2i(0, 1))
		KEY_UP, KEY_W: _dir(Vector2i(0, -1))
		KEY_SPACE, KEY_ENTER: _end()
		KEY_Z, KEY_BACKSPACE: _undo()
		KEY_R: _retry()
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
	walk_t += dt
	if not card.is_empty():
		card_t += dt
		if card_t >= card_len:
			card = []
	for b in extra:
		b.show = time >= done_t + (0.45 if main.data.opts.motion else 0.0)
	while not walk.is_empty() and walk[0].at <= walk_t:
		aim[walk[0].id] = walk[0].to
		walk.pop_front()
	if walk.is_empty():
		aim = {}
	if not later.is_empty():
		for snd in later:
			if snd.at <= walk_t:
				main.sfx(snd.nm)
		later = later.filter(func(snd): return snd.at > walk_t)
	var kk = 1.0 - exp(-dt * (26.0 if not aim.is_empty() else 18.0))
	for y in s.yokai:
		if not disp.has(y.id):
			disp[y.id] = Vector2(y.pos)
		disp[y.id] = disp[y.id].lerp(aim.get(y.id, Vector2(y.pos)), kk)
	shake = max(0.0, shake - dt)
	flash = max(0.0, flash - dt)
	if not fx.is_empty():
		for e in fx:
			if e.get("wait", 0.0) > 0.0:
				e.wait -= dt
			else:
				e.life -= dt
		fx = fx.filter(func(e): return e.life > 0.0)

func busy():
	return not fx.is_empty() or not walk.is_empty() or not later.is_empty() or shake > 0.0 or flash > 0.0 \
		or (not card.is_empty() and card_len < 100.0) or time - born_t < 2.5 or (done and time - done_t < 8.0) \
		or hdisp.distance_squared_to(Vector2(s.hero)) > 0.0004

func ctr(p):
	return ORG + (Vector2(p) + Vector2(0.5, 0.5)) * TS

func _draw():
	var f = main.font
	var off = Vector2.ZERO
	if shake > 0.0:
		off = Vector2(sin(time * 90.0), cos(time * 70.0)) * shake * 14.0
	draw_set_transform(off, 0.0, Vector2.ONE)

	# header
	var spare = main.spare()
	if not spare:
		Ink.kinun(self, Vector2(400, 20), 250.0)
		Ink.kinun(self, Vector2(1090, 204), 240.0, 0.20)
		Ink.seal(self, f, Vector2(84, 52), 24, "上手")
	if spare:
		var fade_in = clamp((time - 0.3) / 0.5, 0.0, 1.0) if main.data.opts.motion else 1.0
		Ink.tategaki(self, f, Vector2(28, 98), lv.kanji, 30, Ink.a(Ink.SUMI, fade_in))
		if custom == null:
			var num = ""
			for dg in str(idx + 1):
				num += "〇一二三四五六七八九"[int(dg)]
			Ink.tategaki(self, f, Vector2(28, 108 + lv.kanji.length() * 32.4), num, 15, Ink.a(Ink.SUMI, 0.55 * fade_in))
		else:
			Ink.text(self, f, Vector2(56, 34), label, 15, Ink.a(Ink.SUMI, 0.6))
		Ink.text(self, f, Vector2(56, 62), lv.name, 28, Ink.SUMI)
	else:
		if main.data.opts.motion:
			Ink.written(self, f, Vector2(124, 62), lv.kanji, 44, Ink.SUMI, time - 0.35)
		else:
			Ink.text(self, f, Vector2(124, 62), lv.kanji, 44, Ink.SUMI)
		Ink.text(self, f, Vector2(140 + 44 * lv.kanji.length(), 48), ("Station %d" % (idx + 1)) if custom == null else label, 16, Ink.a(Ink.SUMI, 0.6))
		Ink.text(self, f, Vector2(140 + 44 * lv.kanji.length(), 72), lv.name, 22, Ink.SUMI)
	if rule_line != "":
		Ink.text(self, f, Vector2(56 if spare else 124, 90 if spare else 96), rule_line, 14, Ink.SHU)

	# board
	var br = Rect2(ORG, Vector2(s.w, s.h) * TS)
	draw_rect(br, Ink.a(Ink.GOFUN, 0.40))
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
				Ink.blot(self, r.get_center(), TS * 0.66, TS * 0.66, Ink.SHU, 0.52 + (0.08 * sin(time * 4.0) if main.data.opts.motion else 0.0))
				if main.data.opts.pattern:
					# a mark that does not depend on telling red from the paper
					var cc = r.get_center()
					draw_line(cc + Vector2(-TS * 0.2, -TS * 0.2), cc + Vector2(TS * 0.2, TS * 0.2), Ink.a(Ink.SUMI, 0.75), 4.0, true)
					draw_line(cc + Vector2(TS * 0.2, -TS * 0.2), cc + Vector2(-TS * 0.2, TS * 0.2), Ink.a(Ink.SUMI, 0.75), 4.0, true)
			if not lit.is_empty() and not lit.has(p):
				draw_rect(r, Color(0.06, 0.06, 0.12, 0.62))
	if spare:
		# each square carries the faint cross that centres a character on practice paper
		for y in range(s.h):
			for x in range(s.w):
				if Sim.ter(s, Vector2i(x, y)) == ".":
					var cc = ctr(Vector2i(x, y))
					draw_dashed_line(cc - Vector2(TS * 0.5, 0), cc + Vector2(TS * 0.5, 0), Ink.a(Ink.SUMI, 0.10), 1.0, 5.0)
					draw_dashed_line(cc - Vector2(0, TS * 0.5), cc + Vector2(0, TS * 0.5), Ink.a(Ink.SUMI, 0.10), 1.0, 5.0)
		for i in range(1, s.w):
			draw_line(ORG + Vector2(i * TS, 0), ORG + Vector2(i * TS, s.h * TS), Ink.a(Ink.SUMI, 0.20), 1.0)
		for i in range(1, s.h):
			draw_line(ORG + Vector2(0, i * TS), ORG + Vector2(s.w * TS, i * TS), Ink.a(Ink.SUMI, 0.20), 1.0)
		draw_rect(br, Ink.a(Ink.SUMI, 0.6), false, 1.6)
		# the paperweight that holds the sheet
		var pw = Rect2(br.position.x + br.size.x * 0.5 - 150, br.position.y - 4, 300, 13)
		draw_rect(pw, Color(0.13, 0.12, 0.13))
		draw_line(pw.position + Vector2(4, 3), Vector2(pw.end.x - 4, pw.position.y + 3), Ink.a(Ink.GOFUN, 0.28), 1.5, true)
	else:
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
	if spare and not done:
		for k in range(s.paths.size()):
			var age = s.paths.size() - 1 - k
			var old = []
			for v in s.paths[k]:
				old.append(ctr(v))
			if old.size() > 1:
				# drying, but still the stroke it was: where the brush came down, how dry it ran, where it lifted
				Ink.fude(self, old, 19.0, clamp(float(old.size() - 1) / max(1.0, float(s.ink_max)), 0.0, 1.0), max(0.07, 0.34 * pow(0.6, age)),
					Ink.AI if (rules.has("wet") and age == 0) else Color(0.11, 0.09, 0.09))
	elif not s.paths.is_empty() and not done:
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
	if not bound.is_empty() and not done:
		var lp = [ctr(s.visited.back()), ctr(s.visited[0])]
		draw_line(lp[0], lp[1], Ink.a(Ink.KIN, 0.9), 6.0, true)
		for i in bound:
			Ink.enso(self, ctr(s.yokai[i].pos), TS * 0.46, 7.0, Ink.KIN)

	# the stroke so far
	var trail = []
	for v in s.visited:
		trail.append(ctr(v))
	if trail.size() > 1 and spare:
		# the stroke in hand, paler and drier the more of the brush's ink it has used
		Ink.fude(self, trail, 21.0, clamp(1.0 - float(s.ink) / max(1.0, float(max(s.ink_max, s.ink + trail.size() - 1))), 0.0, 1.0))
	elif trail.size() > 1:
		Ink.brush(self, trail, 20.0, Color(0.2, 0.18, 0.17))
		if not done:
			draw_circle(trail[trail.size() - 1], 7.5 + (1.2 * sin(time * 5.0) if main.data.opts.motion else 0.0), Color(0.12, 0.10, 0.10))
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
		var born = 1.0 if not main.data.opts.motion else clamp((time - born_t - 0.55 - (y.id % 9) * 0.07) / 0.4, 0.0, 1.0)
		if born < 1.0:
			Ink.blot(self, e[2], TS * (0.75 - 0.25 * born), TS * (0.75 - 0.25 * born), Ink.SUMI, 0.75 * (1.0 - born) * min(1.0, (time - born_t) * 3.0))
			mod.a *= born
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
		if e.get("wait", 0.0) > 0.0:
			continue
		var u = 1.0 - e.life / e.max
		var c = ctr(e.pos)
		if e.k == "flick":
			# drops thrown on along the line of the stroke
			for i in range(6):
				var side = e.dir.orthogonal() * ((i % 3) - 1) * 0.22
				var far = (0.30 + 0.16 * i) * (0.4 + 0.6 * u)
				draw_circle(c + (e.dir * far + side * (0.5 + u)) * TS, (5.0 - i * 0.6) * (1.0 - u * 0.6), Ink.a(Ink.SUMI, 0.8 * (1.0 - u)))
		elif e.k == "glyph":
			# the character just written, whole, over the board
			var gs = TS * 5.6
			var ga = clamp(u * 5.0, 0.0, 1.0) * clamp((1.0 - u) * 2.5, 0.0, 1.0)
			Ink.text(self, f, ORG + Vector2(3.5 * TS - gs * 0.5, 3.5 * TS + gs * 0.36), lv.kanji.substr(0, 1), gs, Ink.a(Ink.SHU, 0.55 * ga), HORIZONTAL_ALIGNMENT_CENTER, gs)
		elif e.k == "bell":
			for ring in range(3):
				var uu = clamp(u * 1.6 - ring * 0.22, 0.0, 1.0)
				draw_arc(c, TS * (0.4 + 3.2 * uu), 0, TAU, 48, Ink.a(Ink.KIN, (1.0 - uu) * 0.9), 6.0, true)
			Ink.text(self, f, c + Vector2(-28, -40 - 20 * u), "鐘", 56, Ink.a(Ink.KIN, 1.0 - u))
		elif e.k == "kill" and e.has("quiet"):
			draw_arc(c, TS * (0.2 + 0.4 * u), 0, TAU, 32, Ink.a(Ink.AI, 1.0 - u), 4.0, true)
		elif e.k == "kill":
			# what was cut comes apart into ink, and the ink drifts up and thins
			for i in range(6):
				var drift = c + Vector2((i - 2.5) * TS * 0.13 + sin(i * 2.1 + u * 3.0) * 7.0, -TS * u * (0.35 + 0.12 * (i % 3)))
				var rad = TS * (0.20 + 0.16 * u + 0.03 * (i % 2))
				Ink.blot(self, drift, rad, rad, Ink.SUMI, 0.55 * (1.0 - u))
			draw_arc(c, TS * (0.2 + 0.5 * u), 0, TAU, 32, Ink.a(Ink.SUMI, 0.6 * (1.0 - u)), 3.0 * (1.0 - u) + 1.0, true)
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
		if main.touch and main.tall:
			# upright the line would run off the board's part: it goes in the open middle of the panel
			Ink.para(self, f, Vector2(692, 318), "手本  " + main.touch_words(guide_msg), 22, Ink.SHU, 570)
		elif main.touch:
			draw_rect(Rect2(40, 690, 1200, 30), Ink.a(Ink.PAPER, 0.92))
			Ink.text(self, f, Vector2(52, 714), "手本  " + main.touch_words(guide_msg), 24, Ink.SHU)
		else:
			Ink.text(self, f, Vector2(ORG.x, 713), "手本  " + guide_msg, 15, Ink.SHU)
	elif not main.touch and not done and card.is_empty():
		var over = tile_at(mouse)
		var oi = Sim.yokai_at(s, over) if Sim.inb(s, over) else -1
		if oi >= 0 and not Sim.hidden(s.yokai[oi]) and (lit.is_empty() or lit.has(over)):
			var L = Data.LEGEND[s.yokai[oi].kind]
			Ink.text(self, f, Vector2(ORG.x, 713), "%s %s  ·  %s" % [L[0], L[1], L[3]], 15, Ink.a(Ink.AI, 0.95))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if flash > 0.0:
		draw_rect(Rect2(0, 0, 1280, 720), Ink.a(Ink.SHU, flash * 0.35))
	if done and time >= done_t:
		_result(f)
		if share_note != "":
			Ink.text(self, f, Vector2(110, 650), share_note, 16, Ink.SHU, HORIZONTAL_ALIGNMENT_CENTER, 480)
	draw_btns()
	if not card.is_empty() and not done:
		_draw_card(f)

# Night: what Suzu can see. Empty when it is not night.
# The rules in force, in a line over the board.
func _rule_line():
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
		rl.append("風 the wind carries lanterns, umbrellas and ghosts " + WIND_ARROW[s.wind])
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
		for k in range(rl.size()):
			rl[k] = RULE_BRIEF.get(rl[k].substr(0, 1), rl[k])
	return "  ·  ".join(rl)

func _lit():
	var out = {}
	if not s.r_night:
		return out
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
					out[e[0] + Vector2i(dx, dy)] = true
	return out

# rain, snow and wind are painted over the board; they change nothing by themselves
func _weather(br):
	var w = br.size.x
	var h = br.size.y
	if rules.has("rain"):
		for k in range(54):
			var slant = Vector2(-0.26 if k % 5 != 0 else -0.40, 1.0)
			var p = br.position + Vector2(fmod(k * 97.0 + time * 90.0, w + 60.0), fmod(k * 53.0 + time * 520.0, h + 80.0) - 80.0)
			var q = p + slant * (70.0 + 30.0 * (k % 3))
			if br.has_point(p) and br.has_point(q):
				draw_line(p, q, Ink.a(Ink.SUMI, 0.30 if k % 5 != 0 else 0.18), 1.2, true)
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
	if kanji == "墨" and main.spare():
		var wd = clamp(mx * 34.0, 110.0, 250.0)
		Ink.suzuri(self, Rect2(PX + 138, y - 21, wd, 24), n, mx)
		Ink.text(self, f, Vector2(PX + 150 + wd, y - 1), str(n), 22, Ink.SUMI)
		return
	for i in range(mx):
		# long brushes wrap onto a tighter row so they never run into the text beside them
		var step = 30.0 if mx <= 8 else 240.0 / mx
		var c = Vector2(PX + 150 + i * step, y - 9)
		var rad = min(10.0, step * 0.36)
		if kanji == "気":
			if i > 0:
				draw_line(c - Vector2(step, 0), c, Ink.a(Ink.SUMI, 0.5), 1.5, true)   # the string of the rosary
			Ink.bead(self, c, rad, i < n)
		elif kanji == "墨":
			Ink.drop(self, c + Vector2(0, 2), rad * 0.92, i < n)
		else:
			if i < n:
				draw_circle(c, rad, col)
			draw_arc(c, rad, 0, TAU, 20, Ink.SUMI, 1.8, true)

# The side panel on a phone: the count of strokes, ki, ink and momentum, large enough to read at
# arm's length. Everything explanatory is in the card.
func _panel_phone(f):
	Ink.text(self, f, Vector2(PX, 62), "Stroke %d" % (s.turn + (0 if done else 1)), 40, Ink.SUMI)
	var ok = _on_par()
	Ink.text(self, f, Vector2(PX + 250, 60), "上手 within %d" % lv.par, 30, Ink.SHU if ok else Ink.a(Ink.SUMI, 0.5))
	var rows = [["気", max(0, s.ki), ki_max, Ink.SHU], ["墨", s.ink, Sim.INK_CAP if s.r_stone else max(s.ink_max, s.ink), Ink.SUMI], ["勢", min(2, s.mom), 2, Ink.AI]]
	for k in range(rows.size()):
		var y = 130.0 + k * 66.0
		if k == 2 and s.mom == 0 and main.spare():
			continue   # no momentum, nothing to say about it
		Ink.text(self, f, Vector2(PX, y + 16), rows[k][0], 46, Ink.SUMI)
		var mx = rows[k][2]
		if k == 1 and main.spare():
			Ink.suzuri(self, Rect2(PX + 78, y - 20, 360, 40), rows[k][1], mx)
			Ink.text(self, f, Vector2(PX + 452, y + 14), str(rows[k][1]), 40, Ink.SUMI)
			continue
		var step = min(54.0, 440.0 / max(1, mx))
		for i in range(mx):
			var c = Vector2(PX + 96 + i * step, y)
			var rad = min(19.0, step * 0.38)
			if k == 0:
				if i > 0:
					draw_line(c - Vector2(step, 0), c, Ink.a(Ink.SUMI, 0.5), 2.0, true)
				Ink.bead(self, c, rad, i < rows[k][1])
			elif k == 1:
				Ink.drop(self, c + Vector2(0, 3), rad * 0.9, i < rows[k][1])
			else:
				if i < rows[k][1]:
					draw_circle(c, rad, rows[k][3])
				draw_arc(c, rad, 0, TAU, 24, Ink.SUMI, 2.6, true)
	if s.mom > 0 or not main.spare():
		Ink.text(self, f, Vector2(PX + 220, 272), "next cut deals %d" % min(3, 1 + s.mom), 26, Ink.a(Ink.SUMI, 0.75))
	var wz = _waza_left()
	var note = ""
	if mode == "leap":
		note = "縮地: choose a direction to leap two tiles."
	elif mode == "ward":
		note = "結界: choose a tile beside you for the ward."
	elif mode == "shiki":
		note = "式神: choose a tile beside you for the shikigami."
	if note != "":
		Ink.para(self, f, Vector2(PX, 318), main.touch_words(note), 22, Ink.SHU, 540)
	elif wz != "":
		Ink.text(self, f, Vector2(PX, 332), wz, 26 if lv.waza.size() < 3 else 21, Ink.SUMI)

# What is left of each technique the stage grants, named as its button names it: "Leap 1 left".
func _waza_left():
	var parts = []
	for w in [["leap", "縮地 Leap", s.leap], ["ward", "結界 Ward", s.ward], ["katsu", "喝 Shout", s.katsu], ["bell", "鐘 Bell", s.bell]]:
		if lv.waza.has(w[0]):
			parts.append("%s %d left" % [w[1], w[2]])
	return "   ".join(parts)

func _panel(f):
	Ink.brush(self, [Vector2(PX - 22, 30), Vector2(PX - 23, 250), Vector2(PX - 21, 470), Vector2(PX - 22, 690)], 4.0, Ink.a(Ink.SUMI, 0.45))
	if main.touch:
		_panel_phone(f)
		return
	Ink.text(self, f, Vector2(PX, 52), "Stroke %d" % (s.turn + (0 if done else 1)), 26, Ink.SUMI)
	Ink.text(self, f, Vector2(PX + 150, 52), "上手 mastery: within %d, unharmed" % lv.par, 17, Ink.SHU if _on_par() else Ink.a(Ink.SUMI, 0.5))
	_pips(f, 96, "気", "Ki", max(0, s.ki), ki_max, Ink.SHU)
	_pips(f, 134, "墨", "Ink", s.ink, Sim.INK_CAP if s.r_stone else max(s.ink_max, s.ink), Ink.SUMI)
	if s.mom > 0 or not main.spare():
		_pips(f, 172, "勢", "Momentum", min(2, s.mom), 2, Ink.AI)
		Ink.text(self, f, Vector2(PX + 230, 170), "a straight cut now deals %d" % min(3, 1 + s.mom), 16, Ink.a(Ink.SUMI, 0.7))
	var wz = _waza_left()
	if wz != "":
		Ink.text(self, f, Vector2(PX, 206), wz, 18, Ink.SUMI)
	var y = 226.0
	for k in (new_kinds if main.spare() else kinds):
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
	var hy = max(y + 24.0, 388.0)
	var say = lv.get("say", [])
	if hint == "" and say.size() == 3:
		# a stage with no lesson of its own carries an old saying instead
		hy = max(y + 30.0, 372.0)
		var floor_y = 458.0 if (lv.waza.size() > 0) else 512.0
		var per = max(3, int((floor_y - hy + 20.0) / 25.0))
		var cols = int(ceil(say[0].length() / float(per)))
		for i in range(say[0].length()):
			var cx = PX + 528.0 - (i / per) * 28.0
			draw_string(f, Vector2(cx - 12.0, hy + (i % per) * 25.0), say[0][i], HORIZONTAL_ALIGNMENT_CENTER, 24.0, 22, Ink.SUMI)
		draw_line(Vector2(PX + 548.0, hy - 20.0), Vector2(PX + 548.0, hy - 20.0 + min(per, say[0].length()) * 25.0), Ink.a(Ink.SHU, 0.8), 2.0, true)
		var tw = 540.0 - cols * 28.0 - 26.0
		Ink.para(self, f, Vector2(PX, hy), say[2], 15, Ink.a(Ink.AI, 0.95), tw)
		var eh = f.get_multiline_string_size(say[2], HORIZONTAL_ALIGNMENT_LEFT, tw, 15).y
		Ink.para(self, f, Vector2(PX, hy + eh + 8.0), say[1], 13, Ink.a(Ink.SUMI, 0.55), tw)
	else:
		Ink.para(self, f, Vector2(PX, hy), main.touch_words(hint), 15, Ink.a(Ink.AI, 0.95), 545)
	if not s.r_shiki and not main.spare():
		Ink.text(self, f, Vector2(PX + 282, 604), "click, drag or arrows to paint", 13, Ink.a(Ink.SUMI, 0.55))
		Ink.text(self, f, Vector2(PX + 282, 622), "right-click undoes", 13, Ink.a(Ink.SUMI, 0.55))

func _result(f):
	var box = Rect2(150, 200, 400, 380)
	var open = _since(0.0, 0.45)
	Ink.kakejiku(self, box, open)
	if open < 1.0:
		return
	if grade == "jouzu":
		if not main.spare():
			Ink.stamp(self, f, Vector2(232, 296), 50, "上手", _since(0.55, 0.3))
		_my_scroll()
		_seals(f)
		Ink.text(self, f, Vector2(150, 408), "Mastered in %d stroke%s, unharmed." % [s.turn, "" if s.turn == 1 else "s"], 19, Ink.SUMI, HORIZONTAL_ALIGNMENT_CENTER, 400)
	elif grade == "ka":
		if not main.spare():
			Ink.stamp(self, f, Vector2(232, 290), 58, "可", _since(0.55, 0.3), Ink.AI)
		_my_scroll()
		_seals(f)
		var why = "%d strokes; mastery asks %d." % [s.turn, lv.par]
		if s.hits > 0:
			why = "%d strokes, %d blow%s taken." % [s.turn, s.hits, "" if s.hits == 1 else "s"]
		Ink.text(self, f, Vector2(150, 402), "Passed. " + why, 17, Ink.SUMI, HORIZONTAL_ALIGNMENT_CENTER, 400)
		Ink.text(self, f, Vector2(150, 422), "上手 needs %d strokes and no blows." % lv.par, 14, Ink.a(Ink.SUMI, 0.7), HORIZONTAL_ALIGNMENT_CENTER, 400)
		if custom == null and main.held_chapter() == main.chapter_of(idx):
			Ink.text(self, f, Vector2(150, 446), "関 The chapter's last station asks for more mastery.", 15, Ink.SHU, HORIZONTAL_ALIGNMENT_CENTER, 400)
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
		if seal_mask & sl[0] and main.spare():
			Ink.text(self, f, Vector2(c.x - 40, c.y + 6), sl[1], 16, Ink.SHU, HORIZONTAL_ALIGNMENT_CENTER, 80)
		elif seal_mask & sl[0]:
			Ink.seal(self, f, c, 11, sl[1])
		else:
			Ink.text(self, f, Vector2(c.x - 40, c.y + 6), sl[1], 15, Ink.a(Ink.SUMI, 0.28), HORIZONTAL_ALIGNMENT_CENTER, 80)

# what you painted to clear this stage, as it will hang in the scroll
func _my_scroll():
	var f = main.font
	var wrote = 0.28 * max(1, my_paths.size())
	if main.spare():
		# your strokes alone on the paper, and round them the circle a teacher gives: two for
		# mastery, one for a pass
		var rr = Rect2(262, 228, 176, 144)
		Ink.calligraphy(self, rr, my_paths, s.w, s.h, _since(0.6, wrote))
		var c = rr.get_center()
		Ink.maru(self, c, 92.0, 7.0, Ink.a(Ink.SHU, 0.9), _since(0.7 + wrote, 0.45))
		if grade == "jouzu":
			Ink.maru(self, c, 78.0, 5.0, Ink.a(Ink.SHU, 0.9), _since(1.0 + wrote, 0.4))
		# and the painter's own seal, pressed last, low at the left as a piece is signed
		Ink.stamp(self, f, Vector2(196, 344), 15, main.my_seal(), _since(1.3 + wrote, 0.3))
		return
	var r = Rect2(318, 222, 196, 160)
	draw_rect(r, Ink.a(Ink.GOFUN, 0.9))
	Ink.frame(self, r, 2.5, Ink.a(Ink.SUMI, 0.7))
	Ink.calligraphy(self, r.grow(-10), my_paths, s.w, s.h, _since(0.85, wrote))
	Ink.stamp(self, f, Vector2(r.position.x + 20, r.end.y - 28), 12, main.my_seal(), _since(1.1 + wrote, 0.3))

# how far along something is that began `after` seconds past the end of the stage and takes `length`
func _since(after, length):
	if not main.data.opts.motion:
		return 1.0
	return clamp((time - done_t - after) / length, 0.0, 1.0)
