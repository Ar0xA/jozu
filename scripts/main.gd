extends Control
# Root: paints the paper, owns the save file, swaps screens.

const Ink = preload("res://scripts/ink.gd")
const Data = preload("res://scripts/data.gd")
const Extra = preload("res://scripts/extra.gd")
var save_path = "user://jozu_save.json"

var font
var data = {}
var cur = null
var fibers = []
var art = {}
var touch = false   # a phone or tablet: no hover, no right-click, fingers not pointers
var turn_note
var paint_rect
var music
var music_name = ""
var sfx_pool = []
var sfx_i = 0
var streams = {}
const MUSIC_DB = {"title": -9.0, "story": -5.0, "battle": -10.0, "boss": -9.0}

func _ready():
	var sysf = SystemFont.new()
	sysf.font_names = PackedStringArray(["Yu Mincho", "YuMincho", "MS Mincho", "Hiragino Mincho ProN", "Noto Serif CJK JP", "Noto Serif JP", "Yu Gothic", "serif"])
	font = sysf
	# Yuji Syuku: a typeface cut from brush-written kana and kanji (SIL OFL, see fonts/OFL.txt)
	var ff = load("res://fonts/YujiSyuku-Regular.ttf")
	if ff:
		ff.fallbacks = [sysf]
		font = ff
	touch = DisplayServer.is_touchscreen_available()
	# everything on screen passes through the paint shader
	var layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var cr = ColorRect.new()
	cr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/paint.gdshader")
	cr.material = mat
	layer.add_child(cr)
	paint_rect = cr
	# a phone held upright shows the game too small to play: ask for it to be turned
	var top = CanvasLayer.new()
	top.layer = 20
	add_child(top)
	turn_note = ColorRect.new()
	turn_note.color = Ink.PAPER
	turn_note.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	turn_note.visible = false
	var lb = Label.new()
	lb.text = "横向きに
Turn your phone sideways"
	lb.add_theme_font_override("font", font)
	lb.add_theme_font_size_override("font_size", 84)
	lb.add_theme_color_override("font_color", Ink.SUMI)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	turn_note.add_child(lb)
	top.add_child(turn_note)
	var rng = RandomNumberGenerator.new()
	rng.seed = 1185
	for i in range(420):
		var p = Vector2(rng.randf() * 1280, rng.randf() * 720)
		var ang = rng.randf() * TAU
		fibers.append([p, p + Vector2(cos(ang), sin(ang)) * rng.randf_range(6, 34), rng.randf_range(0.04, 0.13)])
	art["tohaku"] = load("res://art/tohaku.jpg")
	for nm in ["sesshu", "hyakki"]:
		art[nm] = [load("res://art/%s_0.jpg" % nm), load("res://art/%s_1.jpg" % nm)]
	for nm in ["hero", "oni", "oni3", "tengu", "kitsune", "yurei", "tamamo", "chochin", "kasa", "kappa", "nurikabe", "yukionna", "gasha", "daruma", "tanuki", "shinigami", "kamaitachi"]:
		var t = load("res://art/pieces/%s.png" % nm)
		if t:
			var img = t.get_image()
			img.generate_mipmaps()
			art["p_" + nm] = ImageTexture.create_from_image(img)
	load_save()
	_setup_audio()
	show_title()

# ---------------------------------------------------------------- sound

func _setup_audio():
	var rv = AudioEffectReverb.new()
	rv.room_size = 0.55
	rv.wet = 0.16
	rv.dry = 0.9
	AudioServer.add_bus_effect(0, rv)
	music = AudioStreamPlayer.new()
	add_child(music)
	music.finished.connect(func(): if data.opts.music: music.play())
	for i in range(6):
		var p = AudioStreamPlayer.new()
		add_child(p)
		sfx_pool.append(p)
	for nm in ["title", "battle", "boss", "step", "cut", "kill", "hit", "ward", "leap", "katsu", "sheathe", "click", "win", "lose", "bell", "eat", "splash", "web", "kama", "ink"]:
		streams[nm] = load("res://audio/%s.wav" % nm)
	streams["story"] = load("res://audio/story.ogg")
	AudioServer.set_bus_mute(0, not data.sound)
	apply_opts()

func play_music(nm):
	if nm == music_name:
		return
	music_name = nm
	music.stop()
	music.stream = streams.get(nm)
	music.volume_db = MUSIC_DB.get(nm, -9.0)
	if music.stream and data.opts.music:
		music.play()

