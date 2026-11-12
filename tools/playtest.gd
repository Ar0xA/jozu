extends SceneTree
# Automated playthrough:  godot --headless --path . -s tools/playtest.gd
# Drives the real screens (story, battle, result, map, training) through every stage with the
# stored solutions, alternating keyboard and mouse input, on a throwaway save file.

const Data = preload("res://scripts/data.gd")
const Extra = preload("res://scripts/extra.gd")
const KEYS = {"R": KEY_RIGHT, "L": KEY_LEFT, "D": KEY_DOWN, "U": KEY_UP}
const DIR = {"R": Vector2i(1, 0), "L": Vector2i(-1, 0), "D": Vector2i(0, 1), "U": Vector2i(0, -1)}

var main
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

# a key for the screen, once the goal card (which would take it) has been put away
func key(scr, code):
	if scr.get("card"):
		scr.card = []
	scr.on_key(code)

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
				key(b, KEY_3)
			elif tok == "BELL":
				key(b, KEY_5)
			elif tok.begins_with("leap") or tok.begins_with("ward") or tok.begins_with("shiki"):
				var d = tok.right(1)
				key(b, KEY_1 if tok.begins_with("leap") else (KEY_2 if tok.begins_with("ward") else KEY_4))
				if b.mode == "":
					bad("stage %d: %s mode did not engage" % [i + 1, tok.left(tok.length() - 1)])
				if use_mouse:
					b.on_click(b.ctr(b.s.hero + DIR[d] * (2 if tok.begins_with("leap") else 1)), MOUSE_BUTTON_LEFT)
				else:
					key(b, KEYS[d])
			elif use_mouse:
				b.on_click(b.ctr(b.s.hero + DIR[tok]), MOUSE_BUTTON_LEFT)
			else:
				key(b, KEYS[tok])
			if b.s.ink >= before and not b.done:
				bad("stage %d: action %s was not accepted" % [i + 1, tok])
				return
			await frames()
		if b.done:
			break
		key(b, KEY_SPACE)
		await frames()

