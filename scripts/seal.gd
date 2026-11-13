extends "res://scripts/screen_base.gd"
# 落款 The seal. A calligrapher signs a finished piece with an art name (雅号, gagō) and presses it
# in vermilion. Suzu begins under her master's seal, 筆剣; here she chooses one or two characters of
# her own, and from then on every piece she finishes carries them.

# the characters an art name is made from, with what each means
const KANJI = [
	["雪", "snow"], ["月", "moon"], ["花", "flower"], ["風", "wind"], ["山", "mountain"], ["水", "water"], ["雲", "cloud"], ["石", "stone"],
	["竹", "bamboo"], ["松", "pine"], ["梅", "plum"], ["桜", "cherry"], ["蓮", "lotus"], ["菊", "chrysanthemum"], ["楓", "maple"], ["柳", "willow"],
	["鶴", "crane"], ["亀", "tortoise"], ["龍", "dragon"], ["虎", "tiger"], ["狐", "fox"], ["鈴", "bell"], ["墨", "ink"], ["筆", "brush"],
	["硯", "inkstone"], ["紙", "paper"], ["心", "heart"], ["道", "the way"], ["静", "stillness"], ["空", "sky"], ["海", "sea"], ["川", "river"],
	["泉", "spring"], ["露", "dew"], ["霞", "mist"], ["星", "star"], ["光", "light"], ["夢", "dream"], ["玉", "jewel"], ["白", "white"],
	["青", "blue"], ["紅", "crimson"], ["翠", "green"], ["舟", "boat"], ["庵", "hermitage"], ["斎", "study"], ["堂", "hall"], ["軒", "eaves"],
]
const COLS = 8
const CELL = Vector2(90, 84)
const ORG = Vector2(56, 104)

var back = Callable()
var name_now = ""      # the one or two characters chosen so far
var b_take

func setup():
	still = true
	name_now = main.data.gago
	b_take = btn(Rect2(840, 452, 400, 66), "Take this name", _take, "印")
	btn(Rect2(840, 532, 400, 60), "Begin again", _clear, "消")
	btn(Rect2(840, 632, 400, 66), "Back", _leave, "道")
	_sync()

func _sync():
	b_take.on = name_now != "" and name_now != main.data.gago
	b_take.label = "Taken" if (name_now != "" and name_now == main.data.gago) else "Take this name"

func _take():
	main.data.gago = name_now
	main.write_save()
	main.sfx("ki")
	_sync()

func _clear():
	name_now = ""
	_sync()

func _leave():
	back.call()

func _cell(i):
	return Rect2(ORG + Vector2((i % COLS) * CELL.x, (i / COLS) * CELL.y), CELL - Vector2(6, 6))

func on_click(pos, button):
	if button != MOUSE_BUTTON_LEFT:
		return
	for i in range(KANJI.size()):
		if _cell(i).has_point(pos):
			var k = KANJI[i][0]
			if name_now.contains(k):
				name_now = name_now.replace(k, "")
			elif name_now.length() < 2:
				name_now += k
			else:
				name_now = name_now[1] + k   # a third pushes the first out
			main.sfx("click")
			_sync()
			return

func on_key(code):
	if code == KEY_ESCAPE:
		_leave()

# Upright: the seal and what it is, the characters to choose from, and the buttons.
func tall_parts(_h):
	if not main.touch:
		return super.tall_parts(_h)
	return [{"src": [Rect2(30, 0, 520, 92)], "s": 1.15}, {"src": [Rect2(820, 96, 440, 340)], "s": 1.1},
		{"src": [Rect2(50, 98, 730, 510)], "s": 0.96}, {"src": [Rect2(830, 446, 420, 256)], "s": 1.1}]

func _draw():
	var f = main.font
	backdrop(0.4)
	Ink.tategaki(self, f, Vector2(64, 4), "印", 46, Ink.SUMI)
	Ink.text(self, f, Vector2(110, 46), "Your Seal", 32, Ink.SUMI)
	Ink.text(self, f, Vector2(110, 78), "雅号  an art name of one or two characters", 20 if main.touch else 16, Ink.a(Ink.SUMI, 0.7))
	for i in range(KANJI.size()):
		var r = _cell(i)
		var on = name_now.contains(KANJI[i][0])
		if on:
			Ink.blot(self, r.get_center() - Vector2(0, 8), 40, 36, Ink.SHU, 0.28)
		Ink.text(self, f, Vector2(r.position.x, r.position.y + 46), KANJI[i][0], 42, Ink.SHU if on else Ink.SUMI, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		Ink.text(self, f, Vector2(r.position.x - 6, r.position.y + 70), KANJI[i][1], 15 if main.touch else 13, Ink.a(Ink.SUMI, 0.65), HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 12)
	# the seal as it will be pressed
	var shown = name_now if name_now != "" else main.my_seal()
	Ink.seal(self, f, Vector2(920, 220), 64, shown)
	var says = "This is your master's seal, 筆剣, brush and sword. Choose a name and your own takes its place."
	if name_now != "":
		var words = []
		for ch in name_now:
			for k in KANJI:
				if k[0] == ch:
					words.append(k[1])
		says = "%s: %s. It is pressed on every piece you finish, on your scroll and on the day's card." % [name_now, " and ".join(words)]
	Ink.para(self, f, Vector2(1010, 150), says, 21 if main.touch else 18, Ink.a(Ink.SUMI, 0.85), 240)
	draw_btns()