# the settings a player can change (scripts/settings.gd)
const OPTS = {"music": true, "motion": true, "pattern": false, "filter": true}

func apply_opts():
	paint_rect.visible = data.opts.filter
	if not data.opts.music:
		music.stop()
	elif music.stream and not music.playing:
		music.play()

func show_settings(back = Callable()):
	play_music("title")
	var scr = load("res://scripts/settings.gd").new()
	scr.back = back if back.is_valid() else show_title
	go(scr)

func sfx(nm):
	var st = streams.get(nm)
	if st == null:
		return
	var p = sfx_pool[sfx_i % sfx_pool.size()]
	sfx_i += 1
	p.stream = st
	p.volume_db = -7.0
	p.play()

func toggle_sound():
	data.sound = not data.sound
	AudioServer.set_bus_mute(0, not data.sound)
	write_save()

func _process(_dt):
	var ws = get_window().size
	turn_note.visible = ws.y > ws.x * 1.1

func toggle_fullscreen():
	var full = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _unhandled_input(ev):
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_M:
			toggle_sound()
		elif ev.keycode == KEY_F11:
			toggle_fullscreen()

# A board piece: a figure lifted from an old painting (see art/CREDITS.md).
# On the board it stands on its tile and may rise above it; flat = centred, for the legend.
const PIECE_SCALE = {"hero": 1.3, "oni": 1.3, "oni3": 1.25, "tengu": 1.3, "kitsune": 1.12, "yurei": 1.2, "tamamo": 1.3, "chochin": 0.95,
	"kasa": 1.25, "kappa": 1.0, "nurikabe": 1.1, "yukionna": 1.3, "gasha": 1.15,
	"daruma": 1.05, "tanuki": 1.05, "shinigami": 1.25, "kamaitachi": 1.3}

func piece(ci, kind, c, s, t = 0.0, big = false, flat = false, grow = 1.0, mod = Color.WHITE):
	var key = kind
	if kind == "hitodama":
		Ink.hitodama(ci, c, s, t)
		return
	if kind == "shinigami" and not art.has("p_shinigami"):
		# without its painting, the death god is a black seal with one character
		ci.draw_circle(c, s * 0.40, Ink.a(Ink.SUMI, 0.92 * mod.a))
		Ink.enso(ci, c, s * 0.44, s * 0.05, Ink.a(Ink.SHU, mod.a))
		Ink.text(ci, font, Vector2(c.x - s * 0.5, c.y + s * 0.17), "死", s * 0.46, Ink.GOFUN if mod.r > 0.5 else Ink.SUMI, HORIZONTAL_ALIGNMENT_CENTER, s)
		return
	if kind == "oni" and big:
		key = "oni3"
	var k = 1.0 if flat else PIECE_SCALE.get(key, 1.0) * grow
	var off = Vector2.ZERO
	if kind == "tengu" and big:
		Ink.enso(ci, c, s * 0.46, s * 0.07, Ink.a(Ink.KIN, 0.9))
	elif kind == "chochin":
		Ink.blot(ci, c, s * 0.5, s * 0.5, Color(0.95, 0.55, 0.15), 0.5)
		off = Vector2(0, sin(t * 2.0) * s * 0.02)
	elif kind == "yurei":
		off = Vector2(sin(t * 1.4) * s * 0.03, cos(t * 1.9) * s * 0.02)
	elif kind == "tamamo":
		Ink.blot(ci, c, s * 0.6, s * 0.6, Ink.KIN, 0.45)
	elif kind == "shinigami":
		Ink.blot(ci, c, s * 0.62, s * 0.62, Ink.SUMI, 0.5 * mod.a)   # it brings its own dark
		off = Vector2(sin(t * 1.1) * s * 0.03, cos(t * 1.5) * s * 0.03)
	if not art.has("p_" + key):
		# no painting for this one: a brushed ring and its name
		ci.draw_circle(c, s * 0.36, Ink.PAPER)
		Ink.enso(ci, c, s * 0.38, s * 0.06, Ink.SUMI)
		var kj = Data.LEGEND.get(kind, ["?"])[0].substr(0, 1)
		Ink.text(ci, font, Vector2(c.x - s * 0.5, c.y + s * 0.16), kj, s * 0.42, Ink.SUMI, HORIZONTAL_ALIGNMENT_CENTER, s)
		return
	var sz = Vector2(s, s) * k
	var pos = c + off - sz * 0.5
	if not flat and kind != "chochin" and kind != "kappa" and kind != "shinigami" and kind != "kamaitachi":
		pos.y = c.y + s * 0.47 - sz.y
	ci.draw_texture_rect(art["p_" + key], Rect2(pos, sz), false, mod)

