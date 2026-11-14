extends Control
# Root: paints the paper, owns the save file, swaps screens.

const Ink = preload("res://scripts/ink.gd")
const Data = preload("res://scripts/data.gd")
const Extra = preload("res://scripts/extra.gd")
const Koyomi = preload("res://scripts/koyomi.gd")
var save_path = "user://jozu_save.json"

var font
var data = {}
var cur = null
var fibers = []
var art = {}
var _touch_words = {}
var late = []        # music and paintings not in the first download, still to be fetched (web only)
var art_parts = {}   # the halves of a long scroll that have arrived so far
var newer = false    # a newer build of the game is waiting to be taken (web only)
var tall = false     # the window is upright: the page is painted off screen and re-stacked (scripts/tall.gd)
var stage_vp         # where the page is painted then
var tall_view        # and what shows it
var tip = -1         # whether the title names the home screen this visit: -1 not yet decided, 0 no, 1 yes
var fetching = ""
var touch = false   # a phone or tablet: no hover, no right-click, fingers not pointers
var turn_note
var paint_rect
var wipe
# Zoom, for small screens: two fingers pinch and drag, or the button in the corner.
var zoom = 1.0
var zpos = Vector2.ZERO
var touches = {}       # finger -> where it is
var pinching = false   # two fingers are down: the screens ignore them
var pinch = {}
var zoom_btn
var music
var ambient          # the season's own sound, behind the title
var music_name = ""
var sfx_pool = []
var sfx_i = 0
var streams = {}
const MUSIC_DB = {"title": -9.0, "story": -5.0, "battle": -10.0, "boss": -9.0, "road2": -10.0, "road3": -10.0, "boss2": -9.0, "zen": -7.0}

func _ready():
	var sysf = SystemFont.new()
	sysf.font_names = PackedStringArray(["Yu Mincho", "YuMincho", "MS Mincho", "Hiragino Mincho ProN", "Noto Serif CJK JP", "Noto Serif JP", "Yu Gothic", "serif"])
	font = sysf
	# Yuji Syuku: a typeface cut from brush-written kana and kanji (SIL OFL, see fonts/OFL.txt)
	var ff = load("res://fonts/YujiSyuku-Regular.ttf")
	if ff:
		# the few characters it lacks come from Shippori Mincho (SIL OFL, fonts/OFL-ShipporiMincho.txt)
		var fill = load("res://fonts/ShipporiMincho-Fill.ttf")
		ff.fallbacks = [fill, sysf] if fill else [sysf]
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
	zoom_btn = Button.new()
	zoom_btn.text = "拡"
	zoom_btn.position = Vector2(0, 314)   # the left edge is clear on every screen
	zoom_btn.size = Vector2(42, 92)
	zoom_btn.focus_mode = Control.FOCUS_NONE
	zoom_btn.modulate = Color(1, 1, 1, 0.8)
	zoom_btn.add_theme_font_override("font", font)
	zoom_btn.add_theme_font_size_override("font_size", 24)
	zoom_btn.pressed.connect(func(): set_zoom(1.0 if zoom > 1.01 else 1.7, Vector2(420, 400)))
	zoom_btn.visible = touch
	top.add_child(zoom_btn)
	var rng = RandomNumberGenerator.new()
	rng.seed = 1185
	for i in range(420):
		var p = Vector2(rng.randf() * 1280, rng.randf() * 720)
		var ang = rng.randf() * TAU
		fibers.append([p, p + Vector2(cos(ang), sin(ang)) * rng.randf_range(6, 34), rng.randf_range(0.04, 0.13)])
	art["tohaku"] = load("res://art/tohaku.jpg")
	for nm in ["sesshu", "hyakki"]:
		if ResourceLoader.exists("res://art/%s_0.jpg" % nm):
			art[nm] = [load("res://art/%s_0.jpg" % nm), load("res://art/%s_1.jpg" % nm)]
		else:
			# the web build leaves the two long scrolls out of its first download too
			art[nm] = []
			late.append("art:%s_0" % nm)
			late.append("art:%s_1" % nm)
	for k in PRINTS:
		var pn = PRINTS[k][0]
		if ResourceLoader.exists("res://art/prints/%s.jpg" % pn):
			art["print_" + pn] = load("res://art/prints/%s.jpg" % pn)
		else:
			late.append("art:print_" + pn)   # the web build fetches the prints after everything else
	for nm in ["hero", "oni", "oni3", "tengu", "kitsune", "yurei", "tamamo", "chochin", "kasa", "kappa", "nurikabe", "yukionna", "gasha", "daruma", "tanuki", "shinigami", "kamaitachi"]:
		var t = load("res://art/pieces/%s.png" % nm)
		if t:
			var img = t.get_image()
			img.generate_mipmaps()
			art["p_" + nm] = ImageTexture.create_from_image(img)
	load_save()
	_setup_audio()
	stage_vp = SubViewport.new()
	stage_vp.transparent_bg = true
	stage_vp.size = Vector2i(1280, 720)
	stage_vp.size_2d_override = Vector2i(1280, 720)
	stage_vp.size_2d_override_stretch = true
	stage_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(stage_vp)
	tall_view = load("res://scripts/tall.gd").new()
	tall_view.main = self
	tall_view.visible = false
	add_child(tall_view)
	get_window().size_changed.connect(_fit)
	_fit()
	if not _linked_board():
		show_title()

