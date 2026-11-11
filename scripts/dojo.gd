extends "res://scripts/screen_base.gd"
# Training: spend points earned on the road. Mastery is always possible without any of it.

const MAXLV = 2
var rows = []

func setup():
	btn(Rect2(40, 640, 220, 52), "Back to the road", main.show_map, "道")
	btn(Rect2(280, 640, 220, 52), "Unlearn all", _reset, "忘")
	for i in range(Data.UPGRADES.size()):
		var u = Data.UPGRADES[i]
		var b = btn(Rect2(960, 176 + i * 86, 220, 54), "", _buy.bind(u[0]))
		rows.append(b)
	_refresh()

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
	draw_texture_rect(main.art["tohaku"], Rect2(0, 0, 1280, 720), false, Color(1, 1, 1, 0.45))
	Ink.tategaki(self, f, Vector2(70, 30), "修練", 60, Ink.SUMI)
	Ink.text(self, f, Vector2(130, 76), "Training", 34, Ink.SUMI)
	Ink.text(self, f, Vector2(130, 110), "Points to spend: %d" % main.points(), 22, Ink.SHU)
	Ink.para(self, f, Vector2(130, 140), "Every station can be mastered with nothing from this page. Training is for the road, not the proof.", 16, Ink.a(Ink.SUMI, 0.7), 760)
	for i in range(Data.UPGRADES.size()):
		var u = Data.UPGRADES[i]
		var y = 176 + i * 86
		var lv = int(main.data.up[u[0]])
		draw_line(Vector2(130, y + 70), Vector2(1180, y + 70), Ink.a(Ink.SUMI, 0.2), 1.0)
		Ink.text(self, f, Vector2(130, y + 42), u[1], 40, Ink.SUMI if _known(u[0]) else Ink.a(Ink.SUMI, 0.3))
		Ink.text(self, f, Vector2(250, y + 28), u[2], 24, Ink.SUMI)
		Ink.text(self, f, Vector2(250, y + 54), u[3], 17, Ink.a(Ink.SUMI, 0.7))
		for k in range(MAXLV):
			var c = Vector2(820 + k * 44, y + 28)
			if k < lv:
				draw_circle(c, 14, Ink.SHU)
			draw_arc(c, 14, 0, TAU, 24, Ink.SUMI, 2.0, true)
	draw_btns()