# Draws a window onto one of the long handscrolls, x pixels along it.
func band(ci, nm, dest, x):
	var texs = art[nm]
	var h = float(texs[0].get_height())
	var k = dest.size.y / h
	var ww = dest.size.x / k
	x = clamp(x, 0.0, band_len(nm) - ww)
	var off = 0.0
	for t in texs:
		var w = float(t.get_width())
		var a0 = max(x, off)
		var a1 = min(x + ww, off + w)
		if a1 > a0:
			ci.draw_texture_rect_region(t, Rect2(dest.position.x + (a0 - x) * k, dest.position.y, (a1 - a0) * k, dest.size.y), Rect2(a0 - off, 0, a1 - a0, h))
		off += w

func band_len(nm):
	var n = 0.0
	for t in art[nm]:
		n += t.get_width()
	return n

func _draw():
	draw_rect(Rect2(0, 0, 1280, 720), Ink.PAPER)
	for i in range(fibers.size()):
		var f = fibers[i]
		draw_line(f[0], f[1], Ink.a(Ink.PAPER_D if i % 3 else Ink.GOFUN, f[2] * 4.0), 1.0, true)
	# age at the edges of the sheet
	for i in range(14):
		var al = 0.022 * (14 - i) / 14.0
		draw_rect(Rect2(i * 5, i * 5, 1280 - i * 10, 720 - i * 10), Color(0.35, 0.24, 0.10, al), false, 5.0)

# ---------------------------------------------------------------- save

func fresh():
	return {"cleared": {}, "scroll": {}, "seals": {}, "daily": {"day": -1, "last": -1, "streak": 0, "best": 0},
		"henro": {"at": 0, "staffs": 3, "best": 0, "done": 0}, "mine": "", "sound": true, "opts": OPTS.duplicate(), "days": {}, "tries": {}, "rand": {}, "up": {"ink": 0, "ki": 0, "leap": 0, "ward": 0, "katsu": 0}}

func load_save():
	data = fresh()
	if FileAccess.file_exists(save_path):
		var txt = FileAccess.get_file_as_string(save_path)
		var j = JSON.parse_string(txt)
		if typeof(j) == TYPE_DICTIONARY and j.has("cleared") and j.has("up"):
			if j.has("sound"):
				data.sound = bool(j.sound)
			if j.has("scroll") and typeof(j.scroll) == TYPE_DICTIONARY:
				data.scroll = j.scroll
			for grp in ["daily", "henro"]:
				if j.has(grp) and typeof(j[grp]) == TYPE_DICTIONARY:
					for k in data[grp]:
						if j[grp].has(k):
							data[grp][k] = int(j[grp][k])
			if j.has("mine"):
				data.mine = str(j.mine)
			if j.has("opts") and typeof(j.opts) == TYPE_DICTIONARY:
				for k in data.opts:
					if j.opts.has(k):
						data.opts[k] = bool(j.opts[k])
			for grp in ["days", "tries", "rand"]:
				if j.has(grp) and typeof(j[grp]) == TYPE_DICTIONARY:
					for k in j[grp]:
						data[grp][k] = int(j[grp][k])
			if j.has("seals") and typeof(j.seals) == TYPE_DICTIONARY:
				for k in j.seals:
					data.seals[k] = int(j.seals[k])
			for k in j.cleared:
				data.cleared[k] = str(j.cleared[k])
			for k in data.up:
				if j.up.has(k):
					data.up[k] = int(j.up[k])

func write_save():
	var f = FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

func erase_save():
	var snd = data.get("sound", true)
	var opts = data.get("opts", OPTS.duplicate())
	data = fresh()
	data.sound = snd
	data.opts = opts
	write_save()

func grade_of(i):
	return data.cleared.get(str(i), "")

func unlocked(i):
	return i == 0 or grade_of(i - 1) != ""

func record(i, grade, paths = null, seal_mask = 0):
	var better = grade_of(i) != "jouzu"
	if better:
		data.cleared[str(i)] = grade
	data.seals[str(i)] = int(data.seals.get(str(i), 0)) | seal_mask
	# keep the strokes of the best clear for the scroll gallery
	if paths != null and (better or not data.scroll.has(str(i))):
		var out = []
		for path in paths:
			var line = []
			for v in path:
				line.append([v.x, v.y])
			out.append(line)
		data.scroll[str(i)] = out
	write_save()