# Wide or upright? Upright, the sheet is 720 across and as tall as the screen makes it, and the
# page moves off screen to be cut up (scripts/tall.gd); wide, everything is as it always was.
func _fit():
	var ws = _win_size()
	_seen_size = ws
	var want = ws.y > ws.x * 1.1
	if want != tall:
		tall = want
		var win = get_tree().root
		win.content_scale_size = Vector2i(720, 1280) if tall else Vector2i(1280, 720)
		win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_WIDTH if tall else Window.CONTENT_SCALE_ASPECT_KEEP
		set_zoom(1.0)
		if tall:
			zoom_btn.visible = false
		tall_view.visible = tall
		stage_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if tall else SubViewport.UPDATE_DISABLED
		if cur != null and is_instance_valid(cur):
			cur.get_parent().remove_child(cur)
			_hold(cur)
			cur.wake = 0.6
			cur.tall_changed()
		queue_redraw()
		_again = 4
	if tall:
		# painted at about the size it will be shown, so the writing stays sharp
		var ss = clamp(ceil(ws.x / 720.0 * 1.2 * 2.0) / 2.0, 1.0, 2.0)
		stage_vp.size = Vector2i(int(1280 * ss), int(720 * ss))

# puts a page where pages go: on the sheet itself, or off screen when the phone is upright
func _hold(scr):
	if tall:
		stage_vp.add_child(scr)
	else:
		add_child(scr)
		if wipe != null:
			move_child(wipe, -1)

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
	ambient = AudioStreamPlayer.new()
	add_child(ambient)
	for i in range(6):
		var p = AudioStreamPlayer.new()
		add_child(p)
		sfx_pool.append(p)
	for nm in ["title", "story", "battle", "road2", "road3", "zen", "boss", "boss2"] + AMBIENCE:
		var path = "res://audio/%s.ogg" % nm
		if ResourceLoader.exists(path):
			streams[nm] = load(path)
		elif not AMBIENCE.has(nm):
			late.append(nm)   # the web build leaves the stage music out of its first download
		elif nm == AMBIENCE[Koyomi.today()[4]]:
			late.push_front(nm)   # of the four seasons only today's is fetched, and first
	_fetch_music()
	if OS.has_feature("web"):
		JavaScriptBridge.pwa_update_available.connect(_newer_build)
		if JavaScriptBridge.pwa_needs_update():
			_newer_build()
		# ask now whether there is a newer build, rather than whenever the browser next thinks to
		JavaScriptBridge.eval("if('serviceWorker' in navigator)navigator.serviceWorker.getRegistration().then(function(r){if(r)r.update()}).catch(function(){})", true)
	for nm in ["step", "cut", "kill", "hit", "ward", "leap", "katsu", "sheathe", "click", "win", "lose", "bell", "eat", "splash", "web", "kama", "ink", "ki", "ki2", "brush", "koto", "pon"]:
		streams[nm] = load("res://audio/%s.wav" % nm)
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
	elif late.has(nm):
		late.erase(nm)
		late.push_front(nm)   # wanted now: it is fetched next, and starts when it arrives

# On the web the stage music (music/*.ogg) and the two long scrolls (art/*.webp) sit beside the
# game and are fetched one at a time once the title is up, so the first download is smaller. Until
# a piece of music arrives its stage is quiet; until a scroll arrives its place is bare paper.
func _fetch_music():
	if late.is_empty() or fetching != "":
		return
	fetching = late.pop_front()
	var rq = HTTPRequest.new()
	add_child(rq)
	rq.request_completed.connect(_music_fetched.bind(rq))
	var page = str(JavaScriptBridge.eval("window.location.href.split('?')[0].split('#')[0]", true))
	var file = ("art/" + fetching.substr(4) + ".webp") if fetching.begins_with("art:") else ("music/" + fetching + ".ogg")
	if rq.request(page.substr(0, page.rfind("/") + 1) + file) != OK:
		rq.queue_free()
		fetching = ""

func _music_fetched(result, code, _headers, body, rq):
	rq.queue_free()
	var nm = fetching
	fetching = ""
	if result == HTTPRequest.RESULT_SUCCESS and code == 200 and nm.begins_with("art:"):
		var img = Image.new()
		if img.load_webp_from_buffer(body) == OK and nm.begins_with("art:print_"):
			art[nm.substr(4)] = ImageTexture.create_from_image(img)
		elif img.load_webp_from_buffer(body) == OK:
			art_parts[nm.substr(4)] = ImageTexture.create_from_image(img)
			var scroll = nm.substr(4, nm.length() - 6)
			if art_parts.has(scroll + "_0") and art_parts.has(scroll + "_1"):
				art[scroll] = [art_parts[scroll + "_0"], art_parts[scroll + "_1"]]
	elif result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var got = AudioStreamOggVorbis.load_from_buffer(body)
		if got != null:
			streams[nm] = got
			if music_name == nm:
				music.stream = got
				if data.opts.music:
					music.play()
	_fetch_music()

# What is heard on a stage. The chapters of stillness (QUIET) have the quiet piece; the rest take the three road pieces in turn,
# and the last board of a story has drum and shamisen.
const QUIET = ["Zen Temple", "Stone Garden", "Ensō", "Ink Stone", "Red Thread", "Temple Bell", "The Character", "The Brush"]

func stage_music(i):
	var c = 0
	for k in range(Data.CHAPTERS.size()):
		if Data.CHAPTERS[k].from <= i:
			c = k
	if Data.BOSSES.has(i):
		return "boss" if c % 2 == 0 else "boss2"
	if QUIET.has(Data.CHAPTERS[c].name):
		return "zen"
	return ["battle", "road2", "road3"][c % 3]

