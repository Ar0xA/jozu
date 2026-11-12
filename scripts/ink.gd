extends RefCounted
# Brush, pigment and figures. Everything in Jōzu is painted here with code:
# sumi ink on washi, a handful of mineral pigments, gold mist, and a vermilion seal.

const PAPER = Color(0.925, 0.878, 0.76)
const PAPER_D = Color(0.855, 0.795, 0.655)
const SUMI = Color(0.13, 0.11, 0.10)
const SHU = Color(0.76, 0.22, 0.16)     # vermilion
const AI = Color(0.17, 0.25, 0.40)      # indigo
const KIN = Color(0.78, 0.62, 0.27)     # gold
const MATSU = Color(0.26, 0.36, 0.28)   # pine green
const GOFUN = Color(0.97, 0.95, 0.90)   # shell white
const HADA = Color(0.94, 0.85, 0.72)    # skin

static func a(col, alpha):
	return Color(col.r, col.g, col.b, alpha)

static func ell(c, rx, ry, n = 28, a0 = 0.0, a1 = TAU):
	var pts = PackedVector2Array()
	for i in range(n + 1):
		var t = a0 + (a1 - a0) * float(i) / float(n)
		pts.append(c + Vector2(cos(t) * rx, sin(t) * ry))
	return pts

# filled shape with a brushed contour: the line swells and thins as it travels,
# and the colour sits a hair off-register, as in a woodblock print
static func blob(ci, pts, fill, lw = 2.0, line = SUMI):
	if fill.a > 0.0:
		var off = PackedVector2Array()
		for p in pts:
			off.append(p + Vector2(lw * 0.55, lw * 0.4))
		ci.draw_colored_polygon(off, fill)
	if lw > 0.0:
		var n = pts.size()
		for i in range(n):
			var ww = lw * (0.85 + 0.7 * sin(TAU * i / n + 0.9))
			ci.draw_line(pts[i], pts[(i + 1) % n], line, ww, true)
			ci.draw_circle(pts[i], ww * 0.5, line)

# a soft pool of pigment, dense at the heart and gone at the rim
static func blot(ci, c, rx, ry, col, alpha):
	var n = 18
	var c0 = a(col, alpha)
	var c1 = a(col, 0.0)
	for i in range(n):
		var t0 = TAU * i / n
		var t1 = TAU * (i + 1) / n
		ci.draw_polygon(PackedVector2Array([c, c + Vector2(cos(t0) * rx, sin(t0) * ry), c + Vector2(cos(t1) * rx, sin(t1) * ry)]), PackedColorArray([c0, c1, c1]))

