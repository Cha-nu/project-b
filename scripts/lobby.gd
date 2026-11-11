extends Control
## 로비: 작전(지구본에서 임무 선택) / 지원요청 / 무기 탭. 골드로 지원요청을 해금하고 장착한다(기본 3칸, 골드로 4칸까지).

signal deploy

const UI := preload("res://scripts/ui.gd")
const Data := preload("res://scripts/data.gd")
const Glyph := preload("res://scripts/glyph.gd")
const Icon := preload("res://scripts/icon.gd")
const Globe := preload("res://scripts/globe.gd")
const BG := Color("#090b0c")
const MISSION_N := 10

var globe: Control
var gold_lb: Label
var lvl_lb: Label
var rank_lb: Label
var xp_fill: ColorRect
var tabs := {}
var nav_btns := {}
var nav_icons := {}
var nav_tiles := {}
var top_bg: Panel
## 작전 카드
var m_name: Label
var m_sub: Label
var m_tags: HBoxContainer
var m_reward: Label
var m_idx: Label
var m_op: Label
var m_obj: Label
var m_brief: Label
var m_order: Label
var loadout: HBoxContainer
var aim_a: Button
var aim_m: Button
## 지원요청·무기 탭
var eq_row: HBoxContainer
var own_lb: Label
var grid: GridContainer
var wlist: VBoxContainer
var sheet: Control
var sheet_box: VBoxContainer
var toast_lb: Label
var toast_t := 0.0
var sel := 0
var _sel_init := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg = ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	add_child(UI.hatch())
	## 지구본: 화면 위쪽 영역 (아래는 작전 카드가 덮는다)
	globe = Globe.new()
	globe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	globe.offset_top = 70
	globe.offset_bottom = -662
	add_child(globe)
	globe.picked.connect(func(i):
		if i >= Save.d.stage:
			toast("스테이지 %d를 먼저 완수하세요" % Save.d.stage)
			globe.select(sel, false)
			return
		sel = i
		_fill_card())
	## 본문 탭
	var body = Control.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_top = 128
	body.offset_bottom = -112
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body)
	tabs.play = _play_tab()
	tabs.strat = _strat_tab()
	tabs.weap = _weap_tab()
	for k in tabs:
		body.add_child(tabs[k])
	_top_bar()
	_nav_bar()
	## 해금 시트
	sheet = ColorRect.new()
	sheet.color = Color(0.021, 0.025, 0.028, 0.75)
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet.visible = false
	sheet.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			sheet.visible = false)
	add_child(sheet)
	var sp = PanelContainer.new()
	var ss = UI.card(UI.PANEL2, UI.GOLD, 28, 30)
	ss.corner_radius_bottom_left = 0
	ss.corner_radius_bottom_right = 0
	sp.add_theme_stylebox_override("panel", ss)
	sp.anchor_left = 0; sp.anchor_right = 1; sp.anchor_top = 1; sp.anchor_bottom = 1
	sp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	sheet.add_child(sp)
	sheet_box = VBoxContainer.new()
	sheet_box.add_theme_constant_override("separation", 14)
	sp.add_child(sheet_box)
	toast_lb = UI.label("", 26, UI.TEXT, true, 8)
	toast_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_lb.anchor_left = 0; toast_lb.anchor_right = 1; toast_lb.anchor_top = 1; toast_lb.anchor_bottom = 1
	toast_lb.offset_top = -240
	toast_lb.offset_bottom = -180
	add_child(toast_lb)
	tab("play")


## ---------- 상단: 프로필 · 재화 · 설정 ----------
func _top_bar() -> void:
	top_bg = Panel.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(UI.INK, 0.96)
	sb.border_color = UI.GOLD
	sb.border_width_bottom = 2
	top_bg.add_theme_stylebox_override("panel", sb)
	top_bg.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bg.offset_bottom = 122
	top_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_bg)
	var top = HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 18; top.offset_right = -18; top.offset_top = 22; top.offset_bottom = 104
	top.add_theme_constant_override("separation", 12)
	add_child(top)
	## 계급장 + 레벨
	var badge = PanelContainer.new()
	var bs = UI.box(Color("#23282e"), UI.GOLD, 3, 0, UI.GOLD, 0, 0, UI.GOLD, 40)
	badge.add_theme_stylebox_override("panel", bs)
	badge.custom_minimum_size = Vector2(76, 76)
	var bc = CenterContainer.new()
	badge.add_child(bc)
	var bv = VBoxContainer.new()
	bv.add_theme_constant_override("separation", -6)
	bc.add_child(bv)
	var ic = Icon.new().setup("medal", UI.GOLD, 30)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bv.add_child(ic)
	lvl_lb = UI.label("1", 22, UI.TEXT, true, 4)
	lvl_lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(lvl_lb)
	top.add_child(badge)
	var pv = VBoxContainer.new()
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	pv.add_theme_constant_override("separation", 4)
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(pv)
	pv.add_child(UI.label("지휘관", 28, UI.TEXT, true))
	rank_lb = UI.label("", 18, UI.MUTE)
	pv.add_child(rank_lb)
	var xb = Panel.new()
	xb.custom_minimum_size = Vector2(170, 10)
	xb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	xb.add_theme_stylebox_override("panel", UI.pill(Color("#111417"), Color(1, 1, 1, 0.08), 0, 0))
	xb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.add_child(xb)
	xp_fill = ColorRect.new()
	xp_fill.color = UI.BLUE
	xp_fill.position = Vector2(2, 2)
	xp_fill.size = Vector2(80, 6)
	xp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xb.add_child(xp_fill)
	## 골드
	var gp = PanelContainer.new()
	gp.add_theme_stylebox_override("panel", UI.pill(Color("#14171b"), Color(1, 0.77, 0.19, 0.5), 10, 6))
	gp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var gh = HBoxContainer.new()
	gh.add_theme_constant_override("separation", 8)
	gp.add_child(gh)
	gh.add_child(Icon.new().setup("gem", UI.GOLD, 30))
	gold_lb = UI.label("0", 28, UI.TEXT, true)
	gold_lb.custom_minimum_size = Vector2(70, 0)
	gh.add_child(gold_lb)
	top.add_child(gp)
	## 설정(사운드)
	var gear = Button.new()
	gear.custom_minimum_size = Vector2(64, 64)
	gear.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for k in ["normal", "hover", "pressed", "focus"]:
		gear.add_theme_stylebox_override(k, UI.pill(Color("#1f2429"), Color(1, 1, 1, 0.12), 0, 0))
	var gc = CenterContainer.new()
	gc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gc.add_child(Icon.new().setup("gear", Color("#ccd5e2"), 34))
	gear.add_child(gc)
	gear.pressed.connect(func():
		Save.d.snd = not Save.d.snd
		Synth.enabled = Save.d.snd
		Save.persist()
		toast("사운드 " + ("켜짐" if Save.d.snd else "꺼짐")))
	top.add_child(gear)