# the settings a player can change (scripts/settings.gd)
# undo: 1 only within the stroke in hand (a finished stroke is committed), 2 not at all
# style: 0 shodo (spare: bare paper, one seal, a stroke that runs dry), 1 ornate (as it was)
const OPTS = {"music": true, "motion": true, "pattern": false, "filter": true, "undo": 1, "style": 0}

# The spare style: what would be on a calligrapher's sheet, and no more.
func spare():
	return int(data.opts.style) == 0

func apply_opts():
	paint_rect.visible = data.opts.filter
	if not data.opts.music:
		music.stop()
	elif music.stream and not music.playing:
		music.play()

# 落款: the seal pressed on a finished piece. Suzu's own art name once she has chosen one
# (scripts/seal.gd); until then her master's, 筆剣.
func my_seal():
	return data.gago if data.gago != "" else "筆剣"

func show_seal(back = Callable()):
	play_music("title")
	var scr = load("res://scripts/seal.gd").new()
	scr.back = back if back.is_valid() else show_map
	go(scr)

func show_settings(back = Callable()):
	play_music("title")
	var scr = load("res://scripts/settings.gd").new()
	scr.back = back if back.is_valid() else show_title
	go(scr)

func sfx(nm, pitch = 1.0, db = -7.0):
	var st = streams.get(nm)
	if st == null:
		return
	var p = sfx_pool[sfx_i % sfx_pool.size()]
	sfx_i += 1
	p.stream = st
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()

# A phone taps when a cut lands or you are struck, where the browser or the device can (Android;
# an iPhone's browser cannot). It goes with the Motion setting.
func buzz(ms):
	if not touch or not data.opts.motion:
		return
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if (navigator.vibrate) navigator.vibrate(%d)" % ms)
	else:
		Input.vibrate_handheld(ms)

# Once, on a phone's browser, the title says the game can be kept on the home screen. It is said
# for one visit and not again, and never to someone who already opened it from there.
func install_tip():
	if tip < 0:
		tip = 0
		if touch and OS.has_feature("web") and not data.told and not data.cleared.is_empty():
			var kept = JavaScriptBridge.eval("(window.matchMedia('(display-mode: standalone)').matches || window.matchMedia('(display-mode: fullscreen)').matches || navigator.standalone === true) ? 1 : 0")
			if int(kept) == 0:
				tip = 1
				data.told = true
				write_save()
	return tip == 1

# A stroke is a phrase: each step sounds the next note of the In scale (miyako-bushi: D, E flat,
# G, A, B flat), the scale the stage music is written in, on one koto string. `n` is how many
# notes up from the low D; -5 is the D an octave below, where a lifted brush comes to rest.
const IN_SCALE = [0, 1, 5, 7, 8]

func koto(n, db = -15.0):
	var semis = IN_SCALE[posmod(n, 5)] + 12 * int(floor(n / 5.0))
	sfx("koto", pow(2.0, semis / 12.0), db)

# The season, heard behind the title: a bush warbler in spring, an evening cicada in summer, bell
# crickets in autumn, and in winter only the wind (audio/amb_*.ogg, made by tools/make_audio.py).
const AMBIENCE = ["amb_haru", "amb_natsu", "amb_aki", "amb_fuyu"]

func play_ambience(season):
	var st = streams.get(AMBIENCE[season])
	if st == null or ambient.playing:
		return   # in a browser it may not have arrived yet: the title asks again
	st.loop = true
	ambient.stream = st
	ambient.volume_db = -16.0
	ambient.play()

func toggle_sound():
	data.sound = not data.sound
	AudioServer.set_bus_mute(0, not data.sound)
	write_save()

var _seen_size = Vector2i.ZERO   # the window as it was when the page was last fitted to it
var _look = 0.0                  # seconds until the window is next measured
var _again = 0                   # frames for which the picture is still to be put back on the window

# In a browser, a change of layout made after the window was turned leaves the picture drawn into
# the window's old shape. This says again where on the window it goes: all of it upright, and
# centred with bars at the sides or above and below when wide.
func _reattach():
	if not OS.has_feature("web"):
		return
	var ws = Vector2(get_window().size)
	var rect = Rect2(Vector2.ZERO, ws)
	if not tall:
		var k = min(ws.x / 1280.0, ws.y / 720.0)
		var sz = (Vector2(1280, 720) * k).floor()
		rect = Rect2(((ws - sz) * 0.5).floor(), sz)
	RenderingServer.viewport_attach_to_screen(get_tree().root.get_viewport_rid(), rect, DisplayServer.MAIN_WINDOW_ID)

# The window in real pixels. In a browser the page itself is asked: the engine's own figure can be
# one turn of the phone behind.
func _win_size():
	if OS.has_feature("web"):
		var packed = JavaScriptBridge.eval("Math.round(window.innerWidth * window.devicePixelRatio) * 100000 + Math.round(window.innerHeight * window.devicePixelRatio)", true)
		if packed != null and int(packed) > 100000:
			return Vector2i(int(packed) / 100000, int(packed) % 100000)
	return get_window().size

func _process(_dt):
	# a browser does not always tell the engine the window has been turned: look for ourselves
	if _again > 0:
		_again -= 1
		_reattach()
	_look -= _dt
	if _look <= 0.0:
		_look = 0.4 if OS.has_feature("web") else 0.0
		if _win_size() != _seen_size:
			_fit()
	if zoom > 1.01 or position != Vector2.ZERO:
		# anchors would otherwise put the page back where it was
		scale = Vector2(zoom, zoom)
		position = zpos

func toggle_fullscreen():
	var full = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)

