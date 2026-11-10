extends Control
## 로비: 작전(지구본에서 임무 선택) / 지원요청 / 무기 탭. 골드로 지원요청을 해금하고 3개까지 장착한다.

signal deploy

const UI := preload("res://scripts/ui.gd")
const Data := preload("res://scripts/data.gd")
const Glyph := preload("res://scripts/glyph.gd")
const Icon := preload("res://scripts/icon.gd")
const Globe := preload("res://scripts/globe.gd")
const BG := Color("#040812")
const MISSION_N := 7

var globe: Control
var gold_lb: Label
var lvl_lb: Label
var rank_lb: Label
var xp_fill: ColorRect
var tabs := {}
var nav_btns := {}
var nav_icons := {}
var top_bg: Panel
## 작전 카드
var m_name: Label
var m_sub: Label
var m_tags: HBoxContainer
var m_reward: Label
var m_idx: Label
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


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg = ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	## 지구본: 화면 위쪽 영역 (아래는 작전 카드가 덮는다)
	globe = Globe.new()
	globe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	globe.offset_top = 70
	globe.offset_bottom = -470
	add_child(globe)
	globe.picked.connect(func(i):
		sel = i
		_fill_card())
	## 본문 탭
	var body = Control.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_top = 128
	body.offset_bottom = -132
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
	sheet.color = Color(0.01, 0.02, 0.04, 0.75)
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
	sb.bg_color = Color(0.02, 0.035, 0.065, 0.96)
	sb.border_color = Color(1, 1, 1, 0.06)
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
	var bs = UI.box(Color("#1a2a42"), UI.GOLD, 3, 0, UI.GOLD, 0, 0, UI.GOLD, 40)
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
	xb.add_theme_stylebox_override("panel", UI.pill(Color("#0b1320"), Color(1, 1, 1, 0.08), 0, 0))
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
	gp.add_theme_stylebox_override("panel", UI.pill(Color("#0b1626"), Color(1, 0.77, 0.19, 0.5), 10, 6))
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
		gear.add_theme_stylebox_override(k, UI.pill(Color("#14233a"), Color(1, 1, 1, 0.12), 0, 0))
	var gc = CenterContainer.new()
	gc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gc.add_child(Icon.new().setup("gear", Color("#c8d3e2"), 34))
	gear.add_child(gc)
	gear.pressed.connect(func():
		Save.d.snd = not Save.d.snd
		Synth.enabled = Save.d.snd
		Save.persist()
		toast("사운드 " + ("켜짐" if Save.d.snd else "꺼짐")))
	top.add_child(gear)


