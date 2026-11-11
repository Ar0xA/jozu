extends "res://scripts/screen_base.gd"
# The unmapped road in the browser: a new board is made while you wait, by the same generator and
# solver that made the game's own stages (tools/genweb, running in a web worker).

const Extra = preload("res://scripts/extra.gd")
const BUDGETS = [12000, 18000, 22000, 30000]   # how long the generator may look, by bracket, in ms
const START = "(function(){ if (window.jozuGen) return 1; try { var g = {res: {}, part: {}, dead: 0, n: 0, w: []}; var many = (navigator.hardwareConcurrency || 2) >= 4 ? 2 : 1; for (var k = 0; k < many; k++) { (function(){ var w = new Worker('gen/worker.js', {type: 'module'}); w.onmessage = function(ev) { var d = ev.data; if (d.ready) return; if (d.id === undefined) { g.dead++; return; } var out = d.error ? '' : (d.out || ''); var p = g.part[d.id] || (g.part[d.id] = []); p.push(out); var exact = out.length > 2 && out.charAt(out.length - 1) === '1'; if (g.res[d.id] === undefined && (exact || p.length >= g.w.length)) { var best = ''; for (var i = 0; i < p.length; i++) { if (p[i].length > best.length || (p[i].length > 2 && p[i].charAt(p[i].length - 1) === '1')) best = p[i]; } g.res[d.id] = exact ? out : best; } }; w.onerror = function() { g.dead++; }; g.w.push(w); })(); } window.jozuGen = g; return 1; } catch (e) { return 0; } })()"
const WAIT = [
	"A new board is being laid out and solved for you. A gentle one takes a moment.",
	"A new board is being laid out and solved for you. This usually takes a few seconds.",
	"A new board is being laid out and solved for you. Hard ones take longer: often ten seconds or so.",
	"A new board is being laid out and solved for you. A master's board takes longest: often ten to twenty seconds.",
]
var br = 0
var job = 0
var waited = 0.0
var over = false
var demo = false      # draw the screen without starting a generator (tools/shots.gd)

func setup():
	btn(Rect2(490, 470, 300, 50), "Take one from the shelf", _shelf, "棚")
	btn(Rect2(40, 656, 220, 46), "Back", _back, "道")
	if demo:
		waited = 11.0
		return
	if not JavaScriptBridge.eval(START, true):
		over = true
		main.show_random_banked.call_deferred(br)
		return
	var cuts = Extra.RANDOM_CUTS
	var lo = 0.0 if br == 0 else cuts[br - 1]
	var hi = 999.0 if br == 3 else cuts[br]
	job = int(JavaScriptBridge.eval("window.jozuGen.n += 1; window.jozuGen.n", true))
	JavaScriptBridge.eval("window.jozuGen.w.forEach(function(w, k) { w.postMessage({id: %d, seed: %d + k * 7919, lo: %f, hi: %f, budget: %d, bracket: %d, order: %d}); })" % [job, randi() % 2000000000, lo, hi, BUDGETS[br], br, randi() % 2000000000], true)

func _stop():
	# a generator still at work is let go, so the next request does not queue behind it
	if not over:
		JavaScriptBridge.eval("if (window.jozuGen) { window.jozuGen.w.forEach(function(w) { w.terminate(); }); window.jozuGen = null; }", true)
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
	if over or demo:
		return
	waited += dt
	var got = JavaScriptBridge.eval("(window.jozuGen && window.jozuGen.dead < window.jozuGen.w.length) ? (window.jozuGen.res[%d] === undefined ? null : window.jozuGen.res[%d]) : ''" % [job, job], true)
	if got == null and waited * 1000.0 < BUDGETS[br] + 8000:
		return
	var lv = main.live_board(str(got)) if got != null else {}
	if lv.is_empty():
		# nothing of the right weight turned up in time: say so, and take one from the shelf
		_stop()
		main.show_random_banked(br, "No new board of this weight turned up in time, so this one is from the shelf. ")
		return
	# once a board is found the other generator is stopped, so it does not hold up the next request
	JavaScriptBridge.eval("if (window.jozuGen) { window.jozuGen.w.forEach(function(w) { w.terminate(); }); window.jozuGen = null; }", true)
	over = true
	lv["hint"] = "Painted this moment: no one has seen this board before you. Mastery asks %d stroke%s. Clear it and you can copy its code to pass on." % [int(lv.par), "" if int(lv.par) == 1 else "s"]
	main._play_random(lv, br)

func _draw():
	var f = main.font
	draw_texture_rect(main.art["tohaku"], Rect2(0, 0, 1280, 720), false, Color(1, 1, 1, 0.4))
	Ink.tategaki(self, f, Vector2(64, 4), "乱", 46, Ink.SUMI)
	Ink.text(self, f, Vector2(110, 46), "The Unmapped Road", 32, Ink.SUMI)
	Ink.text(self, f, Vector2(110, 76), main.BRACKETS[br][1] + "  ·  a board no one has seen", 16, Ink.a(Ink.SUMI, 0.7))
	Ink.enso(self, Vector2(640, 250), 78, 13.0, Ink.SUMI, time * 1.6)
	Ink.text(self, f, Vector2(0, 268), "磨", 50, Ink.SHU, HORIZONTAL_ALIGNMENT_CENTER, 1280)
	var limit = BUDGETS[br] / 1000
	Ink.text(self, f, Vector2(0, 366), "Tessai is grinding fresh ink.", 22, Ink.SUMI, HORIZONTAL_ALIGNMENT_CENTER, 1280)
	Ink.text(self, f, Vector2(0, 392), WAIT[br], 15, Ink.a(Ink.SUMI, 0.7), HORIZONTAL_ALIGNMENT_CENTER, 1280)
	# how long it has been, against how long it may take
	var bar = Rect2(440, 412, 400, 10)
	draw_rect(bar, Ink.a(Ink.SUMI, 0.12))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clamp(waited / limit, 0.0, 1.0), bar.size.y)), Ink.a(Ink.SHU, 0.8))
	Ink.text(self, f, Vector2(0, 446), "%d of at most %d seconds. If nothing turns up, a board comes from the shelf instead." % [int(waited), limit], 14, Ink.a(Ink.SUMI, 0.6), HORIZONTAL_ALIGNMENT_CENTER, 1280)
	draw_btns()