# On a phone there is no mouse, no Space bar and no arrow keys: say what a finger does instead.
func touch_words(text):
	if not touch:
		return text
	if _touch_words.has(text):
		return _touch_words[text]
	var asked = text
	for pair in [["Click or drag", "Tap or drag"], ["click or drag", "tap or drag"], [", or use the arrow keys", ""],
			["Press Space to lift the brush", "Tap 収筆 to lift the brush"], [": Space, or 収筆", ": tap 収筆"], ["Right-click or Z takes", "戻 takes"],
			["restart (R)", "restart"], ["Restart (R)", "Restart"], [" (key 5)", ""], ["any key or click", "tap to close"], ["Esc cancels", "tap the button again to cancel"]]:
		text = text.replace(pair[0], pair[1])
	_touch_words[asked] = text
	return text

# Scale the whole page about a point on the screen. `anchor` is the point of the page that should
# stay under `at`; left out, it is whatever is under `at` now.
func set_zoom(z, at = Vector2(640, 360), anchor = null):
	if anchor == null:
		anchor = (at - zpos) / zoom
	zoom = clamp(z, 1.0, 3.0)
	zpos = at - anchor * zoom
	# never show past the edge of the paper
	zpos.x = clamp(zpos.x, 1280.0 * (1.0 - zoom), 0.0)
	zpos.y = clamp(zpos.y, 720.0 * (1.0 - zoom), 0.0)
	scale = Vector2(zoom, zoom)
	position = zpos
	zoom_btn.text = "1×" if zoom > 1.01 else "拡"
	zoom_btn.visible = touch or zoom > 1.01

func _input(ev):
	if tall:
		return   # upright, the page is already as large as the phone: no pinching
	if ev is InputEventScreenTouch:
		if ev.pressed:
			touches[ev.index] = ev.position
		else:
			touches.erase(ev.index)
		if touches.size() == 2:
			var p = touches.values()
			var mid = (p[0] + p[1]) * 0.5
			pinch = {"d": max(1.0, p[0].distance_to(p[1])), "z": zoom, "anchor": (mid - zpos) / zoom}
		pinching = touches.size() >= 2 or (pinching and not touches.is_empty())   # the finger left down after a pinch plays nothing
		if pinching:
			get_viewport().set_input_as_handled()
	elif ev is InputEventScreenDrag and touches.has(ev.index):
		touches[ev.index] = ev.position
		if touches.size() == 2:
			var p = touches.values()
			set_zoom(pinch.z * p[0].distance_to(p[1]) / pinch.d, (p[0] + p[1]) * 0.5, pinch.anchor)
			get_viewport().set_input_as_handled()
	elif ev is InputEventMagnifyGesture:
		set_zoom(zoom * ev.factor, ev.position)
	elif ev is InputEventPanGesture and zoom > 1.01:
		set_zoom(zoom, Vector2(640, 360) - ev.delta * 12.0, (Vector2(640, 360) - zpos) / zoom)

func _unhandled_input(ev):
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if tall and cur != null and is_instance_valid(cur):
			cur.wake = 0.6
			cur.on_key(ev.keycode)   # the page is off screen and hears no keys of its own
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
	if texs.is_empty():
		return   # not yet arrived (web)
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
	if tall:
		return   # the upright sheet paints its own paper
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
		"henro": {"at": 0, "staffs": 3, "best": 0, "done": 0}, "mine": "", "gago": "", "told": false, "sound": true, "opts": OPTS.duplicate(), "days": {}, "tries": {}, "rand": {}, "met": {}, "up": {"ink": 0, "ki": 0, "leap": 0, "ward": 0, "katsu": 0}}

func load_save():
	_front = -1
	data = fresh()
	if FileAccess.file_exists(save_path):
		var txt = FileAccess.get_file_as_string(save_path)
		var j = JSON.parse_string(txt)
		if typeof(j) != TYPE_DICTIONARY or typeof(j.get("cleared")) != TYPE_DICTIONARY:
			# unreadable: keep it aside rather than write a fresh save over it
			DirAccess.copy_absolute(save_path, save_path + ".bad")
		else:
			if j.has("sound"):
				data.sound = bool(j.sound)
			data.told = bool(j.get("told", false))
			data.gago = str(j.get("gago", "")).substr(0, 2)
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
						data.opts[k] = clamp(int(j.opts[k]), 1, 2) if k == "undo" else clamp(int(j.opts[k]), 0, 1) if k == "style" else bool(j.opts[k])
			for grp in ["days", "tries", "rand", "met"]:
				if j.has(grp) and typeof(j[grp]) == TYPE_DICTIONARY:
					for k in j[grp]:
						data[grp][k] = int(j[grp][k])
			if j.has("seals") and typeof(j.seals) == TYPE_DICTIONARY:
				for k in j.seals:
					data.seals[k] = int(j.seals[k])
			for k in j.cleared:
				data.cleared[k] = str(j.cleared[k])
			if typeof(j.get("ids")) == TYPE_DICTIONARY:
				_follow_boards(j.ids)
			if typeof(j.get("up")) == TYPE_DICTIONARY:
				for k in data.up:
					if j.up.has(k):
						data.up[k] = max(0, int(j.up[k]))
			data.henro.at = clamp(data.henro.at, 0, Extra.HENRO.size())
			data.henro.staffs = clamp(data.henro.staffs, 0, 3)

# What a stage's board is called in the save: the board itself, not its place on the road.
func board_id(i):
	return str("".join(Data.LEVELS[i].rows).hash())

