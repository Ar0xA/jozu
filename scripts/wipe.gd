extends Control
# What is seen when one page gives way to the next: a wash of ink drawn across, or, going into and
# out of a stage, a pair of painted sliding doors drawn apart.

const Ink = preload("res://scripts/ink.gd")
var main
var kind = "wash"
var t = 9.0

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _len():
	return 0.42 if kind == "wash" else 0.22 if kind == "fade" else 0.62

func start(k = "wash"):
	kind = k
	t = 0.0

func _process(dt):
	if t < _len():
		t += min(dt, 0.034)   # a long first frame must not swallow the whole of it
		queue_redraw()

func _door(x, left):
	var r = Rect2(x, 0, 640, 720)
	draw_rect(r, Ink.PAPER)
	var tex = main.art["tohaku"]
	var sz = tex.get_size()
	draw_texture_rect_region(tex, r, Rect2(0 if left else sz.x * 0.5, 0, sz.x * 0.5, sz.y), Color(1, 1, 1, 0.8))
	var lacquer = Color(0.10, 0.08, 0.07)
	draw_rect(r, lacquer, false, 12.0)
	# the finger-pull, by the edge where the doors meet
	var pull = Vector2(x + (598 if left else 42), 380)
	draw_circle(pull, 17.0, lacquer)
	draw_arc(pull, 17.0, 0, TAU, 24, Ink.KIN, 3.0, true)
	draw_circle(pull, 8.0, Ink.a(Ink.KIN, 0.5))

func _draw():
	if t >= _len():
		return
	if kind == "fusuma":
		# shut for a breath, then drawn apart
		var u = clamp((t - 0.10) / 0.52, 0.0, 1.0)
		var open = 650.0 * u * u * (3.0 - 2.0 * u)
		_door(-open, true)
		_door(640.0 + open, false)
		return
	if kind == "fade":
		# the page comes up out of bare paper, and that is all
		draw_rect(Rect2(0, 0, 1280, 720), Ink.a(Ink.PAPER, 1.0 - t / _len()))
		return
	var u = t / _len()
	var x = -200.0 + 1700.0 * u * u * (3.0 - 2.0 * u)
	# the page still to be uncovered lies under bare paper; a loaded brush leads the way across
	draw_rect(Rect2(x, 0, 1500 - x, 720), Ink.PAPER)
	for k in range(3):
		var pts = []
		for i in range(9):
			pts.append(Vector2(x - k * 26.0 + sin(i * 1.3 + k * 2.0) * 16.0, -30.0 + i * 98.0))
		Ink.brush(self, pts, 46.0 - k * 12.0, Ink.a(Ink.SUMI, (0.75 - k * 0.22) * (1.0 - u * 0.5)))
