extends "res://scripts/screen_base.gd"
# The unmapped road in the browser: a new board is made while you wait, by the same generator and
# solver that made the game's own stages (tools/genweb, running in a web worker).

const Extra = preload("res://scripts/extra.gd")
const BUDGETS = [15000, 22000, 25000, 30000]   # how long the generator may look, by bracket, in ms
const START = "(function(){ if (window.jozuGen) return 1; try { var g = {res: {}, dead: false, n: 0}; g.w = new Worker('gen/worker.js', {type: 'module'}); g.w.onmessage = function(ev) { var d = ev.data; if (d.ready) return; if (d.id === undefined) { g.dead = true; return; } g.res[d.id] = d.error ? '' : (d.out || ''); }; g.w.onerror = function() { g.dead = true; }; window.jozuGen = g; return 1; } catch (e) { return 0; } })()"
var br = 0
var job = 0
var waited = 0.0
var over = false

func setup():
	btn(Rect2(490, 470, 300, 50), "Take one from the shelf", _shelf, "棚")
	btn(Rect2(40, 656, 220, 46), "Back", _back, "道")
	if not JavaScriptBridge.eval(START, true):
		over = true
		main.show_random_banked.call_deferred(br)
		return
	var cuts = Extra.RANDOM_CUTS
	var lo = 0.0 if br == 0 else cuts[br - 1]
	var hi = 999.0 if br == 3 else cuts[br]
	job = int(JavaScriptBridge.eval("window.jozuGen.n += 1; window.jozuGen.n", true))
	JavaScriptBridge.eval("window.jozuGen.w.postMessage({id: %d, seed: %d, lo: %f, hi: %f, budget: %d, bracket: %d})" % [job, randi() % 2000000000, lo, hi, BUDGETS[br], br], true)

func _stop():
	# a generator still at work is let go, so the next request does not queue behind it
	if not over:
		JavaScriptBridge.eval("if (window.jozuGen) { window.jozuGen.w.terminate(); window.jozuGen = null; }", true)
	over = true

func _shelf():
	_stop()
	main.show_random_banked(br)

func _back():
	_stop()
	main.show_hub()

func on_key(code):
	if code == KEY_ESCAPE:
		_back()

func tick(dt):
	if over:
		return
	waited += dt
	var got = JavaScriptBridge.eval("(window.jozuGen && !window.jozuGen.dead) ? (window.jozuGen.res[%d] === undefined ? null : window.jozuGen.res[%d]) : ''" % [job, job], true)
	if got == null and waited * 1000.0 < BUDGETS[br] + 8000:
		return
	var lv = main.live_board(str(got)) if got != null else {}
	if lv.is_empty():
		_shelf()
		return
	over = true
	lv["hint"] = "Painted this moment: no one has seen this board before you. Mastery asks %d stroke%s. Clear it and you can copy its code to pass on." % [int(lv.par), "" if int(lv.par) == 1 else "s"]
	main._play_random(lv, br)

func _draw():
	var f = main.font
	draw_texture_rect(main.art["tohaku"], Rect2(0, 0, 1280, 720), false, Color(1, 1, 1, 0.4))
	Ink.tategaki(self, f, Vector2(64, 4), "乱", 46, Ink.SUMI)
	Ink.text(self, f, Vector2(110, 46), "The Unmapped Road", 32, Ink.SUMI)
	Ink.text(self, f, Vector2(110, 76), main.BRACKETS[br][1] + "  ·  a board no one has seen", 16, Ink.a(Ink.SUMI, 0.7))
	Ink.enso(self, Vector2(640, 300), 78, 13.0, Ink.SUMI, time * 1.6)
	Ink.text(self, f, Vector2(0, 318), "磨", 50, Ink.SHU, HORIZONTAL_ALIGNMENT_CENTER, 1280)
	Ink.text(self, f, Vector2(0, 420), "Tessai is grinding fresh ink.  %d" % int(waited), 20, Ink.SUMI, HORIZONTAL_ALIGNMENT_CENTER, 1280)
	Ink.text(self, f, Vector2(0, 446), "A new board is being laid out and solved. Harder ones take longer: up to half a minute.", 15, Ink.a(Ink.SUMI, 0.65), HORIZONTAL_ALIGNMENT_CENTER, 1280)
	draw_btns()