# Progress is kept by station number, and beside it which board each number was. If the road has
# since been rebuilt and a board now stands elsewhere, what was earned on it goes with it; a board
# that is no longer on the road takes its record with it, unless another was put in its place
# (Data.SWAPPED): then the clear and the seals stay at that station, and only the drawn scroll goes.
func _follow_boards(ids):
	var moved = {}
	for k in ids:
		if not k.is_valid_int() or int(k) < 0 or int(k) >= Data.LEVELS.size() or board_id(int(k)) != str(ids[k]):
			moved[k] = ""
	if moved.is_empty():
		return
	var at = {}
	for i in range(Data.LEVELS.size()):
		at[board_id(i)] = str(i)
	var swapped = {}
	for rows in Data.SWAPPED:
		swapped[str(rows.hash())] = str(int(Data.SWAPPED[rows]))
	var redrawn = {}   # stations whose board was replaced: the old strokes do not fit the new one
	for k in moved:
		moved[k] = at.get(str(ids[k]), "")
		if moved[k] == "" and swapped.has(str(ids[k])):
			moved[k] = swapped[str(ids[k])]
			redrawn[k] = true
	for grp in ["cleared", "scroll", "seals"]:
		var kept = {}
		for k in data[grp]:
			if not moved.has(k):
				kept[k] = data[grp][k]
		for k in data[grp]:
			if moved.has(k) and moved[k] != "" and not kept.has(moved[k]) and not (grp == "scroll" and redrawn.has(k)):
				kept[moved[k]] = data[grp][k]
		data[grp] = kept

func write_save():
	var ids = {}
	for grp in ["cleared", "scroll", "seals"]:
		for k in data[grp]:
			if k.is_valid_int() and int(k) >= 0 and int(k) < Data.LEVELS.size():
				ids[k] = board_id(int(k))
	data["ids"] = ids
	# written beside the save and then moved over it, so a write cut short cannot leave half a file
	var tmp = save_path + ".tmp"
	var f = FileAccess.open(tmp, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()
		if DirAccess.rename_absolute(tmp, save_path) != OK:
			DirAccess.remove_absolute(save_path)
			DirAccess.rename_absolute(tmp, save_path)

# The whole save as one line of text, to be kept somewhere safe or carried to another device:
# the save file, packed and written in letters and digits.
const SAVE_MARK = "JOZU1:"

func save_code():
	write_save()
	var raw = FileAccess.get_file_as_bytes(save_path)
	return SAVE_MARK + Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_DEFLATE))

# What a save code holds, or null if it is not one: the save as a dictionary.
func read_code(code):
	code = str(code).strip_edges()
	var at = code.find(SAVE_MARK)
	if at < 0:
		return null
	var packed = Marshalls.base64_to_raw(code.substr(at + SAVE_MARK.length()).replace(" ", "").replace("\n", ""))
	if packed.is_empty():
		return null
	var raw = packed.decompress_dynamic(8 * 1024 * 1024, FileAccess.COMPRESSION_DEFLATE)
	if raw.is_empty():
		return null
	var j = JSON.parse_string(raw.get_string_from_utf8())
	if typeof(j) != TYPE_DICTIONARY or typeof(j.get("cleared")) != TYPE_DICTIONARY:
		return null
	return j

# Takes a save code in place of the progress here. What was here is kept beside it (.before).
func take_code(code):
	var j = read_code(code)
	if j == null:
		return false
	if FileAccess.file_exists(save_path):
		DirAccess.copy_absolute(save_path, save_path + ".before")
	var f = FileAccess.open(save_path, FileAccess.WRITE)
	if not f:
		return false
	f.store_string(JSON.stringify(j))
	f.close()
	gate_told = -1
	load_save()
	write_save()
	apply_opts()
	return true

func erase_save():
	var snd = data.get("sound", true)
	var opts = data.get("opts", OPTS.duplicate())
	var told = data.get("told", false)
	_front = -1
	gate_told = -1
	data = fresh()
	data.sound = snd
	data.opts = opts
	data.told = told
	write_save()

func grade_of(i):
	return data.cleared.get(str(i), "")

# The gate. The last station of a chapter opens only when two-thirds of the stations before it in
# that chapter are mastered (上手). Any other station opens when the one before it is passed.
var _front = -1     # the furthest station the road has reached; -1 = to be worked out again
var gate_told = -1  # the chapter whose gate has already been explained on the map

func chapter_of(i):
	var c = 0
	for k in range(Data.CHAPTERS.size()):
		if Data.CHAPTERS[k].from <= i:
			c = k
	return c

# [first station, last station, mastered among those before the last, how many the last asks for]
func gate_of(c):
	var a = Data.CHAPTERS[c].from
	var z = (Data.CHAPTERS[c + 1].from if c + 1 < Data.CHAPTERS.size() else Data.LEVELS.size()) - 1
	var got = 0
	for i in range(a, z):
		if grade_of(i) == "jouzu":
			got += 1
	return [a, z, got, int(ceil((z - a) * 2.0 / 3.0))]

func frontier():
	if _front < 0:
		_front = 0
		for c in range(Data.CHAPTERS.size()):
			var g = gate_of(c)
			for i in range(g[0], g[1] + 1):
				if i == g[1] and g[2] < g[3]:
					return _front   # the gate is shut
				_front = i
				if grade_of(i) == "":
					return _front
	return _front

func unlocked(i):
	return i <= frontier() or grade_of(i) != ""

# The chapter whose gate is holding the road, or -1: every station before its last is passed, and
# too few of them are mastered.
func held_chapter():
	var f = frontier()
	if grade_of(f) == "" or f + 1 >= Data.LEVELS.size():
		return -1
	return chapter_of(f)