# The season, drifting over the page: cherry petals, fireflies, maple leaves or snow.
static func season(ci, kind, t, n = 26):
	for k in range(n):
		var h1 = fmod(k * 0.6180339, 1.0)
		var h2 = fmod(k * 0.7548777, 1.0)
		if kind == "hotaru":
			# fireflies wander and blink
			var p = Vector2(80 + h1 * 1120 + sin(t * 0.31 + k * 1.7) * 70, 150 + h2 * 480 + cos(t * 0.23 + k * 2.3) * 50)
			var glow = max(0.0, sin(t * 1.1 + k * 2.1))
			blot(ci, p, 16, 16, Color(0.80, 0.92, 0.42), 0.42 * glow)
			ci.draw_circle(p, 2.2, Color(0.96, 1.0, 0.75, 0.25 + 0.75 * glow))
			continue
		var fall = (26.0 + 34.0 * h2) if kind != "yuki" else (16.0 + 20.0 * h2)
		var p = Vector2(fmod(h1 * 1280.0 + sin(t * 0.6 + k) * 46.0 + t * (12.0 if kind != "yuki" else 3.0) + 1280.0, 1280.0), fmod(h2 * 720.0 + t * fall, 760.0) - 20.0)
		if kind == "yuki":
			ci.draw_circle(p, 2.0 + 2.4 * h1, a(GOFUN, 0.9))
			continue
		ci.draw_set_transform(p, t * (0.7 + h1) + k, Vector2.ONE)
		if kind == "sakura":
			var pink = Color(0.96, 0.74 + 0.1 * h2, 0.80, 0.9)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(0, -7), Vector2(5, -2), Vector2(3.5, 5), Vector2(0, 2.5), Vector2(-3.5, 5), Vector2(-5, -2)]), pink)
		else:
			var red = Color(0.80, 0.26 + 0.25 * h2, 0.10, 0.9)
			var leaf = PackedVector2Array()
			for i in range(10):
				var ang = TAU * i / 10.0 - PI * 0.5
				leaf.append(Vector2(cos(ang), sin(ang)) * (9.0 if i % 2 == 0 else 3.6))
			ci.draw_colored_polygon(leaf, red)
			ci.draw_line(Vector2(0, 3), Vector2(0, 11), a(red, 0.9), 1.4, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# Which season the calendar says it is.
static func season_now():
	var m = Time.get_date_dict_from_system().month
	return "sakura" if m >= 3 and m <= 5 else "hotaru" if m >= 6 and m <= 8 else "momiji" if m >= 9 and m <= 11 else "yuki"

# A hanging scroll unrolling: u = 0 only the rod, 1 fully open. r is the paper when it is open.
static func kakejiku(ci, r, u):
	var wood = Color(0.27, 0.18, 0.12)
	var top = r.position.y
	var bot = lerp(top + 26.0, r.end.y, clamp(u, 0.0, 1.0))
	var x0 = r.position.x
	var w = r.size.x
	var hang = Vector2(x0 + w * 0.5, top - 74)
	ci.draw_line(hang, Vector2(x0 + 26, top - 42), a(SUMI, 0.8), 2.0, true)
	ci.draw_line(hang, Vector2(x0 + w - 26, top - 42), a(SUMI, 0.8), 2.0, true)
	ci.draw_rect(Rect2(x0 - 6, top - 46, w + 12, 8), wood)
	ci.draw_rect(Rect2(x0, top - 38, w, 30), AI)                       # the upper cloth
	ci.draw_rect(Rect2(x0, top - 8, w, 8), KIN)                        # and its strip of gold
	ci.draw_rect(Rect2(x0, top, w, bot - top), a(PAPER, 0.98))
	ci.draw_rect(Rect2(x0 + 8, top, w - 16, bot - top), a(GOFUN, 0.45))
	ci.draw_rect(Rect2(x0, top, 8, bot - top), AI)
	ci.draw_rect(Rect2(x0 + w - 8, top, 8, bot - top), AI)
	ci.draw_rect(Rect2(x0, bot, w, 8), KIN)
	ci.draw_rect(Rect2(x0, bot + 8, w, 20), AI)
	ci.draw_rect(Rect2(x0 - 18, bot + 28, w + 36, 14), wood)           # the roller, with its two knobs
	for sx in [x0 - 18, x0 + w + 18]:
		ci.draw_circle(Vector2(sx, bot + 35), 10.0, Color(0.48, 0.15, 0.11))
		ci.draw_arc(Vector2(sx, bot + 35), 10.0, 0, TAU, 20, SUMI, 1.5, true)

# Bands of gold cloud, as they drift across a folding screen.
static func kinun(ci, c, w, alpha = 0.26):
	var gold = a(KIN, alpha)
	var rows = [[-0.50, 0.70], [-0.30, 0.95], [-0.42, 0.62], [-0.12, 0.50]]
	for k in range(rows.size()):
		var x0 = c.x + rows[k][0] * w
		var len = rows[k][1] * w
		var y = c.y + k * 11.0
		ci.draw_rect(Rect2(x0, y - 5.0, len, 10.0), gold)
		ci.draw_circle(Vector2(x0, y), 5.0, gold)
		ci.draw_circle(Vector2(x0 + len, y), 5.0, gold)

# One bead of a rosary: ki that is held. An empty place on the string is ki that is spent.
static func bead(ci, c, r, full):
	if full:
		ci.draw_circle(c, r, Color(0.56, 0.15, 0.11))
		ci.draw_circle(c + Vector2(-r * 0.32, -r * 0.34), r * 0.26, a(GOFUN, 0.6))
		ci.draw_arc(c, r, 0, TAU, 22, SUMI, 1.6, true)
	else:
		ci.draw_arc(c, r * 0.9, 0, TAU, 22, a(SUMI, 0.4), 1.4, true)

# One drop of ink.
static func drop(ci, c, r, full):
	var pts = PackedVector2Array([c + Vector2(0, -r * 1.5)])
	for i in range(13):
		var ang = lerp(-PI * 0.18, PI * 1.18, i / 12.0)
		pts.append(c + Vector2(cos(ang) * r, sin(ang) * r + r * 0.12))
	if full:
		ci.draw_colored_polygon(pts, SUMI)
		ci.draw_circle(c + Vector2(-r * 0.32, r * 0.05), r * 0.2, a(GOFUN, 0.5))
	else:
		pts.append(pts[0])
		ci.draw_polyline(pts, a(SUMI, 0.5), 1.6, true)

# enso: a circle drawn in one breath, never quite closed
static func enso(ci, c, r, w, col, phase = -1.9):
	var pts = []
	for i in range(41):
		var t = phase + TAU * 0.94 * i / 40.0
		pts.append(c + Vector2(cos(t), sin(t)) * r * (1.0 + 0.03 * sin(t * 3.0)))
	brush(ci, pts, w, col)

# four ruled strokes that overshoot their corners
static func frame(ci, r, w, col):
	var p = r.position
	var e = r.end
	var o = w * 1.6
	for seg in [[Vector2(p.x - o, p.y), Vector2(e.x + o * 0.5, p.y)], [Vector2(e.x, p.y - o * 0.6), Vector2(e.x, e.y + o)],
			[Vector2(e.x + o, e.y), Vector2(p.x - o * 0.7, e.y)], [Vector2(p.x, e.y + o * 0.5), Vector2(p.x, p.y - o)]]:
		var pts = []
		for k in range(9):
			pts.append(seg[0].lerp(seg[1], k / 8.0))
		brush(ci, pts, w, col)

static func slip(ci, r, w = 3.0):
	ci.draw_rect(r, a(GOFUN, 0.82))
	frame(ci, r, w, SUMI)

static func oval(ci, c, rx, ry, fill, lw = 2.0, line = SUMI):
	var pts = ell(c, rx, ry, 28)
	pts.remove_at(pts.size() - 1)
	blob(ci, pts, fill, lw, line)

# a brush stroke as one ribbon: swells in the middle, thins at both ends
static func brush(ci, pts, w, col):
	var n = pts.size()
	if n == 0:
		return
	if n == 1:
		ci.draw_circle(pts[0], w * 0.5, col)
		return
	var lf = []
	var rt = []
	for i in range(n):
		var d = pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]
		if d.length() < 0.001:
			d = Vector2.RIGHT
		var nrm = d.normalized().orthogonal()
		var t0 = float(i) / float(n - 1)
		var hw = w * 0.5 * (0.35 + 0.65 * sin(PI * clamp(t0 * 0.85 + 0.12, 0.0, 1.0)))
		lf.append(pts[i] + nrm * hw)
		rt.append(pts[i] - nrm * hw)
	for i in range(n - 1):
		if pts[i].distance_to(pts[i + 1]) > 0.01:
			var quad = PackedVector2Array([lf[i], lf[i + 1], rt[i + 1], rt[i]])
			if Geometry2D.triangulate_polygon(quad).is_empty():
				# a hairpin turn folds the ribbon over itself; fall back to a plain segment
				ci.draw_line(pts[i], pts[i + 1], col, lf[i].distance_to(rt[i]), true)
			else:
				ci.draw_colored_polygon(quad, col)

# A stroke as a loaded brush leaves it. Where it touches down the ink pools, a little darker and
# rounder (nijimi). As it runs the brush empties: each step is paler than the one before, and
# toward the end the hairs part and bare paper shows through in streaks (kasure).
# full = how far through its ink the brush is at the end of this stroke, 0 to 1.
static func fude(ci, pts, w, full):
	var n = pts.size()
	if n == 0:
		return
	var black = Color(0.11, 0.09, 0.09)
	if n == 1:
		ci.draw_circle(pts[0], w * 0.42, black)
		return
	for i in range(n - 1):
		var a0 = pts[i]
		var b0 = pts[i + 1]
		var d = (b0 - a0)
		if d.length() < 0.01:
			continue
		var nrm = d.normalized().orthogonal()
		var u0 = float(i) / float(n - 1) * full
		var u1 = float(i + 1) / float(n - 1) * full
		# the ribbon thins as the ink gives out
		var w0 = w * 0.5 * (1.0 - 0.34 * u0)
		var w1 = w * 0.5 * (1.0 - 0.34 * u1)
		var c0 = a(black, 0.96 - 0.42 * u0)
		var c1 = a(black, 0.96 - 0.42 * u1)
		ci.draw_polygon(PackedVector2Array([a0 + nrm * w0, b0 + nrm * w1, b0 - nrm * w1, a0 - nrm * w0]), PackedColorArray([c0, c1, c1, c0]))
		ci.draw_circle(b0, w1, c1)      # the turn of the brush at each corner
		# dry brush: streaks of paper along the stroke, more of them the emptier the brush
		var dry = clamp((u1 - 0.45) / 0.55, 0.0, 1.0)
		if dry > 0.0:
			for k in range(5):
				var off = (k - 2) * w1 * 0.36 + sin(i * 3.7 + k * 1.9) * w1 * 0.08
				var from = a0.lerp(b0, 0.10 + 0.13 * ((k * 3 + i) % 4))
				var to = a0.lerp(b0, 0.62 + 0.09 * ((k + i * 2) % 4))
				ci.draw_line(from + nrm * off, to + nrm * off, a(PAPER, 0.80 * dry), 1.0 + 1.8 * dry, true)
	# where the brush came down
	blot(ci, pts[0], w * 0.95, w * 0.95, black, 0.30)
	ci.draw_circle(pts[0], w * 0.56, a(black, 0.97))
	# and where it lifted: a tail drawn out thin
	var last = pts[n - 1] - pts[n - 2]
	if last.length() > 0.01:
		var tip = pts[n - 1] + last.normalized() * w * 0.55 * (1.0 - 0.3 * full)
		var side = last.normalized().orthogonal() * w * 0.5 * (1.0 - 0.34 * full)
		ci.draw_colored_polygon(PackedVector2Array([pts[n - 1] + side, tip, pts[n - 1] - side]), a(black, 0.96 - 0.42 * full))

