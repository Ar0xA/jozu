extends "res://scripts/screen_base.gd"
# The other roads: the daily koan, the pilgrimage of 88 temples, and the workshop.

const Extra = preload("res://scripts/extra.gd")

func setup():
	btn(Rect2(880, 160, 280, 44), "Sit with it" if not main.daily_done() else "Sit with it again", main.show_daily, "日課")
	btn(Rect2(880, 330, 280, 44), "Walk on" if int(main.data.henro.at) > 0 else "Set out", main.show_henro, "遍路")
	btn(Rect2(880, 500, 280, 44), "Open the workshop", main.show_editor, "工房")
	btn(Rect2(40, 648, 220, 50), "Back to the road", main.show_map, "道")

func on_key(code):
	if code == KEY_ESCAPE:
		main.show_map()

func _card(f, y, kanji, title, lines):
	var r = Rect2(100, y, 1080, 150)
	draw_rect(r, Ink.a(Ink.GOFUN, 0.6))
	Ink.frame(self, r, 2.5, Ink.a(Ink.SUMI, 0.7))
	Ink.tategaki(self, f, Vector2(150, y + 14), kanji, 44, Ink.SHU)
	Ink.text(self, f, Vector2(210, y + 46), title, 30, Ink.SUMI)
	for i in range(lines.size()):
		Ink.text(self, f, Vector2(210, y + 78 + i * 24), lines[i], 17, Ink.a(Ink.SUMI, 0.85 if i == 0 else 0.65))

func _draw():
	var f = main.font
	draw_texture_rect(main.art["tohaku"], Rect2(0, 0, 1280, 720), false, Color(1, 1, 1, 0.4))
	Ink.tategaki(self, f, Vector2(64, 8), "別", 50, Ink.SUMI)
	Ink.text(self, f, Vector2(110, 52), "Other Roads", 34, Ink.SUMI)
	Ink.text(self, f, Vector2(110, 84), "Three ways to keep the brush moving once the scroll is not enough.", 17, Ink.a(Ink.SUMI, 0.7))

	var d = main.data.daily
	var names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
	var wd = (main.today() + 3) % 7
	_card(f, 150, "日課", "The Daily Kōan", [
		"One single-stroke board each day, the same for everyone. Today is %s: %s." % [names[wd], ["the gentlest", "gentle", "plain", "testing", "hard", "harder", "the hardest of the week"][wd]],
		("Answered today.  " if main.daily_done() else "Not yet answered today.  ") + "Days in a row: %d.   Longest: %d." % [int(d.streak) if int(d.last) >= main.today() - 1 else 0, int(d.best)],
		"%d kōan in the bank." % Extra.DAILY.size()])

	var h = main.data.henro
	var at = int(h.at)
	var pr = main.province(min(at, 87))
	_card(f, 320, "遍路", "The 88 Temples", [
		"A pilgrimage of 88 boards. No stroke can be taken back and there is no master to ask.",
		"Next: temple %d of 88, in %s %s.   Staffs: %d of 3.   Furthest: %d.%s" % [min(at + 1, 88), pr[1], pr[2], int(h.staffs), int(h.best), ("   Completed: %d." % int(h.done)) if int(h.done) > 0 else ""],
		"A temple lost or walked out of costs a staff. A province finished gives one back. With none left, begin again."])

	_card(f, 490, "工房", "The Workshop", [
		"Lay out a board of your own: ground, yokai, rules and techniques.",
		"Clear it yourself and it becomes a code you can give to anyone. Paste a code to play theirs.",
		"Your stroke count becomes the mastery target for whoever plays it."])
	draw_btns()
