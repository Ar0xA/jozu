extends RefCounted
# 暦 The old almanac: the year in twenty-four solar terms (sekki), each in three spans of about
# five days (kō), seventy-two in all, each named for what the land is doing. The names are those
# of the Japanese almanac of 1874 (略本暦). The dates are the usual ones and can be a day out in a
# given year. Three names are given in English only: the game's typeface lacks a character of theirs.

# [month, day the sekki begins, sekki, its reading, then three kō: kanji, English]
const SEKKI = [
	[2, 4, "立春", "Risshun", "東風解凍", "The east wind melts the ice", "", "Bush warblers sing in the hills", "魚上氷", "Fish rise through the ice"],
	[2, 19, "雨水", "Usui", "土脉潤起", "Rain wets the soil", "霞始靆", "Mist begins to trail", "草木萌動", "Grass and trees put out buds"],
	[3, 6, "啓蟄", "Keichitsu", "蟄虫啓戸", "Wintering insects open their doors", "桃始笑", "The peach begins to bloom", "菜虫化蝶", "Caterpillars become butterflies"],
	[3, 21, "春分", "Shunbun", "雀始巣", "Sparrows begin to nest", "桜始開", "The cherry begins to open", "雷乃発声", "Thunder finds its voice"],
	[4, 5, "清明", "Seimei", "玄鳥至", "Swallows arrive", "鴻雁北", "Wild geese fly north", "虹始見", "The first rainbow is seen"],
	[4, 20, "穀雨", "Kokuu", "葭始生", "The first reeds sprout", "霜止出苗", "Frost ends; rice seedlings grow", "牡丹華", "Peonies bloom"],
	[5, 6, "立夏", "Rikka", "蛙始鳴", "Frogs begin to sing", "蚯蚓出", "Worms come up", "竹笋生", "Bamboo shoots appear"],
	[5, 21, "小満", "Shōman", "蚕起食桑", "Silkworms wake and eat mulberry", "紅花栄", "Safflowers bloom", "麦秋至", "The barley ripens"],
	[6, 6, "芒種", "Bōshu", "螳螂生", "Mantises hatch", "腐草為蛍", "Rotting grass turns to fireflies", "梅子黄", "Plums turn yellow"],
	[6, 21, "夏至", "Geshi", "乃東枯", "Self-heal withers", "菖蒲華", "Irises bloom", "半夏生", "Crow-dipper sprouts"],
	[7, 7, "小暑", "Shōsho", "温風至", "Warm winds blow", "蓮始開", "The lotus begins to open", "鷹乃学習", "Young hawks learn to fly"],
	[7, 23, "大暑", "Taisho", "桐始結花", "The paulownia sets its seed", "土潤溽暑", "The earth is damp, the air heavy", "大雨時行", "Great rains fall at times"],
	[8, 8, "立秋", "Risshū", "涼風至", "A cool wind comes", "寒蝉鳴", "Evening cicadas sing", "蒙霧升降", "Thick fog comes down"],
	[8, 23, "処暑", "Shosho", "綿柎開", "Cotton bolls open", "天地始粛", "Heaven and earth begin to cool", "禾乃登", "The rice ripens"],
	[9, 8, "白露", "Hakuro", "草露白", "Dew whitens the grass", "鶺鴒鳴", "Wagtails sing", "玄鳥去", "Swallows leave"],
	[9, 23, "秋分", "Shūbun", "雷乃収声", "Thunder falls silent", "蟄虫坏戸", "Insects close their doors", "水始涸", "The fields are drained"],
	[10, 8, "寒露", "Kanro", "鴻雁来", "Wild geese return", "菊花開", "Chrysanthemums bloom", "蟋蟀在戸", "Crickets chirp at the door"],
	[10, 23, "霜降", "Sōkō", "霜始降", "The first frost falls", "霎時施", "Light rains fall now and then", "楓蔦黄", "Maple and ivy turn"],
	[11, 7, "立冬", "Rittō", "山茶始開", "Camellias begin to bloom", "地始凍", "The earth begins to freeze", "金盞香", "Daffodils bloom"],
	[11, 22, "小雪", "Shōsetsu", "虹蔵不見", "The rainbow hides", "朔風払葉", "The north wind strips the leaves", "橘始黄", "Tachibana leaves turn yellow"],
	[12, 7, "大雪", "Taisetsu", "閉塞成冬", "The sky closes; winter comes", "熊蟄穴", "Bears go to their dens", "", "Salmon gather and run"],
	[12, 22, "冬至", "Tōji", "乃東生", "Self-heal sprouts", "麋角解", "Deer shed their antlers", "雪下出麦", "Barley sprouts under snow"],
	[1, 6, "小寒", "Shōkan", "芹乃栄", "Parsley thrives", "水泉動", "Springs thaw", "", "Pheasants begin to call"],
	[1, 20, "大寒", "Daikan", "款冬華", "Butterburs bud", "水沢腹堅", "Ice lies thick on the streams", "鶏始乳", "Hens begin to lay"],
]
const DAYS = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]

static func _day(month, day):
	return DAYS[month - 1] + day

# What the almanac says of a day: [sekki, its reading, kō in kanji, kō in English, season 0-3 from spring].
static func on(month, day):
	var d = _day(month, day)
	var best = SEKKI.size() - 3   # before 6 January it is still the winter solstice's term
	var from = -1
	for i in range(SEKKI.size()):
		var s = _day(SEKKI[i][0], SEKKI[i][1])
		if s <= d and s > from:
			from = s
			best = i
	var e = SEKKI[best]
	var into = d - _day(e[0], e[1])
	if from < 0:
		into = d + 365 - _day(e[0], e[1])
	var k = clamp(into / 5, 0, 2)
	return [e[2], e[3], e[4 + k * 2], e[5 + k * 2], best / 6]

# The season's own colour, for the line that names the day: plum, pine, persimmon, indigo.
const TINT = [Color(0.66, 0.30, 0.42), Color(0.26, 0.36, 0.28), Color(0.68, 0.33, 0.13), Color(0.17, 0.25, 0.40)]

static func today():
	var t = Time.get_date_dict_from_system()
	return on(t.month, t.day)