## ---------- 하단 내비 (세 메뉴가 같은 높이, 고른 메뉴가 금색 타일로 켜진다) ----------
func _nav_bar() -> void:
	var nav = Panel.new()
	var ns = StyleBoxFlat.new()
	ns.bg_color = Color(UI.INK, 0.97)
	ns.border_color = UI.LINE
	ns.border_width_top = 2
	nav.add_theme_stylebox_override("panel", ns)
	nav.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	nav.offset_top = -108
	nav.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(nav)
	var nh = HBoxContainer.new()
	nh.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	nh.offset_left = 14; nh.offset_right = -14; nh.offset_top = 14; nh.offset_bottom = -18
	nh.add_theme_constant_override("separation", 6)
	nav.add_child(nh)
	for k in [["weap", "무기고", "gun"], ["play", "작전", "globe"], ["strat", "지원요청", "radio"]]:
		var b = Button.new()
		b.flat = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.pressed.connect(func():
			Synth.beep(660, 0.04, "sine", 0.04)
			tab(k[0]))
		nh.add_child(b)
		## 탭 한 칸: 평행사변형 바탕 위에 아이콘 + 이름. 고른 탭만 강조색으로 채운다
		var tile = PanelContainer.new()
		tile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tile)
		var cc = CenterContainer.new()
		cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(cc)
		var hb = HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cc.add_child(hb)
		var ic = Icon.new().setup(k[2], UI.MUTE, 36)
		hb.add_child(ic)
		var l = UI.label(k[1], 26, UI.MUTE, true)
		hb.add_child(l)
		nav_icons[k[0]] = ic
		nav_tiles[k[0]] = tile
		nav_btns[k[0]] = l


func _process(dt: float) -> void:
	if toast_t > 0:
		toast_t -= dt
		toast_lb.modulate.a = clampf(toast_t / 0.3, 0, 1)


func toast(t: String) -> void:
	toast_lb.text = t
	toast_t = 1.8


func tab(id: String) -> void:
	for k in tabs:
		tabs[k].visible = k == id
		var on: bool = k == id
		nav_btns[k].add_theme_color_override("font_color", Color(0.1, 0.06, 0.0) if on else UI.MUTE)
		nav_icons[k].col = Color(0.16, 0.1, 0.0) if on else UI.MUTE
		nav_icons[k].queue_redraw()
		nav_tiles[k].add_theme_stylebox_override("panel", UI.bevel(UI.GOLD, UI.GOLD_D, UI.GOLD, false, 0) if on else UI.bevel(UI.PANEL2, UI.LINE, UI.LINE, true, 0))
	globe.visible = id == "play"
	top_bg.visible = id != "play"


func _section(title: String, sub: String) -> HBoxContainer:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var bar = Panel.new()
	bar.add_theme_stylebox_override("panel", UI.bevel(UI.GOLD, UI.GOLD_D, UI.GOLD, true, 0))
	bar.custom_minimum_size = Vector2(16, 30)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(bar)
	h.add_child(UI.label(title, 32, UI.TEXT, true))
	h.add_child(UI.label("//", 22, Color(UI.GOLD, 0.6), true))
	var s = UI.label(sub, 19, UI.MUTE)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(s)
	return h


func _scroll_tab() -> Array:
	var sc = ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var m = MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 22)
	sc.add_child(m)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	m.add_child(v)
	return [sc, v]


