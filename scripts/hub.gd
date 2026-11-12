extends "res://scripts/screen_base.gd"
# The other roads: the daily koan, the pilgrimage of 88 temples, the unmapped road, and the workshop.

const Extra = preload("res://scripts/extra.gd")
const TOP = 112
const STEP = 132

func setup():
	btn(Rect2(880, TOP + 8, 280, 42), "Sit with it" if not main.daily_done() else "Sit with it again", main.show_daily, "日課")
	btn(Rect2(880, TOP + 62, 280, 40), "Days gone by", main.show_calendar, "暦")
	btn(Rect2(880, TOP + STEP + 8, 280, 42), "Walk on" if int(main.data.henro.at) > 0 else "Set out", main.show_henro, "遍路")
	for k in range(4):
		btn(Rect2(628 + k * 138, TOP + STEP * 2 + 62, 132, 40), main.BRACKETS[k][1], main.show_random.bind(k), main.BRACKETS[k][0])
	btn(Rect2(880, TOP + STEP * 3 + 8, 280, 42), "Open the workshop", main.show_editor, "工房")
	btn(Rect2(40, 648, 300, 62) if main.touch else Rect2(40, 656, 220, 46), "Back to the road", main.show_map, "道")
	btn(Rect2(360, 648, 220, 62) if main.touch else Rect2(280, 656, 170, 46), "Settings", main.show_settings.bind(main.show_hub), "設")
	if main.touch:
		# taller buttons, and the four brackets of the unmapped road spread across their card
		for b in btns:
			if b.rect.position.x == 880 and b.rect.size.y <= 42:
				b.rect = Rect2(b.rect.position + Vector2(0, -2), Vector2(280, 50))
			elif b.rect.size.x == 132:
				b.rect = Rect2(b.rect.position + Vector2(0, -8), Vector2(132, 54))

func on_key(code):
	if code == KEY_ESCAPE:
		main.show_map()

func _card(f, i, kanji, title, lines):
	var y = TOP + i * STEP
	var r = Rect2(100, y, 1080, STEP - 12)
	if main.spare():
		draw_line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), Ink.a(Ink.SUMI, 0.35), 1.5, true)   # a rule between, and nothing round
	else:
		draw_rect(r, Ink.a(Ink.GOFUN, 0.6))
		Ink.frame(self, r, 2.5, Ink.a(Ink.SUMI, 0.7))
	Ink.tategaki(self, f, Vector2(150, y + 8), kanji, 40, Ink.SHU)
	Ink.text(self, f, Vector2(210, y + 38), title, 28, Ink.SUMI)
	for k in range(lines.size()):
		if main.touch:
			Ink.text(self, f, Vector2(210, y + 70 + k * 30), lines[k], 22, Ink.a(Ink.SUMI, 0.9 if k == 0 else 0.7))
		else:
			Ink.text(self, f, Vector2(210, y + 66 + k * 22), lines[k], 16, Ink.a(Ink.SUMI, 0.85 if k == 0 else 0.65))

func _draw():
	var f = main.font
	draw_texture_rect(main.art["tohaku"], Rect2(0, 0, 1280, 720), false, Color(1, 1, 1, 0.4))
	Ink.tategaki(self, f, Vector2(64, 4), "別", 46, Ink.SUMI)
	Ink.text(self, f, Vector2(110, 46), "Other Roads", 32, Ink.SUMI)
	Ink.text(self, f, Vector2(110, 78), "Four ways to keep the brush moving once the scroll is not enough.", 21 if main.touch else 16, Ink.a(Ink.SUMI, 0.7))

	var d = main.data.daily
	var names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
	var wd = (main.today() + 3) % 7
	if main.touch:
		# the same four roads, said shortly and set large
		_card(f, 0, "日課", "The Daily Kōan", ["One single-stroke board a day. %s: %s." % [names[wd], ["gentlest", "gentle", "plain", "testing", "hard", "harder", "hardest"][wd]],
			("Answered today.  " if main.daily_done() else "Not yet answered.  ") + "Run: %d.  Best: %d." % [int(d.streak) if int(d.last) >= main.today() - 1 else 0, int(d.best)]])
		var hh = main.data.henro
		_card(f, 1, "遍路", "The 88 Temples", ["88 boards: no undo, no hints, three staffs.",
			"Temple %d  ·  staffs %d of 3  ·  furthest %d" % [min(int(hh.at) + 1, 88), int(hh.staffs), int(hh.best)]])
		var w2 = []
		for k in range(4):
			w2.append(str(int(main.data.rand.get(str(k), 0))))
		_card(f, 2, "乱", "The Unmapped Road", ["A new board, made while you wait.", "Cleared: " + " · ".join(w2)])
		_card(f, 3, "工房", "The Workshop", ["Make a board and share its code.", "Paste a code to play someone's."])
		draw_btns()
		return
	_card(f, 0, "日課", "The Daily Kōan", [
		"One single-stroke board a day, the same for everyone. %s: %s." % [names[wd], ["the gentlest", "gentle", "plain", "testing", "hard", "harder", "the hardest of the week"][wd]],
		("Answered today.  " if main.daily_done() else "Not yet answered today.  ") + "Days running: %d.   Longest: %d." % [int(d.streak) if int(d.last) >= main.today() - 1 else 0, int(d.best)]])

	var h = main.data.henro
	var at = int(h.at)
	var pr = main.province(min(at, 87))
	_card(f, 1, "遍路", "The 88 Temples", [
		"A pilgrimage of 88 boards: no stroke taken back, no master to ask, three staffs.",
		"Next: temple %d, in %s.   Staffs: %d of 3.   Furthest: %d.%s" % [min(at + 1, 88), pr[2], int(h.staffs), int(h.best), ("   Completed: %d." % int(h.done)) if int(h.done) > 0 else ""]])

	var won = []
	for k in range(4):
		won.append(str(int(main.data.rand.get(str(k), 0))))
	_card(f, 2, "乱", "The Unmapped Road", [
		"A new board, made and solved while you wait," if OS.has_feature("web") else "A board at random from %d proven boards" % Extra.RANDOM.size(),
		("or one from a shelf of %d. Cleared: " % Extra.RANDOM.size() if OS.has_feature("web") else "the story never used. Cleared: ") + " · ".join(won)])

	_card(f, 3, "工房", "The Workshop", [
		"Lay out a board of your own, clear it, and it becomes a code to give away.",
		"Paste someone else's code to play theirs."])
	draw_btns()
