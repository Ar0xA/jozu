extends Control
# Shared by every screen: redraw loop, painted buttons, input plumbing.

const Ink = preload("res://scripts/ink.gd")
const Data = preload("res://scripts/data.gd")

var main
var btns = []
var hover_btn = -1
var still = false      # set by a page on which nothing moves unless the player does something
var wake = 1.0
var rest = 0.0         # set by a page that only breathes when left alone: seconds between its redraws then
var slept = 0.0
var painting = false   # a press that began on the page itself is held: dragging paints
var time = 0.0
var mouse = Vector2.ZERO

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	setup()

func setup():
	pass

func tick(_dt):
	pass

# A screen with something laid over it (a card, a notice) says here whether that took the press.
func swallow(_pos, _button):
	return false

func on_click(_pos, _button):
	pass

func on_motion(_pos, _held):
	pass

func on_key(_code):
	pass

# Is something on the page moving that should be seen at full speed? (Only asked where `rest` is set.)
func busy():
	return false

func _process(dt):
	time += dt
	tick(dt)
	wake -= dt
	if still:
		# nothing here moves by itself: draw for a moment after it opens or is touched, then rest
		if wake < 0.0:
			return
	elif rest > 0.0 and wake < 0.0 and not busy():
		# only water, weather and a slow pulse are moving: a few frames a second show them, and spare the battery
		slept += dt
		if slept < rest:
			return
	slept = 0.0
	queue_redraw()

func btn(rect, label, cb, kanji = ""):
	var b = {"rect": rect, "label": label, "cb": cb, "on": true, "kanji": kanji, "sel": false, "show": true}
	btns.append(b)
	return b

func draw_btns():
	# no boxes: a label over one ruled brush line, with a blush of vermilion when chosen
	var f = main.font
	for i in range(btns.size()):
		var b = btns[i]
		if not b.show:
			continue
		var label = b.label
		if main.touch and label.contains("["):
			# a phone has no keys to press: leave the key names off
			label = label.substr(0, label.find("[")).strip_edges() + label.substr(label.find("]") + 1)
		var r = b.rect
		var al = 1.0 if b.on else 0.32
		var hot = (i == hover_btn and b.on and not main.touch) or b.sel   # a finger does not hover
		if hot:
			Ink.blot(self, r.get_center(), r.size.x * 0.56, r.size.y * 0.95, Ink.SHU, 0.26)
		if hot or not main.spare():   # in the spare style a button is its character and its word; the rule comes only under the one chosen
			var pts = []
			for k in range(11):
				pts.append(Vector2(lerp(r.position.x + 2.0, r.end.x - 2.0, k / 10.0), r.end.y - 5.0 + sin(k * 1.3 + r.position.x) * 1.3))
			Ink.brush(self, pts, 6.0 if hot else 4.0, Ink.a(Ink.SHU if hot else Ink.SUMI, 0.9 * al))
		var ts = min(30.0 if main.touch else 22.0, r.size.y * 0.46)   # larger where a finger, not a pointer, must find it
		if b.kanji == "" and label != "" and label.unicode_at(0) >= 0x2E80:
			ts = min(r.size.y * 0.62, (r.size.x - 6.0) / label.length())  # a tab shows its whole name, as large as fits
		var base = r.position.y + r.size.y * 0.5 + ts * 0.30
		if b.kanji != "":
			var kw = ts * 1.2 * b.kanji.length() + 14
			Ink.text(self, f, Vector2(r.position.x + 8, base + 2), b.kanji, ts * 1.2, Ink.a(Ink.SHU, al))
			Ink.text(self, f, Vector2(r.position.x + kw, base), label, ts * 0.9, Ink.a(Ink.SUMI, al), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - kw - 8)
		else:
			Ink.text(self, f, Vector2(r.position.x, base), label, ts, Ink.a(Ink.SUMI, al), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)

func _gui_input(ev):
	wake = 0.6
	if main.pinching:
		return   # two fingers are zooming the page, not playing it
	if ev is InputEventMouseMotion:
		mouse = ev.position
		hover_btn = -1
		for i in range(btns.size()):
			if btns[i].on and btns[i].show and _hit(btns[i]).has_point(mouse):
				hover_btn = i
		on_motion(mouse, (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0)
	elif ev is InputEventMouseButton and ev.pressed:
		mouse = ev.position
		if ev.button_index != MOUSE_BUTTON_LEFT and ev.button_index != MOUSE_BUTTON_RIGHT:
			return   # the wheel presses nothing
		painting = false
		if swallow(mouse, ev.button_index):
			return   # something lying over the page took the press: nothing under it is pressed
		if ev.button_index == MOUSE_BUTTON_LEFT:
			# on a touch screen take the button nearest the finger, with a little grace around each
			var best = null
			for b in btns:
				if b.on and b.show and _hit(b).has_point(mouse) and (best == null or b.rect.get_center().distance_to(mouse) < best.rect.get_center().distance_to(mouse)):
					best = b
			if best != null:
				main.sfx("click")
				best.cb.call()
				return
		on_click(mouse, ev.button_index)

func _hit(b):
	return b.rect.grow(9.0) if main.touch else b.rect

func _unhandled_input(ev):
	if ev is InputEventKey and ev.pressed and not ev.echo:
		wake = 0.6
		on_key(ev.keycode)
