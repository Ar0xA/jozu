extends SceneTree
# Dev tool: renders screens to PNG in user://shots (docs/ holds copies).  godot --path . -s tools/shots.gd
const Data = preload("res://scripts/data.gd")
const DIR = {"R": Vector2i(1, 0), "L": Vector2i(-1, 0), "D": Vector2i(0, 1), "U": Vector2i(0, -1)}
var main
var n = 0
var steps = []

func first(c):
	return Data.CHAPTERS[c].from

# play the stored solution: `strokes` whole strokes, then `extra` actions of the next one
func play(strokes, extra):
	var b = main.cur
	var sol = b.lv.sol.split(" / ")
	for k in range(sol.size()):
		var toks = sol[k].split(" ", false)
		for t in range(toks.size()):
			if k == strokes and t >= extra:
				return
			var tok = toks[t]
			if tok == "KATSU":
				b._katsu()
			elif tok == "BELL":
				b._bell()
			elif tok.begins_with("leap") or tok.begins_with("ward") or tok.begins_with("shiki"):
				b._mode(tok.left(tok.length() - 1))
				b._dir(DIR[tok.right(1)])
			else:
				b._dir(DIR[tok])
		if k == strokes:
			return
		if not b.done:
			b._end()

func _initialize():
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir() + "/itch")
	main = load("res://main.tscn").instantiate()
	main.save_path = "user://shots_save.json"
	root.add_child(main)
	main.erase_save()
	# a player some way down the road, so the map and the seals have something to show
	for i in range(118):
		main.data.cleared[str(i)] = "jouzu" if i % 4 != 3 else "clear"
	main.data.gago = "雪月"
	steps = [
		["1_title", func():
			main.show_title()
			main.cur.time = 9.0],
		["2_board_a", func():
			main.show_battle(104)
			main.cur.card = []
			play(1, 3)],
		["2_board_b", func():
			main.show_battle(64)
			main.cur.card = []
			play(1, 2)],
		["2_board_c", func():
			main.show_battle(131)
			main.cur.card = []
			play(2, 2)],
		["2_board_d", func():
			main.show_battle(99)
			main.cur.card = []
			play(1, 3)],
		["2_board_e", func():
			main.show_battle(580)
			main.cur.card = []
			play(2, 3)],
		["3_print_a", func():
			main.data.cleared.erase("99")
			main.start_stage(99)],
		["3_print_b", func():
			main.data.cleared.erase("9")
			main.start_stage(9)],
		["4_map", func(): main.show_map()],
		["5_daily", func():
			main.show_daily()
			main.cur.card = []
			play(0, 3)],
		["5_calendar", func(): main.show_calendar()],
		["6_seal", func(): main.show_seal()],
		["6_hub", func(): main.show_hub()],
	]

func _process(_dt):
	n += 1
	var i = n / 90
	var ph = n % 90
	if i >= steps.size():
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://shots_save.json"))
		quit()
		return true
	if ph == 1:
		steps[i][1].call()
	if ph == 89:
		root.get_texture().get_image().save_png(OS.get_user_data_dir() + "/itch/" + steps[i][0] + ".png")
	return false
