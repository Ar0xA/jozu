extends "res://scripts/screen_base.gd"
# The road, one chapter at a time. Above it unrolls Sesshu's Long Scroll, travelling with you.
# On a phone the same page is laid out larger: the chapters are chosen from a page of their own
# instead of a row of small tabs, and the history note sits under the scroll in type that can be read.

const BAND = Rect2(40, 124, 1200, 330)

var band = BAND
var road_y = 586.0
var hover_st = -1
var pan = -1.0
var page = 0
var tally = {}
var gate = []         # this page's gate: [first, last, mastered, asked for]
var notice = ""       # the gate, explained: laid over the page until it is sent away
var tabs = []
var nav = []          # the buttons of the road page itself (hidden while chapters are being chosen)
var picking = false   # phone: the page of chapters is open
var b_close

var moving = false   # the scroll above the road is still travelling

func setup():
	rest = 1.0 / 15.0
	# nothing is cleared while the map is open, so the road's totals are counted once
	var done = 0
	for i in range(Data.LEVELS.size()):
		if main.grade_of(i) != "":
			done += 1
	tally = {"done": done, "rank": main.rank(), "seals": main.seal_count(), "points": main.points()}
	if main.held_chapter() >= 0 and main.gate_told != main.held_chapter():
		main.gate_told = main.held_chapter()   # said once when the road first stops; after that, on asking
		notice = main.gate_words()
	var phone = main.touch
	if phone:
		band = Rect2(40, 150, 1200, 236)
		road_y = 556.0
		nav.append(btn(Rect2(40, 632, 216, 72), "Training", main.show_dojo, "修練"))
		nav.append(btn(Rect2(264, 632, 176, 72), "Scroll", main.show_scroll, "巻"))
		nav.append(btn(Rect2(448, 632, 160, 72), "More", main.show_hub, "別"))
		nav.append(btn(Rect2(616, 632, 160, 72), "Title", main.show_title, "題"))
		nav.append(btn(Rect2(790, 632, 130, 72), "Back", func(): _step(-1), "前"))
		nav.append(btn(Rect2(926, 632, 196, 72), "Chapters", _pick, "章"))
		nav.append(btn(Rect2(1128, 632, 112, 72), "On", func(): _step(1), "次"))
	else:
		btn(Rect2(40, 648, 172, 50), "Training", main.show_dojo, "修練")
		btn(Rect2(216, 648, 118, 50), "Scroll", main.show_scroll, "巻")
		btn(Rect2(338, 648, 108, 50), "More", main.show_hub, "別")
		btn(Rect2(450, 648, 112, 50), "Title", main.show_title, "題")
	page = _chapter_of(_next_open())
	var n = Data.CHAPTERS.size()
	var per = int(ceil(n / 2.0)) if n > 17 else n
	var tw = 1200.0 / per
	for c in range(n):
		var r = Rect2(40 + (c % per) * tw + 4, 464 + (c / per) * 34 if n > 17 else 470, tw - 8, 30 if n > 17 else 40)
		if phone:
			r = Rect2(44 + (c % 5) * 240, 78 + (c / 5) * 78, 232, 50)
		tabs.append(btn(r, Data.CHAPTERS[c].kanji, _page.bind(c)))
	if phone:
		b_close = btn(Rect2(44 + 4 * 240, 78 + 7 * 78, 232, 60), "Back", _pick, "道")
	for b in btns:
		b["home"] = b.rect
	_place()
	_sync()

# Upright, the page is cut into parts and stacked (scripts/tall.gd), so its halves are laid out as
# two columns that never meet: the scroll, the road and four buttons on the left; the place's
# history, the next station and the other three buttons on the right.
func tall_changed():
	_place()

func _place():
	for b in btns:
		b.rect = b.home
	band = Rect2(40, 150, 1200, 236) if main.touch else BAND
	if not main.tall or not main.touch:
		return
	band = Rect2(40, 150, 640, 236)
	var at = [Rect2(40, 632, 222, 72), Rect2(266, 632, 148, 72), Rect2(418, 632, 136, 72), Rect2(558, 632, 136, 72),
		Rect2(706, 632, 150, 72), Rect2(866, 632, 210, 72), Rect2(1086, 632, 130, 72)]
	for k in range(nav.size()):
		nav[k].rect = at[k]
	for c in range(tabs.size()):
		# two blocks of chapters, three across: 21 on the left, the rest on the right
		var k = c if c < 21 else c - 21
		tabs[c].rect = Rect2((16 if c < 21 else 652) + (k % 3) * 206, 78 + (k / 3) * 78, 198, 50)
	var left = max(0, tabs.size() - 21)
	b_close.rect = Rect2(652 + 206, 78 + (left / 3 + (0 if left % 3 == 1 else 1)) * 78, 404, 60) if left % 3 != 0 else Rect2(652, 78 + (left / 3) * 78, 404, 60)