## ---------- 작전 탭: 지구본 + 작전 카드 ----------
func _play_tab() -> Control:
	var c = Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hint = UI.label("//  작전 구역  ·  스테이지를 순서대로 완수하라", 20, Color(0.75, 0.82, 0.9), false, 6)
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hint.offset_top = 4
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(hint)
	## 작전 카드
	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.card(Color("#171b1e"), Color("#373f48"), 22, 26))
	card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	card.offset_left = 16; card.offset_right = -16
	card.offset_top = -672; card.offset_bottom = -14
	c.add_child(card)
	var cv = VBoxContainer.new()
	cv.add_theme_constant_override("separation", 10)
	card.add_child(cv)
	c.add_child(_over(card, UI.brackets(UI.GOLD, 22.0, 3.0, 0.0)))
	## 1행: 태그 + 지점 넘기기
	var r1 = HBoxContainer.new()
	r1.add_theme_constant_override("separation", 8)
	cv.add_child(r1)
	m_tags = HBoxContainer.new()
	m_tags.add_theme_constant_override("separation", 8)
	m_tags.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r1.add_child(m_tags)
	var prev = UI.dark_button("", 22)
	_btn_icon(prev, "left", UI.TEXT, 22)
	prev.custom_minimum_size = Vector2(56, 48)
	prev.pressed.connect(func(): _step(-1))
	r1.add_child(prev)
	m_idx = UI.label("1/7", 20, UI.MUTE, true)
	m_idx.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	m_idx.size_flags_vertical = Control.SIZE_FILL
	r1.add_child(m_idx)
	var nxt = UI.dark_button("", 22)
	_btn_icon(nxt, "right", UI.TEXT, 22)
	nxt.custom_minimum_size = Vector2(56, 48)
	nxt.pressed.connect(func(): _step(1))
	r1.add_child(nxt)
	## 2행: 이름 + 보상
	var r2 = HBoxContainer.new()
	cv.add_child(r2)
	var nv = VBoxContainer.new()
	nv.add_theme_constant_override("separation", 2)
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r2.add_child(nv)
	m_name = UI.label("", 40, UI.TEXT, true)
	nv.add_child(m_name)
	m_sub = UI.label("", 19, UI.MUTE)
	nv.add_child(m_sub)
	var rw = VBoxContainer.new()
	rw.alignment = BoxContainer.ALIGNMENT_CENTER
	rw.add_theme_constant_override("separation", 0)
	r2.add_child(rw)
	var rl = UI.label("예상 보상", 17, UI.MUTE)
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rw.add_child(rl)
	var rh = HBoxContainer.new()
	rh.alignment = BoxContainer.ALIGNMENT_END
	rh.add_theme_constant_override("separation", 6)
	rw.add_child(rh)
	rh.add_child(Icon.new().setup("gem", UI.GOLD, 28))
	m_reward = UI.label("", 32, UI.GOLD, true)
	rh.add_child(m_reward)
	## 작전 브리핑: 작전명 + 이 구역의 의미 + 지휘부 지시
	var bp = PanelContainer.new()
	bp.add_theme_stylebox_override("panel", UI.box(Color(0, 0, 0, 0.3), Color(UI.GOLD, 0.35), 1, 0, UI.GOLD, 12, 5, UI.GOLD))
	bp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bv = VBoxContainer.new()
	bv.add_theme_constant_override("separation", 4)
	bp.add_child(bv)
	m_op = UI.label("", 20, UI.GOLD, true)
	bv.add_child(m_op)
	m_brief = UI.label("", 17, Color(0.82, 0.84, 0.86))
	m_brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bv.add_child(m_brief)
	m_order = UI.label("", 17, Color(0.950, 0.666, 0.270))
	m_order.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bv.add_child(m_order)
	cv.add_child(bp)
	## 이 스테이지의 보조 목표와 적 전력 (스테이지가 오를수록 늘어난다)
	m_obj = UI.label("", 15, UI.MUTE)
	m_obj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(m_obj)
	## 3행: 장비 (무기 + 지원요청 3)
	loadout = HBoxContainer.new()
	loadout.add_theme_constant_override("separation", 8)
	cv.add_child(loadout)
	## 4행: 투하 위치 + 출격
	var r4 = HBoxContainer.new()
	r4.add_theme_constant_override("separation", 12)
	cv.add_child(r4)
	var av = VBoxContainer.new()
	av.add_theme_constant_override("separation", 6)
	r4.add_child(av)
	av.add_child(UI.label("지원요청 투하", 17, UI.MUTE))
	var seg = HBoxContainer.new()
	seg.add_theme_constant_override("separation", 6)
	av.add_child(seg)
	aim_a = UI.dark_button("자동", 22)
	aim_m = UI.dark_button("수동", 22)
	aim_a.custom_minimum_size = Vector2(84, 58)
	aim_m.custom_minimum_size = Vector2(84, 58)
	aim_a.pressed.connect(func(): _set_aim("auto"))
	aim_m.pressed.connect(func(): _set_aim("manual"))
	seg.add_child(aim_a)
	seg.add_child(aim_m)
	var go = UI.gold_button("출격", 46)
	_btn_icon(go, "play", Color("#271b09"), 44, 0.5, 86)
	go.custom_minimum_size = Vector2(0, 104)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.pressed.connect(func():
		Synth.beep(523, 0.08); Synth.beep(784, 0.15, "square", 0.05, 0.0, 0.08)
		deploy.emit())
	r4.add_child(go)
	return c


## 버튼 위에 벡터 아이콘을 얹는다. ax: 가로 기준(0~1), dx: 그 지점에서의 치우침
func _btn_icon(b: Button, kind: String, col: Color, sz: float, ax := 0.5, dx := 0.0) -> void:
	var ic = Icon.new().setup(kind, col, sz)
	ic.anchor_left = ax; ic.anchor_right = ax; ic.anchor_top = 0.5; ic.anchor_bottom = 0.5
	ic.offset_left = dx - sz / 2; ic.offset_right = dx + sz / 2
	ic.offset_top = -sz / 2 - 4; ic.offset_bottom = sz / 2 - 4
	b.add_child(ic)


## deco를 target과 같은 자리에 겹쳐 놓는다 (컨테이너 안에 넣으면 배치가 흐트러지므로 형제로 둔다)
func _over(target: Control, deco: Control) -> Control:
	deco.anchor_left = target.anchor_left; deco.anchor_right = target.anchor_right
	deco.anchor_top = target.anchor_top; deco.anchor_bottom = target.anchor_bottom
	deco.offset_left = target.offset_left; deco.offset_right = target.offset_right
	deco.offset_top = target.offset_top; deco.offset_bottom = target.offset_bottom
	return deco


func _step(d: int) -> void:
	## 열린 스테이지 안에서만 넘긴다
	var n = mini(Save.d.missions.size(), Save.d.stage)
	if n == 0:
		return
	sel = (sel + d + n) % n
	globe.select(sel, false)
	Synth.beep(880, 0.05, "sine", 0.04)
	_fill_card()


func _tag(text: String, col: Color, filled := false) -> PanelContainer:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.pill(col if filled else Color(col, 0.16), col, 14, 5))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(UI.label(text, 19, Color("#090b0c") if filled else col, true))
	return p


## 선택된 작전 정보
func current() -> Dictionary:
	_ensure_missions()
	return Save.d.missions[clampi(sel, 0, Save.d.missions.size() - 1)]