## ---------- 하단 내비 (가운데 작전 버튼이 솟아 있다) ----------
func _nav_bar() -> void:
	var nav = Panel.new()
	var ns = UI.box(Color("#0a1424"), Color(1, 1, 1, 0.08), 0, 0, UI.GOLD, 0, 0, UI.GOLD, 0)
	ns.border_width_top = 2
	ns.corner_radius_top_left = 28
	ns.corner_radius_top_right = 28
	ns.shadow_color = Color(0, 0, 0, 0.5)
	ns.shadow_size = 16
	nav.add_theme_stylebox_override("panel", ns)
	nav.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	nav.offset_top = -124
	nav.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(nav)
	var nh = HBoxContainer.new()
	nh.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	nh.add_theme_constant_override("separation", 0)
	nav.add_child(nh)
	for k in [["weap", "무기", "gun"], ["play", "작전", "globe"], ["strat", "지원요청", "radio"]]:
		var b = Button.new()
		b.flat = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.pressed.connect(func():
			Synth.beep(660, 0.04, "sine", 0.04)
			tab(k[0]))
		nh.add_child(b)
		var v = VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 4)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		if k[0] == "play":
			## 솟아오른 원형 버튼
			v.offset_top = -46
			var disc = PanelContainer.new()
			var ds = UI.bevel(UI.GOLD, UI.GOLD_D, Color("#ffe9a3"), false, 0, 50)
			disc.add_theme_stylebox_override("panel", ds)
			disc.custom_minimum_size = Vector2(100, 100)
			disc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var cc = CenterContainer.new()
			cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			disc.add_child(cc)
			var ic = Icon.new().setup(k[2], Color("#2a1a00"), 56)
			cc.add_child(ic)
			v.add_child(disc)
			nav_icons[k[0]] = ic
		else:
			var ic = Icon.new().setup(k[2], UI.MUTE, 44)
			ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			v.add_child(ic)
			nav_icons[k[0]] = ic
		var l = UI.label(k[1], 22, UI.MUTE, true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
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
		nav_btns[k].add_theme_color_override("font_color", UI.GOLD if k == id else UI.MUTE)
		if k != "play":
			nav_icons[k].col = UI.GOLD if k == id else UI.MUTE
			nav_icons[k].queue_redraw()
	globe.visible = id == "play"
	top_bg.visible = id != "play"


func _section(title: String, sub: String) -> HBoxContainer:
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var bar = Panel.new()
	bar.add_theme_stylebox_override("panel", UI.pill(UI.GOLD, UI.GOLD, 0, 0))
	bar.custom_minimum_size = Vector2(8, 34)
	h.add_child(bar)
	h.add_child(UI.label(title, 32, UI.TEXT, true))
	var s = UI.label(sub, 20, UI.MUTE)
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
	var hint = UI.label("지구본을 돌려 작전 지역을 선택하세요", 20, Color(0.75, 0.82, 0.9), false, 6)
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hint.offset_top = 4
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(hint)
	## 작전 카드
	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.card(Color("#0f1a2b"), Color("#2b4466"), 22, 26))
	card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	card.offset_left = 16; card.offset_right = -16
	card.offset_top = -470; card.offset_bottom = -14
	c.add_child(card)
	var cv = VBoxContainer.new()
	cv.add_theme_constant_override("separation", 14)
	card.add_child(cv)
	## 1행: 태그 + 지점 넘기기
	var r1 = HBoxContainer.new()
	r1.add_theme_constant_override("separation", 8)
	cv.add_child(r1)
	m_tags = HBoxContainer.new()
	m_tags.add_theme_constant_override("separation", 8)
	m_tags.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r1.add_child(m_tags)
	var prev = UI.dark_button("◀", 22)
	prev.custom_minimum_size = Vector2(56, 48)
	prev.pressed.connect(func(): _step(-1))
	r1.add_child(prev)
	m_idx = UI.label("1/7", 20, UI.MUTE, true)
	m_idx.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	m_idx.size_flags_vertical = Control.SIZE_FILL
	r1.add_child(m_idx)
	var nxt = UI.dark_button("▶", 22)
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
	var obj = UI.label("주 임무  단말기 해킹 ×2 → 탈출      보조  통신탑 · 부대 · 방공포", 18, Color("#a9b8cc"))
	obj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cv.add_child(obj)
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
	var go = UI.gold_button("출격  ▶", 44)
	go.custom_minimum_size = Vector2(0, 104)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.pressed.connect(func():
		Synth.beep(523, 0.08); Synth.beep(784, 0.15, "square", 0.05, 0.0, 0.08)
		deploy.emit())
	r4.add_child(go)
	return c


func _step(d: int) -> void:
	var n = Save.d.missions.size()
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
	p.add_child(UI.label(text, 19, Color("#101010") if filled else col, true))
	return p


## 선택된 작전 정보
func current() -> Dictionary:
	_ensure_missions()
	return Save.d.missions[clampi(sel, 0, Save.d.missions.size() - 1)]


func reward_of(m: Dictionary) -> int:
	return int(150 * (1.0 + 0.5 * m.diff))


func _fill_card() -> void:
	var m = current()
	for c in m_tags.get_children():
		c.queue_free()
	var bm: Dictionary = Data.BIOMES[m.biome]
	var bc = [Color("#e0a85a"), Color("#6fd352"), Color("#9fd8ff")][m.biome]
	m_tags.add_child(_tag(bm.n, bc))
	m_tags.add_child(_tag("위험도 " + Globe.DIFF_N[m.diff], Globe.DIFF_COL[m.diff], true))
	m_name.text = m.name
	var lat = rad_to_deg(m.lat)
	var lon = rad_to_deg(m.lon)
	m_sub.text = "작전 구역 #%04X   ·   %d°%s %d°%s" % [m.seed % 0xffff, absi(roundi(lat)), "N" if lat >= 0 else "S", absi(roundi(lon)), "E" if lon >= 0 else "W"]
	m_reward.text = "%d+" % reward_of(m)
	m_idx.text = "%d/%d" % [sel + 1, Save.d.missions.size()]


## 저장된 작전 지점 정리 (JSON에서 읽으면 숫자가 float가 된다)
func _ensure_missions() -> void:
	if not Save.d.has("missions") or not (Save.d.missions is Array):
		Save.d.missions = []
	var ms: Array = []
	for m in Save.d.missions:
		if m is Dictionary and m.has("lat"):
			ms.append({lat = float(m.lat), lon = float(m.lon), biome = int(m.biome), diff = int(m.diff), seed = int(m.seed), name = str(m.name)})
	var changed = ms.size() != Save.d.missions.size()
	while ms.size() < MISSION_N:
		var nm = Globe.gen_mission(ms)
		if nm.is_empty():
			break
		ms.append(nm)
		changed = true
	Save.d.missions = ms
	if changed:
		Save.persist()


