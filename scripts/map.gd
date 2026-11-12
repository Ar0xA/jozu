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
var tabs = []
var nav = []          # the buttons of the road page itself (hidden while chapters are being chosen)
var picking = false   # phone: the page of chapters is open
var b_close

func setup():
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
	_sync()

func _next_open():
	for i in range(Data.LEVELS.size()):
		if main.grade_of(i) == "":
			return i
	return Data.LEVELS.size() - 1

func _chapter_of(i):
	var c = 0
	for k in range(Data.CHAPTERS.size()):
		if Data.CHAPTERS[k].from <= i:
			c = k
	return c

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
	var step = min(118.0, 1080.0 / max(1, n - 1))
	return Vector2(640 - step * (n - 1) * 0.5 + k * step, road_y + 14 * sin(k * 0.9 + 0.4))

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

func on_key(code):
	if code == KEY_ESCAPE:
		main.show_title()
	elif code == KEY_RIGHT:
		_step(1)
	elif code == KEY_LEFT:
		_step(-1)

# phone: every chapter on one page, with its English name under it
func _draw_chapters(f):
	draw_texture_rect(main.art["tohaku"], Rect2(0, 0, 1280, 720), false, Color(1, 1, 1, 0.35))
	Ink.tategaki(self, f, Vector2(64, 4), "章", 40, Ink.SUMI)
	Ink.text(self, f, Vector2(110, 48), "Chapters", 34, Ink.SUMI)
	Ink.text(self, f, Vector2(300, 46), "Tap one to go to it. The pale ones are still ahead.", 22, Ink.a(Ink.SUMI, 0.7))
	for c in range(tabs.size()):
		var r = tabs[c].rect
		Ink.text(self, f, Vector2(r.position.x, r.end.y + 18), Data.CHAPTERS[c].name, 18, Ink.a(Ink.SUMI, 0.8 if tabs[c].on else 0.3), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	draw_btns()

func _draw():
	var f = main.font
	var phone = main.touch
	if picking:
		_draw_chapters(f)
		return
	Ink.tategaki(self, f, Vector2(64, 8), "上手", 46, Ink.SUMI)
	var ch = Data.CHAPTERS[page]
	var done = 0
	for i in range(Data.LEVELS.size()):
		if main.grade_of(i) != "":
			done += 1
	var rk = main.rank()
	if phone:
		Ink.text(self, f, Vector2(110, 46), "%s  %s" % [ch.kanji, ch.name], 38, Ink.SUMI)
		Ink.text(self, f, Vector2(110, 80), "Chapter %d of %d" % [page + 1, Data.CHAPTERS.size()], 24, Ink.a(Ink.SHU, 0.9))
		Ink.text(self, f, Vector2(110, 116), "%s %s  ·  %d of %d stations  ·  %d points" % [rk[0], rk[1], done, Data.LEVELS.size(), main.points()], 22, Ink.a(Ink.SUMI, 0.75))
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
		if phone:
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
		if g != "" and spare:
			draw_circle(p, r * 0.52, Ink.SHU if g == "jouzu" else Ink.AI)
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
		if Data.BOSSES.has(i):
			Ink.text(self, f, Vector2(p.x - 30, p.y - r - 8), "主", 16, Ink.a(Ink.SHU, 1.0 if open else 0.4), HORIZONTAL_ALIGNMENT_CENTER, 60)

	# what lies at the station under the cursor (on a phone: the next one to be played)
	var show = _focus()
	var lv = Data.LEVELS[show]
	var sub = "The road is not yet open."
	if main.unlocked(show):
		var g = main.grade_of(show)
		sub = "Mastery: %d strokes, unharmed." % lv.par
		if g == "jouzu":
			sub = "Mastered — 上手."
		elif g != "":
			sub = "Cleared 可.  Mastery: %d strokes, unharmed." % lv.par
	if phone:
		Ink.text(self, f, Vector2(760, 50), lv.kanji, 44, Ink.SUMI, HORIZONTAL_ALIGNMENT_RIGHT, 480)
		Ink.text(self, f, Vector2(760, 84), "%d · %s" % [show + 1, lv.name], 24, Ink.SUMI, HORIZONTAL_ALIGNMENT_RIGHT, 480)
		Ink.text(self, f, Vector2(760, 116), sub, 21, Ink.a(Ink.SHU, 0.9), HORIZONTAL_ALIGNMENT_RIGHT, 480)
	else:
		Ink.text(self, f, Vector2(820, 46), lv.kanji, 38, Ink.SUMI, HORIZONTAL_ALIGNMENT_RIGHT, 420)
		Ink.text(self, f, Vector2(820, 72), "%d · %s" % [show + 1, lv.name], 18, Ink.SUMI, HORIZONTAL_ALIGNMENT_RIGHT, 420)
		Ink.text(self, f, Vector2(820, 96), sub, 15, Ink.a(Ink.SHU, 0.9), HORIZONTAL_ALIGNMENT_RIGHT, 420)
		Ink.text(self, f, Vector2(576, 674), "%s %s   Stations %d / %d   Seals %d / %d   Points %d" % [rk[0], rk[1], done, Data.LEVELS.size(), main.seal_count(), 3 * Data.LEVELS.size(), main.points()], 17, Ink.SUMI)
		Ink.text(self, f, Vector2(566, 700), "Seals: 上手 mastery · 潔 first attempt, nothing taken back · 惜墨 sparing of ink.", 14, Ink.a(Ink.SUMI, 0.6))
	draw_btns()
