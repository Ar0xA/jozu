extends "res://scripts/screen_base.gd"
# Training: spend points earned on the road. Mastery is always possible without any of it.

const MAXLV = 2
var rows = []

func setup():
	still = true
	var bh = 66 if main.touch else 52
	btn(Rect2(40, 700 - bh - 8, 280 if main.touch else 220, bh), "Back to the road", main.show_map, "道")
	btn(Rect2(340 if main.touch else 280, 700 - bh - 8, 240 if main.touch else 220, bh), "Unlearn all", _reset, "忘")
	for i in range(Data.UPGRADES.size()):
		var u = Data.UPGRADES[i]
		var b = btn(Rect2(960, 176 + i * 86, 220, 54), "", _buy.bind(u[0]))
		rows.append(b)
	_refresh()

# Upright: each skill's words, and under them how far it is trained and the button.
func tall_parts(_h):
	if not main.touch:
		return super.tall_parts(_h)
	var parts = [{"src": [Rect2(30, 24, 570, 150)], "s": 1.1}]
	for i in range(Data.UPGRADES.size()):
		var y = 176 + i * 86
		parts.append({"src": [Rect2(120, y, 680, 72)], "s": 1.0})
		parts.append({"src": [Rect2(796, y + 2, 120, 62), Rect2(950, y + 2, 240, 62)], "s": 1.2})
	parts.append({"src": [Rect2(36, 620, 309, 80), Rect2(345, 620, 245, 80)], "s": 1.15})
	return parts

func _known(key):
	if not Data.WAZA_FROM.has(key):
		return true
	return main.unlocked(Data.WAZA_FROM[key])

func _refresh():
	for i in range(rows.size()):
		var key = Data.UPGRADES[i][0]
		var lv = int(main.data.up[key])
		var b = rows[i]
		if not _known(key):
			b.label = "Not yet learned"
			b.on = false
		elif lv >= MAXLV:
			b.label = "Complete"
			b.on = false
		else:
			b.label = "Train  (%d points)" % main.up_cost(key)
			b.on = main.points() >= main.up_cost(key)

func _buy(key):
	if main.points() >= main.up_cost(key) and int(main.data.up[key]) < MAXLV and _known(key):
		main.data.up[key] = int(main.data.up[key]) + 1
		main.write_save()
	_refresh()

func _reset():
	for k in main.data.up:
		main.data.up[k] = 0
	main.write_save()
	_refresh()

func on_key(code):
	if code == KEY_ESCAPE:
		main.show_map()

func _draw():
	var f = main.font
	backdrop(0.45)
	Ink.tategaki(self, f, Vector2(70, 30), "修練", 60, Ink.SUMI)
	Ink.text(self, f, Vector2(130, 76), "Training", 34, Ink.SUMI)
	Ink.text(self, f, Vector2(130, 112), "Points to spend: %d" % main.points(), 28 if main.touch else 22, Ink.SHU)
	if not main.tall:
		Ink.para(self, f, Vector2(130, 140), "Every station can be mastered with nothing from this page. Training is for the road, not the proof.", 20 if main.touch else 16, Ink.a(Ink.SUMI, 0.7), 1040 if main.touch else 760)
	for i in range(Data.UPGRADES.size()):
		var u = Data.UPGRADES[i]
		var y = 176 + i * 86
		var lv = int(main.data.up[u[0]])
		draw_line(Vector2(130, y + 70), Vector2(1180, y + 70), Ink.a(Ink.SUMI, 0.2), 1.0)
		Ink.text(self, f, Vector2(130, y + 42), u[1], 40, Ink.SUMI if _known(u[0]) else Ink.a(Ink.SUMI, 0.3))
		Ink.text(self, f, Vector2(250, y + 28), u[2], 24, Ink.SUMI)
		Ink.text(self, f, Vector2(250, y + (58 if main.touch else 54)), u[3], 21 if main.touch else 17, Ink.a(Ink.SUMI, 0.7))
		for k in range(MAXLV):
			var c = Vector2(820 + k * 44, y + 28)
			if k < lv:
				draw_circle(c, 14, Ink.SHU)
			draw_arc(c, 14, 0, TAU, 24, Ink.SUMI, 2.0, true)
	draw_btns()
