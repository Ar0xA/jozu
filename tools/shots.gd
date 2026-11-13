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
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir() + "/shots")
	main = load("res://main.tscn").instantiate()
	main.save_path = "user://shots_save.json"
	root.add_child(main)
	main.erase_save()
	steps = [
		["board", func():
			main.show_battle(first(3) + 4)
			main.cur.card = []
			play(1, 2)],
		["map", func(): main.show_map()],
		["title", func():
			main.show_title()
			main.cur.time = 9.0],
		["settings", func():
			main.show_settings()
			main.cur._copy()],
	]

func _process(_dt):
	n += 1
	var i = n / 30
	var ph = n % 30
	if i >= steps.size():
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://shots_save.json"))
		quit()
		return true
	if ph == 1:
		steps[i][1].call()
	if ph == 29:
		root.get_texture().get_image().save_png(OS.get_user_data_dir() + "/shots/" + steps[i][0] + ".png")
	return false
