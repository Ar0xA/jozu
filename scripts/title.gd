extends "res://scripts/screen_base.gd"
# Title, set on Hasegawa Tohaku's Pine Trees.

var b_new
var b_snd
var armed = false

func setup():
	var has = not main.data.cleared.is_empty()
	btn(Rect2(940, 444, 290, 58), "Continue the road" if has else "Take up the brush", main.show_map, "旅")
	b_new = btn(Rect2(940, 516, 290, 50), "Begin anew", _anew, "新")
	b_new.show = has
	b_snd = btn(Rect2(940, 588, 290, 44), "", _sound, "音")
	_sound_label()
	if not OS.has_feature("web"):  # a browser tab is closed by the browser
		btn(Rect2(940, 646, 290, 44), "Leave", func(): get_tree().quit(), "去")

func _sound():
	main.toggle_sound()
	_sound_label()

func _sound_label():
	b_snd.label = "Sound: on  [M]" if main.data.sound else "Sound: off  [M]"

func _anew():
	if not armed:
		armed = true
		b_new.label = "Erase all seals? Again"
		return
	main.erase_save()
	main.show_title()

func on_key(code):
	if code == KEY_ENTER or code == KEY_SPACE:
		main.show_map()

func _draw():
	var f = main.font
	draw_texture_rect(main.art["tohaku"], Rect2(0, 0, 1280, 720), false)
	Ink.sun(self, Vector2(150, 150), 62)
	# title, written top to bottom in the empty panel
	Ink.tategaki(self, f, Vector2(1140, 30), "上手", 180, Ink.SUMI)
	Ink.seal(self, f, Vector2(1012, 360), 34, "筆剣")
	Ink.blot(self, Vector2(420, 640), 560, 120, Color(0.93, 0.89, 0.79), 0.95)
	Ink.text(self, f, Vector2(60, 592), "J Ō Z U", 52, Ink.SUMI)
	Ink.text(self, f, Vector2(64, 628), "the upper hand", 24, Ink.a(Ink.SUMI, 0.8))
	Ink.text(self, f, Vector2(64, 668), "A puzzle of single strokes. No dice, no luck — only the measure of distance.", 19, Ink.a(Ink.SUMI, 0.75))
	if not main.data.cleared.is_empty():
		var rk = main.rank()
		Ink.text(self, f, Vector2(420, 594), "%s  %s" % [rk[0], rk[1]], 26, Ink.SHU)
	Ink.text(self, f, Vector2(64, 700), "Paintings: Hasegawa Tōhaku · Sesshū Tōyō · Hyakki Yagyō Emaki", 14, Ink.a(Ink.SUMI, 0.5))
	draw_btns()