# The first part of a path, by length: u = 0 nothing, 1 all of it.
static func part(pts, u):
	if u >= 1.0 or pts.size() < 2:
		return pts
	var total = 0.0
	for i in range(1, pts.size()):
		total += pts[i - 1].distance_to(pts[i])
	var want = total * max(u, 0.0)
	var out = [pts[0]]
	for i in range(1, pts.size()):
		var seg = pts[i - 1].distance_to(pts[i])
		if want <= seg:
			if seg > 0.0:
				out.append(pts[i - 1].lerp(pts[i], want / seg))
			return out
		want -= seg
		out.append(pts[i])
	return out

# A stroke being written: the part done so far, and a wet bead where the brush is.
static func writing(ci, pts, w, col, u):
	if u <= 0.0:
		return
	var done = part(pts, u)
	brush(ci, done, w, col)
	if u < 1.0 and done.size() > 0:
		ci.draw_circle(done[done.size() - 1], w * 0.42, col)

# Text brushed in a character at a time: each one lands a little dark and wet, then dries.
static func written(ci, font, pos, s, size, col, u, per = 0.14):
	var x = pos.x
	for i in range(s.length()):
		var k = clamp((u - i * per) / (per * 2.2), 0.0, 1.0)
		var adv = font.get_string_size(s[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		if k > 0.0:
			if k < 1.0:
				blot(ci, Vector2(x + adv * 0.5, pos.y - size * 0.34), size * 0.55, size * 0.55, SUMI, 0.28 * (1.0 - k))
			ci.draw_string(font, Vector2(x, pos.y + size * 0.10 * (1.0 - k) * (1.0 - k)), s[i], HORIZONTAL_ALIGNMENT_LEFT, -1, size, a(col, col.a * k))
		x += adv

# A seal coming down on the paper: large and faint, then pressed home.
static func stamp(ci, font, c, size, kanji, u, col = SHU):
	if u <= 0.0:
		return
	if u >= 1.0:
		seal(ci, font, c, size, kanji, col)
		return
	var k = 1.0 + 0.9 * (1.0 - u) * (1.0 - u)
	ci.draw_set_transform(c - c * k, 0.0, Vector2(k, k))
	seal(ci, font, c, size, kanji, a(col, u))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# One stroke of a written character, as a calligrapher makes it: the brush is pressed down, drawn
# along more lightly, and pressed again before it lifts. u is how much of it has been written.
static func kaku(ci, pts, w, col, u):
	if u <= 0.0 or pts.size() < 2:
		return
	# the path, evenly divided and gently rounded
	var total = 0.0
	for i in range(1, pts.size()):
		total += pts[i - 1].distance_to(pts[i])
	var n = 22
	var line = []
	for k in range(n + 1):
		var want = total * k / float(n)
		var q = pts[pts.size() - 1]
		for i in range(1, pts.size()):
			var seg = pts[i - 1].distance_to(pts[i])
			if want <= seg:
				q = pts[i - 1].lerp(pts[i], want / max(seg, 0.001))
				break
			want -= seg
		line.append(q)
	var upto = int(ceil(clamp(u, 0.0, 1.0) * n))
	var lf = PackedVector2Array()
	var rt = PackedVector2Array()
	for k in range(upto + 1):
		var t = k / float(n)
		var d = (line[min(k + 1, n)] - line[max(k - 1, 0)]).normalized()
		var press = 0.58 + 0.42 * exp(-pow((t - 0.05) / 0.11, 2.0)) + 0.30 * exp(-pow((t - 0.96) / 0.09, 2.0))
		var hw = w * 0.5 * press
		lf.append(line[k] + d.orthogonal() * hw)
		rt.append(line[k] - d.orthogonal() * hw)
	for k in range(upto):
		var quad = PackedVector2Array([lf[k], lf[k + 1], rt[k + 1], rt[k]])
		if Geometry2D.triangulate_polygon(quad).is_empty():
			ci.draw_line(line[k], line[k + 1], col, lf[k].distance_to(rt[k]), true)
		else:
			ci.draw_colored_polygon(quad, col)
	ci.draw_circle(line[0], lf[0].distance_to(rt[0]) * 0.5, col)
	ci.draw_circle(line[upto], lf[upto].distance_to(rt[upto]) * 0.5, col)

# The two characters of the title, as strokes in the order they are written (a unit square each).
const TITLE_STROKES = [
	[[Vector2(0.49, 0.06), Vector2(0.52, 0.30), Vector2(0.51, 0.60), Vector2(0.50, 0.84)],
	 [Vector2(0.53, 0.40), Vector2(0.66, 0.37), Vector2(0.80, 0.39), Vector2(0.86, 0.44)],
	 [Vector2(0.06, 0.88), Vector2(0.30, 0.85), Vector2(0.70, 0.85), Vector2(0.95, 0.89)]],
	[[Vector2(0.80, 0.07), Vector2(0.62, 0.14), Vector2(0.42, 0.18), Vector2(0.22, 0.21)],
	 [Vector2(0.17, 0.42), Vector2(0.40, 0.39), Vector2(0.66, 0.39), Vector2(0.84, 0.42)],
	 [Vector2(0.05, 0.63), Vector2(0.30, 0.59), Vector2(0.72, 0.59), Vector2(0.96, 0.63)],
	 [Vector2(0.52, 0.17), Vector2(0.54, 0.45), Vector2(0.54, 0.74), Vector2(0.50, 0.88), Vector2(0.42, 0.90), Vector2(0.34, 0.82)]],
]

# 上手 written top to bottom, a stroke at a time; t is seconds since the brush touched the paper.
# Returns how far along the whole thing is, 0 to 1.
static func title_strokes(ci, top, size, col, t):
	var each = 0.34
	var gap = 0.13
	var k = 0
	for ci_i in range(TITLE_STROKES.size()):
		var org = top + Vector2(-size * 0.5, size * 0.04 + ci_i * size * 1.08)
		for st in TITLE_STROKES[ci_i]:
			var pts = []
			for v in st:
				pts.append(org + v * size)
			kaku(ci, pts, size * 0.125, col, (t - k * (each + gap)) / each)
			k += 1
	return clamp(t / (k * (each + gap)), 0.0, 1.0)

static func text(ci, font, pos, s, size, col, align = HORIZONTAL_ALIGNMENT_LEFT, width = -1.0):
	ci.draw_string(font, pos, s, align, width, size, col)

static func para(ci, font, pos, s, size, col, width):
	ci.draw_multiline_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, width, size, -1, col)

# kanji stacked top to bottom, the way a scroll is read
static func tategaki(ci, font, top, s, size, col):
	for i in range(s.length()):
		ci.draw_string(font, top + Vector2(-size * 0.5, size * 0.9 + i * size * 1.08), s[i], HORIZONTAL_ALIGNMENT_CENTER, size, size, col)

static func seal(ci, font, c, size, kanji, col = SHU):
	var sb = StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(size * 0.12))
	var n = kanji.length()
	var h = size * (0.2 + 0.9 * n)
	var r = Rect2(c - Vector2(size * 0.55, h * 0.5), Vector2(size * 1.1, h))
	ci.draw_style_box(sb, r)
	ci.draw_rect(r.grow(-size * 0.07), a(GOFUN, 0.85), false, 1.5)
	for i in range(n):
		ci.draw_string(font, Vector2(r.position.x, r.position.y + size * 0.92 + i * size * 0.9), kanji[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, size * 0.8, GOFUN)

# mist: bare paper left between washes, where the mountains dissolve
static func mist(ci, x, y, w, h, alpha = 0.28):
	var col = Color(0.945, 0.905, 0.80)
	var al = clamp(alpha * 3.3, 0.0, 0.95)
	var xs = [x, x + w * 0.25, x + w * 0.75, x + w]
	var ys = [y - h * 0.9, y + h * 0.5, y + h * 1.9]
	for i in range(3):
		for j in range(2):
			var ps = PackedVector2Array()
			var cs = PackedColorArray()
			for k in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
				ps.append(Vector2(xs[k[0]], ys[k[1]]))
				cs.append(a(col, al if ((k[0] == 1 or k[0] == 2) and k[1] == 1) else 0.0))
			ci.draw_polygon(ps, cs)
	blot(ci, Vector2(x + w * 0.5, y + h * 0.5), w * 0.42, h * 0.9, KIN, alpha * 0.45)

# a mountain in wash: dark at the ridge, thinning to nothing where the mist takes it
static func mountain(ci, base, w, h, col, snow = false, sd = 7):
	var rng = RandomNumberGenerator.new()
	rng.seed = sd + int(w) * 13
	var n = 40
	var ridge = PackedVector2Array()
	var prof = []
	var jag = 0.0
	for i in range(n + 1):
		var u = 2.0 * i / n - 1.0
		var pr = 0.0
		if snow:
			pr = min(pow(1.0 - abs(u), 1.8), 0.9) / 0.9
		else:
			jag = lerp(jag, rng.randf_range(-1.0, 1.0), 0.65)
			pr = pow(1.0 - abs(u), 1.2) * (0.80 + 0.22 * jag)
		prof.append(pr)
		ridge.append(base + Vector2(u * w * 0.5, -max(h * pr, 3.0)))
	var clear = a(col, 0.0)
	for i in range(n):
		ci.draw_polygon(PackedVector2Array([ridge[i], ridge[i + 1], Vector2(ridge[i + 1].x, base.y), Vector2(ridge[i].x, base.y)]),
			PackedColorArray([col, col, clear, clear]))
	if snow:
		var cap = PackedVector2Array()
		var lo = []
		for i in range(n + 1):
			if prof[i] > 0.78:
				cap.append(ridge[i])
				lo.append(Vector2(ridge[i].x, base.y - h * (0.72 - 0.07 * (cap.size() % 2))))
		lo.reverse()
		for p in lo:
			cap.append(p)
		if cap.size() >= 6:
			ci.draw_colored_polygon(cap, Color(0.96, 0.94, 0.88, 0.95))
	else:
		for i in range(4, n - 3, 3):
			var st = ridge[i] + Vector2(0, h * 0.03)
			ci.draw_line(st, st + Vector2(rng.randf_range(-0.03, 0.03) * w, h * rng.randf_range(0.08, 0.24)), a(SUMI, min(0.5, col.a * 0.7)), 1.6, true)
	var line = []
	for i in range(2, n - 1):
		line.append(ridge[i])
	brush(ci, line, 2.0 + h * 0.012, a(SUMI, clamp(col.a * 1.25, 0.15, 0.85)))

# pine: a bent trunk and fans of needles, each needle one flick
static func pine(ci, base, s):
	var trunk = [base, base + Vector2(s * 0.06, -s * 0.25), base + Vector2(-s * 0.05, -s * 0.5), base + Vector2(s * 0.08, -s * 0.75), base + Vector2(s * 0.02, -s)]
	brush(ci, trunk, s * 0.11, SUMI)
	var tips = [Vector2(-0.36, -0.60), Vector2(0.38, -0.80), Vector2(-0.24, -0.96), Vector2(0.14, -1.08)]
	var roots = [trunk[2], trunk[3], trunk[4], trunk[4]]
	var needle = Color(0.09, 0.16, 0.12, 0.9)
	for i in range(4):
		var tip = base + tips[i] * s
		var mid = (roots[i] + tip) * 0.5 + Vector2(0, -s * 0.03)
		brush(ci, [roots[i], mid, tip], s * 0.045, SUMI)
		for c in [tip, mid]:
			blot(ci, c + Vector2(0, -s * 0.05), s * 0.22, s * 0.12, MATSU, 0.6)
			for k in range(13):
				var ang = -PI + PI * (k + 0.5) / 13.0
				ci.draw_line(c, c + Vector2(cos(ang), sin(ang) * 0.8) * s * 0.17, needle, max(1.0, s * 0.012), true)

static func sun(ci, c, r):
	blot(ci, c, r * 1.5, r * 1.5, SHU, 0.22)
	ci.draw_circle(c, r, a(SHU, 0.93))

# ---------------------------------------------------------------- terrain

static func rock(ci, c, s, sd):
	var rng = RandomNumberGenerator.new()
	rng.seed = sd
	var pts = PackedVector2Array()
	for i in range(9):
		var t = TAU * i / 9.0
		var r = s * rng.randf_range(0.30, 0.42)
		pts.append(c + Vector2(cos(t) * r, sin(t) * r * 0.8 + s * 0.06))
	blob(ci, pts, Color(0.50, 0.47, 0.43, 0.9), 3.0)
	ci.draw_colored_polygon(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], c + Vector2(0, s * 0.05)]), a(SUMI, 0.45))
	ci.draw_line(c + Vector2(-s * 0.1, s * 0.08), c + Vector2(s * 0.14, s * 0.2), a(SUMI, 0.6), 2.0, true)
	ci.draw_colored_polygon(ell(c + Vector2(-s * 0.2, s * 0.3), s * 0.16, s * 0.06, 10, PI, TAU), a(MATSU, 0.8))

