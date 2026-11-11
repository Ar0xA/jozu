extends "res://scripts/screen_base.gd"
# The road, one chapter at a time. Above it unrolls Sesshu's Long Scroll, travelling with you.

const BAND = Rect2(40, 124, 1200, 330)

var hover_st = -1
var pan = -1.0
var page = 0
var tabs = []

func setup():
	btn(Rect2(40, 648, 180, 50), "Training", main.show_dojo, "修練")
	btn(Rect2(232, 648, 128, 50), "Scroll", main.show_scroll, "巻")
	btn(Rect2(372, 648, 110, 50), "Title", main.show_title, "題")
	page = _chapter_of(_next_open())
	var n = Data.CHAPTERS.size()
	var tw = 1200.0 / n
	for c in range(n):
		var b = btn(Rect2(40 + c * tw + 4, 470, tw - 8, 40), Data.CHAPTERS[c].kanji, _page.bind(c))
		tabs.append(b)
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
	_sync()

func _sync():
	for c in range(tabs.size()):
		tabs[c].sel = c == page
		tabs[c].on = main.unlocked(Data.CHAPTERS[c].from)

func st_pos(i):
	var rg = _range(page)
	var n = rg[1] - rg[0]
	var k = i - rg[0]
	var step = min(118.0, 1080.0 / max(1, n - 1))
	return Vector2(640 - step * (n - 1) * 0.5 + k * step, 580 + 16 * sin(k * 0.9 + 0.4))

func _focus():
	if hover_st >= 0:
		return hover_st
	var rg = _range(page)
	for i in range(rg[0], rg[1]):
		if main.grade_of(i) == "":
			return i
	return rg[1] - 1

func tick(dt):
	var span = main.band_len("sesshu") - BAND.size.x * 400.0 / BAND.size.y
	var want = span * _focus() / float(Data.LEVELS.size() - 1)
	if pan < 0.0:
		pan = want
	pan = lerp(pan, want, 1.0 - exp(-dt * 2.2))

func on_motion(pos, _held):
	hover_st = -1
	var rg = _range(page)
	for i in range(rg[0], rg[1]):
		if pos.distance_to(st_pos(i)) < (30 if rg[1] - rg[0] <= 11 else 24):
			hover_st = i

func on_click(pos, button):
	if button != MOUSE_BUTTON_LEFT:
		return
	on_motion(pos, false)
	if hover_st >= 0 and main.unlocked(hover_st):
		main.start_stage(hover_st)

func on_key(code):
	if code == KEY_ESCAPE:
		main.show_title()
	elif code == KEY_RIGHT and page + 1 < Data.CHAPTERS.size() and main.unlocked(Data.CHAPTERS[page + 1].from):
		_page(page + 1)
	elif code == KEY_LEFT and page > 0:
		_page(page - 1)

func _draw():
	var f = main.font
	Ink.tategaki(self, f, Vector2(64, 8), "上手", 46, Ink.SUMI)
	Ink.text(self, f, Vector2(110, 52), "The Road of the Blank Scroll", 32, Ink.SUMI)
	var ch = Data.CHAPTERS[page]
	Ink.text(self, f, Vector2(110, 84), "Chapter %d of %d  ·  %s  %s" % [page + 1, Data.CHAPTERS.size(), ch.kanji, ch.name], 19, Ink.a(Ink.SHU, 0.9))

	# the handscroll in its mounting
	main.band(self, "sesshu", BAND, max(pan, 0.0))
	draw_rect(Rect2(BAND.position.x, BAND.position.y - 12, BAND.size.x, 12), Ink.AI)
	draw_rect(Rect2(BAND.position.x, BAND.end.y, BAND.size.x, 12), Ink.AI)
	draw_rect(Rect2(BAND.position.x, BAND.position.y - 3, BAND.size.x, 3), Ink.KIN)
	draw_rect(Rect2(BAND.position.x, BAND.end.y, BAND.size.x, 3), Ink.KIN)

	# a line of history about this place
	var note = ch.get("note", "")
	if note != "":
		var nr = Rect2(BAND.position.x + 14, BAND.end.y - 78, 700, 64)
		draw_rect(nr, Ink.a(Ink.PAPER, 0.86))
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
		var r = (20.0 if small else 26.0) + (2.5 * sin(time * 3.0) if (open and g == "") else 0.0)
		draw_circle(p, r, Ink.PAPER)
		Ink.enso(self, p, r, 6.0 if open else 3.5, Ink.SHU if (i == hover_st and open) else Ink.a(Ink.SUMI, 1.0 if open else 0.35), -1.9 + i)
		if g == "jouzu":
			Ink.seal(self, f, p, 13 if small else 17, "上手")
		elif g != "":
			Ink.seal(self, f, p, 17 if small else 22, "可", Ink.AI)
		else:
			Ink.text(self, f, Vector2(p.x - 30, p.y + (6 if small else 8)), str(i + 1), 17 if small else 22, Ink.a(Ink.SUMI, 1.0 if open else 0.35), HORIZONTAL_ALIGNMENT_CENTER, 60)
		if Data.BOSSES.has(i):
			Ink.text(self, f, Vector2(p.x - 30, p.y - 34), "主", 16, Ink.a(Ink.SHU, 1.0 if open else 0.4), HORIZONTAL_ALIGNMENT_CENTER, 60)

	# what lies at the station under the cursor
	var show = _focus()
	var lv = Data.LEVELS[show]
	Ink.text(self, f, Vector2(820, 46), lv.kanji, 38, Ink.SUMI, HORIZONTAL_ALIGNMENT_RIGHT, 420)
	Ink.text(self, f, Vector2(820, 72), "%d · %s" % [show + 1, lv.name], 18, Ink.SUMI, HORIZONTAL_ALIGNMENT_RIGHT, 420)
	var sub = "The road is not yet open."
	if main.unlocked(show):
		var g = main.grade_of(show)
		sub = "Mastery: %d strokes, unharmed." % lv.par
		if g == "jouzu":
			sub = "Mastered — 上手."
		elif g != "":
			sub = "Cleared 可.  Mastery: %d strokes, unharmed." % lv.par
	Ink.text(self, f, Vector2(820, 96), sub, 15, Ink.a(Ink.SHU, 0.9), HORIZONTAL_ALIGNMENT_RIGHT, 420)

	var done = 0
	var best = 0
	for i in range(Data.LEVELS.size()):
		if main.grade_of(i) != "":
			done += 1
		if main.grade_of(i) == "jouzu":
			best += 1
	Ink.text(self, f, Vector2(504, 674), "Stations %d / %d     上手 seals %d     Training points %d" % [done, Data.LEVELS.size(), best, main.points()], 20, Ink.SUMI)
	Ink.text(self, f, Vector2(504, 700), "Clear a station for 1 point. Master it for 2.  ← → turn chapters.", 15, Ink.a(Ink.SUMI, 0.6))
	draw_btns()
