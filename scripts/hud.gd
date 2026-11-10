extends Control
## 전투 HUD. 게임 상태를 매 프레임 읽어 표시하고, 전건·취소 입력을 게임에 넘긴다.

const UI := preload("res://scripts/ui.gd")
const Glyph := preload("res://scripts/glyph.gd")
const Data := preload("res://scripts/data.gd")

signal pause_pressed

var game: Node3D
var hp_fill: ColorRect
var hp_txt: Label
var xp_fill: ColorRect
var lvl_lb: Label
var lives_lb: Label
var chips: HFlowContainer
var banner_lb: Label
var banner_t := 0.0
var aim_hint: Label
var cards: VBoxContainer
var card_nodes: Array = []
var ctx_card: PanelContainer
var ctx_name: Label
var ctx_glyph
var key: Control
var buf_glyph
var cancel_btn: Button
var ammo_lb: Label
var overlay: Control
var pause_btn: Button
var key_touch := -1
var err_t := 0.0
var _chip_key := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)
	## 상단: 계급 · 체력 · 경험치 · 증원 · 일시정지
	var top = VBoxContainer.new()
	top.position = Vector2(14, 14)
	top.size = Vector2(692, 120)
	top.add_theme_constant_override("separation", 8)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row)
	var lv = PanelContainer.new()
	lv.add_theme_stylebox_override("panel", UI.box(Color(0.04, 0.045, 0.05, 0.85), UI.GOLD, 2, 0, UI.GOLD, 4))
	lv.custom_minimum_size = Vector2(62, 62)
	lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lvl_lb = UI.label("1", 30, UI.GOLD, true)
	lvl_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvl_lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lv.add_child(lvl_lb)
	row.add_child(lv)
	var bars = VBoxContainer.new()
	bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bars.add_theme_constant_override("separation", 5)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bars)
	var hpbg = _bar_bg(30)
	bars.add_child(hpbg)
	hp_fill = ColorRect.new()
	hp_fill.color = Color("#7fb84a")
	hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hpbg.add_child(hp_fill)
	hp_txt = UI.label("120 / 120", 20, UI.TEXT, true, 6)
	hp_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_txt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hpbg.add_child(hp_txt)
	var xpbg = _bar_bg(10)
	bars.add_child(xpbg)
	xp_fill = ColorRect.new()
	xp_fill.color = UI.GOLD
	xp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xpbg.add_child(xp_fill)
	lives_lb = UI.label("증원 2", 22, UI.TEXT, true)
	var lp = _chip_panel(lives_lb, Color(0.04, 0.045, 0.05, 0.85))
	row.add_child(lp)
	pause_btn = UI.dark_button("II", 26)
	pause_btn.custom_minimum_size = Vector2(60, 60)
	pause_btn.pressed.connect(func(): pause_pressed.emit())
	row.add_child(pause_btn)
	chips = HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(chips)
	## 배너·조준 안내
	banner_lb = UI.label("", 32, UI.GOLD, true, 10)
	banner_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_lb.position = Vector2(20, 330)
	banner_lb.size = Vector2(680, 120)
	add_child(banner_lb)
	aim_hint = UI.label("", 28, UI.TEXT, true, 8)
	aim_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aim_hint.position = Vector2(20, 200)
	aim_hint.size = Vector2(680, 100)
	add_child(aim_hint)
	## 왼쪽 아래: 지원요청 카드 + 전건 + 입력 표시/취소
	var left = VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.anchor_top = 1.0
	left.anchor_bottom = 1.0
	left.offset_left = 14
	left.offset_right = 330
	left.offset_top = -620
	left.offset_bottom = -20
	left.alignment = BoxContainer.ALIGNMENT_END
	add_child(left)
	ctx_card = PanelContainer.new()
	ctx_card.add_theme_stylebox_override("panel", UI.box(Color("#3a2410"), Color("#ff9d2a"), 1, 4, Color("#ff9d2a"), 8))
	ctx_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cv = VBoxContainer.new()
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctx_name = UI.label("", 20, UI.TEXT, true)
	ctx_glyph = Glyph.new().setup("", 0, 10)
	cv.add_child(ctx_name)
	cv.add_child(ctx_glyph)
	ctx_card.add_child(cv)
	ctx_card.visible = false
	left.add_child(ctx_card)
	cards = VBoxContainer.new()
	cards.add_theme_constant_override("separation", 6)
	cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(cards)
	var kw = HBoxContainer.new()
	kw.add_theme_constant_override("separation", 12)
	kw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(kw)
	key = Control.new()
	key.custom_minimum_size = Vector2(176, 176)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.draw.connect(_draw_key)
	kw.add_child(key)
	var kc = VBoxContainer.new()
	kc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	kw.add_child(kc)
	buf_glyph = Glyph.new().setup("", 0, 16)
	kc.add_child(buf_glyph)
	var sp = Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kc.add_child(sp)
	cancel_btn = UI.dark_button("✕ 취소", 24, Color("#6a3a30"))
	cancel_btn.add_theme_color_override("font_color", Color("#ff8a7a"))
	cancel_btn.button_down.connect(func(): game.cancel_morse())
	kc.add_child(cancel_btn)
	## 오른쪽 아래: 탄약
	ammo_lb = UI.label("30 / 30", 34, UI.TEXT, true, 8)
	ammo_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_lb.anchor_left = 1.0
	ammo_lb.anchor_right = 1.0
	ammo_lb.anchor_top = 1.0
	ammo_lb.anchor_bottom = 1.0
	ammo_lb.offset_left = -300
	ammo_lb.offset_right = -20
	ammo_lb.offset_top = -80
	ammo_lb.offset_bottom = -24
	add_child(ammo_lb)