# seigaiha: the old wave-scale pattern, brushed in indigo over a pale wash
static func water(ci, r, t):
	ci.draw_rect(r.grow(-1), a(AI, 0.20))
	blot(ci, r.get_center(), r.size.x * 0.62, r.size.y * 0.62, AI, 0.22)
	var s = r.size.x
	for row in range(3):
		for i in range(3):
			var off = s / 6.0 if row % 2 == 1 else 0.0
			var c = r.position + Vector2(off + s * (i + 0.5) / 3.0 + sin(t * 1.3 + row) * 2.0, s * (row + 1) / 3.0)
			if row % 2 == 1 and i == 2:
				continue
			for k in range(3):
				ci.draw_arc(c, s * (0.16 - k * 0.05), PI, TAU, 12, a(AI, 0.8 - k * 0.15), 2.0 - k * 0.4, true)
	# one crest curling over, with its claws of foam
	var cc = r.position + Vector2(s * (0.30 + 0.06 * sin(t * 0.9 + r.position.x)), s * 0.24)
	ci.draw_arc(cc, s * 0.13, PI * 0.9, PI * 2.15, 14, a(GOFUN, 0.95), 3.0, true)
	ci.draw_arc(cc, s * 0.13, PI * 0.9, PI * 2.15, 14, a(AI, 0.7), 1.2, true)
	for k in range(4):
		var ang = PI * 2.15 + k * 0.22
		ci.draw_circle(cc + Vector2(cos(ang), sin(ang)) * s * (0.14 + 0.02 * k), 2.3 - k * 0.3, a(GOFUN, 0.95))

