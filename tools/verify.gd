extends SceneTree
# Proof that every stage can be mastered:  godot --headless --path . -s tools/verify.gd
# Replays the stored solution of each stage through the real rules (scripts/sim.gd) at base
# stats and checks it wins, unharmed, in exactly the stage's mastery stroke count.

const Sim = preload("res://scripts/sim.gd")
const Data = preload("res://scripts/data.gd")
const DIR = {"R": Vector2i(1, 0), "L": Vector2i(-1, 0), "D": Vector2i(0, 1), "U": Vector2i(0, -1)}

func _init():
	var sols = JSON.parse_string(FileAccess.get_file_as_string("res://tools/solutions.json"))
	var bad = 0
	for i in range(Data.LEVELS.size()):
		var lv = Data.LEVELS[i]
		var why = check(lv, sols.get(lv.kanji + "|" + "".join(lv.rows), ""))
		if why != "":
			bad += 1
			print("FAIL %3d %s  %s" % [i + 1, lv.kanji, why])
	print("%d stages checked, %d failed" % [Data.LEVELS.size(), bad])
	quit(1 if bad > 0 else 0)

func check(lv, trace):
	if trace == "":
		return "no stored solution"
	var s = Sim.new_state(lv.rows, Data.base_stats(lv))
	var strokes = trace.split(" / ")
	for k in range(strokes.size()):
		for tok in strokes[k].split(" ", false):
			var ok = false
			if tok == "KATSU":
				ok = Sim.act_katsu(s)
			elif tok.begins_with("leap"):
				ok = Sim.act_leap(s, DIR[tok.substr(4)])
			elif tok.begins_with("ward"):
				ok = Sim.act_ward(s, DIR[tok.substr(4)])
			else:
				ok = Sim.act_move(s, DIR[tok])
			if not ok:
				return "illegal action '%s' in stroke %d" % [tok, k + 1]
		if s.status == "won":
			break
		Sim.end_stroke(s)
	if s.status != "won":
		return "does not win (status %s, %d yokai left)" % [s.status, s.yokai.size()]
	if s.hits > 0:
		return "takes %d blows" % s.hits
	if s.turn != lv.par:
		return "wins in %d strokes but par is %d" % [s.turn, lv.par]
	return ""