func gate_words():
	var c = held_chapter()
	if c < 0:
		return ""
	var g = gate_of(c)
	var more = g[3] - g[2]
	return "The last station of a chapter opens when two-thirds of the chapter is mastered (上手: within the stroke count, unharmed). Here %d of %d are mastered and %d are asked for: master %d more and the road opens. A station passed but not mastered shows an empty ring." % [g[2], g[1] - g[0], g[3], more]

func record(i, grade, paths = null, seal_mask = 0):
	_front = -1
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
#   2  潔   isagiyoshi  mastery at the first attempt since entering: no stroke taken back, no restart
#   4  惜墨 sekiboku    unharmed, spending no more ink than the master's line
const SEALS = [[1, "上手", "mastery"], [2, "潔", "no undo, no restart"], [4, "惜墨", "sparing of ink"]]
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
	# into a stage and out of one, the doors slide; between other pages, a wash of ink
	var stage = scr.get_script().resource_path.ends_with("battle.gd") or (cur != null and cur.get_script().resource_path.ends_with("battle.gd"))
	if cur:
		cur.queue_free()
	ambient.stop()   # only the title has it, and starts it again
	cur = scr
	scr.main = self
	_hold(scr)
	if wipe == null:
		wipe = load("res://scripts/wipe.gd").new()
		wipe.main = self
		add_child(wipe)
	move_child(wipe, -1)
	if data.opts.motion:
		wipe.start("fade" if tall else "fusuma" if stage else "fade" if spare() else "wash")

# The web build is kept by a service worker, so it opens at once and without a network. A newer
# build waits behind the one in use; it is taken (the page reloads) only at the title, never mid-play.
func _newer_build():
	newer = true   # the title takes it (scripts/title.gd, tick)

func _take_newer():
	newer = false
	# once a minute at most, so that a build that will not take cannot reload the page for ever
	var again = JavaScriptBridge.eval("(function(){var t=Number(sessionStorage.getItem('jozu_update')||0),n=Date.now();if(n-t<60000)return 1;sessionStorage.setItem('jozu_update',String(n));return 0})()", true)
	if int(again) == 0:
		JavaScriptBridge.pwa_update()

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
	var quiet = kind == "daily" or lv.rules.has("koan") or lv.rules.has("garden") or lv.rules.has("write") or lv.rules.has("enso")
	play_music("zen" if quiet else "road3" if kind == "henro" else "road2" if kind == "random" else "battle")
	var scr = load("res://scripts/battle.gd").new()
	scr.custom = lv
	scr.kind_of = kind
	scr.label = label
	scr.on_win = on_win
	scr.on_fail = on_fail
	scr.back = back
	go(scr)

# ---------------------------------------------------------------- the daily koan
# One single-stroke board a day, the same for everyone: easy on Monday, expert on Sunday.

const SEASONED_FROM = 20770   # 13 November 2026: from this day the board is chosen by the season

# Does a board suit a season (0 spring .. 3 winter)? Winter has ice and summer has water; spring
# has thawed; autumn is dry, and the foxes are about.
func _in_season(rows, season):
	match season:
		0: return not rows.contains("i")
		1: return rows.contains("~")
		2: return rows.contains("k") and not rows.contains("~")
	return rows.contains("i")

# The four grades of the koan and of the temples, and how many ways to mastery each leaves open
# (tools/tighten_extra.py holds the boards to it). A koan is graded by its weekday, a temple by
# its province.
const GRADES = [["易", "Easy", 10], ["中", "Normal", 5], ["難", "Hard", 3], ["極", "Expert", 1]]
const DAY_GRADE = [0, 0, 1, 1, 2, 2, 3]   # Monday first

func daily_grade(day = -1):
	return DAY_GRADE[((today() if day < 0 else day) + 3) % 7]

func henro_grade(at):
	var g = 0
	for k in range(PROVINCES.size()):
		if at >= PROVINCES[k][0]:
			g = k
	return g

# what a grade promises, in a few words
func grade_words(g, koan = false):
	if g == 3:
		return "Expert: it has one answer." if koan else "Expert: one way to mastery."
	return "%s: at most %d %s." % [GRADES[g][1], GRADES[g][2], "answers" if koan else "ways to mastery"]

# the day by the player's own clock, counted from 1970
func today():
	return int(floor((Time.get_unix_time_from_system() + Time.get_time_zone_from_system().bias * 60.0) / 86400.0))

func daily_level(day = -1):
	if day < 0:
		day = today()
	var bank = Extra.DAILY
	var weekday = (day + 3) % 7              # day 0 was a Thursday; 0 = Monday
	var slice = bank.size() / 7
	var pick = weekday * slice + (day / 7) % slice
	var d = Time.get_date_dict_from_unix_time(day * 86400)
	var koyomi = Koyomi.on(d.month, d.day)
	if day >= SEASONED_FROM:
		# the board suits the season the almanac gives the day; days before this was so keep theirs
		var fit = []
		for k in range(slice):
			if _in_season("".join(bank[weekday * slice + k].rows), koyomi[4]):
				fit.append(weekday * slice + k)
		if not fit.is_empty():
			pick = fit[(day / 7) % fit.size()]
	var lv = bank[pick].duplicate(true)
	lv["kanji"] = "日課"
	lv["name"] = day_name(day)
	var season = "%s %s, %s" % [koyomi[0], koyomi[2], koyomi[3].to_lower()] if koyomi[2] != "" else "%s, %s" % [koyomi[0], koyomi[3].to_lower()]
	lv["hint"] = ("Today's kōan, for %s. One stroke, and only one. It is the same board for everyone today." if day == today() else "The kōan of a day gone by: %s. One stroke, and only one.") % season
	lv["hint"] += " " + grade_words(daily_grade(day), true)
	lv["koyomi"] = koyomi
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