# The strokes that cleared a stage, with the board taken away: what is left is handwriting.
# A stroke that never moved is a single dot.
# u: how much has been written so far, one stroke after another (1 = all of it)
static func calligraphy(ci, r, paths, w, h, u = 1.0):
	var cell = min(r.size.x / w, r.size.y / h)
	var org = r.position + (r.size - Vector2(w, h) * cell) * 0.5
	var n = max(1, paths.size())
	for i in range(paths.size()):
		var k = clamp(u * n - i, 0.0, 1.0)
		if k <= 0.0:
			break
		var pts = []
		for v in paths[i]:
			var q = Vector2(v.x, v.y) if v is Vector2i else Vector2(v[0], v[1])
			pts.append(org + (q + Vector2(0.5, 0.5)) * cell)
		if pts.size() == 1:
			ci.draw_circle(pts[0], cell * 0.15 * k, a(SUMI, 0.85))
		else:
			writing(ci, pts, cell * 0.42, a(SUMI, 0.88), k)

# hitodama: a soul leaving, pale blue, with a tail
static func hitodama(ci, c, s, t):
	var cc = c + Vector2(sin(t * 1.7) * s * 0.04, cos(t * 2.3) * s * 0.05)
	blot(ci, cc, s * 0.42, s * 0.42, Color(0.55, 0.78, 0.92), 0.55)
	var tail = []
	for k in range(7):
		var u = k / 6.0
		tail.append(cc + Vector2(sin(t * 3.0 + u * 4.0) * s * 0.07 * u, -s * 0.40 * u))
	brush(ci, tail, s * 0.20, Color(0.80, 0.92, 0.98, 0.9))
	ci.draw_circle(cc, s * 0.14, Color(0.93, 0.98, 1.0))
	ci.draw_arc(cc, s * 0.14, 0, TAU, 20, a(AI, 0.7), 1.5, true)

# shikigami: a folded paper figure bearing the name of what it was
static func shiki(ci, font, c, s, kanji):
	var pts = PackedVector2Array([c + Vector2(0, -s * 0.38), c + Vector2(s * 0.10, -s * 0.26), c + Vector2(s * 0.34, -s * 0.22),
		c + Vector2(s * 0.30, -s * 0.08), c + Vector2(s * 0.14, -s * 0.06), c + Vector2(s * 0.22, s * 0.36), c + Vector2(-s * 0.22, s * 0.36),
		c + Vector2(-s * 0.14, -s * 0.06), c + Vector2(-s * 0.30, -s * 0.08), c + Vector2(-s * 0.34, -s * 0.22), c + Vector2(-s * 0.10, -s * 0.26)])
	blob(ci, pts, GOFUN, 2.0)
	ci.draw_string(font, Vector2(c.x - s * 0.5, c.y + s * 0.18), kanji, HORIZONTAL_ALIGNMENT_CENTER, s, s * 0.30, SHU)

# the leaf a tanuki wears to change its shape
static func leaf(ci, c, s):
	blob(ci, PackedVector2Array([c + Vector2(-s * 0.12, 0), c + Vector2(0, -s * 0.07), c + Vector2(s * 0.13, -s * 0.01), c + Vector2(0, s * 0.06)]), Color(0.36, 0.52, 0.30), 1.5)
	ci.draw_line(c + Vector2(-s * 0.12, 0), c + Vector2(s * 0.13, -s * 0.01), a(SUMI, 0.6), 1.0, true)

# an offering: three dumplings on a little stand
static func offering(ci, c, s):
	blot(ci, c + Vector2(0, s * 0.06), s * 0.36, s * 0.26, KIN, 0.5)
	ci.draw_line(c + Vector2(-s * 0.24, s * 0.20), c + Vector2(s * 0.24, s * 0.20), SUMI, 3.5, true)
	ci.draw_line(c + Vector2(-s * 0.15, s * 0.20), c + Vector2(-s * 0.11, s * 0.33), SUMI, 2.5, true)
	ci.draw_line(c + Vector2(s * 0.15, s * 0.20), c + Vector2(s * 0.11, s * 0.33), SUMI, 2.5, true)
	var cols = [Color(0.93, 0.66, 0.68), GOFUN, Color(0.62, 0.74, 0.50)]
	for k in range(3):
		oval(ci, c + Vector2((k - 1) * s * 0.15, s * 0.10 - (s * 0.13 if k == 1 else 0.0)), s * 0.095, s * 0.088, cols[k], 1.6)

# a plank bridge over water; worn = Suzu has crossed it and it will not hold much longer
static func bridge(ci, r, worn):
	var w = r.size.x
	var wood = Color(0.60, 0.45, 0.28, 0.55 if worn else 0.96)
	for k in range(4):
		var pr = Rect2(r.position.x + w * 0.05, r.position.y + w * (0.10 + 0.205 * k), w * 0.90, w * 0.17)
		ci.draw_rect(pr, wood)
		ci.draw_rect(pr, a(SUMI, 0.75), false, 1.5)
	for sx in [0.16, 0.84]:
		ci.draw_line(r.position + Vector2(w * sx, w * 0.06), r.position + Vector2(w * sx, w * 0.94), a(SHU, 0.5 if worn else 0.95), 4.0, true)
	if worn:
		var z = PackedVector2Array()
		for k in range(7):
			z.append(r.position + Vector2(w * (0.14 + 0.12 * k), w * (0.5 + (0.1 if k % 2 == 0 else -0.1))))
		ci.draw_polyline(z, SUMI, 2.5, true)

