extends SceneTree
# Automated playthrough:  godot --headless --path . -s tools/playtest.gd
# Drives the real screens (story, battle, result, map, training) through every stage with the
# stored solutions, alternating keyboard and mouse input, on a throwaway save file.

const Data = preload("res://scripts/data.gd")
const KEYS = {"R": KEY_RIGHT, "L": KEY_LEFT, "D": KEY_DOWN, "U": KEY_UP}
const DIR = {"R": Vector2i(1, 0), "L": Vector2i(-1, 0), "D": Vector2i(0, 1), "U": Vector2i(0, -1)}

var main
var sols
var fails = []

func _initialize():
	main = load("res://main.tscn").instantiate()
	main.save_path = "user://playtest_save.json"
	root.add_child(main)
	_run()

func bad(msg):
	fails.append(msg)
	print("  FAIL: ", msg)

func kind():
	return main.cur.get_script().resource_path.get_file().get_basename()

func frames(n = 1):
	for i in range(n):
		await process_frame

func skip_story():
	var guard = 0
	while kind() == "story" and guard < 60:
		main.cur.on_click(Vector2(640, 500), MOUSE_BUTTON_LEFT)
		await frames()
		guard += 1
	if kind() == "story":
		bad("story screen never ends")

func play(i, use_mouse):
	var lv = Data.LEVELS[i]
	var b = main.cur
	var trace = sols.get(lv.kanji + "|" + "".join(lv.rows), "")
	var strokes = trace.split(" / ")
	for k in range(strokes.size()):
		for tok in strokes[k].split(" ", false):
			var before = b.s.ink
			if tok == "KATSU":
				b.on_key(KEY_3)
			elif tok.begins_with("leap") or tok.begins_with("ward"):
				var d = tok.substr(4)
				b.on_key(KEY_1 if tok.begins_with("leap") else KEY_2)
				if b.mode == "":
					bad("stage %d: %s mode did not engage" % [i + 1, tok.substr(0, 4)])
				if use_mouse:
					b.on_click(b.ctr(b.s.hero + DIR[d] * (2 if tok.begins_with("leap") else 1)), MOUSE_BUTTON_LEFT)
				else:
					b.on_key(KEYS[d])
			elif use_mouse:
				b.on_click(b.ctr(b.s.hero + DIR[tok]), MOUSE_BUTTON_LEFT)
			else:
				b.on_key(KEYS[tok])
			if b.s.ink != before - 1 and not b.done:
				bad("stage %d: action %s was not accepted" % [i + 1, tok])
				return
			await frames()
		if b.done:
			break
		b.on_key(KEY_SPACE)
		await frames()

