extends Control
# The parts of the page, as scripts/tall.gd lays them out. They are drawn by a node of their own
# because what was painted off screen has its colour already weighed by its opacity, and must be
# laid down that way or everything translucent turns grey.

var view

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m = CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	material = m

func _process(_dt):
	if is_visible_in_tree():
		queue_redraw()

func _draw():
	view.draw_parts(self)