func _bar_bg(h: float) -> Control:
	var c = ColorRect.new()
	c.color = Color(0.03, 0.035, 0.04, 0.85)
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _chip_panel(l: Label, bg: Color, border := Color("#2c3136")) -> PanelContainer:
	var pc = PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.box(bg, border, 1, 0, UI.GOLD, 6))
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(l)
	return pc


## 전투 시작 시 지원요청 카드 구성
func build() -> void:
	for c in cards.get_children():
		c.queue_free()
	card_nodes.clear()
	for s in game.strats:
		var pc = PanelContainer.new()
		pc.add_theme_stylebox_override("panel", UI.rar_box(s.rar, 7))
		pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var v = VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var nm = UI.label(s.name, 20, UI.TEXT, true)
		var g = Glyph.new().setup(s.code, 0, 10)
		v.add_child(nm)
		v.add_child(g)
		## 통신 드론 재사용 대기 막대 (진화 후 표시)
		var dr = HBoxContainer.new()
		dr.add_theme_constant_override("separation", 6)
		dr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dr.visible = false
		dr.add_child(UI.label("드론", 15, Color("#62d0f0"), true, 4))
		var dbg = ColorRect.new()
		dbg.color = Color(0.02, 0.05, 0.08, 0.9)
		dbg.custom_minimum_size = Vector2(0, 8)
		dbg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dbg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var dfill = ColorRect.new()
		dfill.color = Color("#62d0f0")
		dfill.anchor_bottom = 1.0
		dfill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dbg.add_child(dfill)
		dr.add_child(dbg)
		pc.add_child(v)
		var cd = UI.label("", 30, UI.MUTE, true)
		cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var cdbg = ColorRect.new()
		cdbg.color = Color(0.02, 0.025, 0.03, 0.76)
		cdbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cdbg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cdbg.add_child(cd)
		cd.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		pc.add_child(cdbg)
		var col = VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(pc)
		col.add_child(dr)
		cards.add_child(col)
		card_nodes.append({panel = pc, glyph = g, cd = cd, cdbg = cdbg, s = s, dr = dr, dfill = dfill})
	_chip_key = ""


func banner(t: String) -> void:
	banner_lb.text = t
	banner_lb.modulate.a = 1.0
	banner_t = 2.6


func morse_error() -> void:
	err_t = 0.3


## 화면 좌표가 HUD의 조작 부위 위인지 (게임 쪽 조이스틱이 무시하도록)
func blocks(pos: Vector2) -> bool:
	var rects = [key.get_global_rect(), cancel_btn.get_global_rect(), pause_btn.get_global_rect()]
	for r in rects:
		if r.grow(10).has_point(pos):
			return true
	return false


