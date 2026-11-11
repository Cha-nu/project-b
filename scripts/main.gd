extends Node
## 진입점. 로비 ↔ 전투 전환, 진급·일시정지·결과 화면을 관리한다.

const UI := preload("res://scripts/ui.gd")
const GameScript := preload("res://scripts/game.gd")
const HudScript := preload("res://scripts/hud.gd")
const LobbyScript := preload("res://scripts/lobby.gd")
const Icon := preload("res://scripts/icon.gd")

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
var test_stage := 0


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
	ov.color = Color(0.027, 0.031, 0.035, 0.78)
	ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.visible = false
	ui.add_child(ov)
	var cc = CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.add_child(cc)
	var p = PanelContainer.new()
	p.custom_minimum_size = Vector2(640, 0)
	var ps = UI.card(Color("#171b1e"), Color("#414b56"), 28, 30)
	ps.shadow_size = 24
	ps.shadow_offset = Vector2(0, 10)
	p.add_theme_stylebox_override("panel", ps)
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
	## 자동 점검은 모든 적·목표가 풀린 10단계 구성으로 돈다
	game.new_game(seed_v, m.diff, test_stage if test_stage > 0 else m.stage)
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
		b.custom_minimum_size = Vector2(0, 136)
		var evo: bool = o.has("evo")
		var sub: bool = o.has("up") and o.up.get("sub", false)
		var ac: Color = UI.GOLD if evo else UI.GREEN if sub else UI.BLUE
		var face: Color = Color("#362e16") if evo else Color("#1f2429")
		for k in ["normal", "hover", "focus"]:
			b.add_theme_stylebox_override(k, UI.bevel(face, Color("#090b0c"), ac.darkened(0.1) if evo else face.lightened(0.2), false, 14, 20))
		b.add_theme_stylebox_override("pressed", UI.bevel(face.lightened(0.08), Color("#090b0c"), ac, true, 14, 20))
		var h = HBoxContainer.new()
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 16; h.offset_right = -18; h.offset_top = 10; h.offset_bottom = -14
		h.add_theme_constant_override("separation", 18)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(h)
		var tag: String = "EVO" if evo else "HP" if o.has("heal") else o.up.t
		## 왼쪽 배지: 종류 색 타일 위에 약어
		var tile = PanelContainer.new()
		tile.add_theme_stylebox_override("panel", UI.box(ac.darkened(0.55), ac, 3, 0, UI.GOLD, 0, 0, UI.GOLD, 18))
		tile.custom_minimum_size = Vector2(92, 92)
		tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		## 글씨 약어 대신 그림 아이콘
		const UP_ICON := {dmg = "up_dmg", rate = "up_rate", pierce = "up_pierce", mag = "up_mag", multi = "up_multi", spd = "up_spd", hp = "up_hp", magnet = "up_magnet", cd = "radio", blast = "stun", gren = "up_gren", drone = "drone", taser = "emp", squad = "squad"}
		const EVO_ICON := {ar = "ar", sg = "sg", lmg = "lmg", rail = "rail", gren = "up_gren", drone = "drone", comms = "radio", taser = "emp", squad = "squad"}
		var ik: String = EVO_ICON.get(o.evo.id, "star") if evo else "heal" if o.has("heal") else UP_ICON.get(o.up.id, "star")
		var tc = CenterContainer.new()
		tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tc.add_child(Icon.new().setup(ik, Color.WHITE, 62))
		tile.add_child(tc)
		h.add_child(tile)
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
				name += "  [%s]" % o.up.get("tag", "새 보조무기")
			elif o.get("mat", false):
				name += "  [진화 재료]"
			desc = o.up.dl[l] if o.up.has("dl") else o.up.d
			lv = "Lv %d → %d" % [l, l + 1]
		v.add_child(UI.label(name, 30, UI.TEXT, true))
		var dl = UI.label(desc, 21, Color("#d7d4cb"))
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(dl)
		if lv != "":
			var lp = PanelContainer.new()
			lp.add_theme_stylebox_override("panel", UI.pill(Color(ac, 0.16), Color(ac, 0.7), 12, 4))
			lp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			lp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lp.add_child(UI.label(lv, 19, ac.lightened(0.3), true))
			h.add_child(lp)
		b.pressed.connect(func():
			lvl_ov.visible = false
			game.choose_upgrade(o))
		lvl_box.add_child(b)
	lvl_ov.visible = true


