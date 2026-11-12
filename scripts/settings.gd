extends "res://scripts/screen_base.gd"
# Settings: sound, music, motion, a danger mark that does not rely on colour, and the paint filter.

const ROWS = [
	["sound", "音", "Sound", "Everything you hear."],
	["music", "曲", "Music", "The koto, shamisen and flute. Brush and bell sounds stay on."],
	["motion", "動", "Motion", "Yokai move one after another; the board shakes when you are struck."],
	["pattern", "印", "Mark danger with a cross", "A black cross on the red tiles, if red is hard to tell from the paper."],
	["filter", "紙", "Painted look", "Ink-bleed and paper grain. Off: sharper, and easier on an old phone."],
]
var back = Callable()
var rows = {}

func setup():
	for i in range(ROWS.size()):
		rows[ROWS[i][0]] = btn(Rect2(930, _y(i) + 8, 240, 62) if main.touch else Rect2(900, 150 + i * 92, 260, 50), "", _flip.bind(ROWS[i][0]), ROWS[i][1])
	btn(Rect2(40, 646, 260, 64) if main.touch else Rect2(40, 648, 220, 50), "Back", back, "戻")
	_labels()

func _y(i):
	return (104 + i * 108) if main.touch else (150 + i * 92)

func _on(k):
	return main.data.sound if k == "sound" else main.data.opts[k]

func _labels():
	for k in rows:
		rows[k].label = "On" if _on(k) else "Off"
		rows[k].sel = _on(k)

func _flip(k):
	if k == "sound":
		main.toggle_sound()
	else:
		main.data.opts[k] = not main.data.opts[k]
		main.apply_opts()
		main.write_save()
	_labels()

func on_key(code):
	if code == KEY_ESCAPE:
		back.call()

func _draw():
	var f = main.font
	draw_texture_rect(main.art["tohaku"], Rect2(0, 0, 1280, 720), false, Color(1, 1, 1, 0.4))
	Ink.tategaki(self, f, Vector2(64, 8), "設", 50, Ink.SUMI)
	Ink.text(self, f, Vector2(110, 52), "Settings", 34, Ink.SUMI)
	var big = main.touch
	for i in range(ROWS.size()):
		var y = _y(i)
		var r = Rect2(100, y - 14, 1080, 96 if big else 80)
		draw_rect(r, Ink.a(Ink.GOFUN, 0.6))
		Ink.frame(self, r, 2.0, Ink.a(Ink.SUMI, 0.6))
		Ink.text(self, f, Vector2(130, y + (20 if big else 18)), ROWS[i][2], 30 if big else 26, Ink.SUMI)
		Ink.para(self, f, Vector2(130, y + (48 if big else 42)), ROWS[i][3], 20 if big else 15, Ink.a(Ink.SUMI, 0.7), 780 if big else 740)
	draw_btns()