func _note_h():
	var note = Data.CHAPTERS[page].get("note", "")
	return 0.0 if note == "" else main.font.get_multiline_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, 540, 21).y

func tall_modal():
	return notice != ""

func tall_parts(_h):
	if not main.touch:
		return super.tall_parts(_h)
	if notice != "":
		return [{"src": [_notice_rect(main.font)], "s": 1.05}]
	if picking:
		var rows2 = int(ceil(max(0, tabs.size() - 21) / 3.0)) + 1
		return [{"src": [Rect2(30, 0, 400, 62)], "s": 1.2}, {"src": [Rect2(10, 66, 630, 7 * 78 + 4)], "s": 1.12}, {"src": [Rect2(646, 66, 630, rows2 * 78 + 4)], "s": 1.12}]
	var parts = [{"src": [Rect2(30, 4, 660, 122)], "s": 1.06}, {"src": [Rect2(34, 136, 652, 264)], "s": 1.08}]
	if _note_h() > 0.0:
		parts.append({"src": [Rect2(696, 140, 560, _note_h() + 24.0)], "s": 1.25})
	parts.append({"src": [Rect2(700, 8, 560, 120)], "s": 1.2})
	var rg = _range(page)
	var rows = int(ceil((rg[1] - rg[0]) / float(_per())))
	parts.append({"src": [Rect2(40, 404, 640, rows * 74.0 + 14.0)], "s": 1.1})
	parts.append({"src": [Rect2(700, 628, 524, 80)], "s": 1.3})
	parts.append({"src": [Rect2(34, 628, 664, 80)], "s": 1.07})
	return parts

# upright, how many stations to a row of the road
func _per():
	var rg = _range(page)
	return 5 if rg[1] - rg[0] <= 10 else 6

func _next_open():
	for i in range(Data.LEVELS.size()):
		if main.grade_of(i) == "":
			return i
	return Data.LEVELS.size() - 1

func _chapter_of(i):
	return main.chapter_of(i)

func _range(c):
	var a = Data.CHAPTERS[c].from
	var b = Data.LEVELS.size()
	if c + 1 < Data.CHAPTERS.size():
		b = Data.CHAPTERS[c + 1].from
	return [a, b]

func _page(c):
	page = c
	picking = false
	_sync()

func _pick():
	picking = not picking
	_sync()

func _step(d):
	var c = page + d
	if c >= 0 and c < Data.CHAPTERS.size() and main.unlocked(Data.CHAPTERS[c].from):
		_page(c)

func _sync():
	for c in range(tabs.size()):
		tabs[c].sel = c == page
		tabs[c].on = main.unlocked(Data.CHAPTERS[c].from)
		if main.touch:
			tabs[c].show = picking
	if main.touch:
		b_close.show = picking
		for b in nav:
			b.show = not picking
		nav[4].on = page > 0
		nav[6].on = page + 1 < Data.CHAPTERS.size() and main.unlocked(Data.CHAPTERS[page + 1].from)

# The road runs through the year: each chapter has its season, and the snow chapters their snow.
func _season():
	var nm = Data.CHAPTERS[page].name
	if nm == "Snow Country" or nm == "Deep Snow" or nm == "Mount Osore":
		return "yuki"
	return ["sakura", "hotaru", "momiji", "yuki"][page % 4]

func st_pos(i):
	var rg = _range(page)
	var n = rg[1] - rg[0]
	var k = i - rg[0]
	if main.tall and main.touch:
		# the road doubles back on itself, row under row
		var a = floor(k)
		return _row_pos(int(a)).lerp(_row_pos(min(int(a) + 1, n - 1)), k - a)
	var step = min(118.0, 1080.0 / max(1, n - 1))
	return Vector2(640 - step * (n - 1) * 0.5 + k * step, road_y + 14 * sin(k * 0.9 + 0.4))

