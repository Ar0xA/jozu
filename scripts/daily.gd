extends "res://scripts/screen_base.gd"
# The days gone by: five weeks of daily koan, each still there to be sat with.

const WEEKS = 5
const CW = 132.0
const CH = 84.0
const ORG = Vector2(110, 150)
var first_day = 0
var note = ""
var b_copy

func setup():
	var t = main.today()
	first_day = t - ((t + 3) % 7) - (WEEKS - 1) * 7     # the Monday four weeks back
	b_copy = btn(Rect2(1046, 296, 200, 60) if main.touch else Rect2(1046, 300, 200, 46), "Copy" if main.touch else "Copy the line", _copy, "写")
	btn(Rect2(40, 642, 260, 66) if main.touch else Rect2(40, 656, 220, 46), "Back", main.show_hub, "道")

func _copy():
	var line = main.daily_line(main.today())
	if line == "":
		note = "Answer today's kōan first."
		return
	DisplayServer.clipboard_set(line)
	note = "Copied."

func _cell(day):
	var k = day - first_day
	return Rect2(ORG + Vector2((k % 7) * CW, (k / 7) * CH), Vector2(CW - 8, CH - 8))

func on_click(pos, button):
	if button != MOUSE_BUTTON_LEFT:
		return
	for day in range(first_day, main.today() + 1):
		if _cell(day).has_point(pos):
			main.show_daily(day, main.show_calendar)
			return

func on_key(code):
	if code == KEY_ESCAPE:
		main.show_hub()

func _draw():
	var f = main.font
	draw_texture_rect(main.art["tohaku"], Rect2(0, 0, 1280, 720), false, Color(1, 1, 1, 0.4))
	Ink.tategaki(self, f, Vector2(64, 4), "暦", 46, Ink.SUMI)
	Ink.text(self, f, Vector2(110, 46), "Days Gone By", 32, Ink.SUMI)
	Ink.text(self, f, Vector2(110, 78), "Tap a day to sit with its kōan. Only today's counts toward the run." if main.touch else "Every day's kōan stays where it was. Choose a day to sit with it; only today's counts toward the run of days.", 22 if main.touch else 16, Ink.a(Ink.SUMI, 0.7))
	var names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
	for k in range(7):
		Ink.text(self, f, Vector2(ORG.x + k * CW, ORG.y - 14), names[k], 17, Ink.a(Ink.SUMI, 0.7), HORIZONTAL_ALIGNMENT_CENTER, CW - 8)
	var today = main.today()
	var answered = 0
	for day in range(first_day, first_day + WEEKS * 7):
		var r = _cell(day)
		var d = Time.get_date_dict_from_unix_time(day * 86400)
		if day > today:
			draw_rect(r, Ink.a(Ink.GOFUN, 0.2))
			continue
		draw_rect(r, Ink.a(Ink.GOFUN, 0.75 if r.has_point(mouse) else 0.55))
		Ink.frame(self, r, 3.0 if day == today else 1.5, Ink.SHU if day == today else Ink.a(Ink.SUMI, 0.6))
		Ink.text(self, f, r.position + Vector2(8, 28 if main.touch else 24), "%d.%d" % [d.month, d.day], 25 if main.touch else 17, Ink.SUMI)
		var n = int(main.data.days.get(str(day), 0))
		if n > 0:
			answered += 1
			Ink.seal(self, f, r.position + Vector2(r.size.x - 32, 44), 13, "済")
			Ink.text(self, f, r.position + Vector2(8, 62), ("1st" if n == 1 else "try %d" % n) if main.touch else ("first stroke" if n == 1 else "attempt %d" % n), 19 if main.touch else 13, Ink.a(Ink.SUMI, 0.7))
		elif int(main.data.tries.get(str(day), 0)) > 0:
			Ink.text(self, f, r.position + Vector2(8, 62), "%d tried" % int(main.data.tries[str(day)]), 19 if main.touch else 13, Ink.a(Ink.SHU, 0.8))
	var dd = main.data.daily
	var x = 1046.0
	Ink.text(self, f, Vector2(x, 170), "Days running", 16, Ink.a(Ink.SUMI, 0.7))
	Ink.text(self, f, Vector2(x, 204), str(int(dd.streak) if int(dd.last) >= today - 1 else 0), 34, Ink.SHU)
	Ink.text(self, f, Vector2(x + 130, 170), "Longest", 16, Ink.a(Ink.SUMI, 0.7))
	Ink.text(self, f, Vector2(x + 130, 204), str(int(dd.best)), 34, Ink.SUMI)
	Ink.text(self, f, Vector2(x, 244), "Answered: %d of %d" % [answered, today - first_day + 1], 19 if main.touch else 15, Ink.a(Ink.SUMI, 0.7))
	Ink.text(self, f, Vector2(x, 284), "Today's result:", 19 if main.touch else 15, Ink.a(Ink.SUMI, 0.7))
	var line = main.daily_line(today)
	Ink.para(self, f, Vector2(x, 372), line if line != "" else "Not yet answered today.", 16 if main.touch else 12, Ink.a(Ink.AI, 0.95), 222)
	if note != "":
		Ink.text(self, f, Vector2(x, 500), note, 15, Ink.SHU)
	draw_btns()