func reward_of(m: Dictionary) -> int:
	return int(150 * (1.0 + 0.25 * (m.stage - 1)))


func _fill_card() -> void:
	var m = current()
	for c in m_tags.get_children():
		c.queue_free()
	var bm: Dictionary = Data.BIOMES[m.biome]
	var bc = [Color("#d0933d"), Color("#7ed365"), Color("#c5e0f2")][m.biome]
	m_tags.add_child(_tag(bm.n, bc))
	m_tags.add_child(_tag("스테이지 %d" % m.stage, Globe.DIFF_COL[m.diff], true))
	m_tags.add_child(_tag("위험도 " + Globe.DIFF_N[m.diff], Globe.DIFF_COL[m.diff]))
	if m.stage < Save.d.stage:
		m_tags.add_child(_tag("완수", UI.GREEN))
	m_name.text = m.name
	var lat = rad_to_deg(m.lat)
	var lon = rad_to_deg(m.lon)
	m_sub.text = "작전 구역 #%04X   ·   %d°%s %d°%s" % [m.seed % 0xffff, absi(roundi(lat)), "N" if lat >= 0 else "S", absi(roundi(lon)), "E" if lon >= 0 else "W"]
	m_reward.text = "%d+" % reward_of(m)
	m_idx.text = "%d/%d" % [sel + 1, Save.d.missions.size()]
	var bf: Dictionary = Data.BRIEF[clampi(m.stage - 1, 0, Data.BRIEF.size() - 1)]
	m_op.text = "작전명 「%s」" % bf.op
	m_brief.text = bf.sit
	m_order.text = "지휘부: " + bf.order
	var on: Array = Data.stage_objs(m.stage).map(func(k): return Data.OBJ_NAME[k])
	var nw = Data.stage_new(m.stage)
	var main_t = ("보스 격파: %s → 탈출" % Data.ET[Data.BOSS[m.stage]].n) if Data.BOSS.has(m.stage) else "단말기 해킹 ×2 → 탈출"
	m_obj.text = "주 임무  " + main_t + "\n보조 목표  %s\n적 전력  %s%s" % [" · ".join(on), " · ".join(Data.stage_enemies(m.stage)), ("\n신규 등장  " + nw) if nw != "" else ""] + "\n권장 장비  " + Data.gear_hint(m.stage)
	m_reward.text = "%d+" % reward_of(m)


## 저장된 작전 지점 정리 (JSON에서 읽으면 숫자가 float가 된다)
func _ensure_missions() -> void:
	if not Save.d.has("missions") or not (Save.d.missions is Array):
		Save.d.missions = []
	var ms: Array = []
	for m in Save.d.missions:
		## 스테이지 번호가 없는 예전 저장(자유 선택 작전)은 버리고 10단계를 새로 깐다
		if m is Dictionary and m.has("lat") and m.has("stage"):
			ms.append({lat = float(m.lat), lon = float(m.lon), biome = int(m.biome), diff = int(m.diff), seed = int(m.seed), name = str(m.name), stage = int(m.stage)})
	var changed = ms.size() != Save.d.missions.size()
	if ms.size() != MISSION_N:
		ms = []
		changed = true
	while ms.size() < MISSION_N:
		var nm = Globe.gen_mission(ms)
		if nm.is_empty():
			break
		## 순서대로 스테이지 번호를 매긴다. 위험도 등급: 1~2 정찰, 3~6 교전, 7~10 격전
		nm.stage = ms.size() + 1
		nm.diff = 0 if nm.stage <= 2 else 1 if nm.stage <= 6 else 2
		ms.append(nm)
	Save.d.missions = ms
	if changed:
		Save.persist()


## 임무 성공: 다음 스테이지를 연다
func complete_current() -> void:
	_ensure_missions()
	## 가장 앞선 스테이지를 깼으면 다음 스테이지가 열린다. 선택도 다음으로 넘긴다
	if sel + 1 >= Save.d.stage and Save.d.stage < MISSION_N:
		Save.d.stage += 1
		toast("스테이지 %d 개방" % Save.d.stage)
	Save.persist()
	sel = mini(sel + 1, mini(Save.d.stage, Save.d.missions.size()) - 1)


func _set_aim(v: String) -> void:
	Save.d.aim = v
	Save.persist()
	refresh()


## ---------- 지원요청 탭 ----------
func _strat_tab() -> Control:
	var r = _scroll_tab()
	var v: VBoxContainer = r[1]
	v.add_child(_section("장착 중", "눌러서 교체하거나 해제. 칸은 골드로 늘린다"))
	eq_row = HBoxContainer.new()
	eq_row.add_theme_constant_override("separation", 10)
	v.add_child(eq_row)
	var h = _section("해금 트리", "")
	own_lb = h.get_child(2) as Label
	v.add_child(h)
	grid = GridContainer.new()
	grid.columns = 1
	grid.add_theme_constant_override("v_separation", 16)
	v.add_child(grid)
	return r[0]


func _weap_tab() -> Control:
	var r = _scroll_tab()
	var v: VBoxContainer = r[1]
	v.add_child(_section("무기고", "계열마다 1등급부터 차례로 해금"))
	wlist = VBoxContainer.new()
	wlist.add_theme_constant_override("separation", 16)
	v.add_child(wlist)
	return r[0]