func _row_pos(k):
	var per = _per()
	var row = k / per
	var col = k % per
	if row % 2 == 1:
		col = per - 1 - col
	return Vector2(96 + col * (528.0 / (per - 1)), 446 + row * 74 + 5 * sin(k * 0.9 + 0.4))

func _focus():
	if hover_st >= 0:
		return hover_st
	var rg = _range(page)
	for i in range(rg[0], rg[1]):
		if main.grade_of(i) == "":
			return i
	return rg[1] - 1

func tick(dt):
	var span = main.band_len("sesshu") - band.size.x * 400.0 / band.size.y
	var want = span * _focus() / float(Data.LEVELS.size() - 1)
	if pan < 0.0:
		pan = want
	pan = lerp(pan, want, 1.0 - exp(-dt * 2.2))
	moving = abs(pan - want) > 0.5

func busy():
	return moving

func on_motion(pos, _held):
	hover_st = -1
	if picking:
		return
	var rg = _range(page)
	for i in range(rg[0], rg[1]):
		if pos.distance_to(st_pos(i)) < (30 if rg[1] - rg[0] <= 11 else 24) + (8 if main.touch else 0):
			hover_st = i

func on_click(pos, button):
	if button != MOUSE_BUTTON_LEFT or picking:
		return
	on_motion(pos, false)
	if hover_st >= 0 and main.unlocked(hover_st):
		main.start_stage(hover_st)
	elif hover_st >= 0 and _gated(hover_st):
		notice = main.gate_words()

# is this the station the gate is keeping shut?
func _gated(i):
	return main.held_chapter() >= 0 and i == main.frontier() + 1

func swallow(_pos, _button):
	if notice == "":
		return false
	notice = ""
	return true

func on_key(code):
	if notice != "":
		notice = ""
		return
	if code == KEY_ESCAPE:
		main.show_title()
	elif code == KEY_RIGHT:
		_step(1)
	elif code == KEY_LEFT:
		_step(-1)

