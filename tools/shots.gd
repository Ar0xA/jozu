extends SceneTree
# Dev tool: renders screens to PNG in user://shots.  godot --path . -s tools/shots.gd
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
		["title", func(): main.show_title()],
		["daruma", func(): main.show_battle(first(17) + 3); play(1, 1)],
		["tanuki", func(): main.show_battle(first(18) + 6)],
		["thread", func(): main.show_battle(first(19) + 9)],
		["wind", func(): main.show_battle(first(20) + 8)],
		["rain", func(): main.show_battle(first(21) + 8)],
		["snow", func(): main.show_battle(first(22) + 9)],
		["night", func(): main.show_battle(first(23) + 8)],
		["shinigami", func(): main.show_battle(first(24) + 9)],
		["shikigami", func(): main.show_battle(first(25) + 4); play(2, 1)],
		["enso", func(): main.show_battle(first(14) + 1); play(1, 99)],
		["garden", func(): main.show_battle(first(11) + 5); play(0, 9)],
		["won", func(): main.show_battle(first(17)); play(99, 99)],
		["map", func(): main.show_map(); main.cur._page(20)],
		["scroll", _fill_scroll],
	]

func _fill_scroll():
	for i in range(first(14), first(14) + 6):
		main.show_battle(i)
		play(99, 99)
	main.show_scroll()
	main.cur._page(14)

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