func _run():
	await frames(3)
	sols = JSON.parse_string(FileAccess.get_file_as_string("res://tools/solutions.json"))
	main.erase_save()
	if kind() != "title":
		bad("did not start on the title screen")

	# ---- title: sound toggle and its button
	var snd = main.data.sound
	main.cur.on_key(KEY_M)
	main._unhandled_input(_key(KEY_M))
	if main.data.sound == snd:
		bad("M does not toggle sound")
	main.toggle_sound()
	main.cur.on_key(KEY_ENTER)
	await frames(2)
	if kind() != "map":
		bad("Enter on the title does not open the map")

	# ---- map: locked stages must not start, tabs page correctly
	main.cur.hover_st = 5
	main.cur.on_click(main.cur.st_pos(5), MOUSE_BUTTON_LEFT)
	await frames()
	if kind() != "map":
		bad("a locked stage could be started")
	for c in range(Data.CHAPTERS.size()):
		main.cur._page(c)
		await frames()
	main.cur._page(0)

	# ---- undo, restart and losing, on stage 2
	main.show_battle(1)
	await frames(2)
	var b = main.cur
	b.on_key(KEY_RIGHT)
	b.on_key(KEY_RIGHT)
	if b.s.hero != Vector2i(2, 3):
		bad("arrow keys do not move Suzu")
	b.on_click(Vector2(10, 10), MOUSE_BUTTON_RIGHT)
	if b.s.hero != Vector2i(1, 3) or b.s.ink != 3:
		bad("right-click undo does not restore the last step")
	b.on_key(KEY_Z)
	b.on_key(KEY_Z)
	if b.s.hero != Vector2i(0, 3) or not b.hist.is_empty():
		bad("undo past the start misbehaves")
	b.on_key(KEY_RIGHT)
	b.on_key(KEY_R)
	if b.s.hero != Vector2i(0, 3) or b.s.turn != 0:
		bad("restart does not reset the stage")
	# drag: a held mouse moving across tiles paints a stroke
	b.on_click(b.ctr(Vector2i(1, 3)), MOUSE_BUTTON_LEFT)
	b.on_motion(b.ctr(Vector2i(2, 3)), true)
	b.on_motion(b.ctr(Vector2i(2, 3)) + Vector2(5, 5), true)
	b.on_motion(b.ctr(Vector2i(3, 3)), true)
	if b.s.hero != Vector2i(3, 3) or b.s.ink != 1:
		bad("dragging does not paint one step per tile (hero %s, ink %d)" % [str(b.s.hero), b.s.ink])
	b.on_key(KEY_R)
	var guard = 0
	while not b.done and guard < 20:
		b.on_key(KEY_SPACE)
		await frames()
		guard += 1
	if b.grade != "lost":
		bad("standing still beside an oni does not lose (grade '%s')" % b.grade)
	else:
		b.extra[0].cb.call()
		if b.done or b.s.status != "play":
			bad("'Take it back' after a loss does not resume play")
	if main.grade_of(1) != "":
		bad("a lost stage was recorded as cleared")

	# ---- a sloppy win must grade as passed, not mastered
	main.show_battle(0)
	await frames(2)
	b = main.cur
	b.on_key(KEY_SPACE)
	await play(0, false)
	if b.grade != "ka":
		bad("winning one stroke over par graded '%s', expected 'ka'" % b.grade)
	if main.grade_of(0) != "ka" or main.points() != 1:
		bad("a pass should be saved and worth 1 point (grade %s, points %d)" % [main.grade_of(0), main.points()])

	# ---- the whole road
	for i in range(Data.LEVELS.size()):
		var lv = Data.LEVELS[i]
		if not main.unlocked(i):
			bad("stage %d is locked when reached in order" % (i + 1))
		main.show_map()
		await frames()
		main.cur._page(main.cur._chapter_of(i))
		main.cur.on_click(main.cur.st_pos(i), MOUSE_BUTTON_LEFT)
		await frames()
		if lv.story.is_empty():
			if kind() != "battle":
				bad("stage %d: clicking the station did not start the battle" % (i + 1))
				continue
		else:
			if kind() != "story":
				bad("stage %d: story did not show" % (i + 1))
			await skip_story()
		if kind() != "battle":
			bad("stage %d: no battle after the story" % (i + 1))
			continue
		b = main.cur
		var first = main.grade_of(i) != "jouzu"
		await play(i, i % 2 == 1)
		await frames(2)
		if not b.done or b.grade != "jouzu":
			bad("stage %d %s: finished with grade '%s' (turn %d, par %d, hits %d)" % [i + 1, lv.kanji, b.grade, b.s.turn, lv.par, b.s.hits])
			continue
		if main.grade_of(i) != "jouzu":
			bad("stage %d: mastery was not saved" % (i + 1))
		if b.b_undo.on:
			bad("stage %d: undo still enabled after winning" % (i + 1))
		b.extra[0].cb.call()   # Onward
		await frames()
		if first and not lv.after.is_empty() and i != 0:
			if kind() != "story":
				bad("stage %d: closing story did not show" % (i + 1))
		await skip_story()
		if kind() != "map":
			bad("stage %d: 'Onward' did not return to the map" % (i + 1))
		if i % 10 == 9:
			print("  chapter %d cleared" % (i / 10 + 1))

	# ---- saving survives a reload
	var saved = main.data.cleared.duplicate()
	main.load_save()
	if main.data.cleared != saved or main.data.cleared.size() != Data.LEVELS.size():
		bad("progress did not survive a save and reload")
	if main.points_total() != 2 * Data.LEVELS.size():
		bad("expected %d points after mastering everything, got %d" % [2 * Data.LEVELS.size(), main.points_total()])

	# ---- training
	main.show_dojo()
	await frames(2)
	var d = main.cur
	var p0 = main.points()
	for rep in range(3):
		for r in d.rows:
			if r.on:
				r.cb.call()
		await frames()
	for k in main.data.up:
		if int(main.data.up[k]) != d.MAXLV:
			bad("training: %s stopped at level %d" % [k, int(main.data.up[k])])
	if main.points() != p0 - 25:
		bad("training: buying everything should cost 25 points, cost %d" % (p0 - main.points()))
	var st = main.stats_for(99)
	if st.ink != Data.BASE_INK + 2 or st.ki != Data.BASE_KI + 2:
		bad("training does not change battle stats")
	d._reset()
	if main.points() != p0:
		bad("'Unlearn all' does not refund points")
	await frames()

	# ---- replaying a mastered stage skips nothing it shouldn't, and keeps the seal
	main.start_stage(3)
	await skip_story()
	b = main.cur
	b.on_key(KEY_ESCAPE)
	await frames()
	if kind() != "map" or main.grade_of(3) != "jouzu":
		bad("leaving a replayed stage lost its seal or did not return to the map")

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://playtest_save.json"))
	print("playtest finished: %d problem(s)" % fails.size())
	for f in fails:
		print("  - ", f)
	quit(1 if fails.size() > 0 else 0)

func _key(code):
	var e = InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e