# The day's answer as a picture to pass on (scripts/card.gd). It is painted off screen.
func daily_card(day, paths, cols, rows):
	var vp = SubViewport.new()
	vp.size = Vector2i(1080, 1080)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var c = load("res://scripts/card.gd").new()
	var d = Time.get_date_dict_from_unix_time(day * 86400)
	c.font = font
	c.day_name = day_name(day)
	c.koyomi = Koyomi.on(d.month, d.day)
	c.paths = paths
	c.cols = cols
	c.rows = rows
	c.tries = int(data.days.get(str(day), 1))
	c.streak = int(data.daily.streak) if day == today() else 0
	c.seal = my_seal()
	vp.add_child(c)
	add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img = vp.get_texture().get_image()
	vp.queue_free()
	return img

# Passes the card on: a phone's own share sheet where the browser has one, otherwise a picture
# saved (to the downloads in a browser, to Pictures on a desktop) with the line of words copied.
# Returns what to tell the player.
func share_daily(day, paths, cols, rows):
	var img = await daily_card(day, paths, cols, rows)
	var line = daily_line(day)
	var file = "jozu-%s.png" % day_name(day)
	if OS.has_feature("web"):
		var b64 = Marshalls.raw_to_base64(img.save_png_to_buffer())
		var js = "(function(b,t,n){var s=atob(b),u=new Uint8Array(s.length);for(var i=0;i<s.length;i++)u[i]=s.charCodeAt(i);var f=new File([u],n,{type:'image/png'});function dl(){var a=document.createElement('a');a.href=URL.createObjectURL(f);a.download=n;document.body.appendChild(a);a.click();a.remove();}if(navigator.canShare&&navigator.canShare({files:[f]})){navigator.share({files:[f],text:t}).catch(function(e){if(e&&e.name!=='AbortError')dl();});return 1;}dl();return 0;})(%s,%s,%s)" % [JSON.stringify(b64), JSON.stringify(line), JSON.stringify(file)]
		var shared = JavaScriptBridge.eval(js, true)
		return "" if int(shared) == 1 else "Saved as %s." % file
	DisplayServer.clipboard_set(line)
	var dir = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if dir == "" or img.save_png(dir.path_join(file)) != OK:
		return "The line is copied; the picture could not be saved."
	return "Saved to Pictures as %s; the line is copied." % file

# ---------------------------------------------------------------- the unmapped road
# A board drawn at random from the proven boards the story never used, by how hard it is.

const BRACKETS = [["易", "Gentle"], ["中", "Even"], ["難", "Hard"], ["極", "Master"]]
var last_random = -1

# A new board is made on the spot (scripts/forge.gd): in the browser by the generator compiled
# for it, on the desktop by the generator's own program. If that cannot be had, or finds nothing in
# time, one is drawn from the shelf.
var shelf_only = false      # tools/playtest.gd: no waiting

func show_random(br):
	if shelf_only:
		show_random_banked(br)
		return
	var scr = load("res://scripts/forge.gd").new()
	scr.br = br
	play_music("title")
	go(scr)

# Where the desktop's generator is: beside the game once it is exported (gen/gen.exe), and where
# it is built in the project otherwise. "" if there is none.
func gen_path():
	var nm = "gen.exe" if OS.get_name() == "Windows" else "gen"
	for p in [OS.get_executable_path().get_base_dir().path_join("gen").path_join(nm), ProjectSettings.globalize_path("res://tools/gen/bin/Release/net8.0/" + nm)]:
		if FileAccess.file_exists(p):
			return p
	return ""

func show_random_banked(br, why = ""):
	var bank = Extra.RANDOM
	var n = bank.size() / 4
	var lo = br * n
	var hi = bank.size() if br == 3 else lo + n
	var i = lo + randi() % max(1, hi - lo)
	if i == last_random:
		i = lo + (i - lo + 1) % max(1, hi - lo)
	last_random = i
	var lv = bank[i].duplicate(true)
	lv["hint"] = why + "A board from off the map, number %d of %d on the shelf. Mastery asks %d stroke%s. Clear it and you can copy its code to pass on." % [i + 1, bank.size(), int(lv.par), "" if int(lv.par) == 1 else "s"]
	_play_random(lv, br)

func _play_random(lv, br):
	lv["code"] = board_code(lv)
	lv["kanji"] = "乱"
	lv["name"] = "Off the map: %s" % BRACKETS[br][1].to_lower()
	lv["story"] = []
	lv["after"] = []
	lv["say"] = []
	show_custom(lv, "random", "The Unmapped Road", _random_won.bind(br), Callable(), show_hub)

# A board the generator has just made, as "rows|waza|rules|ink|par|answer|...". It is trusted only
# after its answer has been played through the real rules. Returns {} if it does not hold up.
func live_board(text):
	var p = text.split("|")
	if p.size() < 6 or p[0].length() != 49:
		return {}
	var lv = {"rows": [], "waza": Array(p[1].split(",", false)), "rules": Array(p[2].split(",", false)), "ink": int(p[3]), "par": int(p[4]), "sol": p[5]}
	for y in range(7):
		lv.rows.append(p[0].substr(y * 7, 7))
	if board_from_code(board_code(lv)).is_empty() or not solution_holds(lv):
		return {}
	return lv