# a spider's web
static func web(ci, c, s):
	var col = a(GOFUN, 0.95)
	var dk = a(SUMI, 0.6)
	for k in range(8):
		var d = Vector2(cos(k * TAU / 8.0 + 0.2), sin(k * TAU / 8.0 + 0.2))
		ci.draw_line(c, c + d * s * 0.46, dk, 2.2, true)
		ci.draw_line(c, c + d * s * 0.46, col, 1.2, true)
	for ring in [0.16, 0.29, 0.42]:
		var pts = PackedVector2Array()
		for k in range(9):
			pts.append(c + Vector2(cos(k * TAU / 8.0 + 0.2), sin(k * TAU / 8.0 + 0.2)) * s * ring)
		ci.draw_polyline(pts, dk, 2.2, true)
		ci.draw_polyline(pts, col, 1.2, true)

# one tile of the character to be written: pale until it is painted
static func mark(ci, r, done):
	if done:
		ci.draw_rect(r.grow(-5), a(SUMI, 0.86))
	else:
		ci.draw_rect(r.grow(-7), a(SUMI, 0.13))
		ci.draw_rect(r.grow(-7), a(SUMI, 0.3), false, 1.5)

# the number on a sealed yokai
static func tag(ci, font, c, s, kanji, open):
	var r = Rect2(c + Vector2(s * 0.16, -s * 0.46), Vector2(s * 0.28, s * 0.34))
	ci.draw_rect(r, GOFUN if not open else KIN)
	ci.draw_rect(r, SUMI if not open else SHU, false, 2.0)
	text(ci, font, Vector2(r.position.x, r.position.y + r.size.y * 0.78), kanji, s * (0.24 if kanji.length() == 1 else 0.14), SHU if not open else SUMI, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)

# torii: two posts, two lintels, vermilion
static func torii(ci, r):
	var c = r.get_center()
	var s = r.size.x
	blot(ci, c, s * 0.5, s * 0.5, KIN, 0.4)
	for sx in [-1.0, 1.0]:
		brush(ci, [c + Vector2(sx * s * 0.22, s * 0.36), c + Vector2(sx * s * 0.20, 0), c + Vector2(sx * s * 0.19, -s * 0.24)], s * 0.10, SHU)
	brush(ci, [c + Vector2(-s * 0.40, -s * 0.27), c + Vector2(0, -s * 0.31), c + Vector2(s * 0.40, -s * 0.27)], s * 0.12, SHU)
	ci.draw_line(c + Vector2(-s * 0.36, -s * 0.33), c + Vector2(s * 0.36, -s * 0.33), SUMI, 3.0, true)
	ci.draw_line(c + Vector2(-s * 0.27, -s * 0.10), c + Vector2(s * 0.27, -s * 0.10), SHU, s * 0.06, true)

# ice: a pale glaze with a few skate-marks of light
static func ice(ci, r):
	ci.draw_rect(r.grow(-1), Color(0.78, 0.87, 0.92, 0.8))
	for k in range(4):
		var o = r.size.x * (0.2 + 0.2 * k)
		ci.draw_line(r.position + Vector2(o, r.size.y * 0.14), r.position + Vector2(o - r.size.x * 0.12, r.size.y * 0.32), a(GOFUN, 0.95), 2.0, true)
		ci.draw_line(r.position + Vector2(o + 4, r.size.y * 0.62), r.position + Vector2(o - r.size.x * 0.1 + 4, r.size.y * 0.8), a(AI, 0.4), 1.5, true)

# fire: three licking strokes over a glow
static func fire(ci, r, t):
	var c = r.get_center()
	blot(ci, c, r.size.x * 0.6, r.size.y * 0.6, Color(0.92, 0.38, 0.10), 0.6)
	for k in range(3):
		var bx = c.x + (k - 1) * r.size.x * 0.2
		var hgt = r.size.y * (0.26 + 0.07 * sin(t * 5.0 + k * 2.1))
		brush(ci, [Vector2(bx, c.y + r.size.y * 0.28), Vector2(bx + sin(t * 4.0 + k) * 3.0, c.y + r.size.y * 0.02), Vector2(bx - sin(t * 3.0 + k) * 2.0, c.y - hgt)], r.size.x * 0.13, a(SHU, 0.9))

static func ward(ci, font, c, s):
	var r = Rect2(c - Vector2(s * 0.16, s * 0.34), Vector2(s * 0.32, s * 0.68))
	ci.draw_rect(r, GOFUN)
	ci.draw_rect(r, SUMI, false, 1.5)
	ci.draw_string(font, Vector2(r.position.x, c.y - s * 0.04), "結", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, s * 0.24, SHU)
	ci.draw_string(font, Vector2(r.position.x, c.y + s * 0.24), "界", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, s * 0.24, SHU)

# ---------------------------------------------------------------- figures

static func hp_pips(ci, c, s, hp, mx):
	for i in range(mx):
		var p = c + Vector2((i - (mx - 1) * 0.5) * s * 0.15, s * 0.43)
		if i < hp:
			ci.draw_circle(p, s * 0.05, SUMI)
		else:
			ci.draw_arc(p, s * 0.045, 0, TAU, 12, a(SUMI, 0.5), 1.2, true)