func up_cost(key):
	return 2 + int(data.up[key])

# Three seals can be won on every stage:
#   1  上手 jozu      within the mastery stroke count, unharmed
#   2  潔   isagiyoshi  mastery with no stroke taken back
#   4  惜墨 sekiboku    unharmed, spending no more ink than the master's line
const SEALS = [[1, "上手", "mastery"], [2, "潔", "no stroke taken back"], [4, "惜墨", "sparing of ink"]]
const RANKS = [
	["十級", "10th kyū"], ["九級", "9th kyū"], ["八級", "8th kyū"], ["七級", "7th kyū"], ["六級", "6th kyū"],
	["五級", "5th kyū"], ["四級", "4th kyū"], ["三級", "3rd kyū"], ["二級", "2nd kyū"], ["一級", "1st kyū"],
	["初段", "shodan"], ["二段", "2nd dan"], ["三段", "3rd dan"], ["四段", "4th dan"], ["五段", "5th dan"],
	["六段", "6th dan"], ["七段", "7th dan"], ["八段", "8th dan"], ["九段", "9th dan"], ["名人", "meijin"],
]

func seals_of(i):
	return int(data.seals.get(str(i), 0))

func seal_count():
	var n = 0
	for k in data.seals:
		for sl in SEALS:
			if int(data.seals[k]) & sl[0]:
				n += 1
	return n

# kyu and dan, as in go, shogi and the martial arts: earned by seals, not by clearing
func rank():
	var total = 3 * Data.LEVELS.size()
	var n = seal_count()
	if n >= total:
		return RANKS[RANKS.size() - 1]
	return RANKS[min(RANKS.size() - 2, int(float(n) / total * (RANKS.size() - 1)))]

func points_total():
	return data.cleared.size() + seal_count()

func points_spent():
	var n = 0
	for k in data.up:
		for lv in range(int(data.up[k])):
			n += 2 + lv
	return n

func points():
	return points_total() - points_spent()

func stats_for(i):
	var st = Data.base_stats(Data.LEVELS[i])
	var rl = Data.LEVELS[i].get("rules", [])
	if not (rl.has("koan") or rl.has("garden")):
		st.ink += int(data.up.ink)  # a koan is answered with the brush it was set for
	st.ki += int(data.up.ki)
	for k in ["leap", "ward", "katsu"]:
		if st[k] > 0:
			st[k] += int(data.up[k])
	return st

# ---------------------------------------------------------------- screens

func go(scr):
	if cur:
		cur.queue_free()
	cur = scr
	scr.main = self
	add_child(scr)

func show_title():
	play_music("title")
	go(load("res://scripts/title.gd").new())

func show_map():
	play_music("title")
	go(load("res://scripts/map.gd").new())

func show_hub():
	play_music("title")
	go(load("res://scripts/hub.gd").new())

func show_custom(lv, kind, label, on_win, on_fail, back):
	play_music("battle")
	var scr = load("res://scripts/battle.gd").new()
	scr.custom = lv
	scr.kind_of = kind
	scr.label = label
	scr.on_win = on_win
	scr.on_fail = on_fail
	scr.back = back
	go(scr)

# ---------------------------------------------------------------- the daily koan
# One single-stroke board a day, the same for everyone: gentle on Monday, hardest on Sunday.

func today():
	return int(Time.get_unix_time_from_system() / 86400.0)

func daily_level(day = -1):
	if day < 0:
		day = today()
	var bank = Extra.DAILY
	var weekday = (day + 3) % 7              # day 0 was a Thursday; 0 = Monday
	var slice = bank.size() / 7
	var lv = bank[weekday * slice + (day / 7) % slice].duplicate(true)
	lv["kanji"] = "日課"
	lv["name"] = day_name(day)
	lv["hint"] = "Today's kōan. One stroke, and only one. It is the same board for everyone today." if day == today() else "The kōan of a day gone by. One stroke, and only one."
	lv["story"] = []
	lv["after"] = []
	lv["say"] = []
	lv["day"] = day
	return lv

func day_name(day):
	var d = Time.get_date_dict_from_unix_time(day * 86400)
	return "%d-%02d-%02d" % [d.year, d.month, d.day]

func daily_done(day = -1):
	return data.days.has(str(today() if day < 0 else day)) or (day < 0 and int(data.daily.day) == today())

func show_daily(day = -1, back = Callable()):
	if day < 0:
		day = today()
	var names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
	show_custom(daily_level(day), "daily", names[(day + 3) % 7] + "'s kōan", _daily_won.bind(day, back), Callable(), back if back.is_valid() else show_hub)

