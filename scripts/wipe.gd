extends Control
# A wash of ink drawn across the screen when one page gives way to the next.

const Ink = preload("res://scripts/ink.gd")
const LEN = 0.42
var t = LEN

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func start():
	t = 0.0

func _process(dt):
	if t < LEN:
		t += min(dt, 0.034)   # a long first frame must not swallow the whole wash
		queue_redraw()

func _draw():
	if t >= LEN:
		return
	var u = t / LEN
	var x = -200.0 + 1700.0 * u * u * (3.0 - 2.0 * u)
	# the page still to be uncovered lies under bare paper; a loaded brush leads the way across
	draw_rect(Rect2(x, 0, 1500 - x, 720), Ink.PAPER)
	for k in range(3):
		var pts = []
		for i in range(9):
			pts.append(Vector2(x - k * 26.0 + sin(i * 1.3 + k * 2.0) * 16.0, -30.0 + i * 98.0))
		Ink.brush(self, pts, 46.0 - k * 12.0, Ink.a(Ink.SUMI, (0.75 - k * 0.22) * (1.0 - u * 0.5)))
