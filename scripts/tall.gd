extends Control
# A phone held upright. The page is still painted the way it is laid out for a wide screen, but off
# screen (main.stage_vp); here its parts are cut out and stacked one above the other, each as wide
# as the phone allows, and a finger on a part is passed to the page as if it had touched it there.
# Each page says which parts it has (screen_base.gd: tall_parts).

const Ink = preload("res://scripts/ink.gd")
const W = 720.0
var main
var lay = []      # [{src: Rect2 on the page, dst: Rect2 here}]

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var cut = load("res://scripts/tall_cut.gd").new()
	cut.view = self
	add_child(cut)

func _process(_dt):
	if visible:
		queue_redraw()

# Stacks the parts down the screen. A part is {"src": [Rect2, ...] (side by side), "s": scale}.
# If they are taller than the screen all are made smaller together; spare room goes between them.
# A first part marked "top" sits at the very top, a last part marked "foot" at the very bottom.
func _layout(parts, h):
	if parts.is_empty():
		return []
	var total = 0.0
	for p in parts:
		total += p.src[0].size.y * p.s
	var k = min(1.0, h / total)
	var top = parts[0].get("top", false)
	var foot = parts[-1].get("foot", false)
	var gaps = parts.size() + 1 - (1 if top else 0) - (1 if foot else 0)
	var gap = (h - total * k) / max(1, gaps)
	var out = []
	var y = 0.0 if top else gap
	for p in parts:
		var s = p.s * k
		var wide = 0.0
		for r in p.src:
			wide += r.size.x * s
		var x = (W - wide) * 0.5
		for r in p.src:
			out.append({"src": r, "dst": Rect2(x, y, r.size.x * s, r.size.y * s)})
			x += r.size.x * s
		y += p.src[0].size.y * s + gap
	return out

func _draw():
	var h = size.y
	draw_rect(Rect2(0, 0, W, h), Ink.PAPER)
	for i in range(14):
		draw_rect(Rect2(i * 4, i * 4, W - i * 8, h - i * 8), Color(0.35, 0.24, 0.10, 0.022 * (14 - i) / 14.0), false, 4.0)
	var cur = main.cur
	if cur == null or not is_instance_valid(cur) or cur.get_parent() != main.stage_vp:
		return
	if cur.tall_art > 0.0:
		# Tohaku's pines behind the page, cut to the upright sheet
		var tex = main.art["tohaku"]
		var sz = tex.get_size()
		var ww = sz.y * W / h
		draw_texture_rect_region(tex, Rect2(0, 0, W, h), Rect2((sz.x - ww) * cur.tall_at, 0, ww, sz.y), Color(1, 1, 1, cur.tall_art))
	lay = _layout(cur.tall_parts(h), h)

# the parts themselves (drawn by scripts/tall_cut.gd, over the paper)
func draw_parts(ci):
	var cur = main.cur
	if cur == null or not is_instance_valid(cur) or cur.get_parent() != main.stage_vp:
		return
	var tex2 = main.stage_vp.get_texture()
	var ss = main.stage_vp.size.x / 1280.0
	for p in lay:
		ci.draw_texture_rect_region(tex2, p.dst, Rect2(p.src.position * ss, p.src.size * ss))

# where on the page a point here lies, or null if it is on none of its parts
func _to_page(pos):
	for i in range(lay.size() - 1, -1, -1):
		var p = lay[i]
		if p.dst.has_point(pos):
			return p.src.position + (pos - p.dst.position) * p.src.size.x / p.dst.size.x
	return null

func _gui_input(ev):
	var cur = main.cur
	if cur == null or not is_instance_valid(cur):
		return
	if ev is InputEventMouseButton or ev is InputEventMouseMotion:
		var q = _to_page(ev.position)
		if q == null:
			if not cur.tall_modal():
				return
			q = Vector2(-100, -100)   # off every part: only something laid over the page will hear it
		var e2 = ev.duplicate()
		e2.position = q
		cur._gui_input(e2)
