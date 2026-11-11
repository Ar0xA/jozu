extends SceneTree
# Dev tool: renders each screen to PNG in user://shots.  godot --path . -s tools/shots.gd
var main
var n = 0
var steps = []

func _initialize():
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir() + "/shots")
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	steps = [
		["title", func(): pass],
		["map", func(): main.show_map()],
		["snow", func(): main.show_battle(56)],
		["kappa", func(): main.show_battle(69)],
		["fire", func(): main.show_battle(79)],
		["gasha", func(): main.show_battle(99)],
		["dojo", func(): main.show_dojo()],
	]

func _process(_dt):
	n += 1
	var i = n / 40
	var ph = n % 40
	if i >= steps.size():
		quit()
		return true
	if ph == 1:
		steps[i][1].call()
	if ph == 39:
		root.get_texture().get_image().save_png(OS.get_user_data_dir() + "/shots/" + steps[i][0] + ".png")
	return false