static func person(ci, c, s, robe, hat, bald = false):
	# robe with hanging sleeves
	blob(ci, PackedVector2Array([c + Vector2(-s * 0.10, -s * 0.10), c + Vector2(s * 0.10, -s * 0.10), c + Vector2(s * 0.31, s * 0.07),
		c + Vector2(s * 0.25, s * 0.19), c + Vector2(s * 0.15, s * 0.11), c + Vector2(s * 0.22, s * 0.38), c + Vector2(-s * 0.22, s * 0.38),
		c + Vector2(-s * 0.15, s * 0.11), c + Vector2(-s * 0.25, s * 0.19), c + Vector2(-s * 0.31, s * 0.07)]), robe, 2.2)
	brush(ci, [c + Vector2(-s * 0.07, -s * 0.09), c + Vector2(-s * 0.01, s * 0.02), c + Vector2(s * 0.04, s * 0.14)], s * 0.035, a(GOFUN, 0.9))
	brush(ci, [c + Vector2(-s * 0.17, s * 0.16), c + Vector2(0, s * 0.175), c + Vector2(s * 0.17, s * 0.16)], s * 0.06, SHU if not bald else KIN)
	# head
	oval(ci, c + Vector2(0, -s * 0.2), s * 0.11, s * 0.12, HADA, 1.8)
	if bald:
		ci.draw_arc(c + Vector2(0, -s * 0.16), s * 0.05, 0.2, PI - 0.2, 8, SUMI, 1.5, true)
		ci.draw_line(c + Vector2(-s * 0.07, -s * 0.22), c + Vector2(-s * 0.02, -s * 0.21), SUMI, 1.5, true)
		ci.draw_line(c + Vector2(s * 0.07, -s * 0.22), c + Vector2(s * 0.02, -s * 0.21), SUMI, 1.5, true)
	elif not hat:
		ci.draw_colored_polygon(ell(c + Vector2(0, -s * 0.22), s * 0.125, s * 0.12, 14, PI, TAU), SUMI)
	if hat:
		# sedge hat: a shallow curve, not a triangle
		var top = PackedVector2Array()
		for k in range(11):
			var x = lerp(-0.30, 0.30, k / 10.0)
			top.append(c + Vector2(x * s, -s * (0.21 + 0.20 * pow(1.0 - pow(abs(x) / 0.30, 1.6), 0.9))))
		for k in range(5):
			var x = lerp(0.24, -0.24, k / 4.0)
			top.append(c + Vector2(x * s, -s * (0.20 - 0.025 * (1.0 - pow(x / 0.24, 2)))))
		blob(ci, top, Color(0.78, 0.65, 0.40), 1.8)
		for k in [-0.16, -0.06, 0.06, 0.16]:
			ci.draw_line(c + Vector2(k * s * 0.2, -s * 0.40), c + Vector2(k * s, -s * 0.215), a(SUMI, 0.35), 1.0, true)

static func hero(ci, c, s):
	# the brush-blade, carried over the shoulder
	brush(ci, [c + Vector2(s * 0.10, s * 0.14), c + Vector2(s * 0.26, -s * 0.10), c + Vector2(s * 0.39, -s * 0.30)], s * 0.045, Color(0.42, 0.28, 0.17))
	brush(ci, [c + Vector2(s * 0.37, -s * 0.27), c + Vector2(s * 0.42, -s * 0.36), c + Vector2(s * 0.47, -s * 0.47)], s * 0.10, SUMI)
	person(ci, c, s, AI, true)

static func chochin(ci, c, s, t):
	var cc = c + Vector2(0, sin(t * 2.0) * s * 0.02)
	ci.draw_circle(cc, s * 0.36, a(Color(0.95, 0.6, 0.2), 0.16))
	oval(ci, cc, s * 0.22, s * 0.27, Color(0.93, 0.74, 0.42), 2.0)
	for i in range(-2, 3):
		var yy = i * s * 0.085
		var hw = s * 0.22 * sqrt(max(0.0, 1.0 - pow(yy / (s * 0.27), 2)))
		ci.draw_line(cc + Vector2(-hw, yy), cc + Vector2(hw, yy), a(SUMI, 0.35), 1.2, true)
	ci.draw_rect(Rect2(cc + Vector2(-s * 0.1, -s * 0.31), Vector2(s * 0.2, s * 0.06)), SUMI)
	ci.draw_rect(Rect2(cc + Vector2(-s * 0.1, s * 0.25), Vector2(s * 0.2, s * 0.05)), SUMI)
	ci.draw_circle(cc + Vector2(0, -s * 0.07), s * 0.075, GOFUN)
	ci.draw_circle(cc + Vector2(0.0, -s * 0.06), s * 0.035, SUMI)
	ci.draw_colored_polygon(ell(cc + Vector2(0, s * 0.07), s * 0.11, s * 0.05, 10, 0, PI), SUMI)
	blob(ci, PackedVector2Array([cc + Vector2(-s * 0.05, s * 0.08), cc + Vector2(s * 0.05, s * 0.08), cc + Vector2(s * 0.04, s * 0.22), cc + Vector2(-s * 0.03, s * 0.22)]), SHU, 1.2)

static func oni(ci, c, s, big):
	var col = Color(0.72, 0.22, 0.16)
	if big:
		col = Color(0.22, 0.33, 0.52)
	for sx in [-1.0, 1.0]:
		blob(ci, PackedVector2Array([c + Vector2(sx * s * 0.22, -s * 0.20), c + Vector2(sx * s * 0.30, -s * 0.44), c + Vector2(sx * s * 0.08, -s * 0.26)]), GOFUN, 1.5)
	ci.draw_colored_polygon(ell(c + Vector2(0, -s * 0.1), s * 0.33, s * 0.26, 14, PI, TAU), SUMI)
	oval(ci, c + Vector2(0, s * 0.03), s * 0.30, s * 0.28, col, 2.2)
	for sx in [-1.0, 1.0]:
		ci.draw_circle(c + Vector2(sx * s * 0.12, -s * 0.03), s * 0.06, GOFUN)
		ci.draw_circle(c + Vector2(sx * s * 0.11, -s * 0.02), s * 0.026, SUMI)
		ci.draw_line(c + Vector2(sx * s * 0.21, -s * 0.15), c + Vector2(sx * s * 0.04, -s * 0.08), SUMI, 3.5, true)
		blob(ci, PackedVector2Array([c + Vector2(sx * s * 0.07, s * 0.14), c + Vector2(sx * s * 0.13, s * 0.14), c + Vector2(sx * s * 0.10, s * 0.05)]), GOFUN, 1.0)
	ci.draw_arc(c + Vector2(0, s * 0.10), s * 0.15, 0.25, PI - 0.25, 12, SUMI, 2.5, true)
	if big:
		ci.draw_circle(c + Vector2(0, -s * 0.2), s * 0.035, KIN)

static func tengu(ci, c, s, big):
	for sx in [-1.0, 1.0]:
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(sx * s * 0.16, -s * 0.02), c + Vector2(sx * s * 0.44, -s * 0.24), c + Vector2(sx * s * 0.40, s * 0.02),
			c + Vector2(sx * s * 0.42, s * 0.2), c + Vector2(sx * s * 0.18, s * 0.2)]), SUMI)
	blob(ci, PackedVector2Array([c + Vector2(-s * 0.16, s * 0.1), c + Vector2(s * 0.16, s * 0.1), c + Vector2(s * 0.22, s * 0.36), c + Vector2(-s * 0.22, s * 0.36)]),
		KIN if big else GOFUN, 2.0)
	oval(ci, c + Vector2(0, -s * 0.08), s * 0.2, s * 0.21, Color(0.78, 0.2, 0.14), 2.0)
	ci.draw_rect(Rect2(c + Vector2(-s * 0.06, -s * 0.36), Vector2(s * 0.12, s * 0.09)), SUMI)
	for sx in [-1.0, 1.0]:
		ci.draw_line(c + Vector2(sx * s * 0.16, -s * 0.2), c + Vector2(sx * s * 0.04, -s * 0.14), GOFUN, 3.5, true)
		ci.draw_circle(c + Vector2(sx * s * 0.09, -s * 0.1), s * 0.024, SUMI)
	ci.draw_line(c + Vector2(0, -s * 0.06), c + Vector2(s * 0.24, s * 0.04), SUMI, s * 0.085, true)
	ci.draw_line(c + Vector2(0, -s * 0.06), c + Vector2(s * 0.23, s * 0.035), Color(0.84, 0.26, 0.18), s * 0.055, true)
	ci.draw_line(c + Vector2(-s * 0.08, s * 0.06), c + Vector2(s * 0.06, s * 0.06), SUMI, 2.0, true)