## 전건: 터치(마우스는 터치로 에뮬레이트됨)를 직접 처리해 멀티터치에서도 이동과 동시에 누를 수 있게 한다
func _input(ev: InputEvent) -> void:
	if not visible or game == null or not game.active:
		return
	if ev is InputEventScreenTouch:
		var r = key.get_global_rect()
		var c = r.get_center()
		if ev.pressed and key_touch == -1 and ev.position.distance_to(c) < r.size.x * 0.55:
			key_touch = ev.index
			game.press_key()
			get_viewport().set_input_as_handled()
		elif not ev.pressed and ev.index == key_touch:
			key_touch = -1
			game.release_key(false)
			get_viewport().set_input_as_handled()


func _process(dt: float) -> void:
	if game == null or not game.active:
		return
	var p: Dictionary = game.p
	var hp = maxi(0, ceili(p.hp))
	hp_fill.size = Vector2(hp_fill.get_parent().size.x * clampf(p.hp / p.maxhp, 0, 1), hp_fill.get_parent().size.y)
	hp_txt.text = "%d / %d" % [hp, p.maxhp]
	xp_fill.size = Vector2(xp_fill.get_parent().size.x * clampf(float(p.xp) / p.next, 0, 1), xp_fill.get_parent().size.y)
	lvl_lb.text = str(p.lvl)
	lives_lb.text = "증원 %d" % p.lives
	## 상태 칩
	var mm = "%d:%02d" % [int(game.t / 60), int(game.t) % 60]
	var st = "교전" if game.alertN > 0 else "수색" if game.susN > 0 else "은신"
	var key_s = st + "|" + str(game.in_aa()) + "|" + mm + "|" + str(game.gold_now()) + "|" + game.ext.state + "|" + str(int(game.ext.t))
	for o in game.map.objs:
		key_s += "|" + str(o.done) + str(o.known)
	if key_s != _chip_key:
		_chip_key = key_s
		for c in chips.get_children():
			c.queue_free()
		var stc = {"교전": [Color("#8c1e14"), Color.WHITE], "수색": [Color("#785a0a"), Color("#ffe27a")], "은신": [Color(0.04, 0.045, 0.05, 0.85), Color("#a6dc68")]}
		_add_chip(st, stc[st][0], stc[st][1])
		if game.in_aa():
			_add_chip("방공 교란", Color("#8c1e14"), Color.WHITE)
		var nm = {cap = "통신탑", nest = "부대", term = "단말기", aa = "방공포"}
		for o in game.map.objs:
			var tx: String = ("★" if o.type == "term" else "") + (nm[o.type] if o.known or o.done else "미확인")
			_add_chip(tx, Color("#466e28") if o.done else Color(0.04, 0.045, 0.05, 0.85), Color.WHITE if o.done else UI.MUTE)
		var es: String = game.ext.state
		var et = "탈출" + (" %d" % ceili(game.ext.t) if es == "wait" else "")
		_add_chip(et, UI.GOLD if es == "call" else Color("#466e28") if es != "locked" else Color(0.04, 0.045, 0.05, 0.85), Color("#111111") if es == "call" else Color.WHITE if es != "locked" else UI.MUTE)
		_add_chip(mm, Color(0.04, 0.045, 0.05, 0.85), Color.WHITE)
		_add_chip("◆ %d" % game.gold_now(), Color(0.04, 0.045, 0.05, 0.85), UI.GOLD)
	## 지원요청 카드
	var b: String = game.M.buf
	var jam: bool = game.in_aa()
	for cn in card_nodes:
		var s: Dictionary = cn.s
		cn.glyph.set_code(s.code, b.length() if s.code.begins_with(b) else 0)
		if game.comms != null:
			cn.dr.visible = true
			var dc: float = game.comms.cd.get(s.id, 0.0)
			cn.dfill.anchor_right = 1.0 - clampf(dc / maxf(0.1, game.comms_max(s)), 0, 1)
			cn.dfill.color = Color("#62d0f0") if dc <= 0 else Color("#2c6d86")
		var v = ceili(s.t) if s.t > 0 else 0
		cn.cdbg.visible = v > 0 or jam
		cn.cd.text = str(v) if v > 0 else "교란"
		cn.panel.modulate = Color(1, 1, 1, 0.95)
	var cc = game.ctx_code()
	ctx_card.visible = cc != null
	if cc != null:
		ctx_name.text = cc.name
		ctx_glyph.set_code(cc.code, b.length() if cc.code.begins_with(b) else 0)
	err_t -= dt
	if err_t > 0:
		buf_glyph.col_on = UI.RED
		buf_glyph.set_code("--", 2)
	else:
		buf_glyph.col_on = UI.GOLD
		buf_glyph.set_code(b, b.length())
	var off: bool = b == "" and game.M.queue == null and game.M.pend == null and game.aim == null
	cancel_btn.modulate.a = 0.4 if off else 1.0
	ammo_lb.text = "탄약 ∞" if p.evo.has("lmg") else "재장전" if p.reload > 0 else "%d / %d" % [p.ammo, game.mag_size()]
	if game.aim != null:
		var s: Dictionary = game.aim.s
		aim_hint.text = s.name + "\n" + ("터치한 곳에서 원하는 방향으로 슬라이드" if s.aim == "line" else "투하할 곳을 터치하고 떼세요")
	else:
		aim_hint.text = ""
	if banner_t > 0:
		banner_t -= dt
		banner_lb.modulate.a = clampf(banner_t / 0.4, 0, 1)
	key.queue_redraw()
	overlay.queue_redraw()


