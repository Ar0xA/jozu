extends SceneTree
# Automated playthrough:  godot --headless --path . -s tools/playtest.gd
# Drives the real screens (story, battle, result, map, training) through every stage with the
# stored solutions, alternating keyboard and mouse input, on a throwaway save file.

const Data = preload("res://scripts/data.gd")
const Extra = preload("res://scripts/extra.gd")
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

func play(i, use_mouse, lv = null):
	if lv == null:
		lv = Data.LEVELS[i]
	var b = main.cur
	var trace = lv.get("sol", "")
	var strokes = trace.split(" / ")
	for k in range(strokes.size()):
		for tok in strokes[k].split(" ", false):
			var before = b.s.ink
			if tok == "KATSU":
				b.on_key(KEY_3)
			elif tok.begins_with("leap") or tok.begins_with("ward") or tok.begins_with("shiki"):
				var d = tok.right(1)
				b.on_key(KEY_1 if tok.begins_with("leap") else (KEY_2 if tok.begins_with("ward") else KEY_4))
				if b.mode == "":
					bad("stage %d: %s mode did not engage" % [i + 1, tok.left(tok.length() - 1)])
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
	if main.grade_of(0) != "ka" or main.seals_of(0) & 3 != 0:
		bad("a pass should be saved without the mastery seals (grade %s, seals %d)" % [main.grade_of(0), main.seals_of(0)])

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
		# the master's hint must show the solution's first stroke from a fresh board
		b.on_key(KEY_H)
		if b.hint_msg != "" and not b.hint_msg.begins_with("The master waits"):
			bad("stage %d: hint refused on a fresh board: %s" % [i + 1, b.hint_msg])
		elif b.hint_path.size() < 2 and b.hint_marks.is_empty() and b.hint_msg == "":
			bad("stage %d: hint shows nothing" % (i + 1))
		await frames()
		if lv.get("rules", []).has("koan") or lv.get("rules", []).has("garden"):
			b.on_key(KEY_SPACE)
			if b.grade != "lost":
				bad("stage %d: sheathing a one-stroke stage unfinished should fail" % (i + 1))
			b.on_key(KEY_R)
		await play(i, i % 2 == 1)
		await frames(2)
		if not b.done or b.grade != "jouzu":
			bad("stage %d %s: finished with grade '%s' (turn %d, par %d, hits %d)" % [i + 1, lv.kanji, b.grade, b.s.turn, lv.par, b.s.hits])
			continue
		if main.grade_of(i) != "jouzu":
			bad("stage %d: mastery was not saved" % (i + 1))
		if main.seals_of(i) != 7:
			bad("stage %d: the master's line without undo should earn all three seals, got %d" % [i + 1, main.seals_of(i)])
		if not main.data.scroll.has(str(i)) or main.data.scroll[str(i)].size() != lv.par:
			bad("stage %d: the scroll did not keep %d strokes" % [i + 1, lv.par])
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
	if main.points_total() != 4 * Data.LEVELS.size():
		bad("expected %d points after earning every seal, got %d" % [4 * Data.LEVELS.size(), main.points_total()])
	if main.rank()[0] != "名人":
		bad("every seal earned should be the rank of meijin, got %s" % main.rank()[0])

	# ---- the scroll gallery, every chapter
	main.show_scroll()
	await frames(2)
	if kind() != "scroll":
		bad("the scroll gallery does not open")
	else:
		for c in range(Data.CHAPTERS.size()):
			main.cur._page(c)
			await frames()
	main.load_save()
	if main.data.scroll.size() != Data.LEVELS.size():
		bad("the scroll did not survive a reload")

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

	await other_roads()

	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://playtest_save.json"))
	print("playtest finished: %d problem(s)" % fails.size())
	for f in fails:
		print("  - ", f)
	quit(1 if fails.size() > 0 else 0)