# phone: every chapter on one page, with its English name under it
func _draw_chapters(f):
	backdrop(0.35)
	Ink.tategaki(self, f, Vector2(64, 4), "章", 40, Ink.SUMI)
	Ink.text(self, f, Vector2(110, 48), "Chapters", 34, Ink.SUMI)
	if not main.tall:
		Ink.text(self, f, Vector2(300, 46), "Tap one to go to it. The pale ones are still ahead.", 22, Ink.a(Ink.SUMI, 0.7))
	for c in range(tabs.size()):
		var r = tabs[c].rect
		Ink.text(self, f, Vector2(r.position.x, r.end.y + 18), Data.CHAPTERS[c].name, 18, Ink.a(Ink.SUMI, 0.8 if tabs[c].on else 0.3), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	draw_btns()

func _draw():
	gate = main.gate_of(page)
	var f = main.font
	var phone = main.touch
	if picking:
		_draw_chapters(f)
		return
	Ink.tategaki(self, f, Vector2(64, 8), "上手", 46, Ink.SUMI)
	var ch = Data.CHAPTERS[page]
	var done = tally.done
	var rk = tally.rank
	if phone:
		Ink.text(self, f, Vector2(110, 46), "%s  %s" % [ch.kanji, ch.name], 38, Ink.SUMI)
		Ink.text(self, f, Vector2(110, 80), "Chapter %d of %d" % [page + 1, Data.CHAPTERS.size()], 24, Ink.a(Ink.SHU, 0.9))
		Ink.text(self, f, Vector2(110, 116), "%s %s  ·  %d of %d stations  ·  %d points" % [rk[0], rk[1], done, Data.LEVELS.size(), tally.points], 22, Ink.a(Ink.SUMI, 0.75))
	else:
		Ink.text(self, f, Vector2(110, 52), "The Road of the Blank Scroll", 32, Ink.SUMI)
		Ink.text(self, f, Vector2(110, 84), "Chapter %d of %d  ·  %s  %s" % [page + 1, Data.CHAPTERS.size(), ch.kanji, ch.name], 19, Ink.a(Ink.SHU, 0.9))

	# the handscroll in its mounting
	main.band(self, "sesshu", band, max(pan, 0.0))
	draw_rect(Rect2(band.position.x, band.position.y - 12, band.size.x, 12), Ink.AI)
	draw_rect(Rect2(band.position.x, band.end.y, band.size.x, 12), Ink.AI)
	draw_rect(Rect2(band.position.x, band.position.y - 3, band.size.x, 3), Ink.KIN)
	draw_rect(Rect2(band.position.x, band.end.y, band.size.x, 3), Ink.KIN)

	# the chapter's name on a slip of paper, as the title is set on a print
	var spare = main.spare()
	if not spare:
		var kj = ch.kanji
		var slip = Rect2(band.end.x - 76, band.position.y + 12, 52, kj.length() * 38.0 + 22)
		draw_rect(slip, Ink.a(Ink.GOFUN, 0.94))
		draw_rect(slip, Ink.SHU, false, 3.0)
		Ink.tategaki(self, f, Vector2(slip.position.x + 26, slip.position.y + 6), kj, 34, Ink.SUMI)

	# the season drifts across the painting, behind the words
	if main.data.opts.motion and not spare:
		Ink.season(self, _season(), time, 22)

	# a line of history about this place
	var note = ch.get("note", "")
	if note != "":
		if phone and main.tall:
			Ink.para(self, f, Vector2(706, 166), note, 21, Ink.a(Ink.SUMI, 0.9), 540)
		elif phone:
			Ink.para(self, f, Vector2(48, 426), note, 21, Ink.a(Ink.SUMI, 0.9), 1184)
		else:
			var nr = Rect2(band.position.x + 14, band.end.y - 96, 860, 82)
			draw_rect(nr, Ink.a(Ink.PAPER, 0.86))
			if not spare:
				Ink.frame(self, nr, 2.0, Ink.a(Ink.SUMI, 0.6))
			Ink.para(self, f, nr.position + Vector2(12, 20), note, 14, Ink.SUMI, nr.size.x - 24)

	# the road through this chapter
	var rg = _range(page)
	var road = []
	for k in range(0, (rg[1] - rg[0] - 1) * 8 + 1):
		road.append(st_pos(rg[0] + k / 8.0))
	if road.size() > 1:
		Ink.brush(self, road, 9, Ink.a(Ink.SUMI, 0.75))

	for i in range(rg[0], rg[1]):
		var p = st_pos(i)
		var open = main.unlocked(i)
		var g = main.grade_of(i)
		var small = rg[1] - rg[0] > 11
		var r = ((24.0 if phone else 20.0) if small else 28.0 if phone else 26.0) + (2.5 * sin(time * 3.0) if (open and g == "") else 0.0)
		draw_circle(p, r, Ink.PAPER)
		Ink.enso(self, p, r, 6.0 if open else 3.5, Ink.SHU if (i == hover_st and open) else Ink.a(Ink.SUMI, 1.0 if open else 0.35), -1.9 + i)
		if g == "jouzu" and spare:
			draw_circle(p, r * 0.52, Ink.SHU)
		elif g != "" and spare:
			# passed, not mastered: an empty ring where the red dot would be
			draw_arc(p, r * 0.46, 0, TAU, 28, Ink.AI, 3.0, true)
		elif g == "jouzu":
			Ink.seal(self, f, p, 13 if small else 17, "上手")
		elif g != "":
			Ink.seal(self, f, p, 17 if small else 22, "可", Ink.AI)
		else:
			var ns = (21 if phone else 17) if small else 22
			Ink.text(self, f, Vector2(p.x - 30, p.y + ns * 0.36), str(i + 1), ns, Ink.a(Ink.SUMI, 1.0 if open else 0.35), HORIZONTAL_ALIGNMENT_CENTER, 60)
		# the three seals of this station
		var m = main.seals_of(i)
		for k in range(3):
			var q = p + Vector2((k - 1) * 9.0, r + 9.0)
			if m & main.SEALS[k][0]:
				draw_circle(q, 3.2, Ink.SHU)
			elif open:
				draw_arc(q, 3.0, 0, TAU, 10, Ink.a(Ink.SUMI, 0.35), 1.0, true)
		if i == gate[1] and g == "" and gate[2] < gate[3]:
			# the chapter's gate, and how far along it is
			Ink.text(self, f, Vector2(p.x - 50, p.y - r - (28 if Data.BOSSES.has(i) else 8)), "関 %d/%d" % [gate[2], gate[3]], 15, Ink.a(Ink.SHU, 0.9), HORIZONTAL_ALIGNMENT_CENTER, 100)
		if Data.BOSSES.has(i):
			Ink.text(self, f, Vector2(p.x - 30, p.y - r - 8), "主", 16, Ink.a(Ink.SHU, 1.0 if open else 0.4), HORIZONTAL_ALIGNMENT_CENTER, 60)

	# what lies at the station under the cursor (on a phone: the next one to be played)
	var show = _focus()
	var lv = Data.LEVELS[show]
	var sub = "The road is not yet open."
	if _gated(show):
		sub = "Held: master %d more in this chapter." % (gate[3] - gate[2])
	if main.unlocked(show):
		var g = main.grade_of(show)
		sub = "Mastery: %d strokes, unharmed." % lv.par
		if g == "jouzu":
			sub = "Mastered — 上手."
		elif g != "":
			sub = "Passed, not mastered.  上手: %d strokes, unharmed." % lv.par
	if phone and main.tall:
		Ink.text(self, f, Vector2(700, 50), lv.kanji, 44, Ink.SUMI, HORIZONTAL_ALIGNMENT_CENTER, 560)
		Ink.text(self, f, Vector2(700, 84), "%d · %s" % [show + 1, lv.name], 24, Ink.SUMI, HORIZONTAL_ALIGNMENT_CENTER, 560)
		Ink.text(self, f, Vector2(700, 116), sub, 21, Ink.a(Ink.SHU, 0.9), HORIZONTAL_ALIGNMENT_CENTER, 560)
	elif phone:
		Ink.text(self, f, Vector2(760, 50), lv.kanji, 44, Ink.SUMI, HORIZONTAL_ALIGNMENT_RIGHT, 480)
		Ink.text(self, f, Vector2(760, 84), "%d · %s" % [show + 1, lv.name], 24, Ink.SUMI, HORIZONTAL_ALIGNMENT_RIGHT, 480)
		Ink.text(self, f, Vector2(760, 116), sub, 21, Ink.a(Ink.SHU, 0.9), HORIZONTAL_ALIGNMENT_RIGHT, 480)
	else:
		Ink.text(self, f, Vector2(820, 46), lv.kanji, 38, Ink.SUMI, HORIZONTAL_ALIGNMENT_RIGHT, 420)
		Ink.text(self, f, Vector2(820, 72), "%d · %s" % [show + 1, lv.name], 18, Ink.SUMI, HORIZONTAL_ALIGNMENT_RIGHT, 420)
		Ink.text(self, f, Vector2(820, 96), sub, 15, Ink.a(Ink.SHU, 0.9), HORIZONTAL_ALIGNMENT_RIGHT, 420)
		Ink.text(self, f, Vector2(576, 674), "%s %s   Stations %d / %d   Seals %d / %d   Points %d" % [rk[0], rk[1], done, Data.LEVELS.size(), tally.seals, 3 * Data.LEVELS.size(), tally.points], 17, Ink.SUMI)
		Ink.text(self, f, Vector2(566, 700), "Seals: 上手 mastery · 潔 first attempt, nothing taken back · 惜墨 sparing of ink.", 14, Ink.a(Ink.SUMI, 0.6))
	draw_btns()
	if notice != "":
		_draw_notice(f)

# The gate explained, on a slip of paper over the road.
func _notice_rect(f):
	var big = main.touch
	var w = 680.0 if main.tall else 1000.0 if big else 720.0
	var h = f.get_multiline_string_size(notice, HORIZONTAL_ALIGNMENT_LEFT, w - 80.0, 26 if big else 19).y + (150.0 if big else 120.0)
	return Rect2(640.0 - w * 0.5, 360.0 - h * 0.5, w, h)

func _draw_notice(f):
	var big = main.touch
	var size = 26 if big else 19
	var r = _notice_rect(f)
	var w = r.size.x
	draw_rect(Rect2(0, 0, 1280, 720), Ink.a(Ink.PAPER, 0.55))
	draw_rect(r, Ink.a(Ink.PAPER, 0.98))
	draw_rect(Rect2(r.position.x, r.position.y, 5.0, r.size.y), Ink.a(Ink.SHU, 0.85))
	Ink.text(self, f, Vector2(r.position.x + 40.0, r.position.y + (56.0 if big else 46.0)), "関  The road is held", 34 if big else 26, Ink.SUMI)
	Ink.para(self, f, Vector2(r.position.x + 40.0, r.position.y + (104.0 if big else 84.0)), notice, size, Ink.a(Ink.AI, 0.95), w - 80.0)
	Ink.text(self, f, Vector2(r.position.x, r.end.y - 18.0), "tap to close" if big else "any key or click", 18 if big else 12, Ink.a(Ink.SUMI, 0.5), HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 30.0)
