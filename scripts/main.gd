extends Node
## 진입점. 로비 ↔ 전투 전환, 진급·일시정지·결과 화면을 관리한다.

const UI := preload("res://scripts/ui.gd")
const GameScript := preload("res://scripts/game.gd")
const HudScript := preload("res://scripts/hud.gd")
const LobbyScript := preload("res://scripts/lobby.gd")

var game: Node3D
var ui: Control
var hud: Control
var lobby: Control
var lvl_ov: Control
var lvl_box: VBoxContainer
var lvl_title: Label
var pause_ov: Control
var pause_aim: Button
var res_ov: Control
var res_box: VBoxContainer
var seed_v := 0


func _ready() -> void:
	randomize()
	seed_v = randi() % 0xffff
	game = GameScript.new()
	add_child(game)
	var cl = CanvasLayer.new()
	add_child(cl)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = UI.make_theme()
	cl.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	## 로비 배경 아래쪽을 어둡게
	hud = HudScript.new()
	hud.game = game
	hud.visible = false
	ui.add_child(hud)
	game.hud = hud
	lobby = LobbyScript.new()
	ui.add_child(lobby)
	lobby.deploy.connect(_deploy)
	hud.pause_pressed.connect(_pause)
	game.leveled.connect(_level_up)
	game.ended.connect(_ended)
	_build_overlays()
	_to_lobby()
	## 자동 점검용: --autotest 인자로 실행하면 전투를 시작하고 스크린샷을 남긴 뒤 종료
	if "--autotest" in OS.get_cmdline_user_args():
		_autotest()


func _ov() -> Array:
	var ov = ColorRect.new()
	ov.color = Color(0.016, 0.02, 0.024, 0.8)
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.visible = false
	ui.add_child(ov)
	var cc = CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.add_child(cc)
	var p = PanelContainer.new()
	p.custom_minimum_size = Vector2(640, 0)
	p.add_theme_stylebox_override("panel", UI.box(UI.PANEL2, UI.GOLD, 1, 5, UI.GOLD, 26))
	cc.add_child(p)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	p.add_child(v)
	return [ov, v]