## 임무 성공: 해당 지점을 해방하고 새 지점을 만든다
func complete_current() -> void:
	_ensure_missions()
	Save.d.missions.remove_at(clampi(sel, 0, Save.d.missions.size() - 1))
	_ensure_missions()
	sel = mini(sel, Save.d.missions.size() - 1)


func _set_aim(v: String) -> void:
	Save.d.aim = v
	Save.persist()
	refresh()


## ---------- 지원요청 탭 ----------
func _strat_tab() -> Control:
	var r = _scroll_tab()
	var v: VBoxContainer = r[1]
	v.add_child(_section("장착 중", "3개까지. 눌러서 교체하거나 해제"))
	eq_row = HBoxContainer.new()
	eq_row.add_theme_constant_override("separation", 10)
	v.add_child(eq_row)
	var h = _section("지원요청", "")
	own_lb = h.get_child(2) as Label
	v.add_child(h)
	grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	return r[0]


func _weap_tab() -> Control:
	var r = _scroll_tab()
	var v: VBoxContainer = r[1]
	v.add_child(_section("주무기", "사거리 안 가장 가까운 적을 자동 조준해 사격한다"))
	wlist = VBoxContainer.new()
	wlist.add_theme_constant_override("separation", 16)
	v.add_child(wlist)
	return r[0]


## 지원요청 타일 (버튼). sub: 부호 또는 가격
func _tile(s: Dictionary, h := 150.0, show_eq := true) -> Button:
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
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var nm = UI.label(s.name, 22 if h < 120 else 24, UI.TEXT if own else UI.MUTE, true)
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
		tp.position = Vector2(8, 10)
		b.add_child(tp)
	if not own:
		b.modulate = Color(0.72, 0.75, 0.8)
	b.pressed.connect(func(): open_sheet(s.id))
	return b