## 지원요청 타일 (버튼). sub: 부호 또는 가격
func _tile(s: Dictionary, h := 168.0, show_eq := true) -> Button:
	var b = Button.new()
	b.custom_minimum_size = Vector2(0, h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var own: bool = Save.d.own.has(s.id)
	var st = UI.rar_box(s.rar, 10)
	for k in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(k, st)
	var v = VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 5 if h < 120 else 7)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var rc: Color = [Color("#ccd5e0"), Color("#acdaf2"), Color("#dbc7f2"), Color("#eda239")][s.rar]
	var si = Icon.new().setup(s.id, rc if own else UI.MUTE, 30 if h < 120 else 44)
	si.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(si)
	var nm = UI.label(s.name, 19 if h < 120 else 22, UI.TEXT if own else UI.MUTE, true)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nm)
	var cc = CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if own:
		cc.add_child(Glyph.new().setup(s.code, 0, 10 if h >= 120 else 8))
	else:
		var ph = HBoxContainer.new()
		ph.add_theme_constant_override("separation", 4)
		ph.add_child(Icon.new().setup("gem", UI.GOLD, 22))
		ph.add_child(UI.label("%d" % s.price, 22, UI.GOLD, true))
		cc.add_child(ph)
	v.add_child(cc)
	if show_eq and Save.d.eq.has(s.id):
		var tp = _tag("장착", UI.GOLD, true)
		tp.position = Vector2(6, 9)
		tp.scale = Vector2(0.82, 0.82)
		b.add_child(tp)
	if not own:
		b.modulate = Color(0.72, 0.75, 0.8)
	b.pressed.connect(func(): open_sheet(s.id))
	return b


