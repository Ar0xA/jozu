extends Control
# The day's kōan as a square of paper to pass on: the stroke that answered it with the board
# taken away, the day as the almanac names it, and how many attempts it took.

const Ink = preload("res://scripts/ink.gd")
const Koyomi = preload("res://scripts/koyomi.gd")
const SIDE = 1080

var font
var day_name = ""
var koyomi = []       # [sekki, its reading, kō in kanji, kō in English, season]
var paths = []        # the strokes, as lists of tiles
var cols = 7
var rows = 7
var tries = 1
var streak = 0
var seal = "筆剣"     # the painter's seal

func _draw():
	draw_rect(Rect2(0, 0, SIDE, SIDE), Ink.PAPER)
	draw_rect(Rect2(34, 34, SIDE - 68, SIDE - 68), Ink.a(Ink.SUMI, 0.55), false, 3.0)
	# the stroke, large, a little left of centre
	Ink.calligraphy(self, Rect2(90, 150, 700, 700), paths, cols, rows)
	# the name of the game down the right edge, and its seal
	Ink.tategaki(self, font, Vector2(930, 90), "上手", 150, Ink.SUMI)
	Ink.seal(self, font, Vector2(930, 520), 54, seal)
	# the day
	var tint = Koyomi.TINT[koyomi[4]]
	Ink.text(self, font, Vector2(90, 118), "%s  %s" % [koyomi[0], koyomi[2]], 52, tint)
	Ink.text(self, font, Vector2(90, 912), "%s · %s" % [koyomi[1], koyomi[3]], 34, Ink.a(Ink.SUMI, 0.8))
	var how = "answered at the first stroke" if tries <= 1 else "answered on attempt %d" % tries
	if streak > 1:
		how += " · %d days running" % streak
	Ink.text(self, font, Vector2(90, 962), "Daily kōan %s · %s" % [day_name, how], 30, Ink.SUMI)
	Ink.text(self, font, Vector2(90, 1010), "Jōzu 上手 · ar0xa.github.io/jozu", 24, Ink.a(Ink.SUMI, 0.6))