func _empty_slot(h := 150.0) -> Control:
	var p = PanelContainer.new()
	p.custom_minimum_size = Vector2(0, h)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", UI.box(Color(0.05, 0.08, 0.12, 0.6), UI.LINE, 2, 0, UI.GOLD, 8))
	var l = UI.label("+ 비어 있음", 20, UI.MUTE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


func refresh() -> void:
	_ensure_missions()
	sel = clampi(sel, 0, Save.d.missions.size() - 1)
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
	var wi = Icon.new().setup("gun", UI.BLUE, 40)
	wi.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wv.add_child(wi)
	var wl = UI.label(w.name, 20, UI.TEXT, true)
	wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wv.add_child(wl)
	wb.add_child(wv)
	wb.pressed.connect(func(): tab("weap"))
	loadout.add_child(wb)
	for i in 3:
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
	for i in 3:
		if i < Save.d.eq.size():
			eq_row.add_child(_tile(Data.strat(Save.d.eq[i]), 120, false))
		else:
			eq_row.add_child(_empty_slot(120))
	own_lb.text = "%d / %d 보유" % [Save.d.own.size(), Data.STRATS.size()]
	for c in grid.get_children():
		c.queue_free()
	for s in Data.STRATS:
		grid.add_child(_tile(s))
	for c in wlist.get_children():
		c.queue_free()
	for wd in Data.WEAPONS:
		wlist.add_child(_wcard(wd))


func _wcard(w: Dictionary) -> Button:
	var on: bool = Save.d.w == w.id
	var b = Button.new()
	b.custom_minimum_size = Vector2(0, 240)
	var st = UI.card(Color("#16304a") if on else UI.PANEL2, UI.GOLD if on else UI.LINE, 18, 22)
	if on:
		st.border_width_left = 8
	for k in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(k, st)
	var v = VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 28; v.offset_top = 18; v.offset_right = -22; v.offset_bottom = -18
	v.add_theme_constant_override("separation", 7)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var hh = HBoxContainer.new()
	hh.add_theme_constant_override("separation", 12)
	hh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hh.add_child(Icon.new().setup("gun", UI.GOLD if on else UI.BLUE, 44))
	var nl = UI.label(w.name, 32, UI.GOLD if on else UI.TEXT, true)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hh.add_child(nl)
	if on:
		hh.add_child(_tag("장착 중", UI.GOLD, true))
	v.add_child(hh)
	v.add_child(UI.label(w.desc, 20, Color("#c4cfdd")))
	for row in [["화력", w.dmg * w.pellets * w.rate / 1.3], ["사거리", w.range / 4.0], ["탄창", w.mag * 1.1]]:
		var h = HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l = UI.label(row[0], 18, UI.MUTE)
		l.custom_minimum_size = Vector2(80, 0)
		h.add_child(l)
		var bg = Panel.new()
		bg.add_theme_stylebox_override("panel", UI.pill(Color("#07101c"), Color(1, 1, 1, 0.05), 0, 0))
		bg.custom_minimum_size = Vector2(0, 14)
		bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fill = Panel.new()
		fill.add_theme_stylebox_override("panel", UI.pill(UI.GOLD if on else UI.BLUE, Color(0, 0, 0, 0), 0, 0))
		fill.anchor_bottom = 1.0
		fill.anchor_right = minf(1.0, row[1] / 100.0)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(fill)
		h.add_child(bg)
		v.add_child(h)
	for e in Data.EVOS:
		if e.get("w", "") == w.id:
			var need = []
			for k in e.need:
				need.append("%s Lv%d" % [Data.up_name(k), e.need[k]])
			v.add_child(UI.label("진화  " + " + ".join(need) + "  →  " + e.n, 18, UI.GOLD))
	b.pressed.connect(func():
		Save.d.w = w.id
		Save.persist()
		Synth.beep(740, 0.06, "sine", 0.05)
		refresh())
	return b


func open_sheet(id: String) -> void:
	var s: Dictionary = Data.strat(id)
	var own: bool = Save.d.own.has(id)
	var eq: bool = Save.d.eq.has(id)
	for c in sheet_box.get_children():
		c.queue_free()
	var hd = HBoxContainer.new()
	hd.add_theme_constant_override("separation", 16)
	var v = VBoxContainer.new()
	v.add_child(_tag(Data.RAR[s.rar], Data.RAR_COL[s.rar]))
	v.add_child(UI.label(s.name, 42, UI.TEXT, true))
	hd.add_child(v)
	sheet_box.add_child(hd)
	var desc = UI.label(s.desc, 24, Color("#cbd5e2"))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sheet_box.add_child(desc)
	sheet_box.add_child(_kv("호출 부호", Glyph.new().setup(s.code, s.code.length(), 18)))
	sheet_box.add_child(_kv("재사용 대기", UI.label("%d초" % s.cd, 24, UI.TEXT)))
	sheet_box.add_child(_kv("수동 조준 방식", UI.label(Data.AIMN.get(s.aim, "즉시 발동"), 24, UI.TEXT)))
	if not own and Save.d.gold < s.price:
		var l = UI.label("골드가 %d 부족합니다. 임무를 완수해 모으세요." % (s.price - Save.d.gold), 22, UI.RED)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sheet_box.add_child(l)
	var row = HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 12)
	row.add_theme_constant_override("v_separation", 14)
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	sheet_box.add_child(row)
	if not own:
		var b = UI.gold_button("◆ %d 해금" % s.price, 32)
		b.custom_minimum_size = Vector2(260, 84)
		b.disabled = Save.d.gold < s.price
		b.pressed.connect(func():
			Save.d.gold -= s.price
			Save.d.own.append(id)
			if Save.d.eq.size() < 3:
				Save.d.eq.append(id)
			Save.persist()
			Synth.beep(660, 0.1); Synth.beep(990, 0.25, "square", 0.05, 0.0, 0.1)
			toast(s.name + " 해금 완료")
			refresh()
			open_sheet(id))
		row.add_child(b)
	elif eq:
		var b = UI.color_button("장착 해제", 28, Color("#7a3a36"))
		b.custom_minimum_size = Vector2(220, 80)
		b.pressed.connect(func():
			Save.d.eq.erase(id)
			_done())
		row.add_child(b)
	elif Save.d.eq.size() < 3:
		var b = UI.gold_button("장착", 32)
		b.custom_minimum_size = Vector2(220, 84)
		b.pressed.connect(func():
			Save.d.eq.append(id)
			_done())
		row.add_child(b)
	else:
		for i in Save.d.eq.size():
			var b = UI.color_button(Data.strat(Save.d.eq[i]).name + "와 교체", 22, Color("#1f6fb0"))
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
	p.add_theme_stylebox_override("panel", UI.box(Color("#0a1322"), Color("#22344d"), 2, 0, UI.GOLD, 14))
	var h = HBoxContainer.new()
	var l = UI.label(k, 22, UI.MUTE)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(val)
	p.add_child(h)
	return p