func _empty_slot(h := 150.0) -> Control:
	var p = PanelContainer.new()
	p.custom_minimum_size = Vector2(0, h)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", UI.box(Color(0.064, 0.074, 0.084, 0.6), UI.LINE, 2, 0, UI.GOLD, 8))
	var l = UI.label("+ 비어 있음", 20, UI.MUTE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


func refresh() -> void:
	_ensure_missions()
	if not _sel_init:
		## 처음 열 때는 가장 앞선 스테이지를 고른다
		_sel_init = true
		sel = Save.d.stage - 1
	sel = clampi(sel, 0, mini(Save.d.stage, Save.d.missions.size()) - 1)
	gold_lb.text = "%d" % Save.d.gold
	var runs: int = Save.d.runs
	var lv = 1 + runs / 3
	lvl_lb.text = str(lv)
	const RANKS := ["훈련병", "이병", "일병", "상병", "병장", "하사", "중사", "상사", "소위", "중위", "대위", "소령"]
	rank_lb.text = "%s · 작전 %d회" % [RANKS[mini(lv - 1, RANKS.size() - 1)], runs]
	xp_fill.size.x = 166.0 * ((runs % 3) / 3.0) + 4
	globe.set_missions(Save.d.missions, sel)
	_fill_card()
	for c in loadout.get_children():
		c.queue_free()
	var w: Dictionary = Data.weapon(Save.d.w)
	var wb = Button.new()
	wb.custom_minimum_size = Vector2(150, 104)
	for k in ["normal", "hover", "pressed", "focus"]:
		wb.add_theme_stylebox_override(k, UI.rar_box(1, 8))
	var wv = VBoxContainer.new()
	wv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wv.alignment = BoxContainer.ALIGNMENT_CENTER
	wv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wi = Icon.new().setup(w.id, UI.BLUE, 44)
	wi.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wv.add_child(wi)
	var wl = UI.label(w.name, 20, UI.TEXT, true)
	wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wv.add_child(wl)
	wb.add_child(wv)
	wb.pressed.connect(func(): tab("weap"))
	loadout.add_child(wb)
	for i in Save.d.slots:
		if i < Save.d.eq.size():
			var t = _tile(Data.strat(Save.d.eq[i]), 104, false)
			for cn in t.pressed.get_connections():
				t.pressed.disconnect(cn.callable)
			t.pressed.connect(func(): tab("strat"))
			loadout.add_child(t)
		else:
			loadout.add_child(_empty_slot(104))
	for pair in [[aim_a, "auto"], [aim_m, "manual"]]:
		var on: bool = Save.d.aim == pair[1]
		var b: Button = pair[0]
		var face = UI.BLUE if on else UI.PANEL2
		for k in ["normal", "hover"]:
			b.add_theme_stylebox_override(k, UI.bevel(face, face.darkened(0.5), face.lightened(0.25), false, 10))
		b.add_theme_stylebox_override("pressed", UI.bevel(face, face.darkened(0.5), face.lightened(0.25), true, 10))
		b.add_theme_color_override("font_color", Color.WHITE if on else UI.MUTE)
		b.add_theme_color_override("font_hover_color", Color.WHITE if on else UI.TEXT)
	for c in eq_row.get_children():
		c.queue_free()
	for i in Save.d.slots:
		if i < Save.d.eq.size():
			eq_row.add_child(_tile(Data.strat(Save.d.eq[i]), 120, false))
		else:
			eq_row.add_child(_empty_slot(120))
	if Save.d.slots < Data.SLOT_MAX:
		## 네 번째 칸: 아주 비싸게 산다
		var can: bool = Save.d.gold >= Data.SLOT_PRICE
		var sb = UI.gold_button("칸 추가\n%d" % Data.SLOT_PRICE, 22) if can else UI.dark_button("칸 추가\n%d" % Data.SLOT_PRICE, 22)
		sb.custom_minimum_size = Vector2(120, 120)
		sb.pressed.connect(func():
			if Save.d.gold < Data.SLOT_PRICE:
				toast("골드가 %d 부족합니다" % (Data.SLOT_PRICE - Save.d.gold))
				return
			Save.d.gold -= Data.SLOT_PRICE
			Save.d.slots += 1
			Save.persist()
			Synth.beep(660, 0.1); Synth.beep(990, 0.25, "square", 0.05, 0.0, 0.1)
			toast("지원요청 칸이 %d개로 늘었다" % Save.d.slots)
			refresh())
		eq_row.add_child(sb)
	own_lb.text = "%d / %d 보유" % [Save.d.own.size(), Data.STRATS.size()]
	for c in grid.get_children():
		c.queue_free()
	for br in Data.BRANCHES:
		grid.add_child(_branch_panel(br))
	for c in wlist.get_children():
		c.queue_free()
	for cls in ["ar", "sg", "lmg", "rail"]:
		wlist.add_child(_wclass_panel(cls))


## 등급 색 (1 강철 · 2 청색 · 3 금색)
const TIER_COL := [Color("#9aa6b2"), Color("#5fa8d8"), Color("#e68600")]


## 트리 한 줄의 틀: 제목 + 진행도 + 가로로 이어진 칸들
func _tree_panel(title: String, sub: String, have: int, total: int) -> Array:
	var pc = PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var done = have >= total
	pc.add_theme_stylebox_override("panel", UI.card(UI.PANEL, Color(UI.GOLD, 0.7) if done else UI.LINE, 14, 10))
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pc.add_child(v)
	var hd = HBoxContainer.new()
	hd.add_theme_constant_override("separation", 10)
	v.add_child(hd)
	hd.add_child(UI.label(title, 26, UI.GOLD if done else UI.TEXT, true))
	var sl = UI.label(sub, 17, UI.MUTE)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.clip_text = true
	hd.add_child(sl)
	## 진행도 점
	var dots = HBoxContainer.new()
	dots.add_theme_constant_override("separation", 5)
	dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in total:
		var d = Panel.new()
		d.custom_minimum_size = Vector2(14, 14)
		d.add_theme_stylebox_override("panel", UI.pill(UI.GOLD if i < have else Color(1, 1, 1, 0.12), Color(0, 0, 0, 0), 0, 0))
		dots.add_child(d)
	hd.add_child(dots)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	v.add_child(row)
	return [pc, row]


func _tree_arrow(lit: bool) -> Control:
	var a = Icon.new().setup("right", UI.GOLD if lit else Color(1, 1, 1, 0.18), 16)
	a.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return a


## 트리 칸 공통 모양. state: "on"(장착) / "own"(보유) / "buy"(지금 살 수 있음) / "need"(골드 부족) / "lock"(앞 단계 필요)
func _node_button(col: Color, state: String, h: float) -> Button:
	var b = Button.new()
	b.custom_minimum_size = Vector2(0, h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_contents = true
	var bg = col.darkened(0.72)
	var line = col
	var bw = 2
	match state:
		"on":
			bg = UI.GOLD.darkened(0.68)
			line = UI.GOLD
			bw = 3
		"own":
			bg = col.darkened(0.62)
		"buy":
			## 살 수 있는 칸은 금색 테두리로 눈에 띄게
			bg = col.darkened(0.55)
			line = UI.GOLD
			bw = 3
		"need":
			line = Color(col, 0.6)
		"lock":
			bg = Color(0.044, 0.051, 0.058)
			line = Color(1, 1, 1, 0.1)
	var st = UI.box(bg, line, bw, 0, UI.GOLD, 6)
	st.shadow_color = Color(0, 0, 0, 0.4)
	st.shadow_size = 4
	st.shadow_offset = Vector2(0, 3)
	if state == "buy":
		st.shadow_color = Color(UI.GOLD, 0.35)
		st.shadow_size = 8
		st.shadow_offset = Vector2.ZERO
	for k in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(k, st)
	var sp = st.duplicate()
	sp.bg_color = bg.lightened(0.08)
	b.add_theme_stylebox_override("pressed", sp)
	return b


## 칸 아래쪽 상태 줄: 장착 중 / 보유 / 가격 / 잠김
func _node_foot(state: String, price: int) -> Control:
	var pc = PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	pc.add_child(h)
	match state:
		"on":
			pc.add_theme_stylebox_override("panel", UI.pill(UI.GOLD, UI.GOLD, 10, 3))
			h.add_child(UI.label("장착 중", 16, Color(0.16, 0.1, 0.0), true))
		"own":
			pc.add_theme_stylebox_override("panel", UI.pill(Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.2), 10, 3))
			h.add_child(Icon.new().setup("check", UI.GREEN, 16))
			h.add_child(UI.label("보유", 16, UI.TEXT, true))
		"lock":
			pc.add_theme_stylebox_override("panel", UI.pill(Color(0, 0, 0, 0.3), Color(1, 1, 1, 0.1), 10, 3))
			h.add_child(Icon.new().setup("lock", UI.MUTE, 16))
			h.add_child(UI.label("%d" % price, 16, UI.MUTE, true))
		_:
			var ok = state == "buy"
			pc.add_theme_stylebox_override("panel", UI.pill(UI.GOLD if ok else Color(0, 0, 0, 0.35), UI.GOLD if ok else Color(UI.RED, 0.6), 10, 3))
			h.add_child(Icon.new().setup("gem", Color(0.3, 0.2, 0.0) if ok else UI.GOLD, 16))
			h.add_child(UI.label("%d" % price, 17, Color(0.16, 0.1, 0.0) if ok else UI.RED, true))
	return pc


## ---------- 지원요청 해금 트리 ----------
func _strat_state(s: Dictionary) -> String:
	if Save.d.eq.has(s.id):
		return "on"
	if Save.d.own.has(s.id):
		return "own"
	var rq = Data.req_of(s.id)
	if rq != "" and not Save.d.own.has(rq):
		return "lock"
	return "buy" if Save.d.gold >= s.price else "need"


func _branch_panel(br: Dictionary) -> Control:
	var have = 0
	for id in br.ids:
		if Save.d.own.has(id):
			have += 1
	var r = _tree_panel(br.n, br.d, have, br.ids.size())
	var row: HBoxContainer = r[1]
	for i in br.ids.size():
		var s: Dictionary = Data.strat(br.ids[i])
		if i > 0:
			row.add_child(_tree_arrow(Save.d.own.has(br.ids[i - 1])))
		var state = _strat_state(s)
		var col: Color = Data.RAR_COL[s.rar]
		var b = _node_button(col, state, 158)
		var v = VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.offset_top = 8; v.offset_bottom = -10
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 5)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var locked = state == "lock"
		var ic = Icon.new().setup(s.id, Color(1, 1, 1, 0.25) if locked else col.lightened(0.35) if state != "on" else UI.GOLD, 46)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		var nm = UI.label(s.name, 17, UI.MUTE if locked else UI.TEXT, true)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.clip_text = true
		v.add_child(nm)
		var gc = CenterContainer.new()
		gc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gc.custom_minimum_size = Vector2(0, 14)
		if not locked:
			gc.add_child(Glyph.new().setup(s.code, 0, 7 if s.code.length() <= 4 else 5.5 if s.code.length() == 5 else 4.6))
		v.add_child(gc)
		v.add_child(_node_foot(state, s.price))
		b.pressed.connect(func(): open_sheet(s.id))
		row.add_child(b)
	return r[0]


