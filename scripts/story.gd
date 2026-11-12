extends "res://scripts/screen_base.gd"
# Dialogue, one panel at a time, beneath the Night Parade scroll itself.

const WHO = {
	"Suzu": "鈴", "Tessai": "鉄斎", "Ibaraki": "茨木童子", "Sōjōbō": "僧正坊",
	"Kuzunoha": "葛の葉", "Gennō": "源翁", "Tamamo": "玉藻前", "Tsuna": "渡辺綱", "Shuten": "酒呑童子",
	"Yuki-onna": "雪女", "Kappa": "河童", "Gashadokuro": "餓者髑髏",
}
const BAND = Rect2(40, 64, 1200, 330)   # on a phone the text box rises a little over its foot

var lines = []
var after
var where = 0.0
var at = 0
var shown = 0.0

func setup():
	btn(Rect2(1060, 4, 180, 52) if main.touch else Rect2(1100, 12, 140, 40), "Skip  [Esc]", _finish)

func tick(dt):
	shown += dt * 60.0

func _finish():
	after.call()

func _next():
	if at >= lines.size():
		return
	if int(shown) < lines[at][1].length():
		shown = 99999.0
		return
	at += 1
	shown = 0.0
	if at >= lines.size():
		_finish()

func on_click(_pos, _button):
	_next()

func on_key(code):
	if code == KEY_ESCAPE:
		_finish()
	elif code == KEY_SPACE or code == KEY_ENTER:
		_next()

func _draw():
	if at >= lines.size():
		return
	var f = main.font
	var who = lines[at][0]
	var txt = lines[at][1]
	# the scroll unrolls a little with every line
	var span = main.band_len("hyakki") - BAND.size.x * 400.0 / BAND.size.y
	main.band(self, "hyakki", BAND, where * span + at * 90.0 + time * 6.0)
	draw_rect(Rect2(BAND.position.x, BAND.position.y - 12, BAND.size.x, 12), Ink.AI)
	draw_rect(Rect2(BAND.position.x, BAND.end.y, BAND.size.x, 12), Ink.AI)
	draw_rect(Rect2(BAND.position.x, BAND.position.y - 3, BAND.size.x, 3), Ink.KIN)
	draw_rect(Rect2(BAND.position.x, BAND.end.y, BAND.size.x, 3), Ink.KIN)
	var big = main.touch
	var box = Rect2(70, 420, 1140, 276) if big else Rect2(150, 452, 980, 206)
	var ts = 33 if big else 25
	var tx = box.position.x + 32
	Ink.slip(self, box, 4.0)
	if WHO.has(who):
		if not big:
			Ink.tategaki(self, f, Vector2(96, 452), WHO[who], 36, Ink.SHU)
		Ink.text(self, f, Vector2(tx, box.position.y + 46), who if not big else "%s  %s" % [WHO[who], who], 30 if big else 26, Ink.SHU)
		Ink.para(self, f, Vector2(tx, box.position.y + (92 if big else 88)), txt.substr(0, int(shown)), ts, Ink.SUMI, box.size.x - 64)
	else:
		Ink.para(self, f, Vector2(tx, box.position.y + (56 if big else 58)), txt.substr(0, int(shown)), ts, Ink.a(Ink.SUMI, 0.85), box.size.x - 64)
	if int(shown) >= txt.length() and fmod(time, 1.0) < 0.6:
		var q = box.end - Vector2(40, 28)
		draw_colored_polygon(PackedVector2Array([q, q + Vector2(16, 0), q + Vector2(8, 12)]), Ink.SHU)
	if big:
		Ink.text(self, f, Vector2(box.position.x, box.end.y - 14), "tap to continue", 20, Ink.a(Ink.SUMI, 0.5), HORIZONTAL_ALIGNMENT_RIGHT, box.size.x - 70)
	else:
		Ink.text(self, f, Vector2(150, 694), "click or Space to continue", 15, Ink.a(Ink.SUMI, 0.5))
	draw_btns()