# ---- the daily koan, the 88 temples and the workshop
func other_roads():
	main.show_map()
	await frames()
	for bt in main.cur.btns:
		if bt.label == "More":
			bt.cb.call()
	await frames(2)
	if kind() != "hub":
		bad("the map's More button does not open the other roads")
		return

	# the daily koan
	if main.daily_done():
		bad("the daily koan is answered on a fresh save")
	main.show_daily()
	await frames(2)
	var b = main.cur
	if kind() != "battle" or b.kind_of != "daily":
		bad("the daily koan does not open")
		return
	b.on_key(KEY_H)
	if b.hint_path.size() < 2:
		bad("the daily koan has no hint")
	await play(-1, true, b.lv)
	await frames(2)
	if b.grade != "jouzu":
		bad("the daily koan's stored answer graded '%s'" % b.grade)
	else:
		b.extra[0].cb.call()
		await frames(2)
		if kind() != "hub":
			bad("the daily koan does not lead back to the other roads")
	if not main.daily_done() or int(main.data.daily.streak) != 1 or int(main.data.daily.best) != 1:
		bad("the daily koan was not recorded")
	if int(main.data.cleared.size()) != Data.LEVELS.size():
		bad("a board outside the story changed the story's record")
	main.data.daily.day -= 1     # as if that had been yesterday
	main.data.daily.last -= 1
	main._daily_won("jouzu", 7, 1)
	if int(main.data.daily.streak) != 2:
		bad("answering on the next day does not lengthen the streak")
	main.data.daily.day -= 3
	main.data.daily.last -= 3
	main._daily_won("jouzu", 7, 1)
	if int(main.data.daily.streak) != 1 or int(main.data.daily.best) != 2:
		bad("a missed day does not reset the streak")

	# the pilgrimage: losing staffs
	main.show_henro()
	await frames(2)
	b = main.cur
	if b.kind_of != "henro" or b.b_hint.on:
		bad("a temple offers the master's hint")
	b.on_key(KEY_UP)
	b.on_key(KEY_LEFT)
	var where = b.s.hero
	b.on_key(KEY_Z)
	if b.s.hero != where:
		bad("a pilgrim could take a step back")
	b.on_key(KEY_R)              # give up this temple
	await frames(2)
	if int(main.data.henro.staffs) != 2 or int(main.data.henro.at) != 0 or kind() != "battle":
		bad("giving up a temple should cost one staff and stay at it")
	main.cur.on_key(KEY_R)
	await frames()
	main.cur.on_key(KEY_R)
	await frames(2)
	if int(main.data.henro.staffs) != 3 or int(main.data.henro.at) != 0 or kind() != "hub":
		bad("losing the last staff should begin the pilgrimage again")

	# walking out mid-temple costs a staff; walking out untouched does not
	main.show_henro()
	await frames(2)
	main.cur.on_key(KEY_ESCAPE)
	await frames(2)
	if int(main.data.henro.staffs) != 3:
		bad("leaving an untouched temple cost a staff")
	main.show_henro()
	await frames(2)
	main.cur.on_key(KEY_UP)
	main.cur.on_key(KEY_ESCAPE)
	await frames(2)
	if int(main.data.henro.staffs) != 2 or kind() != "hub":
		bad("walking out of a temple mid-stroke should cost a staff")
	main.data.henro.staffs = 3

	# the pilgrimage: all 88
	main.show_henro()
	await frames(2)
	for t in range(Extra.HENRO.size()):
		b = main.cur
		if kind() != "battle" or int(main.data.henro.at) != t:
			bad("temple %d did not open" % (t + 1))
			return
		await play(-1, t % 2 == 0, b.lv)
		await frames(2)
		if not b.done or (b.grade != "jouzu" and b.grade != "ka"):
			bad("temple %d: finished with grade '%s'" % [t + 1, b.grade])
			return
		b.extra[0].cb.call()
		await frames(2)
	if kind() != "hub" or int(main.data.henro.done) != 1 or int(main.data.henro.best) != 88:
		bad("finishing the 88 temples was not recorded")
	main.cur.queue_redraw()
	await frames(2)

	# the workshop
	main.show_editor()
	await frames(2)
	var e = main.cur
	if kind() != "editor":
		bad("the workshop does not open")
		return
	if e._problem() == "":
		bad("an empty board can be played")
	e.tool_btns["o"].cb.call()
	e.on_click(e.ORG + Vector2(3.5, 2.5) * e.TS, MOUSE_BUTTON_LEFT)
	e.on_motion(e.ORG + Vector2(4.5, 2.5) * e.TS, true)
	if e.st.rows[2] != "...oo..":
		bad("painting on the workshop board gives %s" % e.st.rows[2])
	e.tool_btns["H"].cb.call()
	e.on_click(e.ORG + Vector2(0.5, 0.5) * e.TS, MOUSE_BUTTON_LEFT)
	if "".join(e.st.rows).count("H") != 1 or e.st.rows[0][0] != "H":
		bad("placing Suzu twice leaves two of her")
	for r in ["wind", "wind", "rain", "koan", "koan"]:
		e.rule_btns[r].cb.call()
	if not e.st.rules.has("wind:L") or not e.st.rules.has("rain") or e.st.rules.has("koan"):
		bad("the workshop's rule buttons misbehave: %s" % str(e.st.rules))
	if e.line.text != "":
		bad("an uncleared board already has a code")
	# lay out stage 1 and clear it
	var lv = Data.LEVELS[0]
	e._clear()
	e.st.rows = lv.rows.duplicate()
	e.st.ink = Data.base_stats(lv).ink
	e._changed()
	await frames(2)
	e._test()
	await frames(2)
	b = main.cur
	if kind() != "battle" or b.kind_of != "custom":
		bad("'Play it' does not start the board")
		return
	await play(-1, false, lv)
	await frames(2)
	if b.grade != "jouzu" and b.grade != "ka":
		bad("the workshop board graded '%s'" % b.grade)
		return
	b.extra[0].cb.call()
	await frames(2)
	e = main.cur
	if kind() != "editor" or int(e.st.par) != lv.par or not e.line.text.begins_with("JZ1."):
		bad("clearing a workshop board does not make its code")
		return
	var code = e.line.text
	var back = main.board_from_code(code)
	if back.is_empty() or back.rows != lv.rows or int(back.par) != lv.par or int(back.ink) != int(e.st.ink):
		bad("a board code does not read back as the same board")
	for junk in ["", "JZ1.", "JZ1.!!!!", "hello", code.substr(0, code.length() - 6), "JZ1." + Marshalls.utf8_to_base64("x|y")]:
		if not main.board_from_code(junk).is_empty():
			bad("a broken code was accepted: " + junk)
	e._clear()
	e.line.text = "  " + code + " "
	e._load()
	if e.st.rows != lv.rows or int(e.st.par) != lv.par:
		bad("loading a code does not bring the board back")
	main.load_save()
	if main.data.mine != code or int(main.data.henro.done) != 1:
		bad("the workshop board or the pilgrimage did not survive a reload")
	e.on_key(KEY_ESCAPE)
	await frames(2)
	if kind() != "hub":
		bad("Escape does not leave the workshop")

func _key(code):
	var e = InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e