func show_calendar():
	play_music("title")
	go(load("res://scripts/daily.gd").new())

# a failed attempt at a day's koan is counted, so the result line can say how many it took
func daily_fail(day):
	if not data.days.has(str(day)):
		data.tries[str(day)] = int(data.tries.get(str(day), 0)) + 1
		write_save()

func _daily_won(_grade, _mask, _turns, day, back):
	if not data.days.has(str(day)):
		data.days[str(day)] = int(data.tries.get(str(day), 0)) + 1
	var d = data.daily
	if day == today() and int(d.day) != today():
		d.streak = int(d.streak) + 1 if int(d.last) == today() - 1 else 1
		d.last = today()
		d.day = today()
		d.best = max(int(d.best), int(d.streak))
	write_save()
	return back if back.is_valid() else show_hub

# one line to pass on: the day, how many attempts it took, and the run of days
func daily_line(day):
	var n = int(data.days.get(str(day), 0))
	if n <= 0:
		return ""
	var names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
	var how = "at the first stroke" if n == 1 else "on attempt %d" % n
	var line = "Jōzu 上手 · daily kōan %s (%s) · answered %s" % [day_name(day), names[(day + 3) % 7], how]
	if day == today() and int(data.daily.streak) > 1:
		line += " · %d days running" % int(data.daily.streak)
	return line + " · https://ar0xa.github.io/jozu/"

# ---------------------------------------------------------------- the unmapped road
# A board drawn at random from the proven boards the story never used, by how hard it is.

const BRACKETS = [["易", "Gentle"], ["中", "Even"], ["難", "Hard"], ["極", "Master"]]
var last_random = -1

func show_random(br):
	var bank = Extra.RANDOM
	var n = bank.size() / 4
	var lo = br * n
	var hi = bank.size() if br == 3 else lo + n
	var i = lo + randi() % max(1, hi - lo)
	if i == last_random:
		i = lo + (i - lo + 1) % max(1, hi - lo)
	last_random = i
	var lv = bank[i].duplicate(true)
	lv["code"] = board_code(lv)
	lv["kanji"] = "乱"
	lv["name"] = "Off the map: %s" % BRACKETS[br][1].to_lower()
	lv["hint"] = "A board from off the map, number %d of %d. Mastery asks %d stroke%s. Clear it and you can copy its code to pass on." % [i + 1, bank.size(), int(lv.par), "" if int(lv.par) == 1 else "s"]
	lv["story"] = []
	lv["after"] = []
	lv["say"] = []
	show_custom(lv, "random", "The Unmapped Road", _random_won.bind(br), Callable(), show_hub)

func _random_won(grade, _mask, _turns, br):
	var k = str(br)
	data.rand[k] = int(data.rand.get(k, 0)) + 1
	if grade == "jouzu":
		data.rand["m" + k] = int(data.rand.get("m" + k, 0)) + 1
	write_save()
	return show_random.bind(br)

# ---------------------------------------------------------------- the 88 temples
# A pilgrimage of 88 boards with no stroke taken back. Three staffs: a temple lost or given
# up costs one, and a province completed gives one back. With none left, you begin again.

const PROVINCES = [[0, "発心の道場", "Awa, the place of awakening"], [23, "修行の道場", "Tosa, the place of discipline"],
	[39, "菩提の道場", "Iyo, the place of enlightenment"], [65, "涅槃の道場", "Sanuki, the place of nirvana"]]

func province(at):
	var p = PROVINCES[0]
	for q in PROVINCES:
		if at >= q[0]:
			p = q
	return p

func show_henro():
	var h = data.henro
	if int(h.at) >= Extra.HENRO.size():
		h.at = 0
		h.staffs = 3
	var at = int(h.at)
	var lv = Extra.HENRO[at].duplicate(true)
	lv["kanji"] = "第%d番" % (at + 1)
	lv["name"] = province(at)[2]
	lv["hint"] = "Temple %d of 88. No stroke can be taken back here, and there is no master to ask. Staffs left: %d." % [at + 1, int(h.staffs)]
	lv["story"] = []
	lv["after"] = []
	lv["say"] = []
	show_custom(lv, "henro", province(at)[1], _henro_won, _henro_failed, show_hub)