func _add_chip(t: String, bg: Color, fg: Color) -> void:
	chips.add_child(_chip_panel(UI.label(t, 19, fg, true), bg, bg.lightened(0.15)))


func _draw_key() -> void:
	var c = key.size / 2
	var r = key.size.x / 2 - 8
	var down: bool = game != null and game.M.down
	var pr: float = game.key_progress() if game else 0.0
	var aim_mode: bool = game != null and game.aim != null
	key.draw_circle(c + Vector2(0, 6), r + 6, Color(0, 0, 0, 0.5))
	key.draw_circle(c, r + 6, Color("#5a5f55") if not aim_mode else UI.RED)
	key.draw_circle(c, r + 3, Color("#0b0c0d"))
	var body = Color("#2a2e33")
	if aim_mode:
		body = Color("#3a3e44")
	elif down and pr >= 1.0:
		body = Color("#d9a515")
	elif down:
		body = Color("#5a2a20")
	key.draw_circle(c + Vector2(0, 3 if down else 0), r, body)
	key.draw_circle(c + Vector2(-r * 0.2, -r * 0.3), r * 0.45, Color(1, 1, 1, 0.05))
	if down:
		key.draw_arc(c, r + 12, -PI / 2, -PI / 2 + TAU * pr, 48, UI.GOLD, 7)
	var f = UI.font(true)
	var sym = "—" if down and pr >= 1.0 else "·"
	var lb = "취소" if aim_mode else "전건"
	var col = Color("#111111") if down and pr >= 1.0 else UI.TEXT
	key.draw_string(f, Vector2(0, c.y - 2), sym, HORIZONTAL_ALIGNMENT_CENTER, key.size.x, 54, col)
	key.draw_string(f, Vector2(0, c.y + 40), lb, HORIZONTAL_ALIGNMENT_CENTER, key.size.x, 26, col)


