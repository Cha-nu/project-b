extends Node
## 저장 (오토로드 "Save"). user://morse_save.json 에 골드·해금·장착·설정을 저장한다.

const Data := preload("res://scripts/data.gd")
const PATH := "user://morse_save.json"

var d: Dictionary = {}


func _ready() -> void:
	load_save()


func _default() -> Dictionary:
	return {gold = 0, own = ["air", "supply", "turret"], eq = ["air", "supply", "turret"], w = "ar", aim = "auto", snd = true, runs = 0}


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
	for id in s.get("own", []) + _default().own:
		if ok.call(id) and not own.has(str(id)):
			own.append(str(id))
	var eq: Array = []
	for id in s.get("eq", []):
		if own.has(str(id)) and not eq.has(str(id)) and eq.size() < 3:
			eq.append(str(id))
	for id in own:
		if eq.size() < 3 and not eq.has(id):
			eq.append(id)
	s.own = own
	s.eq = eq
	var wid := str(s.get("w", "ar"))
	s.w = wid if Data.WEAPONS.any(func(w): return w.id == wid) else "ar"
	s.gold = maxi(0, int(s.get("gold", 0)))
	s.runs = int(s.get("runs", 0))
	s.snd = bool(s.get("snd", true))
	s.aim = "manual" if str(s.get("aim", "auto")) == "manual" else "auto"
	return s


func persist() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))
