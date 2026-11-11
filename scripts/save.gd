extends Node
## 저장 (오토로드 "Save"). user://morse_save.json 에 골드·해금·장착·설정을 저장한다.

const Data := preload("res://scripts/data.gd")
const PATH := "user://morse_save.json"

var d: Dictionary = {}


func _ready() -> void:
	load_save()


func _default() -> Dictionary:
	return {gold = 0, own = ["air", "supply", "turret"], eq = ["air", "supply", "turret"], slots = 3, w = "ar1", wown = ["ar1"], aim = "auto", snd = true, runs = 0, stage = 1}


func load_save() -> void:
	var s := _default()
	if FileAccess.file_exists(PATH):
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				for k in parsed:
					s[k] = parsed[k]
	d = _fix(s)
	Synth.enabled = d.snd


func _fix(s: Dictionary) -> Dictionary:
	var ok := func(id): return not Data.strat(str(id)).is_empty()
	var own: Array = []
	## 예전 "공격 드론"은 "거치 기관총"으로 바뀌었다
	var ren := func(a: Array) -> Array: return a.map(func(id): return "hmg" if str(id) == "drone" else id)
	s.own = ren.call(s.get("own", []))
	s.eq = ren.call(s.get("eq", []))
	for id in s.get("own", []) + _default().own:
		if ok.call(id) and not own.has(str(id)):
			own.append(str(id))
	## 지원요청 장착 칸 (기본 3, 골드로 4까지 늘린다)
	s.slots = clampi(int(s.get("slots", 3)), 3, Data.SLOT_MAX)
	var eq: Array = []
	for id in s.get("eq", []):
		if own.has(str(id)) and not eq.has(str(id)) and eq.size() < int(s.slots):
			eq.append(str(id))
	for id in own:
		if eq.size() < int(s.slots) and not eq.has(id):
			eq.append(id)
	s.own = own
	s.eq = eq
	## 무기: 예전 저장(계열 이름)은 1등급으로 옮기고, 그때 쓰던 무기는 보유한 것으로 친다
	var wid := str(s.get("w", "ar1"))
	if ["ar", "sg", "lmg", "rail"].has(wid):
		wid += "1"
	var wok := func(x): return Data.WEAPONS.any(func(w): return w.wid == str(x))
	if not wok.call(wid):
		wid = "ar1"
	var wown: Array = ["ar1"]
	for x in s.get("wown", []) + [wid]:
		if wok.call(x) and not wown.has(str(x)):
			wown.append(str(x))
	s.w = wid
	s.wown = wown
	## 열린 스테이지 수 (1~10)
	s.stage = clampi(int(s.get("stage", 1)), 1, 10)
	s.gold = maxi(0, int(s.get("gold", 0)))
	s.runs = int(s.get("runs", 0))
	s.snd = bool(s.get("snd", true))
	s.aim = "manual" if str(s.get("aim", "auto")) == "manual" else "auto"
	return s


func persist() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))