## ---------- 무기고 트리 ----------
func _weap_state(w: Dictionary) -> String:
	if Save.d.w == w.wid:
		return "on"
	if Save.d.wown.has(w.wid):
		return "own"
	var rq = Data.wreq_of(w)
	if rq != "" and not Save.d.wown.has(rq):
		return "lock"
	return "buy" if Save.d.gold >= w.price else "need"


func _wclass_panel(cls: String) -> Control:
	var ws: Array = Data.WEAPONS.filter(func(w): return w.id == cls)
	var have = ws.filter(func(w): return Save.d.wown.has(w.wid)).size()
	var evo = ""
	for e in Data.EVOS:
		if e.get("w", "") == cls:
			evo = "진화 → " + e.n
	var r = _tree_panel(Data.WCLASS[cls], evo, have, ws.size())
	var row: HBoxContainer = r[1]
	var top: float = 0.0
	for w in Data.WEAPONS:
		top = maxf(top, Data.dps(w))
	for i in ws.size():
		var w: Dictionary = ws[i]
		if i > 0:
			row.add_child(_tree_arrow(Save.d.wown.has(ws[i - 1].wid)))
		var state = _weap_state(w)
		var col: Color = TIER_COL[w.tier - 1]
		var locked = state == "lock"
		var b = _node_button(col, state, 236)
		var v = VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 10; v.offset_right = -10; v.offset_top = 8; v.offset_bottom = -10
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 5)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var tl = UI.label("%d등급" % w.tier, 15, Color(col, 0.4 if locked else 1.0), true)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(tl)
		var ic = Icon.new().setup(cls, Color(1, 1, 1, 0.22) if locked else UI.GOLD if state == "on" else col.lightened(0.3), 76)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		var nm = UI.label(w.name, 19, UI.MUTE if locked else UI.TEXT, true)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.clip_text = true
		v.add_child(nm)
		## 화력(초당 피해) 숫자 + 막대
		var dh = HBoxContainer.new()
		dh.alignment = BoxContainer.ALIGNMENT_CENTER
		dh.add_theme_constant_override("separation", 6)
		dh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dh.add_child(UI.label("화력", 15, UI.MUTE))
		dh.add_child(UI.label("%d" % Data.dps(w), 22, Color(col.lightened(0.3), 0.4 if locked else 1.0), true))
		v.add_child(dh)
		var bg = Panel.new()
		bg.add_theme_stylebox_override("panel", UI.pill(Color(0, 0, 0, 0.5), Color(0, 0, 0, 0), 0, 0))
		bg.custom_minimum_size = Vector2(0, 8)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fill = Panel.new()
		fill.add_theme_stylebox_override("panel", UI.pill(Color(col, 0.35 if locked else 1.0), Color(0, 0, 0, 0), 0, 0))
		fill.anchor_bottom = 1.0
		fill.anchor_right = clampf(Data.dps(w) / top, 0.05, 1.0)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(fill)
		v.add_child(bg)
		v.add_child(_node_foot(state, w.price))
		b.pressed.connect(func():
			if Save.d.wown.has(w.wid):
				Save.d.w = w.wid
				Save.persist()
				Synth.beep(740, 0.06, "sine", 0.05)
				refresh()
			else:
				open_wsheet(w.wid))
		row.add_child(b)
	return r[0]


## 성능 한 줄: 값 + 지금 장착한 무기와의 차이
func _cmp(k: String, val: float, cur: float, fmt: String, lower_better := false) -> PanelContainer:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.add_child(UI.label(fmt % val, 24, UI.TEXT, true))
	if absf(val - cur) > 0.001 and cur > 0:
		var pct = (val - cur) / cur * 100.0
		var good = (pct < 0) if lower_better else (pct > 0)
		h.add_child(UI.label("%+d%%" % roundi(pct), 20, UI.GREEN if good else UI.RED, true))
	return _kv(k, h)