func _title(t: String) -> Label:
	var l = UI.label(t, 48, UI.GOLD, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _build_overlays() -> void:
	var r = _ov()
	lvl_ov = r[0]
	lvl_title = _title("진급! 보급 선택")
	r[1].add_child(lvl_title)
	lvl_box = VBoxContainer.new()
	lvl_box.add_theme_constant_override("separation", 14)
	r[1].add_child(lvl_box)
	r = _ov()
	pause_ov = r[0]
	r[1].add_child(_title("일시 정지"))
	pause_aim = UI.dark_button("", 28)
	pause_aim.pressed.connect(func():
		Save.d.aim = "manual" if Save.d.aim == "auto" else "auto"
		Save.persist()
		_aim_text())
	r[1].add_child(pause_aim)
	var res = UI.gold_button("계속하기", 40)
	res.custom_minimum_size.y = 96
	res.pressed.connect(func():
		pause_ov.visible = false
		game.pause = "")
	r[1].add_child(res)
	var quit = UI.dark_button("작전 포기", 32)
	quit.custom_minimum_size.y = 84
	quit.pressed.connect(func():
		pause_ov.visible = false
		game.end_game(false))
	r[1].add_child(quit)
	r = _ov()
	res_ov = r[0]
	res_box = r[1]


func _aim_text() -> void:
	pause_aim.text = "지원요청 투하 위치: " + ("수동" if Save.d.aim == "manual" else "자동")


func _to_lobby() -> void:
	seed_v = randi() % 0xffff
	hud.visible = false
	res_ov.visible = false
	pause_ov.visible = false
	lvl_ov.visible = false
	game.active = false
	## 로비는 지구본 화면이므로 전투 맵은 비워 둔다
	game.preview_mode = false
	game._clear()
	lobby.visible = true
	lobby.tab("play")
	lobby.refresh()


func _deploy() -> void:
	lobby.visible = false
	res_ov.visible = false
	var m: Dictionary = lobby.current()
	seed_v = m.seed
	game.new_game(seed_v, m.diff)
	hud.build()
	hud.visible = true


func _pause() -> void:
	if game.active and game.run and game.pause == "":
		game.pause = "menu"
		game.release_key(true)
		_aim_text()
		pause_ov.visible = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if game and game.active and game.run and game.pause == "" and not OS.is_debug_build():
			_pause()


func _level_up(opts: Array) -> void:
	lvl_title.text = "진화 가능!" if opts[0].has("evo") else "진급! 보급 선택"
	for c in lvl_box.get_children():
		c.queue_free()
	for o in opts:
		var b = Button.new()
		b.custom_minimum_size = Vector2(0, 128)
		var evo: bool = o.has("evo")
		var sub: bool = o.has("up") and o.up.get("sub", false)
		var st = UI.box(Color("#3a2f0e") if evo else UI.PANEL2, UI.GOLD if evo else UI.LINE, 1, 0, UI.GOLD, 14, 8, UI.GOLD if evo else UI.GREEN if sub else UI.BLUE)
		for k in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(k, st)
		var h = HBoxContainer.new()
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 26; h.offset_right = -18
		h.add_theme_constant_override("separation", 18)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(h)
		var tag: String = "EVO" if evo else "HP" if o.has("heal") else o.up.t
		var tl = UI.label(tag, 28, UI.GOLD if evo else UI.TEXT, true)
		tl.custom_minimum_size = Vector2(90, 0)
		tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tl.size_flags_vertical = Control.SIZE_FILL
		h.add_child(tl)
		var v = VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(v)
		var name = ""
		var desc = ""
		var lv = ""
		if evo:
			name = o.evo.n; desc = o.evo.d; lv = "진화"
		elif o.has("heal"):
			name = "전투 식량"; desc = "체력 40 회복"
		else:
			var l: int = game.p.up.get(o.up.id, 0)
			name = o.up.n
			if sub and l == 0:
				name += "  [새 보조무기]"
			elif o.get("mat", false):
				name += "  [진화 재료]"
			desc = o.up.d
			lv = "Lv %d → %d" % [l, l + 1]
		v.add_child(UI.label(name, 30, UI.TEXT, true))
		var dl = UI.label(desc, 21, Color("#d7d4c9"))
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(dl)
		if lv != "":
			var ll = UI.label(lv, 19, UI.MUTE, true)
			ll.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			ll.size_flags_vertical = Control.SIZE_FILL
			h.add_child(ll)
		b.pressed.connect(func():
			lvl_ov.visible = false
			game.choose_upgrade(o))
		lvl_box.add_child(b)
	lvl_ov.visible = true


func _ended(win: bool, rows: Array, total: int, stars: int) -> void:
	if win:
		lobby.complete_current()
	for c in res_box.get_children():
		c.queue_free()
	res_box.add_child(_title("임무 성공" if win else "임무 실패"))
	var st = UI.label("★".repeat(stars) + "☆".repeat(3 - stars), 64, UI.GOLD, true)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	res_box.add_child(st)
	var rp = PanelContainer.new()
	rp.add_theme_stylebox_override("panel", UI.box(Color("#0f1113"), Color("#262a2e"), 1, 0, UI.GOLD, 18))
	var rv = VBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	rp.add_child(rv)
	for r in rows:
		var h = HBoxContainer.new()
		var a = UI.label(r[0], 24, UI.MUTE)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(a)
		h.add_child(UI.label("+%d" % r[1], 24, UI.TEXT, true))
		rv.add_child(h)
	var tot = HBoxContainer.new()
	var ta = UI.label("획득 골드", 32, UI.GOLD, true)
	ta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tot.add_child(ta)
	tot.add_child(UI.label("◆ %d" % total, 32, UI.GOLD, true))
	rv.add_child(HSeparator.new())
	rv.add_child(tot)
	res_box.add_child(rp)
	var again = UI.gold_button("다음 작전 출격" if win else "다시 출격", 40)
	again.custom_minimum_size.y = 96
	again.pressed.connect(_deploy)
	res_box.add_child(again)
	var menu = UI.dark_button("로비로", 32)
	menu.custom_minimum_size.y = 84
	menu.pressed.connect(_to_lobby)
	res_box.add_child(menu)
	res_ov.visible = true


## ---------- 자동 점검 ----------
func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	img.save_png("user://autotest_%s.png" % name)
	print("AUTOTEST shot ", ProjectSettings.globalize_path("user://autotest_%s.png" % name))


func _autotest() -> void:
	await get_tree().create_timer(1.0).timeout
	await _shot("lobby")
	lobby._step(1)
	await get_tree().create_timer(1.2).timeout
	await _shot("lobby_next")
	for tb in ["strat", "weap"]:
		lobby.tab(tb)
		await get_tree().create_timer(0.3).timeout
		await _shot("lobby_" + tb)
	lobby.tab("play")
	_deploy()
	## 근처 경비 초소로 이동시켜 적과 구조물이 화면에 들어오게 한다
	var o: Dictionary = game.map.objs[0]
	game.p.x = o.x + 60
	game.p.y = o.y + 230
	game.p.inv = 999.0
	await get_tree().create_timer(2.5).timeout
	await _shot("battle")
	for s in game.strats:
		s.t = 0.0
		game.exec(s, game.auto_target(s))
	await get_tree().create_timer(0.62).timeout
	print("AUTOTEST flyby jets=%d warns=%d" % [game.jets.size(), game.calls.filter(func(c): return c.get("w", false)).size()])
	await _shot("flyby")
	await get_tree().create_timer(1.0).timeout
	await _shot("strike")
	## 정밀 공습만 단독으로
	await get_tree().create_timer(2.0).timeout
	var air = game.strats.filter(func(q): return q.id == "air")
	if game.pause == "lvl":
		lvl_ov.visible = false
		game.choose_upgrade({heal = true})
	game.p.xp = 0
	game.gems.clear()
	if air.size():
		game.exec(air[0], {x = game.p.x - 60, y = game.p.y + 60, ang = 0.0})
		await get_tree().create_timer(0.7).timeout
		await _shot("air_pass")
		await get_tree().create_timer(0.3).timeout
		await _shot("air_drop")
	## 실제 입력 경로 점검: 전건을 터치로 눌러 첫 지원요청 부호 입력
	await get_tree().create_timer(1.0).timeout
	for s in game.strats:
		s.t = 0.0
	game.map.objs.filter(func(q): return q.type == "aa")[0].done = true
	var kc: Vector2 = get_viewport().get_final_transform() * hud.key.get_global_rect().get_center()
	var code: String = game.strats[0].code
	var ci = 0
	for ch in code:
		var ev = InputEventScreenTouch.new()
		ev.index = 0
		ev.position = kc
		ev.pressed = true
		Input.parse_input_event(ev)
		if ci == 2:
			await get_tree().create_timer(0.03).timeout
			await _shot("morse_input")
			await get_tree().create_timer(0.02 if ch == "." else 0.29).timeout
		else:
			await get_tree().create_timer(0.05 if ch == "." else 0.32).timeout
		ci += 1
		var ev2 = InputEventScreenTouch.new()
		ev2.index = 0
		ev2.position = kc
		ev2.pressed = false
		Input.parse_input_event(ev2)
		await get_tree().create_timer(0.12).timeout
	print("AUTOTEST key code=%s fired=%s buf=%s" % [code, game.strats[0].t > 0, game.M.buf])
	## 조이스틱: 두 번째 손가락으로 오른쪽으로 끈다
	var x0: float = game.p.x
	var jp = Vector2(520, 760)
	var t1 = InputEventScreenTouch.new()
	t1.index = 1
	t1.position = jp
	t1.pressed = true
	Input.parse_input_event(t1)
	var dr = InputEventScreenDrag.new()
	dr.index = 1
	dr.position = jp + Vector2(80, 0)
	Input.parse_input_event(dr)
	await get_tree().create_timer(0.6).timeout
	var t2 = InputEventScreenTouch.new()
	t2.index = 1
	t2.position = jp + Vector2(80, 0)
	t2.pressed = false
	Input.parse_input_event(t2)
	print("AUTOTEST joystick dx=%d face=%.2f" % [game.p.x - x0, game.p.face])
	await _shot("input")
	## 증원 요청 → 무전병 처치 시 취소
	var caller = null
	for e in game.en:
		if e.type == "ru" and e.hp > 0:
			caller = e
			break
	if caller != null:
		game.rcall = null
		game.rcd = 0.0
		caller.st = "post"
		caller.x = game.p.x + 160
		caller.y = game.p.y - 60
		var heat0 = game.heat
		game.alert_e(caller)
		var calling = is_same(game.rcall, caller) and caller.st == "call"
		await get_tree().create_timer(1.2).timeout
		await _shot("call")
		for st in game.strats:
			st.t = 20.0
		game.hit_enemy(caller, 9999.0, true)
		game.update(1.0 / 30.0)
		print("AUTOTEST cancel calling=%s cleared=%s heat=%d->%d rcd=%.1f strat_cd=%.1f" % [calling, game.rcall == null, heat0, game.heat, game.rcd, game.strats[0].t])
	## 무기 진화 연출
	for ev in preload("res://scripts/data.gd").EVOS:
		if ev.get("w", "") == game.p.w.id:
			game.choose_upgrade({evo = ev})
			break
	await get_tree().create_timer(0.35).timeout
	await _shot("evo")
	await get_tree().create_timer(1.9).timeout
	print("AUTOTEST evo evoT=%.2f glow=%s" % [game.evoT, game.player_node.get_node_or_null("Body/Gun/EvoGlow") != null])
	await _shot("evo_fire")
	## 통신 드론 진화: 교전 상황에서 지원요청을 스스로 호출하는지
	for ev in preload("res://scripts/data.gd").EVOS:
		if ev.id == "comms":
			game.choose_upgrade({evo = ev})
	for st in game.strats:
		st.t = 30.0
	game.p.inv = 99.0
	for i in 6:
		game.spawn("rf", game.p.x + 220 + i * 12, game.p.y - 60 + i * 20)
	var fired = []
	for i in 240:
		var before = {}
		for st in game.strats:
			before[st.id] = game.comms.cd[st.id]
		game.update(1.0 / 30.0)
		for st in game.strats:
			if game.comms.cd[st.id] > before[st.id] + 0.5:
				fired.append(st.id)
	print("AUTOTEST comms fired=%s player_cd=%.1f alertN=%d" % [fired, game.strats[0].t, game.alertN])
	await get_tree().create_timer(0.8).timeout
	await _shot("comms")
	game.p.inv = 0.0
	## 통신탑 점령 → 무조건 증원
	for co in game.map.objs:
		if co.type == "cap":
			var n0 = game.en.size()
			game.p.x = co.x
			game.p.y = co.y
			for i in 120:
				game.update(1.0 / 30.0)
			print("AUTOTEST siege on=%s prog=%.2f waves_spawned=%d" % [co.get("siege", false), co.prog, game.siegeN])
			await get_tree().create_timer(0.4).timeout
			await _shot("siege")
			break
	## 대규모 증원
	var pat = 0
	for e in game.en:
		if e.home == "patrol":
			pat += 1
	var e0 = game.en.size()
	game.p.inv = 99.0
	if game.pause == "lvl":
		lvl_ov.visible = false
		game.choose_upgrade({heal = true})
	game.p.xp = 0
	game.reinforce({x = game.p.x + 400, y = game.p.y})
	await get_tree().create_timer(7.0).timeout
	print("AUTOTEST reinforce patrol_units=%d en %d->%d" % [pat, e0, game.en.size()])
	await _shot("swarm")
	game.p.inv = 0.0
	## 1분 분량 시뮬레이션으로 런타임 오류 확인
	game.p.inv = 0.0
	for i in 1800:
		if game.pause == "lvl":
			lvl_ov.visible = false
			game.choose_upgrade({heal = true})
		if game.over:
			break
		game.update(1.0 / 30.0)
	print("AUTOTEST sim en=%d kills=%d heat=%d alert=%d hp=%d lives=%d over=%s" % [game.en.size(), game.kills, game.heat, game.alertN, game.p.hp, game.p.lives, game.over])
	await get_tree().create_timer(0.5).timeout
	await _shot("after")
	## nearest(): 격자 고리 탐색이 전수 탐색과 같은 답을 내는지, 속도 비교
	var brute = func(x, y, r):
		var bb = null
		var bdd = r
		for e in game.en:
			if e.hp > 0:
				var dd = Vector2(e.x - x, e.y - y).length() - e.r
				if dd < bdd:
					bdd = dd
					bb = e
		return bb
	while game.en.size() < 300:
		game.spawn("ru", randf_range(100, 2900), randf_range(100, 2900))
	game.update(1.0 / 30.0)
	var pts = []
	for i in 400:
		var c = game.en[randi() % game.en.size()] if randf() < 0.7 and game.en.size() > 0 else {x = randf() * 3000, y = randf() * 3000}
		pts.append(Vector2(c.x + randf_range(-200, 200), c.y + randf_range(-200, 200)))
	var mism = 0
	for q in pts:
		for r in [230.0, 290.0, 600.0]:
			if not is_same(game.nearest(q.x, q.y, r, false), brute.call(q.x, q.y, r)):
				mism += 1
	var u0 = Time.get_ticks_usec()
	for q in pts:
		game.nearest(q.x, q.y, 290.0, false)
	var u1 = Time.get_ticks_usec()
	for q in pts:
		brute.call(q.x, q.y, 290.0)
	var u2 = Time.get_ticks_usec()
	var blocked = 0
	for q in pts:
		var a1 = game.nearest(q.x, q.y, 290.0, false)
		var a2 = game.nearest(q.x, q.y, 290.0, false, true)
		if a1 != null and not is_same(a1, a2):
			blocked += 1
	print("AUTOTEST nearest en=%d mismatch=%d grid_us=%d brute_us=%d los_skipped=%d/%d" % [game.en.size(), mism, (u1 - u0) / pts.size(), (u2 - u1) / pts.size(), blocked, pts.size()])
	await _search_lab()
	print("AUTOTEST done")
	get_tree().quit()


## ---------- nearest() 탐색 실험: 벽 뒤 적, 밀집, 벽 뒤 밀집 ----------
## 프레임마다 한 번 부르는 상황을 흉내 낸다 (게임 시간 t를 1/30초씩 진행)
func _bench(x: float, y: float, r: float, los_on: bool, n := 200, cache := false) -> Array:
	game.los_n = 0
	for e in game.en:
		e.erase("lvT")
	var u0 = Time.get_ticks_usec()
	for i in n:
		game.t += 1.0 / 30.0
		game.nearest(x, y, r, false, los_on, false, cache)
	var us = float(Time.get_ticks_usec() - u0) / n
	return [us, float(game.los_n) / n]


func _brute_us(x: float, y: float, r: float, n := 200) -> float:
	var u0 = Time.get_ticks_usec()
	for i in n:
		var bd = r
		for e in game.en:
			if e.hp > 0:
				var d = Vector2(e.x - x, e.y - y).length() - e.r
				if d < bd:
					bd = d
	return float(Time.get_ticks_usec() - u0) / n


func _clear_enemies() -> void:
	for e in game.en:
		if is_instance_valid(e.node):
			e.node.queue_free()
	game.en.clear()
	game.rcall = null


func _freeze_all() -> void:
	for e in game.en:
		e.frz = 999.0
		e.st = "alert"
		e.alT = 0.0
		e.aw = 1.0
		e.px = e.x
		e.py = e.y


func _search_lab() -> void:
	if game.pause == "lvl":
		lvl_ov.visible = false
		game.choose_upgrade({heal = true})
	game.p.inv = 0.0
	game.p.hp = game.p.maxhp
	game.p.xp = -99999
	game.comms = null
	## 촬영용: 사격을 멈추고(재장전 상태 유지) 화면 글자를 지운다
	game.p.reload = 9999.0
	hud.banner_t = 0.0
	hud.banner_lb.modulate.a = 0.0
	game.fl.clear()
	## 높이 16 이상, 한 변 60~140인 건물 하나를 고른다
	var wall = null
	for cell in game.map.rg:
		for k in cell:
			var far_aa = true
			for o in game.map.objs:
				if Vector2(o.x - k.x, o.y - k.y).length() < game.AAR + 250:
					far_aa = false
			if far_aa and k.has("hw") and k.h >= 16 and k.hw > 30 and k.hh > 30 and k.hw < 70 and k.x > 500 and k.x < 2500 and k.y > 500 and k.y < 2500:
				wall = k
				break
		if wall != null:
			break
	if wall == null:
		print("AUTOTEST lab no wall")
		return
	var px = wall.x - wall.hw - 45.0
	var py = wall.y
	game.p.x = px
	game.p.y = py
	var r: float = game.p.w.range
	## 1) 벽 뒤 가까운 적 4 + 트인 곳의 먼 적 3
	_clear_enemies()
	for i in 4:
		game.spawn("ru", wall.x + wall.hw + 25 + i * 12, wall.y - 30 + i * 20)
	for i in 3:
		game.spawn("rf", px - 60 + i * 30, py + 200 + i * 15)
	_freeze_all()
	game.dbg_trace = true
	for i in 3:
		game.update(1.0 / 30.0)
	var near_raw = game.nearest(px, py, r, false, false)
	var near_los = game.nearest(px, py, r, false, true)
	game.nearest(px, py, r, false, true, true)
	print("AUTOTEST lab wall: no_los_pick=%s los_pick=%s" % [near_raw.type if near_raw else "-", near_los.type if near_los else "-"])
	await get_tree().create_timer(0.4).timeout
	await _shot("trace_wall")
	## 2) 밀집: 플레이어 앞 160 지점에 반경 90 안 150명
	_clear_enemies()
	game.p.x = px - 400
	game.p.y = py
	var cx = game.p.x - 160
	var cy = game.p.y
	for i in 150:
		var a = randf() * TAU
		var d = sqrt(randf()) * 90
		game.spawn("ru", cx + cos(a) * d, cy + sin(a) * d)
	_freeze_all()
	for i in 3:
		game.update(1.0 / 30.0)
	var g1 = _bench(game.p.x, game.p.y, r, false)
	var g2 = _bench(game.p.x, game.p.y, r, true)
	var bf = _brute_us(game.p.x, game.p.y, r)
	game.nearest(game.p.x, game.p.y, r, false, true, true)
	print("AUTOTEST lab crowd: en=%d grid_us=%.1f grid_los_us=%.1f los_calls=%.1f brute_us=%.1f rings=%d cells=%d" % [game.en.size(), g1[0], g2[0], g2[1], bf, game.trace.rings, game.trace.cells.size()])
	await get_tree().create_timer(0.4).timeout
	await _shot("trace_crowd")
	## 3) 최악: 벽 바로 뒤에 150명 (모두 플레이어보다 가깝지만 시야가 막힘)
	_clear_enemies()
	game.p.x = px
	game.p.y = py
	for i in 150:
		game.spawn("ru", wall.x + wall.hw + 15 + randf() * 70, wall.y - wall.hh + randf() * wall.hh * 2)
	_freeze_all()
	for i in 3:
		game.update(1.0 / 30.0)
	var w1 = _bench(px, py, r, false)
	var w2 = _bench(px, py, r, true)
	var w3 = _bench(px, py, r, true, 200, true)
	var wb = _brute_us(px, py, r)
	game.nearest(px, py, r, false, true, true)
	print("AUTOTEST lab behind_wall: en=%d grid_us=%.1f grid_los_us=%.1f los_calls=%.1f cached_us=%.1f cached_los_calls=%.1f brute_us=%.1f rings=%d cells=%d pick=%s" % [game.en.size(), w1[0], w2[0], w2[1], w3[0], w3[1], wb, game.trace.rings, game.trace.cells.size(), game.trace.pick != null])
	await get_tree().create_timer(0.4).timeout
	await _shot("trace_worst")
	game.dbg_trace = false