func _ended(win: bool, rows: Array, total: int, stars: int) -> void:
	if win:
		lobby.complete_current()
	_show_result(win, rows, total, stars)


func _show_result(win: bool, rows: Array, total: int, stars: int) -> void:
	for c in res_box.get_children():
		c.queue_free()
	var tt = _title("임무 성공" if win else "임무 실패")
	if not win:
		tt.add_theme_color_override("font_color", UI.RED)
	res_box.add_child(tt)
	var st = HBoxContainer.new()
	st.alignment = BoxContainer.ALIGNMENT_CENTER
	st.add_theme_constant_override("separation", 10)
	for i in 3:
		var big = 92 if i == 1 else 72
		var si = Icon.new().setup("star", UI.GOLD if i < stars else Color(1, 1, 1, 0.14), big)
		si.size_flags_vertical = Control.SIZE_SHRINK_END
		st.add_child(si)
	res_box.add_child(st)
	var rp = PanelContainer.new()
	rp.add_theme_stylebox_override("panel", UI.box(Color("#121518"), Color("#292f36"), 2, 0, UI.GOLD, 20))
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
	tot.add_theme_constant_override("separation", 8)
	tot.add_child(Icon.new().setup("gem", UI.GOLD, 32))
	tot.add_child(UI.label("%d" % total, 34, UI.GOLD, true))
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
	print("AUTOTEST shot fps=%d draws=%d %s" % [Engine.get_frames_per_second(), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), ProjectSettings.globalize_path("user://autotest_%s.png" % name)])