func solution_holds(lv):
	var Sim = preload("res://scripts/sim.gd")
	var dirs = {"R": Vector2i(1, 0), "L": Vector2i(-1, 0), "D": Vector2i(0, 1), "U": Vector2i(0, -1)}
	var s = Sim.new_state(lv.rows, Data.base_stats(lv), lv.rules)
	for stroke in lv.sol.split(" / "):
		for tok in stroke.split(" ", false):
			var ok = false
			if tok == "KATSU":
				ok = Sim.act_katsu(s)
			elif tok == "BELL":
				ok = Sim.act_bell(s)
			elif not dirs.has(tok.right(1)):
				return false
			elif tok.begins_with("leap"):
				ok = Sim.act_leap(s, dirs[tok.right(1)])
			elif tok.begins_with("ward"):
				ok = Sim.act_ward(s, dirs[tok.right(1)])
			elif tok.length() == 1:
				ok = Sim.act_move(s, dirs[tok])
			if not ok:
				return false
		if s.status == "won":
			break
		Sim.end_stroke(s)
	return s.status == "won" and s.hits == 0 and s.turn == int(lv.par)

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
	lv["hint"] = "Temple %d of 88. No stroke can be taken back here. Staffs left: %d. %s" % [at + 1, int(h.staffs), grade_words(henro_grade(at))]
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

# the author has cleared their own board unharmed: their stroke count becomes its mastery target
func mine_won(grade, _mask, turns):
	var b = board_from_code(data.mine)
	if not b.is_empty() and grade == "jouzu":
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

# A board's code as a link: opened in a browser, it goes straight to that board.
const HOME = "https://ar0xa.github.io/jozu/"

func board_link(code):
	return HOME + "#" + code

# The page was opened by such a link: play the board it carries, once, and forget the link.
func _linked_board():
	if not OS.has_feature("web"):
		return false
	var hash = str(JavaScriptBridge.eval("window.location.hash || ''", true))
	if not hash.contains("JZ1."):
		return false
	JavaScriptBridge.eval("history.replaceState(null, '', window.location.pathname + window.location.search)", true)
	var b = board_from_code(hash)
	if b.is_empty():
		return false
	var lv = board_level(b)
	lv["code"] = board_code(b)
	lv["kanji"] = "伝"
	lv["name"] = "A board passed on"
	lv["hint"] = "Someone made this board and passed it on to you." + (" They mastered it in %d stroke%s." % [int(b.par), "" if int(b.par) == 1 else "s"] if int(b.par) > 0 else "")
	play_music("battle")
	show_custom(lv, "custom", "A board passed on", func(_g, _m, _t): return show_title, Callable(), show_title)
	return true

# The code may come with a link or other words around it: it is read from where it begins.
func board_from_code(code):
	var from = code.find("JZ1.")
	if from < 0:
		return {}
	code = code.substr(from).strip_edges()
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
	out.ink = clamp(int(parts[3]), 1, 40)   # a stone garden asks for as much ink as it has tiles
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

# The old prints shown before the great yokai (scripts/print.gd; sources in art/CREDITS.md):
# stage index -> [file, artist, title in Japanese, title in English, year, where it is kept]
const PRINTS = {
	9: ["ibaraki", "Tsukioka Yoshitoshi", "羅城門渡辺綱鬼腕斬之図", "Watanabe no Tsuna cuts off the demon's arm at Rashōmon", "1888", "National Diet Library, Japan"],
	19: ["sojobo", "Kawanabe Kyōsai", "", "Yoshitsune training with the tengu Sōjōbō", "1863", "Los Angeles County Museum of Art"],
	29: ["kuzunoha", "Tsukioka Yoshitoshi", "葛の葉きつね童子にわかるるの図", "The fox-woman Kuzunoha leaving her child", "about 1890", "Library of Congress"],
	39: ["shuten", "Tsukioka Yoshitoshi", "頼光四天王大江山鬼神退治之図", "Raikō and his four companions conquer the demon of Mount Ōe", "1864", "Minneapolis Institute of Art"],
	49: ["tamamo", "Utagawa Kunisada", "安倍泰成調伏妖怪図", "Abe no Yasunari exorcises Tamamo-no-Mae, the nine-tailed fox", "mid-19th century", "National Diet Library, Japan"],
	59: ["yukionna", "Tsukioka Yoshitoshi", "さぎむすめ", "The Heron Maiden, from New Forms of Thirty-six Ghosts", "1889", "Minneapolis Institute of Art"],
	69: ["kappa", "Tsukioka Yoshitoshi", "和漢百物語 白藤源太", "Shirafuji Genta watches kappa wrestle", "1865", "National Diet Library, Japan"],
	90: ["hyakki", "Kawanabe Kyōsai", "暁斎百鬼画談", "Kyōsai's Pictures of One Hundred Demons", "1890", "The Metropolitan Museum of Art"],
	99: ["gashadokuro", "Utagawa Kuniyoshi", "相馬の古内裏", "Takiyasha the Witch and the Skeleton Spectre", "about 1844", "National Diet Library, Japan"],
}

func start_stage(i):
	var story = show_story.bind(Data.LEVELS[i].story, show_battle.bind(i), i / float(Data.LEVELS.size()))
	if PRINTS.has(i) and grade_of(i) == "":
		var nm = "print_" + PRINTS[i][0]
		if art.has(nm):
			play_music("story")
			var scr = load("res://scripts/print.gd").new()
			scr.info = PRINTS[i]
			scr.after = story
			go(scr)
			return
		if late.has("art:" + nm):
			late.erase("art:" + nm)
			late.push_front("art:" + nm)   # not here yet (a browser): fetched next, for the next time
	story.call()

func show_battle(i):
	play_music(stage_music(i))
	var scr = load("res://scripts/battle.gd").new()
	scr.idx = i
	go(scr)
