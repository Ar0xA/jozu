extends SceneTree
# Dev tool: the pages as a phone held upright shows them, to PNG in user://shots (tall_*.png).
#   godot --path . -s tools/shots_tall.gd [-- name ...]     (no names: every page)
const Data = preload("res://scripts/data.gd")
const DIR = {"R": Vector2i(1, 0), "L": Vector2i(-1, 0), "D": Vector2i(0, 1), "U": Vector2i(0, -1)}
var main
var n = 0
var steps = []

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
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir() + "/shots")
	main = load("res://main.tscn").instantiate()
	main.save_path = "user://shots_save.json"
	root.add_child(main)
	var all = [
		["title", func():
			main.show_title()
			main.cur.time = 9.0],
		["notice", func(): main.show_map()],
		["map", func():
			main.show_map()
			main.cur.notice = ""],
		["chapters", func():
			main.show_map()
			main.cur.notice = ""
			main.cur._pick()],
		["map18", func():
			main.show_map()
			main.cur.notice = ""
			main.cur._page(17)],
		["card", func(): main.show_battle(34)],
		["first", func():
			main.show_battle(0)
			main.cur.card = []],
		["board", func():
			main.show_battle(34)
			main.cur.card = []
			play(1, 2)],
		["won", func():
			main.show_battle(3)
			main.cur.card = []
			play(99, 0)],
		["story", func(): main.show_story(Data.LEVELS[0].story, main.show_map)],
		["hub", func(): main.show_hub()],
		["daily", func(): main.show_calendar()],
		["settings", func(): main.show_settings()],
		["scroll", func(): main.show_scroll()],
		["dojo", func(): main.show_dojo()],
		["print", func():
			main.data.cleared.erase("9")
			main.start_stage(9)],
		["print2", func():
			main.data.cleared.erase("99")
			main.start_stage(99)],
		["seal", func():
			main.show_seal()
			main.cur.name_now = "雪舟"
			main.cur._sync()],
		["editor", func(): main.show_editor()],
	]
	var want = OS.get_cmdline_user_args()
	for s in all:
		if want.is_empty() or want == PackedStringArray(["wide"]) or want.has(s[0]):
			steps.append(s)

func _process(_dt):
	n += 1
	if n == 2:
		if not OS.get_cmdline_user_args().has("wide"):
			get_root().size = Vector2i(600, 1300)
		main.touch = true
		main.erase_save()
		for k in range(12):
			main.record(k, "jouzu" if k % 2 == 0 else "ka", null, 1)
	if n < 40:
		return false
	var i = n / 40 - 1
	var ph = n % 40
	if i >= steps.size():
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://shots_save.json"))
		quit()
		return true
	if ph == 1:
		steps[i][1].call()
	if ph == 39:
		root.get_texture().get_image().save_png(OS.get_user_data_dir() + "/shots/" + ("wide_" if OS.get_cmdline_user_args().has("wide") else "tall_") + steps[i][0] + ".png")
	return false