func _run():
	await frames(3)
	main.erase_save()
	if kind() != "title":
		bad("did not start on the title screen")

	# ---- the gate: a chapter's last station asks for two-thirds of the chapter mastered
	var g0 = main.gate_of(0)
	for i in range(g0[0], g0[1]):
		main.record(i, "ka")
	if main.unlocked(g0[1]) or main.held_chapter() != 0 or main.gate_words() == "":
		bad("a chapter passed without mastery should find its last station shut, and say why")
	main.show_map()
	await frames(2)
	if main.cur.notice == "":
		bad("the map does not explain the gate when the road is first held")
	key(main.cur, KEY_SPACE)
	main.cur.on_click(main.cur.st_pos(g0[1]), MOUSE_BUTTON_LEFT)
	if kind() != "map" or main.cur.notice == "":
		bad("clicking the shut station should explain the gate, not open it")
	for i in range(g0[0], g0[0] + g0[3] - 1):
		main.record(i, "jouzu")
	if main.unlocked(g0[1]):
		bad("the gate opened one mastery short")
	main.record(g0[0] + g0[3] - 1, "jouzu")
	if not main.unlocked(g0[1]) or main.held_chapter() != -1:
		bad("the gate did not open at two-thirds mastered")
	main.erase_save()
	main.show_title()
	await frames(2)

	# ---- title: sound toggle and its button
	var snd = main.data.sound
	key(main.cur, KEY_M)
	main._unhandled_input(_key(KEY_M))
	if main.data.sound == snd:
		bad("M does not toggle sound")
	main.toggle_sound()
	key(main.cur, KEY_ENTER)
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
	key(b, KEY_RIGHT)
	key(b, KEY_RIGHT)
	if b.s.hero != Vector2i(2, 3):
		bad("arrow keys do not move Suzu")
	b.on_click(Vector2(10, 10), MOUSE_BUTTON_RIGHT)
	if b.s.hero != Vector2i(1, 3) or b.s.ink != 3:
		bad("right-click undo does not restore the last step")
	key(b, KEY_Z)
	key(b, KEY_Z)
	if b.s.hero != Vector2i(0, 3) or not b.hist.is_empty():
		bad("undo past the start misbehaves")
	key(b, KEY_RIGHT)
	key(b, KEY_R)
	if b.s.hero != Vector2i(0, 3) or b.s.turn != 0:
		bad("restart does not reset the stage")
	# drag: a held mouse moving across tiles paints a stroke
	b.on_click(b.ctr(Vector2i(1, 3)), MOUSE_BUTTON_LEFT)
	b.on_motion(b.ctr(Vector2i(2, 3)), true)
	b.on_motion(b.ctr(Vector2i(2, 3)) + Vector2(5, 5), true)
	b.on_motion(b.ctr(Vector2i(3, 3)), true)
	if b.s.hero != Vector2i(3, 3) or b.s.ink != 1:
		bad("dragging does not paint one step per tile (hero %s, ink %d)" % [str(b.s.hero), b.s.ink])
	key(b, KEY_R)
	var guard = 0
	while not b.done and guard < 20:
		key(b, KEY_SPACE)
		await frames()
		guard += 1
	if b.grade != "lost":
		bad("standing still beside an oni does not lose (grade '%s')" % b.grade)
	else:
		b.extra[0].cb.call()
		if b.done or b.s.status != "play":
			bad("'Begin again' after a loss does not resume play")
	if main.grade_of(1) != "":
		bad("a lost stage was recorded as cleared")

	# ---- a sloppy win must grade as passed, not mastered
	main.show_battle(0)
	await frames(2)
	b = main.cur
	key(b, KEY_SPACE)
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
		key(b, KEY_H)
		if b.hint_msg != "" and not b.hint_msg.begins_with("The master waits"):
			bad("stage %d: hint refused on a fresh board: %s" % [i + 1, b.hint_msg])
		elif b.hint_path.size() < 2 and b.hint_marks.is_empty() and b.hint_msg == "":
			bad("stage %d: hint shows nothing" % (i + 1))
		await frames()
		if lv.get("rules", []).has("koan") or lv.get("rules", []).has("garden"):
			key(b, KEY_SPACE)
			if b.grade != "lost":
				bad("stage %d: sheathing a one-stroke stage unfinished should fail" % (i + 1))
			# begin the stage afresh: a restart would forfeit the seal for a first attempt
			main.show_battle(i)
			await frames()
			b = main.cur
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
	key(b, KEY_ESCAPE)
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
	key(b, KEY_H)
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
	main._daily_won("jouzu", 7, 1, main.today(), Callable())
	if int(main.data.daily.streak) != 2:
		bad("answering on the next day does not lengthen the streak")
	main.data.daily.day -= 3
	main.data.daily.last -= 3
	main._daily_won("jouzu", 7, 1, main.today(), Callable())
	if int(main.data.daily.streak) != 1 or int(main.data.daily.best) != 2:
		bad("a missed day does not reset the streak")

	# days gone by: yesterday's koan, failed once and then answered
	var streak0 = int(main.data.daily.streak)
	main.show_calendar()
	await frames(2)
	if kind() != "daily":
		bad("the calendar does not open")
	else:
		var yday = main.today() - 1
		main.cur.on_click(main.cur._cell(yday).get_center(), MOUSE_BUTTON_LEFT)
		await frames(2)
		b = main.cur
		if kind() != "battle" or b.kind_of != "daily" or int(b.lv.day) != yday:
			bad("clicking a past day does not open its koan")
		else:
			key(b, KEY_SPACE)
			if int(main.data.tries.get(str(yday), 0)) != 1:
				bad("a failed attempt at a daily koan was not counted")
			key(b, KEY_R)
			await play(-1, false, b.lv)
			await frames(2)
			if int(main.data.days.get(str(yday), 0)) != 2:
				bad("a past day answered on the second attempt should record 2")
			if int(main.data.daily.streak) != streak0:
				bad("a past day changed the run of days")
			b.extra[0].cb.call()
			await frames(2)
			if kind() != "daily":
				bad("a past day does not lead back to the calendar")
		if not main.daily_line(main.today()).contains("daily kōan") or main.daily_line(main.today() - 20) != "":
			bad("the daily result line is wrong")

	# every board on the shelf must survive being made into a code and read back
	var lost = 0
	for bd in Extra.RANDOM:
		var rt = main.board_from_code(main.board_code(bd))
		if rt.is_empty() or rt.rows != bd.rows or rt.rules != bd.rules or rt.waza != bd.waza or int(rt.ink) != int(bd.ink) or int(rt.par) != int(bd.par):
			lost += 1
	if lost > 0:
		bad("%d of the shelf's boards do not survive their own share code" % lost)

	# the unmapped road: one board from each bracket, and its code
	for br in range(4):
		main.show_random(br)
		await frames(2)
		b = main.cur
		if kind() != "battle" or b.kind_of != "random":
			bad("the unmapped road does not open (bracket %d)" % br)
			continue
		var back2 = main.board_from_code(b.lv.code)
		if back2.is_empty() or back2.rows != b.lv.rows or back2.rules != b.lv.rules or int(back2.ink) != int(b.lv.ink):
			bad("an unmapped board's code does not read back (bracket %d)" % br)
		await play(-1, br % 2 == 0, b.lv)
		await frames(2)
		if b.grade != "jouzu":
			bad("an unmapped board's stored answer graded '%s' (bracket %d)" % [b.grade, br])
			continue
		b.extra[0].cb.call()
		await frames(2)
		if kind() != "battle" or main.cur == b:
			bad("'Another' does not deal another board")
		if int(main.data.rand.get(str(br), 0)) != 1:
			bad("an unmapped clear was not counted")

	# a board handed over by the live generator is trusted only if its answer plays out
	var lv0 = Data.LEVELS[0]
	var text = "".join(lv0.rows) + "||" + "|%d|%d|%s|40.0|3|900|1" % [Data.base_stats(lv0).ink, lv0.par, lv0.sol]
	var made = main.live_board(text)
	if made.is_empty() or made.rows != lv0.rows:
		bad("a sound generated board was refused")
	if not main.live_board(text.replace(lv0.sol, "U")).is_empty():
		bad("a generated board with a wrong answer was accepted")
	if not main.live_board("").is_empty() or not main.live_board("x|y|z|1|1|U").is_empty():
		bad("rubbish from the generator was accepted")

	# zoom: the button's way, the two-finger way, and back
	main.set_zoom(2.0, Vector2(900, 500))
	if abs(main.scale.x - 2.0) > 0.01 or main.position.x > 0.0 or main.position.x < -1280.0 or main.position.y < -720.0:
		bad("zooming in leaves the page out of place: scale %s at %s" % [str(main.scale), str(main.position)])
	main.set_zoom(1.0)
	if main.scale != Vector2.ONE or main.position != Vector2.ZERO:
		bad("zooming back out does not restore the page")
	for k in range(2):
		var t = InputEventScreenTouch.new()
		t.index = k
		t.pressed = true
		t.position = Vector2(500 + k * 200, 360)
		main._input(t)
	if not main.pinching:
		bad("two fingers down are not taken as a pinch")
	var dg = InputEventScreenDrag.new()
	dg.index = 1
	dg.position = Vector2(900, 360)
	main._input(dg)
	if main.zoom < 1.8 or main.zoom > 2.2:
		bad("spreading two fingers to twice the distance gives zoom %.2f" % main.zoom)
	for k in range(2):
		var t = InputEventScreenTouch.new()
		t.index = k
		t.pressed = false
		main._input(t)
	if main.pinching:
		bad("lifting the fingers leaves the pinch on")
	main.set_zoom(1.0)

	# with a mouse, a click on the card is the card's, and a click beside it goes through
	main.show_battle(Data.WAZA_FROM["leap"])
	await frames(2)
	var bm = main.cur
	var click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = bm._card_rect(main.font).get_center()
	var h0 = bm.s.hero
	bm._gui_input(click)
	if not bm.card.is_empty() or bm.s.hero != h0:
		bad("a click on the card should close it and do nothing else")
	bm._brief(false)
	click.position = bm.b_leap.rect.get_center()
	bm._gui_input(click)
	if not bm.card.is_empty() or bm.mode != "leap":
		bad("a click on a button beside the card should close the card and press the button")
	bm._mode("leap")

	# the card over a stage: there when it opens, gone at a key, back when asked for
	main.show_battle(0)
	await frames(2)
	var bc = main.cur
	if bc.card.size() < 3 or not main.data.met.has("y:chochin"):
		bad("a stage opens without its goal card, or does not note what was met")
	var at0 = bc.s.hero
	bc.on_key(KEY_UP)
	if not bc.card.is_empty() or bc.s.hero != at0:
		bad("a key should put the goal card away and do nothing else")
	bc._brief(false)
	if bc.card.size() < 4:
		bad("asking for the goal again shows nothing")
	bc.card = []

	# the phone layout: every button on the page, none on top of another, and the stage still plays
	main.touch = true
	for st in [1, Data.CHAPTERS[25].from + 3, Data.CHAPTERS[27].from + 2]:
		main.show_battle(st)
		await frames(2)
		var bp = main.cur
		if bp.card.is_empty():
			bad("stage %d opens without its card on a phone" % (st + 1))
		var tap = InputEventMouseButton.new()
		tap.button_index = MOUSE_BUTTON_LEFT
		tap.pressed = true
		tap.position = bp.ctr(bp.s.hero + Vector2i(1, 0))
		bp._gui_input(tap)
		if not bp.card.is_empty() or bp.s.visited.size() != 1:
			bad("on a phone the first touch should only put the card away")
		var shown = bp.btns.filter(func(x): return x.show)
		for i in range(shown.size()):
			if not Rect2(0, 0, 1280, 720).encloses(shown[i].rect):
				bad("stage %d: the %s button is off the page on a phone" % [st + 1, shown[i].label])
			for j in range(i):
				if shown[i].rect.intersects(shown[j].rect):
					bad("stage %d: %s and %s overlap on a phone" % [st + 1, shown[i].label, shown[j].label])
		await play(st, true)
		await frames(2)
		if bp.grade != "jouzu":
			bad("stage %d does not play through in the phone layout (grade '%s')" % [st + 1, bp.grade])
	# a touch that puts the card away must not also press the button lying under it
	var lst = Data.WAZA_FROM["leap"]
	main.show_battle(lst)
	await frames(2)
	var bl = main.cur
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = bl.b_leap.rect.get_center()
	if bl.card.is_empty() or not bl.b_leap.show:
		bad("the leap stage has no card or no leap button on a phone")
	bl._gui_input(press)
	if not bl.card.is_empty() or bl.mode != "":
		bad("on a phone, the touch that closes the card also pressed Leap (mode '%s')" % bl.mode)
	bl._gui_input(press)
	if bl.mode != "leap":
		bad("after the card is closed, Leap cannot be pressed")
	bl._mode("leap")
	press.position = bl.ctr(bl.s.hero + Vector2i(0, -1))
	main.show_battle(lst)
	await frames(2)
	bl = main.cur
	var hero0 = bl.s.hero
	bl._gui_input(press)
	if bl.s.hero != hero0 or not bl.card.is_empty():
		bad("on a phone, the touch that closes the card also painted a step")

	# every other page in its phone layout: buttons on the page and clear of one another
	var pages = [["title", func(): main.show_title()], ["map", func(): main.show_map()],
		["chapters", func():
			main.show_map()
			main.cur._pick()],
		["hub", func(): main.show_hub()], ["settings", func(): main.show_settings()], ["calendar", func(): main.show_calendar()],
		["training", func(): main.show_dojo()], ["scroll", func(): main.show_scroll()],
		["workshop ground", func(): main.show_editor()],
		["workshop yokai", func():
			main.show_editor()
			main.cur._tab(1)],
		["workshop rules", func():
			main.show_editor()
			main.cur._tab(2)],
		["workshop share", func():
			main.show_editor()
			main.cur._tab(3)]]
	for pg in pages:
		pg[1].call()
		await frames(2)
		var shown = main.cur.btns.filter(func(x): return x.show)
		if shown.is_empty():
			bad("the %s page has no buttons on a phone" % pg[0])
		for i in range(shown.size()):
			if not Rect2(0, 0, 1280, 720).encloses(shown[i].rect):
				bad("%s: the %s button is off the page on a phone" % [pg[0], shown[i].label])
			if shown[i].rect.size.y < 48.0:
				bad("%s: the %s button is too short for a finger (%d)" % [pg[0], shown[i].label, int(shown[i].rect.size.y)])
			for j in range(i):
				if shown[i].rect.intersects(shown[j].rect):
					bad("%s: %s and %s overlap on a phone" % [pg[0], shown[i].label, shown[j].label])
	# choosing a chapter from the page of chapters, and painting in the workshop
	main.show_map()
	await frames(2)
	main.cur._pick()
	main.cur.tabs[0].cb.call()
	if main.cur.picking or main.cur.page != 0:
		bad("picking a chapter on a phone does not go to it")
	main.cur._step(1)
	if main.cur.page != 1:
		bad("the phone's next-chapter arrow does not turn the chapter")
	main.show_editor()
	await frames(2)
	main.cur._tab(1)
	main.cur.tool_btns["o"].cb.call()
	main.cur.on_click(main.cur.ORG + Vector2(2.5, 2.5) * main.cur.TS, MOUSE_BUTTON_LEFT)
	if main.cur.st.rows[2][2] != "o":
		bad("placing a yokai in the phone workshop does not work")
	main.cur._clear()
	main.touch = false

	# the seal for a first attempt is lost by a restart as well as by an undo
	main.show_battle(2)
	await frames(2)
	key(main.cur, KEY_R)
	await play(2, false)
	await frames(2)
	if main.cur.grade != "jouzu" or main.cur.seal_mask & 2 != 0:
		bad("a clear after a restart still earned the first-attempt seal")
	# undo only within the stroke in hand
	main.data.opts.undo = 1
	main.show_battle(1)
	await frames(2)
	var bu = main.cur
	key(bu, KEY_RIGHT)
	key(bu, KEY_Z)
	if bu.s.hero != Vector2i(0, 3):
		bad("with undo set to 'this stroke', a step in the stroke in hand cannot be taken back")
	key(bu, KEY_RIGHT)
	key(bu, KEY_SPACE)
	var after = bu.s.turn
	key(bu, KEY_Z)
	if bu.s.turn != after or bu.b_undo.on:
		bad("with undo set to 'this stroke', a sheathed stroke was taken back")
	# no undo at all
	main.data.opts.undo = 2
	main.show_battle(1)
	await frames(2)
	bu = main.cur
	key(bu, KEY_RIGHT)
	key(bu, KEY_Z)
	if bu.s.hero != Vector2i(1, 3) or bu.b_undo.on:
		bad("with undo set to 'never', a step was taken back")
	for k in range(12):
		if not bu.done:
			key(bu, KEY_SPACE)
			await frames()
	if bu.grade != "lost" or bu.extra.size() != 1:
		bad("with undo set to 'never', a loss should offer only to begin again")
	main.data.opts.undo = 1

	# every stage has music that exists, and the quiet chapters have the quiet piece
	var heard = {}
	for i in range(Data.LEVELS.size()):
		var nm = main.stage_music(i)
		heard[nm] = true
		if main.streams.get(nm) == null:
			bad("stage %d asks for music '%s' that is not there" % [i + 1, nm])
	if heard.size() < 6 or main.stage_music(Data.CHAPTERS[10].from + 1) != "zen":
		bad("the stages do not spread across the pieces of music: %s" % str(heard.keys()))

	# both styles draw every page and play a stage through without complaint
	for style in [1, 0]:
		main.data.opts.style = style
		for pg in [func(): main.show_title(), func(): main.show_map(), func(): main.show_hub(), func(): main.show_settings(),
				func(): main.show_calendar(), func(): main.show_scroll(), func(): main.show_editor()]:
			pg.call()
			await frames(3)
		main.show_battle(Data.CHAPTERS[14].from + 2)
		await frames(2)
		await play(Data.CHAPTERS[14].from + 2, false)
		await frames(3)
		if main.cur.grade != "jouzu":
			bad("a stage does not play through in style %d" % style)

	# settings
	main.show_settings(main.show_hub)
	await frames(2)
	if kind() != "settings":
		bad("settings do not open")
	else:
		for k in ["music", "motion", "pattern", "filter"]:
			var was = main.data.opts[k]
			main.cur.rows[k].cb.call()
			if main.data.opts[k] == was:
				bad("the %s setting does not change" % k)
		main.cur.rows["style"].cb.call()
		if int(main.data.opts.style) != 1:
			bad("the style setting does not change")
		main.cur.rows["style"].cb.call()
		for want in [2, 1]:
			main.cur.rows["undo"].cb.call()
			if int(main.data.opts.undo) != want:
				bad("the undo setting does not step to %d" % want)
		if main.paint_rect.visible:
			bad("turning the painted look off leaves the filter on")
		main.load_save()
		if main.data.opts.motion or not main.data.opts.pattern:
			bad("settings did not survive a reload")
		# a stage plays through with motion off and the cross on
		main.show_battle(1)
		await frames(2)
		await play(1, false)
		await frames(2)
		if main.cur.grade != "jouzu":
			bad("a stage does not play with motion off")
		main.show_settings(main.show_hub)
		await frames(2)
		for k in ["music", "motion", "pattern", "filter"]:
			main.cur.rows[k].cb.call()
		key(main.cur, KEY_ESCAPE)
		await frames(2)
		if kind() != "hub" or not main.data.opts.motion:
			bad("leaving settings misbehaves")

	# the pilgrimage: losing staffs
	main.show_henro()
	await frames(2)
	b = main.cur
	if b.kind_of != "henro" or b.b_hint.on:
		bad("a temple offers the master's hint")
	key(b, KEY_UP)
	key(b, KEY_LEFT)
	var where = b.s.hero
	key(b, KEY_Z)
	if b.s.hero != where:
		bad("a pilgrim could take a step back")
	key(b, KEY_R)              # give up this temple
	await frames(2)
	if int(main.data.henro.staffs) != 2 or int(main.data.henro.at) != 0 or kind() != "battle":
		bad("giving up a temple should cost one staff and stay at it")
	key(main.cur, KEY_R)
	await frames()
	key(main.cur, KEY_R)
	await frames(2)
	if int(main.data.henro.staffs) != 3 or int(main.data.henro.at) != 0 or kind() != "hub":
		bad("losing the last staff should begin the pilgrimage again")

	# walking out mid-temple costs a staff; walking out untouched does not
	main.show_henro()
	await frames(2)
	key(main.cur, KEY_ESCAPE)
	await frames(2)
	if int(main.data.henro.staffs) != 3:
		bad("leaving an untouched temple cost a staff")
	main.show_henro()
	await frames(2)
	key(main.cur, KEY_UP)
	key(main.cur, KEY_ESCAPE)
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
	key(e, KEY_ESCAPE)
	await frames(2)
	if kind() != "hub":
		bad("Escape does not leave the workshop")

func _key(code):
	var e = InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e