## 무기 구매 확인 시트
func open_wsheet(wid: String) -> void:
	var w: Dictionary = Data.weapon(wid)
	for c in sheet_box.get_children():
		c.queue_free()
	var hd = HBoxContainer.new()
	hd.add_theme_constant_override("separation", 16)
	var it = PanelContainer.new()
	it.add_theme_stylebox_override("panel", UI.rar_box(mini(3, w.tier), 14))
	it.add_child(Icon.new().setup(w.id, Color.WHITE, 72))
	hd.add_child(it)
	var v = VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(UI.label("%s · %d등급" % [Data.WCLASS[w.id], w.tier], 20, UI.MUTE))
	v.add_child(UI.label(w.name, 40, UI.TEXT, true))
	hd.add_child(v)
	sheet_box.add_child(hd)
	var desc = UI.label(w.desc, 24, Color(0.8, 0.83, 0.86))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sheet_box.add_child(desc)
	## 지금 장착한 무기와 비교해 얼마나 좋아지는지 보여 준다
	var cur: Dictionary = Data.weapon(Save.d.w)
	sheet_box.add_child(UI.label("현재 장착: %s 대비" % cur.name, 18, UI.MUTE))
	sheet_box.add_child(_cmp("화력 (초당 피해)", Data.dps(w), Data.dps(cur), "%d"))
	sheet_box.add_child(_cmp("탄창", w.mag, cur.mag, "%d발"))
	sheet_box.add_child(_cmp("재장전", w.reload, cur.reload, "%.1f초", true))
	sheet_box.add_child(_cmp("사거리", w.range, cur.range, "%d"))
	var wrq = Data.wreq_of(w)
	var wlocked = wrq != "" and not Save.d.wown.has(wrq)
	if wlocked:
		var l0 = UI.label("먼저 %s을(를) 구매해야 합니다." % Data.weapon(wrq).name, 22, UI.RED)
		l0.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sheet_box.add_child(l0)
	elif Save.d.gold < w.price:
		var l = UI.label("골드가 %d 부족합니다. 임무를 완수해 모으세요." % (w.price - Save.d.gold), 22, UI.RED)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sheet_box.add_child(l)
	var row = HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 12)
	row.add_theme_constant_override("v_separation", 14)
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	sheet_box.add_child(row)
	var b = UI.gold_button("     %d 구매" % w.price, 32)
	_btn_icon(b, "gem", Color(0.45, 0.3, 0.02), 30, 0.0, 44)
	b.custom_minimum_size = Vector2(260, 84)
	b.disabled = Save.d.gold < w.price or wlocked
	b.pressed.connect(func():
		Save.d.gold -= w.price
		Save.d.wown.append(wid)
		Save.d.w = wid
		Save.persist()
		Synth.beep(660, 0.1); Synth.beep(990, 0.25, "square", 0.05, 0.0, 0.1)
		toast(w.name + " 구매 · 장착 완료")
		refresh()
		sheet.visible = false)
	row.add_child(b)
	var x = UI.dark_button("닫기", 28)
	x.custom_minimum_size = Vector2(160, 80)
	x.pressed.connect(func(): sheet.visible = false)
	row.add_child(x)
	sheet.visible = true


func open_sheet(id: String) -> void:
	var s: Dictionary = Data.strat(id)
	var own: bool = Save.d.own.has(id)
	var eq: bool = Save.d.eq.has(id)
	for c in sheet_box.get_children():
		c.queue_free()
	var hd = HBoxContainer.new()
	hd.add_theme_constant_override("separation", 16)
	var it = PanelContainer.new()
	it.add_theme_stylebox_override("panel", UI.rar_box(s.rar, 14))
	it.add_child(Icon.new().setup(s.id, Color.WHITE, 72))
	hd.add_child(it)
	var v = VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var tg = _tag(Data.RAR[s.rar], Data.RAR_COL[s.rar])
	tg.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(tg)
	v.add_child(UI.label(s.name, 42, UI.TEXT, true))
	hd.add_child(v)
	sheet_box.add_child(hd)
	var desc = UI.label(s.desc, 24, Color("#ced7e2"))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sheet_box.add_child(desc)
	sheet_box.add_child(_kv("호출 부호", Glyph.new().setup(s.code, s.code.length(), 18)))
	sheet_box.add_child(_kv("재사용 대기", UI.label("%d초" % s.cd, 24, UI.TEXT)))
	sheet_box.add_child(_kv("수동 조준 방식", UI.label(Data.AIMN.get(s.aim, "즉시 발동"), 24, UI.TEXT)))
	var rq = Data.req_of(id)
	var locked = not own and rq != "" and not Save.d.own.has(rq)
	if locked:
		var l0 = UI.label("먼저 %s을(를) 해금해야 합니다." % Data.strat(rq).name, 22, UI.RED)
		l0.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sheet_box.add_child(l0)
	elif not own and Save.d.gold < s.price:
		var l = UI.label("골드가 %d 부족합니다. 임무를 완수해 모으세요." % (s.price - Save.d.gold), 22, UI.RED)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sheet_box.add_child(l)
	var row = HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 12)
	row.add_theme_constant_override("v_separation", 14)
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	sheet_box.add_child(row)
	if not own:
		var b = UI.gold_button("     %d 해금" % s.price, 32)
		_btn_icon(b, "gem", Color("#714f19"), 30, 0.0, 44)
		b.custom_minimum_size = Vector2(260, 84)
		b.disabled = Save.d.gold < s.price or locked
		b.pressed.connect(func():
			Save.d.gold -= s.price
			Save.d.own.append(id)
			if Save.d.eq.size() < Save.d.slots:
				Save.d.eq.append(id)
			Save.persist()
			Synth.beep(660, 0.1); Synth.beep(990, 0.25, "square", 0.05, 0.0, 0.1)
			toast(s.name + " 해금 완료")
			refresh()
			open_sheet(id))
		row.add_child(b)
	elif eq:
		var b = UI.color_button("장착 해제", 28, Color("#7a4440"))
		b.custom_minimum_size = Vector2(220, 80)
		b.pressed.connect(func():
			Save.d.eq.erase(id)
			_done())
		row.add_child(b)
	elif Save.d.eq.size() < Save.d.slots:
		var b = UI.gold_button("장착", 32)
		b.custom_minimum_size = Vector2(220, 84)
		b.pressed.connect(func():
			Save.d.eq.append(id)
			_done())
		row.add_child(b)
	else:
		for i in Save.d.eq.size():
			var b = UI.color_button(Data.strat(Save.d.eq[i]).name + "와 교체", 22, Color("#6288a7"))
			b.custom_minimum_size = Vector2(0, 72)
			b.pressed.connect(func():
				Save.d.eq[i] = id
				_done())
			row.add_child(b)
	var x = UI.dark_button("닫기", 28)
	x.custom_minimum_size = Vector2(160, 80)
	x.pressed.connect(func(): sheet.visible = false)
	row.add_child(x)
	sheet.visible = true


func _done() -> void:
	Save.persist()
	refresh()
	sheet.visible = false


func _kv(k: String, val: Control) -> PanelContainer:
	var p = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(Color("#121518"), Color("#292f36"), 2, 0, UI.GOLD, 14))
	var h = HBoxContainer.new()
	var l = UI.label(k, 22, UI.MUTE)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(val)
	p.add_child(h)
	return p