static func fox_head(ci, c, s, fur):
	for sx in [-1.0, 1.0]:
		blob(ci, PackedVector2Array([c + Vector2(sx * s * 0.06, -s * 0.16), c + Vector2(sx * s * 0.2, -s * 0.4), c + Vector2(sx * s * 0.24, -s * 0.1)]), fur, 2.0)
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(sx * s * 0.12, -s * 0.18), c + Vector2(sx * s * 0.19, -s * 0.33), c + Vector2(sx * s * 0.21, -s * 0.15)]), SHU)
	blob(ci, PackedVector2Array([c + Vector2(-s * 0.24, -s * 0.12), c + Vector2(0, -s * 0.2), c + Vector2(s * 0.24, -s * 0.12),
		c + Vector2(s * 0.16, s * 0.08), c + Vector2(0, s * 0.24), c + Vector2(-s * 0.16, s * 0.08)]), fur, 2.0)
	for sx in [-1.0, 1.0]:
		ci.draw_line(c + Vector2(sx * s * 0.16, -s * 0.07), c + Vector2(sx * s * 0.05, -s * 0.01), SUMI, 2.5, true)
		ci.draw_line(c + Vector2(sx * s * 0.19, s * 0.02), c + Vector2(sx * s * 0.1, s * 0.07), SHU, 2.0, true)
	ci.draw_circle(c + Vector2(0, s * 0.2), s * 0.03, SUMI)
	ci.draw_circle(c + Vector2(0, -s * 0.1), s * 0.025, SHU)

static func kitsune(ci, c, s, t):
	var pts = []
	for i in range(8):
		var u = i / 7.0
		pts.append(c + Vector2(s * (0.1 + 0.3 * u), s * (0.3 - 0.45 * u * u) + sin(t * 2.5 + u * 3.0) * s * 0.02))
	brush(ci, pts, s * 0.16, SUMI)
	brush(ci, pts, s * 0.11, GOFUN)
	blob(ci, PackedVector2Array([c + Vector2(-s * 0.14, s * 0.1), c + Vector2(s * 0.14, s * 0.1), c + Vector2(s * 0.18, s * 0.37), c + Vector2(-s * 0.18, s * 0.37)]), GOFUN, 2.0)
	fox_head(ci, c + Vector2(0, -s * 0.05), s * 0.9, GOFUN)

static func yurei(ci, c, s, t):
	var cc = c + Vector2(sin(t * 1.4) * s * 0.03, cos(t * 1.9) * s * 0.02)
	var body = PackedVector2Array([cc + Vector2(-s * 0.13, -s * 0.12), cc + Vector2(s * 0.13, -s * 0.12), cc + Vector2(s * 0.2, s * 0.12),
		cc + Vector2(s * 0.1, s * 0.26), cc + Vector2(s * 0.14, s * 0.4), cc + Vector2(-s * 0.02, s * 0.3), cc + Vector2(-s * 0.2, s * 0.14)])
	ci.draw_colored_polygon(body, Color(0.88, 0.92, 0.93, 0.85))
	var o = PackedVector2Array(body)
	o.append(body[0])
	ci.draw_polyline(o, a(AI, 0.7), 1.6, true)
	ci.draw_colored_polygon(PackedVector2Array([cc + Vector2(-s * 0.17, -s * 0.34), cc + Vector2(s * 0.17, -s * 0.34), cc + Vector2(s * 0.2, s * 0.1),
		cc + Vector2(s * 0.12, -s * 0.05), cc + Vector2(-s * 0.12, -s * 0.05), cc + Vector2(-s * 0.22, s * 0.14)]), SUMI)
	oval(ci, cc + Vector2(0, -s * 0.19), s * 0.11, s * 0.12, Color(0.93, 0.95, 0.95), 1.5)
	blob(ci, PackedVector2Array([cc + Vector2(-s * 0.07, -s * 0.28), cc + Vector2(s * 0.07, -s * 0.28), cc + Vector2(0, -s * 0.42)]), GOFUN, 1.5)
	for sx in [-1.0, 1.0]:
		ci.draw_line(cc + Vector2(sx * s * 0.07, -s * 0.2), cc + Vector2(sx * s * 0.025, -s * 0.185), SUMI, 2.0, true)
	ci.draw_line(cc + Vector2(-s * 0.03, -s * 0.12), cc + Vector2(s * 0.03, -s * 0.12), a(SHU, 0.8), 1.5, true)

static func tamamo(ci, c, s, t):
	for i in range(9):
		var ang = -PI * 0.5 + (i - 4) * 0.27 + sin(t * 1.2 + i) * 0.04
		var pts = []
		for k in range(7):
			var u = k / 6.0
			pts.append(c + Vector2(0, s * 0.2) + Vector2(cos(ang + u * 0.25 * sign(i - 4.0)), sin(ang + u * 0.25 * sign(i - 4.0))) * s * 0.52 * u)
		brush(ci, pts, s * 0.12, SUMI)
		brush(ci, pts, s * 0.08, Color(0.90, 0.76, 0.40))
	blob(ci, PackedVector2Array([c + Vector2(-s * 0.14, s * 0.08), c + Vector2(s * 0.14, s * 0.08), c + Vector2(s * 0.24, s * 0.38), c + Vector2(-s * 0.24, s * 0.38)]), Color(0.55, 0.16, 0.22), 2.0)
	ci.draw_line(c + Vector2(-s * 0.07, s * 0.09), c + Vector2(s * 0.03, s * 0.3), KIN, 2.5, true)
	fox_head(ci, c + Vector2(0, -s * 0.04), s * 0.85, Color(0.98, 0.93, 0.80))

static func figure(ci, kind, c, s, t, big = false):
	match kind:
		"hero": hero(ci, c, s)
		"monk": person(ci, c, s, Color(0.42, 0.38, 0.32), false, true)
		"monk2": person(ci, c, s, Color(0.60, 0.42, 0.18), false, true)
		"lady": person(ci, c, s, GOFUN, false)
		"chochin": chochin(ci, c, s, t)
		"oni": oni(ci, c, s, big)
		"tengu": tengu(ci, c, s, big)
		"kitsune": kitsune(ci, c, s, t)
		"yurei": yurei(ci, c, s, t)
		"tamamo": tamamo(ci, c, s, t)
