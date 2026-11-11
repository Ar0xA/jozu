extends Control
# Root: paints the paper, owns the save file, swaps screens.

const Ink = preload("res://scripts/ink.gd")
const Data = preload("res://scripts/data.gd")
var save_path = "user://jozu_save.json"

var font
var data = {}
var cur = null
var fibers = []
var art = {}
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
	var rng = RandomNumberGenerator.new()
	rng.seed = 1185
	for i in range(420):
		var p = Vector2(rng.randf() * 1280, rng.randf() * 720)
		var ang = rng.randf() * TAU
		fibers.append([p, p + Vector2(cos(ang), sin(ang)) * rng.randf_range(6, 34), rng.randf_range(0.04, 0.13)])
	art["tohaku"] = load("res://art/tohaku.jpg")
	for nm in ["sesshu", "hyakki"]:
		art[nm] = [load("res://art/%s_0.jpg" % nm), load("res://art/%s_1.jpg" % nm)]
	for nm in ["hero", "oni", "oni3", "tengu", "kitsune", "yurei", "tamamo", "chochin", "kasa", "kappa", "nurikabe", "yukionna", "gasha"]:
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
	music.finished.connect(func(): music.play())
	for i in range(6):
		var p = AudioStreamPlayer.new()
		add_child(p)
		sfx_pool.append(p)
	for nm in ["title", "battle", "boss", "step", "cut", "kill", "hit", "ward", "leap", "katsu", "sheathe", "click", "win", "lose"]:
		streams[nm] = load("res://audio/%s.wav" % nm)
	streams["story"] = load("res://audio/story.ogg")
	AudioServer.set_bus_mute(0, not data.sound)

func play_music(nm):
	if nm == music_name:
		return
	music_name = nm
	music.stop()
	music.stream = streams.get(nm)
	music.volume_db = MUSIC_DB.get(nm, -9.0)
	if music.stream:
		music.play()

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

func _unhandled_input(ev):
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_M:
		toggle_sound()

# A board piece: a figure lifted from an old painting (see art/CREDITS.md).
# On the board it stands on its tile and may rise above it; flat = centred, for the legend.
const PIECE_SCALE = {"hero": 1.3, "oni": 1.3, "oni3": 1.25, "tengu": 1.3, "kitsune": 1.12, "yurei": 1.2, "tamamo": 1.3, "chochin": 0.95,
	"kasa": 1.25, "kappa": 1.0, "nurikabe": 1.1, "yukionna": 1.3, "gasha": 1.15}

func piece(ci, kind, c, s, t = 0.0, big = false, flat = false, grow = 1.0):
	var key = kind
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
	if not art.has("p_" + key):
		# no painting for this one: a brushed ring and its name
		ci.draw_circle(c, s * 0.36, Ink.PAPER)
		Ink.enso(ci, c, s * 0.38, s * 0.06, Ink.SUMI)
		var kj = Data.LEGEND.get(kind, ["?"])[0].substr(0, 1)
		Ink.text(ci, font, Vector2(c.x - s * 0.5, c.y + s * 0.16), kj, s * 0.42, Ink.SUMI, HORIZONTAL_ALIGNMENT_CENTER, s)
		return
	var sz = Vector2(s, s) * k
	var pos = c + off - sz * 0.5
	if not flat and kind != "chochin" and kind != "kappa":
		pos.y = c.y + s * 0.47 - sz.y
	ci.draw_texture_rect(art["p_" + key], Rect2(pos, sz), false)

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
	return {"cleared": {}, "scroll": {}, "sound": true, "up": {"ink": 0, "ki": 0, "leap": 0, "ward": 0, "katsu": 0}}

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
	data = fresh()
	data.sound = snd
	write_save()

func grade_of(i):
	return data.cleared.get(str(i), "")

func unlocked(i):
	return i == 0 or grade_of(i - 1) != ""

func record(i, grade, paths = null):
	var better = grade_of(i) != "jouzu"
	if better:
		data.cleared[str(i)] = grade
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

func points_total():
	var n = 0
	for k in data.cleared:
		n += 2 if data.cleared[k] == "jouzu" else 1
	return n

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
