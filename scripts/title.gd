extends "res://scripts/screen_base.gd"
# Title, set on Hasegawa Tohaku's Pine Trees.

const Koyomi = preload("res://scripts/koyomi.gd")
var b_new
var koyomi = []        # today in the almanac of seventy-two seasons
var armed = false
var armed_at = 0.0

func setup():
	koyomi = Koyomi.today()
	main.play_ambience(koyomi[4])
	var has = not main.data.cleared.is_empty()
	btn(Rect2(940, 444, 290, 58), "Continue the road" if has else "Take up the brush", main.show_map, "旅")
	b_new = btn(Rect2(940, 516, 290, 50), "Begin anew", _anew, "新")
	b_new.show = has
	btn(Rect2(940, 588, 290, 44), "Settings", main.show_settings, "設")
	if OS.has_feature("web"):  # a browser tab is closed by the browser; offer the whole screen instead
		btn(Rect2(940, 646, 290, 44), "Full screen", main.toggle_fullscreen, "全")
	else:
		btn(Rect2(940, 646, 290, 44), "Leave", func(): get_tree().quit(), "去")
	if main.touch:
		_grow()

# Upright: the name, then the day and the words, then the buttons, over the pines.
func tall_parts(_h):
	if not main.touch:
		return super.tall_parts(_h)
	return [{"src": [Rect2(990, 20, 262, 392)], "s": 1.25}, {"src": [Rect2(50, 478, 644, 240)], "s": 1.08}, {"src": [Rect2(890, 412, 362, 304)], "s": 1.45}]

# a phone's thumbs want taller buttons
func _grow():
	var y = 420.0
	for b in btns:
		if b.show:
			b.rect = Rect2(900, y, 340, 64)
			y += 72.0

func _anew():
	if not armed:
		armed = true
		armed_at = time
		b_new.label = "Erase all seals? Again"
		return
	if time - armed_at < 0.7:
		return   # the second press of a double-click is not an answer
	main.erase_save()
	main.show_title()

func tick(_dt):
	if not main.ambient.playing:
		main.play_ambience(koyomi[4])   # in a browser the season's sound arrives a little after the title
	if main.newer and time > 1.5:
		main._take_newer()   # a newer build is waiting: the page reloads into it

func on_key(code):
	if code == KEY_ENTER or code == KEY_SPACE:
		main.show_map()

func _draw():
	var f = main.font
	backdrop(1.0)
	Ink.sun(self, Vector2(150, 150), 62)
	if main.data.opts.motion:
		Ink.season(self, Ink.season_now(), time, 30)
	# title, written top to bottom in the empty panel
	# the name is written out, stroke by stroke, and then settles into the cut of the typeface
	var t = time - 0.5
	var done = 1.0 if (not main.data.opts.motion or t > 4.4) else Ink.title_strokes(self, Vector2(1140, 30), 180, Ink.a(Ink.SUMI, clamp(1.0 - (t - 3.5) / 0.8, 0.0, 1.0)), t)
	var settle = 1.0 if not main.data.opts.motion else clamp((t - 3.4) / 0.8, 0.0, 1.0)
	if done >= 1.0 and settle > 0.0:
		Ink.tategaki(self, f, Vector2(1140, 30), "上手", 180, Ink.a(Ink.SUMI, settle))
	Ink.stamp(self, f, Vector2(1012, 360), 34, "筆剣", 1.0 if not main.data.opts.motion else (t - 4.0) / 0.3)
	Ink.blot(self, Vector2(420, 630), 560, 140, Color(0.93, 0.89, 0.79), 0.95)
	if main.install_tip():
		Ink.text(self, f, Vector2(64, 496), "Add this page to your home screen and it opens without a network.", 16, Ink.a(Ink.SUMI, 0.6))
	# the day, as the old almanac names it
	Ink.text(self, f, Vector2(64, 534), "%s  %s" % [koyomi[0], koyomi[2]], 24, Koyomi.TINT[koyomi[4]])
	Ink.text(self, f, Vector2(64 + f.get_string_size("%s  %s" % [koyomi[0], koyomi[2]], HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 16.0, 532), "%s · %s" % [koyomi[1], koyomi[3]], 17, Ink.a(Ink.SUMI, 0.7))
	Ink.text(self, f, Vector2(60, 592), "J Ō Z U", 52, Ink.SUMI)
	Ink.text(self, f, Vector2(64, 628), "the upper hand", 24, Ink.a(Ink.SUMI, 0.8))
	if main.tall and main.touch:
		Ink.para(self, f, Vector2(64, 668), "A puzzle of single strokes. No dice, no luck — only the measure of distance.", 19, Ink.a(Ink.SUMI, 0.75), 600)
	else:
		Ink.text(self, f, Vector2(64, 668), "A puzzle of single strokes. No dice, no luck — only the measure of distance.", 19, Ink.a(Ink.SUMI, 0.75))
	if not main.data.cleared.is_empty():
		var rk = main.rank()
		Ink.text(self, f, Vector2(420, 594), "%s  %s" % [rk[0], rk[1]], 26, Ink.SHU)
	if not (main.tall and main.touch):
		Ink.text(self, f, Vector2(64, 700), "Paintings: Hasegawa Tōhaku · Sesshū Tōyō · Hyakki Yagyō Emaki", 14, Ink.a(Ink.SUMI, 0.5))
	draw_btns()
