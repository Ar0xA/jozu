extends "res://scripts/screen_base.gd"
# Settings: sound, music, motion, a danger mark that does not rely on colour, the paint filter,
# taking steps back, and the look (Shodō or ornate).

const ROWS = [
	["sound", "音", "Sound", "Everything you hear."],
	["music", "曲", "Music", "The koto, shamisen and flute. Brush and bell sounds stay on."],
	["motion", "動", "Motion", "Yokai move one after another; the board shakes when you are struck."],
	["pattern", "印", "Mark danger with a cross", "A black cross on the red tiles, if red is hard to tell from the paper."],
	["filter", "紙", "Painted look", "Ink-bleed and paper grain. Off: sharper, and easier on an old phone."],
	["undo", "戻", "Taking strokes back", "Within the stroke in hand, until the brush is lifted; or never, as on the pilgrimage."],
	["style", "書", "Style", "Shodō: bare paper, one seal, a stroke that runs dry. Ornate: clouds, seasons, seals, frames."],
]
const STYLE = ["Shodō", "Ornate"]
const UNDO = ["", "This stroke", "Never"]
var back = Callable()
var rows = {}

func setup():
	still = true
	for i in range(ROWS.size()):
		rows[ROWS[i][0]] = btn(Rect2(910, _y(i) - 8, 260, 56) if main.touch else Rect2(900, _y(i), 260, 50), "", _flip.bind(ROWS[i][0]), ROWS[i][1])
	btn(Rect2(40, 646, 260, 64) if main.touch else Rect2(40, 648, 220, 50), "Back", back, "戻")
	_labels()

func _y(i):
	return (76 + i * 80) if main.touch else (104 + i * 76)

func _on(k):
	return main.data.sound if k == "sound" else main.data.opts[k]

func _labels():
	for k in rows:
		if k == "undo":
			rows[k].label = UNDO[int(main.data.opts.undo)]
			rows[k].sel = int(main.data.opts.undo) == 2
			continue
		if k == "style":
			rows[k].label = STYLE[int(main.data.opts.style)]
			rows[k].sel = int(main.data.opts.style) > 0
			continue
		rows[k].label = "On" if _on(k) else "Off"
		rows[k].sel = _on(k)

func _flip(k):
	if k == "sound":
		main.toggle_sound()
	elif k == "undo":
		main.data.opts.undo = 2 if int(main.data.opts.undo) == 1 else 1
		main.write_save()
	elif k == "style":
		main.data.opts.style = (int(main.data.opts.style) + 1) % 2
		main.write_save()
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
		var r = Rect2(100, y - 14, 1080, 72 if big else 68)
		if main.spare():
			draw_line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), Ink.a(Ink.SUMI, 0.3), 1.5, true)
		else:
			draw_rect(r, Ink.a(Ink.GOFUN, 0.6))
			Ink.frame(self, r, 2.0, Ink.a(Ink.SUMI, 0.6))
		Ink.text(self, f, Vector2(130, y + 14), ROWS[i][2], 27 if big else 24, Ink.SUMI)
		Ink.text(self, f, Vector2(130, y + (42 if big else 38)), ROWS[i][3], 19 if big else 15, Ink.a(Ink.SUMI, 0.7))
	draw_btns()