## 화면 밖 목표 화살표 · 미니맵 · 조이스틱 · 연속 처치
func _draw_overlay() -> void:
	if game == null or not game.active:
		return
	var p: Dictionary = game.p
	var cam: Camera3D = game.cam
	var vs = overlay.size
	if vs.x < 200 or vs.y < 600:
		return
	var f = UI.font(true)
	var tg: Array = []
	for o in game.map.objs:
		if not o.done and o.known:
			var c = Color("#4fa3d9") if o.type == "cap" else UI.RED if game.is_dest(o) else UI.GOLD
			var t: String = "탑" if o.type == "cap" else "부" if o.type == "nest" else "방" if o.type == "aa" else "★"
			tg.append([o.x, o.y, c, t])
	if game.ext.state != "locked":
		tg.append([game.ext.x, game.ext.y, UI.GOLD, "H"])
	if game.rcall != null:
		tg.append([game.rcall.x, game.rcall.y, Color("#ff3a2a") if int(game.t * 6) % 2 == 0 else Color("#ffb0a0"), "!"])
	for q in tg:
		var w3: Vector3 = game.p3(q[0], q[1], 0.5)
		var sp = cam.unproject_position(w3)
		var behind = cam.is_position_behind(w3)
		if not behind and Rect2(Vector2(30, 160), vs - Vector2(60, 420)).has_point(sp):
			continue
		var ctr = vs / 2
		var dir = (sp - ctr) if not behind else (ctr - sp)
		if dir.length() < 1:
			continue
		var a = dir.angle()
		var hw = vs.x / 2 - 44
		var hh = vs.y / 2 - 200
		var k = minf(hw / maxf(absf(cos(a)), 1e-4), hh / maxf(absf(sin(a)), 1e-4))
		var ap = ctr + Vector2(cos(a), sin(a)) * k + Vector2(0, 20)
		var tip = ap + Vector2(cos(a), sin(a)) * 36
		var s1 = ap + Vector2(cos(a + 2.4), sin(a + 2.4)) * 4 + Vector2(cos(a), sin(a)) * 18
		overlay.draw_colored_polygon(PackedVector2Array([tip, ap + Vector2(cos(a + PI / 2), sin(a + PI / 2)) * 12 + Vector2(cos(a), sin(a)) * 18, ap + Vector2(cos(a - PI / 2), sin(a - PI / 2)) * 12 + Vector2(cos(a), sin(a)) * 18]), q[2])
		var dia = PackedVector2Array([ap + Vector2(0, -20), ap + Vector2(20, 0), ap + Vector2(0, 20), ap + Vector2(-20, 0)])
		overlay.draw_colored_polygon(dia, Color(0.03, 0.035, 0.04, 0.88))
		overlay.draw_polyline(dia + PackedVector2Array([dia[0]]), q[2], 3)
		overlay.draw_string(f, ap + Vector2(-20, 8), q[3], HORIZONTAL_ALIGNMENT_CENTER, 40, 20, q[2])
		var dm = roundi(Vector2(q[0] - p.x, q[1] - p.y).length() / 10)
		overlay.draw_string_outline(f, ap + Vector2(-40, 46), "%dm" % dm, HORIZONTAL_ALIGNMENT_CENTER, 80, 18, 6, Color(0, 0, 0, 0.9))
		overlay.draw_string(f, ap + Vector2(-40, 46), "%dm" % dm, HORIZONTAL_ALIGNMENT_CENTER, 80, 18, UI.TEXT)
	## 미니맵
	var ms = 128.0
	var mp = Vector2(vs.x - ms - 18, 168)
	var W: float = game.WORLD
	overlay.draw_rect(Rect2(mp - Vector2(5, 5), Vector2(ms + 10, ms + 10)), Color(0.03, 0.035, 0.04, 0.88))
	overlay.draw_rect(Rect2(mp, Vector2(ms, ms)), Color(game.map.biome.g[1]).darkened(0.25))
	for rd in game.map.roads:
		if rd.v:
			overlay.draw_rect(Rect2(mp + Vector2(rd.p / W * ms - 1.5, 0), Vector2(3, ms)), Color(game.map.biome.road))
		else:
			overlay.draw_rect(Rect2(mp + Vector2(0, rd.p / W * ms - 1.5), Vector2(ms, 3)), Color(game.map.biome.road))
	overlay.draw_rect(Rect2(mp, Vector2(ms, ms)), Color(0.95, 0.76, 0.1, 0.5), false, 1.5)
	if game.intel:
		for e in game.en:
			overlay.draw_rect(Rect2(mp + Vector2(e.x, e.y) / W * ms - Vector2(1.5, 1.5), Vector2(3, 3)), Color(1, 0.27, 0.2, 0.85))
	if game.rcall != null and int(game.t * 4) % 2 == 0:
		overlay.draw_rect(Rect2(mp + Vector2(game.rcall.x, game.rcall.y) / W * ms - Vector2(5, 5), Vector2(10, 10)), Color("#ff3a2a"))
	for q in tg:
		overlay.draw_rect(Rect2(mp + Vector2(q[0], q[1]) / W * ms - Vector2(5, 5), Vector2(10, 10)), q[2])
	overlay.draw_circle(mp + Vector2(p.x, p.y) / W * ms, 5, Color.WHITE)
	## 연속 처치
	if game.combo >= 5:
		var col = UI.RED if game.combo >= 100 else Color("#ff9d1a") if game.combo >= 50 else UI.GOLD
		var cp = Vector2(vs.x - 150, mp.y + ms + 50)
		overlay.draw_string_outline(f, cp, "x%d" % game.combo, HORIZONTAL_ALIGNMENT_CENTER, 140, 44, 10, Color(0, 0, 0, 0.9))
		overlay.draw_string(f, cp, "x%d" % game.combo, HORIZONTAL_ALIGNMENT_CENTER, 140, 44, col)
		overlay.draw_string(f, cp + Vector2(0, 28), "연속 처치", HORIZONTAL_ALIGNMENT_CENTER, 140, 18, UI.TEXT)
		overlay.draw_rect(Rect2(cp + Vector2(20, 40), Vector2(100, 6)), Color(0.03, 0.035, 0.04, 0.85))
		overlay.draw_rect(Rect2(cp + Vector2(20, 41), Vector2(100 * clampf(game.comboT / 2.6, 0, 1), 4)), UI.GOLD)
	## 조이스틱
	var j: Dictionary = game.joy
	if j.id != -1:
		overlay.draw_arc(Vector2(j.ox, j.oy), 90, 0, TAU, 40, Color(0.93, 0.91, 0.86, 0.35), 3)
		overlay.draw_circle(Vector2(j.x, j.y), 38, Color(0.95, 0.76, 0.1, 0.4))
		overlay.draw_arc(Vector2(j.x, j.y), 38, 0, TAU, 32, UI.GOLD, 3)
	## 화면 효과: 피격·섬광·조준 중
	if game.aim != null:
		overlay.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.08, 0.12, 0.2, 0.22))
	if p.hurtT > 0:
		overlay.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.8, 0.08, 0.04, p.hurtT * 1.1))
	if game.flash > 0:
		overlay.draw_rect(Rect2(Vector2.ZERO, vs), Color(1, 0.98, 0.92, minf(0.8, game.flash * 1.6)))
	## 진화 연출: 레터박스 + 대형 문구
	if game.evoT > 0:
		var el: float = 2.0 - game.evoT
		var al: float = clampf(game.evoT / 0.4, 0, 1)
		var bar: float = 90.0 * clampf(el / 0.15, 0, 1) * al
		overlay.draw_rect(Rect2(0, 0, vs.x, bar), Color(0, 0, 0, 0.85))
		overlay.draw_rect(Rect2(0, vs.y - bar, vs.x, bar), Color(0, 0, 0, 0.85))
		var c: Color = game.evo_col
		var pop: float = 1.0 + 0.6 * maxf(0.0, 1.0 - el / 0.18)
		var cy = vs.y * 0.36
		var band = Rect2(0, cy - 70, vs.x, 120)
		overlay.draw_rect(band, Color(0, 0, 0, 0.55 * al))
		overlay.draw_rect(Rect2(0, band.position.y, vs.x, 3), Color(c, al))
		overlay.draw_rect(Rect2(0, band.end.y - 3, vs.x, 3), Color(c, al))
		var s1 = roundi(24 * pop)
		var s2 = roundi(58 * pop)
		overlay.draw_string_outline(f, Vector2(0, cy - 30), "무기 진화", HORIZONTAL_ALIGNMENT_CENTER, vs.x, s1, 6, Color(0, 0, 0, al))
		overlay.draw_string(f, Vector2(0, cy - 30), "무기 진화", HORIZONTAL_ALIGNMENT_CENTER, vs.x, s1, Color(1, 1, 1, al))
		overlay.draw_string_outline(f, Vector2(0, cy + 34), game.evo_name, HORIZONTAL_ALIGNMENT_CENTER, vs.x, s2, 12, Color(0, 0, 0, al))
		overlay.draw_string(f, Vector2(0, cy + 34), game.evo_name, HORIZONTAL_ALIGNMENT_CENTER, vs.x, s2, Color(c, al))
