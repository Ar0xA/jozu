extends "res://scripts/screen_base.gd"
# 錦絵 A frontispiece. Before the story of a great yokai, the old print that shows it: Yoshitoshi's
# Rashōmon, Kuniyoshi's skeleton, Kyōsai's tengu king. The whole print is shown, with whose hand it
# is from and where it is kept (art/CREDITS.md). A tap goes on.

const AREA = Rect2(40, 16, 1200, 606)

var info = []          # [file name, artist, title in Japanese, title in English, year, where it is kept]
var after = Callable()

func setup():
	still = true

func _pic():
	var tex = main.art.get("print_" + info[0])
	if tex == null:
		return Rect2()
	var sz = tex.get_size()
	var k = min(AREA.size.x / sz.x, AREA.size.y / sz.y)
	return Rect2(AREA.position + (AREA.size - sz * k) * 0.5, sz * k)

func on_click(_pos, _button):
	after.call()

func on_key(_code):
	after.call()

func tall_modal():
	return true

# Upright: the print as large as the phone allows, and its caption under it.
func tall_parts(_h):
	if not main.touch:
		return super.tall_parts(_h)
	var r = _pic()
	if r.size.x <= 0.0:
		return [{"src": [Rect2(40, 626, 1200, 90)], "s": 0.6}]
	return [{"src": [r.grow(4.0)], "s": min(700.0 / (r.size.x + 8.0), 1150.0 / (r.size.y + 8.0))}, {"src": [Rect2(340, 630, 600, 86)], "s": 1.15}]

func _draw():
	var f = main.font
	var r = _pic()
	if r.size.x > 0.0:
		draw_rect(r.grow(4.0), Ink.a(Ink.SUMI, 0.85))
		draw_texture_rect(main.art["print_" + info[0]], r, false)
	var big = main.touch
	var up = main.tall and main.touch
	# the caption: centred under the print (upright it is cut out, so it is set narrow)
	var cx = 340.0 if up else 140.0
	var cw = 600.0 if up else 1000.0
	Ink.text(self, f, Vector2(cx, 654), "%s  %s" % [info[2], info[1]] if info[2] != "" else info[1], 22 if big else 19, Ink.SUMI, HORIZONTAL_ALIGNMENT_CENTER, cw)
	Ink.text(self, f, Vector2(cx, 680), "%s, %s" % [info[3], info[4]], 17 if big else 15, Ink.a(Ink.SUMI, 0.8), HORIZONTAL_ALIGNMENT_CENTER, cw)
	Ink.text(self, f, Vector2(cx, 704), info[5] + (" · tap to go on" if big else " · any key or click"), 15 if big else 13, Ink.a(Ink.SUMI, 0.55), HORIZONTAL_ALIGNMENT_CENTER, cw)