func _autotest() -> void:
	## 9단계: 모든 적·보조 목표가 풀려 있고 보스 스테이지가 아니다 (보스는 --quick에서 따로 본다)
	test_stage = 9
	## 스테이지별로 풀리는 것 확인
	for st in [1, 2, 3, 4, 5, 6, 8]:
		var mm = preload("res://scripts/worldgen.gd").gen_map(1234, st)
		var D = preload("res://scripts/data.gd")
		print("AUTOTEST unlock s%d objs=%s enemies=%s tk->%s" % [st, mm.objs.map(func(q): return q.type), D.stage_enemies(st).size(), D.unlocked("tk", st)])
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
	## --biome=N 이면 그 바이옴(0 사막, 1 산림, 2 설원)의 작전으로, --quick 이면 전투 화면만 찍고 끝낸다
	var quick = "--quick" in OS.get_cmdline_user_args()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--biome="):
			for i in Save.d.missions.size():
				if int(Save.d.missions[i].biome) == int(a.get_slice("=", 1)):
					lobby.sel = i
					break
	_deploy()
	## 출격 직후: 낙하산 강하
	await get_tree().create_timer(1.1).timeout
	await _shot("drop")
	## 지원요청 점검이 방공망에 막히지 않게 방공포는 부순 것으로 둔다 (요격 연출은 --quick에서 따로 찍는다)
	var aa_o: Dictionary = game.map.objs.filter(func(q): return q.type == "aa")[0]
	aa_o.done = true
	## 교란기 사보타주: 살아 있으면 좌표가 흐트러진다 → 확인한 뒤 부순 것으로 둔다
	var jm_o: Dictionary = game.map.objs.filter(func(q): return q.type == "jam")[0]
	var c_n = game.calls.size()
	game.exec(game.Data.strat("supply"), {x = game.p.x, y = game.p.y, ang = 0.0})
	var jc: Dictionary = game.calls[game.calls.size() - 1] if game.calls.size() > c_n else {x = game.p.x, y = game.p.y}
	print("AUTOTEST jam_scatter in_jam=%s offset=%d" % [game.in_jam(), int(Vector2(jc.x - game.p.x, jc.y - game.p.y).length())])
	jm_o.done = true
	game.calls.clear()
	for st2 in game.strats:
		st2.t = 0.0
	## 근처 경비 초소로 이동시켜 적과 구조물이 화면에 들어오게 한다
	var o: Dictionary = game.map.objs[0]
	game.p.x = o.x + 60
	game.p.y = o.y + 230
	game.p.inv = 999.0
	await get_tree().create_timer(2.5).timeout
	await _shot("battle")
	if quick:
		## 모델 확대: 적 종류별로 한 줄 세우고 카메라를 당겨 찍는다
		_clear_enemies()
		game.p.reload = 9999.0
		game.p.inv = 0.0
		var li = 0
		for ty in ["ru", "rf", "sh", "sp", "tk"]:
			game.spawn(ty, game.p.x - 96 + li * 40 + (40 if ty == "tk" else 0) + (40 if li >= 2 else 0), game.p.y - 26)
			li += 1
		_freeze_all()
		for e in game.en:
			e.st = "post"
			e.aw = 0.0
			e.face = PI / 2
			e.ha = PI / 2 - 0.5
		game.dbg_zoom = 15.5
		await get_tree().create_timer(0.5).timeout
		await _shot("models")
		## 방공망 요격: 전투기 회피 + 공중 격추
		aa_o.done = false
		game.dbg_zoom = -6.0
		var keep_xy = Vector2(game.p.x, game.p.y)
		game.p.x = aa_o.x + 120
		game.p.y = aa_o.y + 200
		var d0 = game.stage
		game.stage = 5
		game.exec(game.strats[0], {x = game.p.x + 40, y = game.p.y - 120, ang = 0.4})
		game.exec(game.Data.strat("supply"), {x = game.p.x - 60, y = game.p.y - 60, ang = 0.0})
		await get_tree().create_timer(0.8).timeout
		## 공격헬기(지원요청)도 방공망이 살아나면 격추된다
		aa_o.done = true
		game.exec(game.Data.strat("apache"), {x = game.p.x, y = game.p.y, ang = 0.0})
		var g_a = game.gs != null
		aa_o.done = false
		for i in 60:
			game.update(1.0 / 30.0)
		var g_b = game.gs != null
		print("AUTOTEST heli_aa clear=%s under_aa=%s" % [g_a, g_b])
		if game.gs != null:
			game.gs.node.queue_free()
			game.gs = null
		print("AUTOTEST intercept global=%s sams=%d jets=%d calls=%d" % [game.aa_global(), game.sams.size(), game.jets.size(), game.calls.size()])
		await _shot("intercept")
		await get_tree().create_timer(1.6).timeout
		game.stage = d0
		aa_o.done = true
		game.p.x = keep_xy.x
		game.p.y = keep_xy.y
		## 지원 항공기 세 종 (F-35형 · A-10형 · 폭격기)
		_clear_enemies()
		if game.pause == "lvl":
			lvl_ov.visible = false
			game.choose_upgrade({heal = true})
		game.p.xp = -99999
		game.jets.clear()
		game.flyby(game.p.x - 60, game.p.y - 150, 0.0, 0.5, false, "f35")
		game.flyby(game.p.x - 60, game.p.y - 20, 0.0, 0.5, false, "a10")
		game.flyby(game.p.x - 20, game.p.y + 140, 0.0, 0.5, true)
		game.dbg_zoom = -2.0
		for i in 15:
			game.update(1.0 / 30.0)
		await get_tree().create_timer(0.1).timeout
		await _shot("jets")
		## 전차 주포 발사 · 자주포
		_clear_enemies()
		var tke = game.spawn("tk", game.p.x - 70, game.p.y + 110)
		var spe = game.spawn("sp", game.p.x + 90, game.p.y + 190)
		var lte = game.spawn("lt", game.p.x + 110, game.p.y + 40)
		var mle = game.spawn("ml", game.p.x - 130, game.p.y - 20)
		lte.ha = 0.8
		mle.ha = -0.4
		var arm_log = []
		for st in [1, 3, 5, 7, 10]:
			var s0 = game.stage
			var h0 = game.heat
			game.stage = st
			game.heat = 1
			var a1 = game.reinf_armor()
			game.heat = 3
			arm_log.append("s%d:%s/%s" % [st, "+".join(a1), "+".join(game.reinf_armor())])
			game.stage = s0
			game.heat = h0
		print("AUTOTEST armor ", arm_log)
		## 경전차 3점사: 2초 동안 쏜 기관포탄 수
		game.p.inv = 0.0
		lte.frz = 0.0
		lte.st = "alert"
		lte.shoot = 0.0
		var ac_n = 0
		var eb0 = game.eb.size()
		for i in 60:
			## 쏠 때마다 반동(rec)이 튀어 오른다
			var rec0: float = lte.rec
			game.update(1.0 / 30.0)
			if lte.rec > rec0:
				ac_n += 1
		print("AUTOTEST lt_burst shots=%d" % ac_n)
		## 자주포: 날아오는 포탄이 보이는지
		spe.frz = 0.0
		spe.st = "alert"
		spe.shoot = 0.0
		var l0 = game.lobs.size()
		for i in 22:
			game.update(1.0 / 30.0)
		print("AUTOTEST spg_shell lobs %d->%d tele=%d" % [l0, game.lobs.size(), game.tele.size()])
		game.dbg_zoom = -8.0
		await get_tree().create_timer(0.1).timeout
		await _shot("spg_shell")
		game.dbg_zoom = 4.0
		spe.frz = 999.0
		lte.frz = 999.0
		game.p.hp = game.p.maxhp
		game.p.inv = 999.0
		## 동료 사망 → 경계, 탄약 칸 터치 → 재장전
		var wa = game.spawn("ru", game.p.x + 300, game.p.y + 300)
		var wb = game.spawn("ru", game.p.x + 340, game.p.y + 320)
		for q in [wa, wb]:
			q.st = "post"
			q.aw = 0.0
		wa.x = game.p.x + 40
		wa.y = game.p.y + 6
		wb.x = wa.x + 30
		wb.y = wa.y + 10
		wa.hp = 0.0
		game.kill_enemy(wa)
		var w_st: String = wb.st
		game.p.reload = 0.0
		game.p.ammo = 3
		var ev_r = InputEventScreenTouch.new()
		ev_r.index = 3
		ev_r.pressed = true
		ev_r.position = get_viewport().get_final_transform() * hud.ammo_rect.get_center()
		Input.parse_input_event(ev_r)
		await get_tree().process_frame
		await get_tree().process_frame
		print("AUTOTEST witness st=%s los=%s d=%d reload=%.2f" % [w_st, game.los(wb.x, wb.y, wa.x, wa.y), game.d2(wa, wb), game.p.reload])
		game.p.reload = 9999.0
		_freeze_all()
		tke.ha = 0.3
		spe.ha = 2.4
		tke.aimA = 0.15
		game.dbg_zoom = 4.0
		await get_tree().create_timer(0.3).timeout
		game._tank_fire(tke)
		await get_tree().create_timer(0.07).timeout
		await _shot("tankfire")
		## 거치 기관총 탑승 · 공격헬기
		_clear_enemies()
		game.exec(game.Data.strat("hmg"), {x = game.p.x + 10, y = game.p.y + 60, ang = 0.0})
		game.exec(game.Data.strat("apache"), {x = game.p.x, y = game.p.y, ang = 0.0})
		await get_tree().create_timer(1.2).timeout
		game.p.x += 10
		game.p.y += 60
		game.p.reload = 0.0
		for i in 5:
			game.spawn("ru", game.p.x + 150 + i * 14, game.p.y + 40 + i * 12)
		_freeze_all()
		game.dbg_zoom = 0.0
		await get_tree().create_timer(1.6).timeout
		for i in 3:
			game.spawn("sh", game.p.x - 150 + i * 30, game.p.y + 150)
		_freeze_all()
		game.exec(game.Data.strat("missiles"), {x = game.p.x, y = game.p.y, ang = 0.0})
		await get_tree().create_timer(1.75).timeout
		await _shot("cruise")
		await get_tree().create_timer(1.5).timeout
		print("AUTOTEST cruise left=%d en=%d" % [game.mis.size(), game.en.size()])
		## 지형물 파괴: 주변 엄폐물에 큰 폭발
		var props0 = game.map.props.filter(func(q): return q.get("dead", false) or q.kind == "rubble").size()
		for q in game.map.props:
			if game.d2(q, game.p) < 420:
				game.explode(q.x, q.y, 80, 900, {noFF = true, fixed = true})
		var props1 = game.map.props.filter(func(q): return q.get("dead", false) or q.kind == "rubble").size()
		print("AUTOTEST wreck %d->%d" % [props0, props1])
		game.dbg_zoom = -5.0
		await get_tree().create_timer(0.9).timeout
		await _shot("wreck")
		game.dbg_zoom = 0.0
		## 새 원격 지원 5종
		_clear_enemies()
		for i in 4:
			game.spawn("rf", game.p.x + 200 + i * 16, game.p.y - 60 + i * 14)
		game.spawn("tk", game.p.x - 220, game.p.y - 120)
		for e in game.en:
			e.st = "alert"
		var e_n = game.en.size()
		for id in ["sniper", "sat", "emp", "smoke", "naval"]:
			game.exec(game.Data.strat(id), {x = game.p.x + 150, y = game.p.y + 160, ang = 0.0})
		for i in 150:
			game.update(1.0 / 30.0)
		var smoke_n = game.zones.filter(func(z): return z.k == "smoke").size()
		var frozen = game.en.filter(func(e): return e.T.has("armor") and e.frz > 0).size()
		print("AUTOTEST five en %d->%d snipe=%s emp=%.0f sat=%.0f smoke=%d tank_frozen=%d" % [e_n, game.en.size(), game.snipe != null, game.empT, game.satT, smoke_n, frozen])
		game.dbg_zoom = -4.0
		await get_tree().create_timer(0.3).timeout
		await _shot("five")
		game.dbg_zoom = 0.0
		print("AUTOTEST hmg mounted=%s heli=%s en=%d turrets=%d pause=%s" % [game.p.mount != null, game.gs != null, game.en.size(), game.turrets.size(), game.pause])
		await _shot("hmg")
		game.p.reload = 9999.0
		## 탈출: 착륙장에 적이 있으면 미니건이 쓸고, 비면 착륙 → 탑승 → 이탈 (결과 창 직전까지만)
		_clear_enemies()
		game.ext.state = "wait"
		game.ext.t = 0.05
		game.p.x = game.ext.x + 150
		game.p.y = game.ext.y + 120
		game.p.inv = 99.0
		for i in 8:
			game.spawn("ru", game.ext.x - 60 + i * 16, game.ext.y - 40 + (i % 3) * 30)
		_freeze_all()
		var log = []
		var e_lz = game.en.size()
		for i in 400:
			game.update(1.0 / 30.0)
			if i == 45:
				game.dbg_zoom = -8.0
				await get_tree().create_timer(0.15).timeout
				await _shot("exfil_gun")
			if game.ext.landed and game.ext.state == "land" and not log.has("landed"):
				log.append("landed@%d en=%d" % [i, game.en.size()])
				log.append("landed")
				game.p.x = game.ext.x
				game.p.y = game.ext.y
			if game.ext.state == "leave":
				log.append("leave@%d" % i)
				break
		for i in 30:
			game.update(1.0 / 30.0)
		await get_tree().create_timer(0.15).timeout
		await _shot("exfil_leave")
		print("AUTOTEST exfil lz_en=%d %s out=%.2f" % [e_lz, log, game.ext.out])
		game.ext.state = "locked"
		if game.heli_node:
			game.heli_node.queue_free()
			game.heli_node = null
		game.p.inv = 999.0
		game.p.reload = 9999.0
		game.dbg_zoom = 0.0
		## 길리 저격수: 숨어 있을 때는 자동 조준이 못 잡고, 쏘면 드러난다
		_clear_enemies()
		game.p.inv = 0.0
		game.p.hp = game.p.maxhp
		game.zones.clear()
		## 앞 테스트에서 남은 공격헬기·포탑이 저격수를 먼저 잡지 않게 치운다
		game.p.evo.erase("drone")
		game.p.up.erase("drone")
		if game.gs != null:
			game.gs.node.queue_free()
			game.gs = null
		for tu in game.turrets:
			tu.node.queue_free()
		game.turrets.clear()
		game.comms = null
		game.snipe = null
		var sn = game.spawn("sn", game.p.x + 30, game.p.y + 170)
		sn.st = "post"
		sn.shoot = 0.2
		game.update(1.0 / 30.0)
		var hid0 = game.nearest(game.p.x, game.p.y, 400.0, false) == null
		var hp0 = game.p.hp
		var seen = false
		for i in 75:
			game.update(1.0 / 30.0)
			if game.nearest(game.p.x, game.p.y, 400.0, false) != null:
				seen = true
			if i == 30:
				game.dbg_zoom = 2.0
				await get_tree().create_timer(0.1).timeout
				await _shot("sniper")
		print("AUTOTEST ghillie hidden_at_start=%s targetable_later=%s hp %d->%d rev=%.1f" % [hid0, seen, hp0, game.p.hp, sn.rev])
		game.p.inv = 99.0
		game.p.hp = game.p.maxhp
		game.dbg_zoom = 0.0
		## 보스 세 종: 각 보스 스테이지를 실제로 열어 깨우고, 싸우는 장면을 찍고, 격파하면 탈출이 열리는지 본다
		for bs in [5, 8, 10]:
			game.new_game(seed_v, 2, bs)
			hud.build()
			var bo = game.boss
			var has_term = game.map.objs.any(func(q): return q.type == "term")
			game.p.x = bo.x + 40
			game.p.y = bo.y + 250
			game.p.inv = 99.0
			game.p.reload = 9999.0
			for q in game.en:
				if not is_same(q, bo) and is_instance_valid(q.node):
					q.node.queue_free()
			game.en = [bo]
			game.rcall = null
			bo.hp = bo.maxhp * 0.9
			for i in 150:
				game.update(1.0 / 30.0)
			game.dbg_zoom = -14.0
			await get_tree().create_timer(0.25).timeout
			await _shot("boss_%d" % bs)
			var aa1 = game._aa_src() != null
			bo.hp = bo.maxhp * 0.2
			for i in 20:
				game.update(1.0 / 30.0)
			var ph = bo.bph
			game.hit_enemy(bo, 999999.0, true)
			for i in 40:
				game.update(1.0 / 30.0)
			print("AUTOTEST boss s%d %s term=%s awake=%s aa_src=%s phase=%d ext=%s" % [bs, bo.T.n, has_term, bo.awake, aa1, ph, game.ext.state])
			game.dbg_zoom = 0.0
		game.new_game(seed_v, 2, 9)
		hud.build()
		aa_o = game.map.objs.filter(func(q): return q.type == "aa")[0]
		aa_o.done = true
		o = game.map.objs[0]
		game.p.x = o.x + 60
		game.p.y = o.y + 230
		## 새 보조 임무 구조물
		for ty in ["aa", "jam", "fac"]:
			for q in game.map.objs:
				if q.type == ty:
					_clear_enemies()
					game.p.x = q.x - 30
					game.p.y = q.y + 110
					game.dbg_zoom = 7.0
					await get_tree().create_timer(0.6).timeout
					await _shot(ty)
		game.dbg_zoom = 0.0
		_clear_enemies()
		game.p.x = o.x + 60
		game.p.y = o.y + 230
		game.p.reload = 0.0
		game.p.inv = 999.0
	for s in game.strats:
		s.t = 0.0
		game.exec(s, game.auto_target(s))
	await get_tree().create_timer(0.62).timeout
	print("AUTOTEST flyby jets=%d warns=%d" % [game.jets.size(), game.calls.filter(func(c): return c.get("w", false)).size()])
	await _shot("flyby")
	await get_tree().create_timer(1.0).timeout
	await _shot("strike")
	if quick:
		print("AUTOTEST done (quick)")
		get_tree().quit()
		return
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
		## 주변 적이 먼저 무전기를 잡을 수 있다. 실제로 요청 중인 병사를 대상으로 삼는다
		if game.rcall != null:
			caller = game.rcall
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
	## 부대원·드론 편대: 포위되면 탈출로를 잡는지, 드론 종류가 다 뜨는지, 공병이 부호를 대신 넣는지
	var uid0: int = game.uid_n
	var kills0: int = game.kills
	game.p.up["squad"] = 4
	game.p.up["drone"] = 5
	game.recalc()
	game.kamiT = 0.3
	## 찍는 동안 진급 창이 화면을 가리지 않게 잠깐 막아 둔다
	var next0 = game.p.next
	game.p.next = 999999
	for i in 14:
		var ra = i / 14.0 * TAU
		if i % 7 != 0:
			game.spawn("ru" if i % 2 == 0 else "rf", game.p.x + cos(ra) * 190, game.p.y + sin(ra) * 190)
	for e in game.en:
		if e.uid >= uid0:
			e.st = "alert"
			e.frz = 1.2
	## 아군 기갑 지원요청 (경전차·전차)도 같이 불러 본다
	game.exec(game.Data.strat("tank"), {x = game.p.x + 70, y = game.p.y + 50, ang = 0.0})
	game.exec(game.Data.strat("ltank"), {x = game.p.x - 70, y = game.p.y + 50, ang = 0.0})
	var broke = false
	var kam = 0
	for i in 75:
		game.update(1.0 / 30.0)
		broke = broke or game.breakout != null
		kam = maxi(kam, game.kamis.size())
	if game.pause == "lvl":
		game.pause = ""
		lvl_ov.visible = false
	await get_tree().create_timer(0.25).timeout
	await _shot("squad")
	game.p.next = next0
	print("AUTOTEST squad n=%d roles=%s breakout=%s drones=%s kami=%d armor=%s kills=%d" % [game.squad.size(), game.squad.map(func(q): return q.role), broke, game.drones.map(func(q): return q.k), kam, game.avs.map(func(q): return q.k), game.kills - kills0])
	for av in game.avs:
		av.node.queue_free()
	game.avs.clear()
	## 부대원·드론은 맞으면 쓰러지고 대기 시간 뒤 복귀한다
	var dm: Dictionary = game.squad[0]
	var ddr: Dictionary = game.drones[0]
	game.ally_hurt(dm, 9999.0)
	game.ally_hurt(ddr, 9999.0)
	var down_s = "%.0f/%.0f" % [dm.down, ddr.down]
	dm.down = 0.5
	ddr.down = 0.5
	for i in 30:
		game.update(1.0 / 30.0)
	print("AUTOTEST ally_down cd=%s back=%s hp=%d/%d" % [down_s, dm.down <= 0 and ddr.down <= 0, dm.hp, ddr.hp])
	## 공병 점검 동안에는 부대원이 쓰러지지 않게 해 둔다
	for sq in game.squad:
		sq.down = 0.0
		sq.hp = 99999.0
	var eng_o = null
	for to in game.map.objs:
		if to.type == "term" and not to.done:
			eng_o = to
			break
	if eng_o != null:
		var keep = Vector2(game.p.x, game.p.y)
		game.p.x = eng_o.x
		game.p.y = eng_o.y + 30
		for i in 30 * 9:
			game.update(1.0 / 30.0)
			if eng_o.hackN > 0:
				break
		print("AUTOTEST engineer hackN=%d" % eng_o.hackN)
		eng_o.hackN = 0
		eng_o.hackT = 0.0
		eng_o.scoutT = 0.0
		game.sirenT = 0.0
		game.p.x = keep.x
		game.p.y = keep.y
	for e in game.en:
		if e.uid >= uid0 and is_instance_valid(e.node):
			e.node.queue_free()
	game.en = game.en.filter(func(q): return q.uid < uid0)
	game.p.up.erase("squad")
	game.p.up.erase("drone")
	game.recalc()
	if game.pause == "lvl":
		game.pause = ""
		lvl_ov.visible = false
	game.p.inv = 0.0
	## 단말기 3단계 해킹: 두 번째 입력에서 증원
	for to in game.map.objs:
		if to.type == "term":
			var h0 = game.heat
			game.p.x = to.x
			game.p.y = to.y + 30
			game.rcall = null
			var steps = []
			for k in 3:
				game.update(1.0 / 30.0)
				var cc = game.ctx_code()
				steps.append(cc.name if cc != null else "-")
				var en0 = game.en.size()
				if cc != null:
					game.fire_code(cc)
				if k == 0:
					var sc = game.en.slice(en0)
					print("AUTOTEST scout n=%d sus=%d min_dist=%d" % [sc.size(), sc.filter(func(q): return q.st == "sus").size(), sc.map(func(q): return int(game.d2(q, game.p))).min() if sc.size() else 0])
				for i in 170:
					if game.pause == "lvl":
						lvl_ov.visible = false
						game.choose_upgrade({heal = true})
					game.update(1.0 / 30.0)
			print("AUTOTEST term steps=%s done=%s heat %d->%d" % [steps, to.done, h0, game.heat])
			break
	## 통신탑 점령 → 무조건 증원
	for co in game.map.objs:
		if co.type == "cap":
			var n0 = game.en.size()
			game.p.x = co.x
			game.p.y = co.y
			## 통신탑은 해킹해야 점령이 시작된다
			game.update(1.0 / 30.0)
			var need_hack = game.ctx_code() != null and game.ctx_code().name == "통신탑 해킹"
			game.fire_code(game.ctx_code())
			print("AUTOTEST hack need=%s hacked=%s" % [need_hack, co.hacked])
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
	print("AUTOTEST stage=%d lv=%.2f unlocked=%d missions=%d" % [game.stage, game.lv(), Save.d.stage, Save.d.missions.size()])
	print("AUTOTEST sim en=%d kills=%d heat=%d alert=%d hp=%d lives=%d over=%s" % [game.en.size(), game.kills, game.heat, game.alertN, game.p.hp, game.p.lives, game.over])
	await get_tree().create_timer(0.5).timeout
	await _shot("after")
	## 진급 창 · 결과 화면 모양 확인
	game.level_up()
	await get_tree().create_timer(0.3).timeout
	await _shot("levelup")
	## 보급 아이콘 전부를 세 장에 나눠 찍는다
	var all_opts: Array = []
	for u in preload("res://scripts/data.gd").UPS:
		all_opts.append({up = u})
	for ev3 in preload("res://scripts/data.gd").EVOS:
		all_opts.append({evo = ev3})
	for pg in 4:
		_level_up(all_opts.slice(pg * 6, pg * 6 + 6))
		await get_tree().create_timer(0.2).timeout
		await _shot("upicons%d" % pg)
	if game.pause == "lvl":
		lvl_ov.visible = false
		game.choose_upgrade({heal = true})
	_show_result(true, [["처치 84", 84], ["은밀 처치 12", 60], ["보조 임무 2", 200]], 344, 2)
	await get_tree().create_timer(0.3).timeout
	await _shot("result")
	res_ov.visible = false
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
