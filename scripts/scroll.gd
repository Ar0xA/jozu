extends "res://scripts/screen_base.gd"
# The scroll you have painted: for every stage cleared, the strokes that cleared it,
# with the board taken away.

var page = 0
var tabs = []

func setup():
	btn(Rect2(40, 664, 220, 44), "Back to the road", main.show_map, "道")
	var n = Data.CHAPTERS.size()
	var tw = 1200.0 / n
	for c in range(n):
		tabs.append(btn(Rect2(40 + c * tw + 4, 614, tw - 8, 38), Data.CHAPTERS[c].kanji, _page.bind(c)))
	for c in range(n):
		if main.grade_of(Data.CHAPTERS[c].from) != "":
			page = c
	_page(page)

func _page(c):
	page = c
	for k in range(tabs.size()):
		tabs[k].sel = k == page

func _range(c):
	var a = Data.CHAPTERS[c].from
	var b = Data.LEVELS.size()
	if c + 1 < Data.CHAPTERS.size():
		b = Data.CHAPTERS[c + 1].from
	return [a, b]

func on_key(code):
	if code == KEY_ESCAPE:
		main.show_map()
	elif code == KEY_RIGHT and page + 1 < Data.CHAPTERS.size():
		_page(page + 1)
	elif code == KEY_LEFT and page > 0:
		_page(page - 1)

func _draw():
	var f = main.font
	Ink.tategaki(self, f, Vector2(64, 6), "巻", 50, Ink.SUMI)
	Ink.text(self, f, Vector2(110, 50), "Your Scroll", 32, Ink.SUMI)
	var ch = Data.CHAPTERS[page]
	Ink.text(self, f, Vector2(110, 82), "%s  %s  ·  the strokes that cleared each station, and nothing else" % [ch.kanji, ch.name], 17, Ink.a(Ink.SHU, 0.9))
	var rg = _range(page)
	var painted = 0
	for i in range(rg[0], rg[1]):
		var k = i - rg[0]
		var cols = 5 if rg[1] - rg[0] <= 10 else 6
		var rws = 2 if rg[1] - rg[0] <= 10 else 3
		var cw = 1160.0 / cols
		var chh = 500.0 / rws
		var r = Rect2(64 + (k % cols) * cw, 106 + (k / cols) * chh, cw - 20, chh - 18)
		var lv = Data.LEVELS[i]
		draw_rect(r, Ink.a(Ink.GOFUN, 0.75))
		Ink.frame(self, r, 2.5, Ink.a(Ink.SUMI, 0.75))
		var key = str(i)
		if main.data.scroll.has(key):
			painted += 1
			Ink.calligraphy(self, Rect2(r.position + Vector2(14, 8), r.size - Vector2(28, 44)), main.data.scroll[key], lv.rows[0].length(), lv.rows.size())
			if main.grade_of(i) == "jouzu":
				Ink.seal(self, f, r.end - Vector2(20, 24), 10, "上手")
			var ks = 19 if rws == 2 else 16
			Ink.text(self, f, Vector2(r.position.x + 10, r.end.y - 10), lv.kanji, ks, Ink.SUMI)
			Ink.text(self, f, Vector2(r.position.x + 16 + ks * lv.kanji.length(), r.end.y - 11), str(i + 1), 12, Ink.a(Ink.SUMI, 0.55))
		else:
			Ink.text(self, f, Vector2(r.position.x, r.position.y + r.size.y * 0.58), str(i + 1), 36, Ink.a(Ink.SUMI, 0.12), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var total = main.data.scroll.size()
	Ink.text(self, f, Vector2(290, 692), "%d of %d painted in this chapter   ·   %d of %d in all   ·   ← → turn chapters" % [painted, rg[1] - rg[0], total, Data.LEVELS.size()], 17, Ink.SUMI)
	draw_btns()
