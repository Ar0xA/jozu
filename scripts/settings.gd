extends "res://scripts/screen_base.gd"
# Settings: sound, music, motion, a danger mark that does not rely on colour, and the paint filter.

const ROWS = [
	["sound", "音", "Sound", "Everything you hear. The M key does the same anywhere."],
	["music", "曲", "Music", "The koto, shamisen and flute. Brush and bell sounds stay on."],
	["motion", "動", "Motion", "Yokai move one after another and the board shakes when you are struck. Off: all at once, no shake."],
	["pattern", "印", "Mark danger with a cross", "Adds a black cross to the red tiles, for anyone who finds red hard to tell from the paper."],
	["filter", "紙", "Painted look", "Ink-bleed and paper grain over the whole screen. Off: sharper, plainer, and easier on an old phone."],
]
var back = Callable()
var rows = {}

func setup():
	for i in range(ROWS.size()):
		rows[ROWS[i][0]] = btn(Rect2(900, 150 + i * 92, 260, 50), "", _flip.bind(ROWS[i][0]), ROWS[i][1])
	btn(Rect2(40, 648, 220, 50), "Back", back, "戻")
	_labels()

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
	for i in range(ROWS.size()):
		var y = 150 + i * 92
		var r = Rect2(100, y - 14, 1080, 80)
		draw_rect(r, Ink.a(Ink.GOFUN, 0.6))
		Ink.frame(self, r, 2.0, Ink.a(Ink.SUMI, 0.6))
		Ink.text(self, f, Vector2(130, y + 18), ROWS[i][2], 26, Ink.SUMI)
		Ink.para(self, f, Vector2(130, y + 42), ROWS[i][3], 15, Ink.a(Ink.SUMI, 0.7), 740)
	draw_btns()
