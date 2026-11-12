extends "res://scripts/screen_base.gd"
# The scroll you have painted: for every stage cleared, the strokes that cleared it,
# with the board taken away.

var page = 0
var tabs = []
var page_t = 0.0     # when this chapter was turned to: its strokes are written out afresh

func setup():
	btn(Rect2(40, 672, 220, 40), "Back to the road", main.show_map, "道")
	var n = Data.CHAPTERS.size()
	var per = int(ceil(n / 2.0)) if n > 17 else n
	var tw = 1200.0 / per
	for c in range(n):
		tabs.append(btn(Rect2(40 + (c % per) * tw + 4, 606 + (c / per) * 30 if n > 17 else 614, tw - 8, 27 if n > 17 else 38), Data.CHAPTERS[c].kanji, _page.bind(c)))
	if main.touch:
		# a phone turns the chapters with two large arrows instead of a row of small tabs
		for b in tabs:
			b.show = false
		btns[0].rect = Rect2(40, 636, 300, 68)
		btn(Rect2(960, 636, 140, 68), "Back", func(): on_key(KEY_LEFT), "前")
		btn(Rect2(1110, 636, 130, 68), "On", func(): on_key(KEY_RIGHT), "次")
	for c in range(n):
		if main.grade_of(Data.CHAPTERS[c].from) != "":
			page = c
	_page(page)

func _page(c):
	page = c
	page_t = time
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
	if main.touch:
		Ink.text(self, f, Vector2(110, 86), "%s  %s" % [ch.kanji, ch.name], 26, Ink.a(Ink.SHU, 0.9))
	else:
		Ink.text(self, f, Vector2(110, 82), "%s  %s  ·  the strokes that cleared each station, and nothing else" % [ch.kanji, ch.name], 17, Ink.a(Ink.SHU, 0.9))
	var rg = _range(page)
	var painted = 0
	for i in range(rg[0], rg[1]):
		var k = i - rg[0]
		var cols = 5 if rg[1] - rg[0] <= 10 else 6
		var rws = 2 if rg[1] - rg[0] <= 10 else 3
		var cw = 1160.0 / cols
		var chh = 492.0 / rws
		var r = Rect2(64 + (k % cols) * cw, 106 + (k / cols) * chh, cw - 20, chh - 18)
		var lv = Data.LEVELS[i]
		draw_rect(r, Ink.a(Ink.GOFUN, 0.75))
		Ink.frame(self, r, 2.5, Ink.a(Ink.SUMI, 0.75))
		var key = str(i)
		if main.data.scroll.has(key):
			painted += 1
			Ink.calligraphy(self, Rect2(r.position + Vector2(14, 8), r.size - Vector2(28, 44)), main.data.scroll[key], lv.rows[0].length(), lv.rows.size(), 1.0 if not main.data.opts.motion else clamp((time - page_t - 0.3 - k * 0.07) / 0.9, 0.0, 1.0))
			if main.grade_of(i) == "jouzu":
				Ink.seal(self, f, r.end - Vector2(20, 24), 10, "上手")
			var ks = 19 if rws == 2 else 16
			Ink.text(self, f, Vector2(r.position.x + 10, r.end.y - 10), lv.kanji, ks, Ink.SUMI)
			Ink.text(self, f, Vector2(r.position.x + 16 + ks * lv.kanji.length(), r.end.y - 11), str(i + 1), 12, Ink.a(Ink.SUMI, 0.55))
		else:
			Ink.text(self, f, Vector2(r.position.x, r.position.y + r.size.y * 0.58), str(i + 1), 36, Ink.a(Ink.SUMI, 0.12), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var total = main.data.scroll.size()
	if main.touch:
		Ink.text(self, f, Vector2(360, 666), "Chapter %d of %d" % [page + 1, Data.CHAPTERS.size()], 26, Ink.SUMI)
		Ink.text(self, f, Vector2(360, 696), "%d of %d painted here  ·  %d of %d in all" % [painted, rg[1] - rg[0], total, Data.LEVELS.size()], 22, Ink.a(Ink.SUMI, 0.75))
	else:
		Ink.text(self, f, Vector2(290, 700), "%d of %d painted in this chapter   ·   %d of %d in all   ·   ← → turn chapters" % [painted, rg[1] - rg[0], total, Data.LEVELS.size()], 17, Ink.SUMI)
	draw_btns()