func _henro_won(_grade, _mask, _turns):
	var h = data.henro
	h.at = int(h.at) + 1
	h.best = max(int(h.best), int(h.at))
	for q in PROVINCES:
		if q[0] == int(h.at) and int(h.at) > 0:
			h.staffs = min(3, int(h.staffs) + 1)   # a province walked: one staff restored
	if int(h.at) >= Extra.HENRO.size():
		h.done = int(h.done) + 1
		write_save()
		return show_hub
	write_save()
	return show_henro

func henro_spend():
	var h = data.henro
	h.staffs = int(h.staffs) - 1
	if int(h.staffs) <= 0:
		h.at = 0
		h.staffs = 3
		write_save()
		return false
	write_save()
	return true

func _henro_failed():
	if henro_spend():
		show_henro()
	else:
		show_hub()

# ---------------------------------------------------------------- the workshop
# A board is given away as a short code: "JZ1." and the board, base64-encoded.

func show_editor():
	play_music("title")
	go(load("res://scripts/editor.gd").new())

# the author has cleared their own board: their stroke count becomes its mastery target
func mine_won(_grade, _mask, turns):
	var b = board_from_code(data.mine)
	if not b.is_empty():
		b.par = turns if int(b.par) == 0 else min(int(b.par), turns)
		data.mine = board_code(b)
		write_save()
	return show_editor

func blank_board():
	return {"rows": [".......", ".......", ".......", ".......", ".......", ".......", "...H..."], "waza": [], "rules": [], "ink": 4, "par": 0}

func board_code(b):
	var initials = ""
	for w in b.waza:
		initials += w.substr(0, 1)
	var raw = "".join(b.rows) + "|" + initials + "|" + ",".join(b.rules) + "|" + str(int(b.ink)) + "|" + str(int(b.par))
	return "JZ1." + Marshalls.utf8_to_base64(raw).replace("+", "-").replace("/", "_").replace("=", "")

func board_from_code(code):
	if not code.begins_with("JZ1."):
		return {}
	var b64 = code.substr(4).replace("-", "+").replace("_", "/")
	for ch in b64:
		if not "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".contains(ch):
			return {}
	if b64.length() % 4 == 1 or b64.length() < 60:
		return {}
	while b64.length() % 4 != 0:
		b64 += "="
	var raw = Marshalls.base64_to_utf8(b64)
	var parts = raw.split("|")
	if parts.size() != 5 or parts[0].length() != 49:
		return {}
	var allowed = ".#~ifgmbwxH" + "".join(preload("res://scripts/sim.gd").DEF.keys())
	for ch in parts[0]:
		if not allowed.contains(ch):
			return {}
	if parts[0].count("H") != 1:
		return {}
	var out = blank_board()
	out.rows = []
	for y in range(7):
		out.rows.append(parts[0].substr(y * 7, 7))
	var names = {"l": "leap", "w": "ward", "k": "katsu", "b": "bell"}
	for ch in parts[1]:
		if names.has(ch) and not out.waza.has(names[ch]):
			out.waza.append(names[ch])
	var known = ["koan", "garden", "gate", "wet", "enso", "stone", "nocut", "shiki", "rain", "snow", "night", "order", "write", "wind:R", "wind:L", "wind:D", "wind:U"]
	for r in parts[2].split(",", false):
		if known.has(r) and not out.rules.has(r):
			out.rules.append(r)
	out.ink = clamp(int(parts[3]), 2, 12)
	out.par = clamp(int(parts[4]), 0, 99)
	return out

# a board from the workshop, in the shape the battle screen plays
func board_level(b):
	return {"kanji": "", "name": "", "par": int(b.par) if int(b.par) > 0 else 99, "waza": b.waza.duplicate(), "rules": b.rules.duplicate(),
		"ink": int(b.ink), "rows": b.rows.duplicate(), "hint": "", "say": [], "story": [], "after": [], "sol": ""}

func show_scroll():
	play_music("title")
	go(load("res://scripts/scroll.gd").new())

func show_dojo():
	go(load("res://scripts/dojo.gd").new())

func show_story(lines, after, where = 0.0):
	if lines.is_empty():
		after.call()
		return
	play_music("story")
	var scr = load("res://scripts/story.gd").new()
	scr.where = where
	scr.lines = lines
	scr.after = after
	go(scr)

func start_stage(i):
	show_story(Data.LEVELS[i].story, show_battle.bind(i), i / float(Data.LEVELS.size()))

func show_battle(i):
	play_music("boss" if Data.BOSSES.has(i) else "battle")
	var scr = load("res://scripts/battle.gd").new()
	scr.idx = i
	go(scr)
