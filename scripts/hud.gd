extends Control
## 전투 HUD. 게임 상태를 매 프레임 읽어 직접 그리고, 전건·취소 입력을 게임에 넘긴다.
## 배치(기준 720 x 1280): 위 = 계급·체력·증원·일시정지 / 상태·목표 칩, 오른쪽 위 = 미니맵,
## 왼쪽 아래 = 지원요청 카드·전건, 오른쪽 아래 = 탄약

const UI := preload("res://scripts/ui.gd")
const Glyph := preload("res://scripts/glyph.gd")
const Icon := preload("res://scripts/icon.gd")
const Data := preload("res://scripts/data.gd")

signal pause_pressed

const GLASS := Color(0.053, 0.062, 0.070, 0.84)
const GLASS_LINE := Color(1, 1, 1, 0.14)
const RAR_C := [Color("#a8b2bf"), Color("#97d0f2"), Color("#d0b4f2"), Color("#ed9214")]
const OBJ_NAME := {cap = "통신탑", nest = "부대", term = "단말기", aa = "방공포"}
const CARD_W := 304.0
const CARD_H := 62.0
const CARD_GAP := 8.0

var game: Node3D
var overlay: Control
var top: Control
var cards: Control
var key: Control
var buf_glyph
var cancel_btn: Button
var pause_btn: Button
var banner_box: PanelContainer
var banner_lb: Label
var banner_t := 0.0
var aim_box: PanelContainer
var aim_hint: Label
var card_nodes: Array = []
var key_touch := -1
var err_t := 0.0
var hp_ghost := 1.0
var hp_last := 1.0
var hp_pulse := 0.0
## 탄약 칸 (누르면 재장전). 화면 좌표
var ammo_rect := Rect2()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	## 화면 가장자리 정리: 비네트 + 위·아래 그라디언트 (HUD 글자가 3D 위에서 읽히도록)
	var vg = TextureRect.new()
	vg.texture = UI.vignette(0.55)
	vg.stretch_mode = TextureRect.STRETCH_SCALE
	vg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vg)
	var ts = TextureRect.new()
	ts.texture = UI.vgrad(Color(0.027, 0.031, 0.035, 0.62), Color(0.027, 0.031, 0.035, 0.0))
	ts.stretch_mode = TextureRect.STRETCH_SCALE
	ts.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	ts.offset_bottom = 210
	ts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ts)
	var bs = TextureRect.new()
	bs.texture = UI.vgrad(Color(0.027, 0.031, 0.035, 0.0), Color(0.027, 0.031, 0.035, 0.6))
	bs.stretch_mode = TextureRect.STRETCH_SCALE
	bs.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bs.offset_top = -380
	bs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bs)
	overlay = _canvas(_draw_overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	## 상단
	top = _canvas(_draw_top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16; top.offset_right = -16; top.offset_top = 16; top.offset_bottom = 132
	pause_btn = Button.new()
	pause_btn.custom_minimum_size = Vector2(64, 64)
	var pn = UI.rbox(GLASS, 32, GLASS_LINE, 2)
	for k in ["normal", "hover", "focus"]:
		pause_btn.add_theme_stylebox_override(k, pn)
	pause_btn.add_theme_stylebox_override("pressed", UI.rbox(Color(0.139, 0.160, 0.183, 0.95), 32, UI.GOLD, 2))
	pause_btn.anchor_left = 1.0; pause_btn.anchor_right = 1.0
	pause_btn.offset_left = -80; pause_btn.offset_right = -16; pause_btn.offset_top = 16; pause_btn.offset_bottom = 80
	var pi = Icon.new().setup("pause", UI.TEXT, 30)
	pi.position = Vector2(17, 17)
	pi.size = Vector2(30, 30)
	pause_btn.add_child(pi)
	pause_btn.pressed.connect(func(): pause_pressed.emit())
	add_child(pause_btn)
	## 배너·조준 안내 (어두운 알약 위에 글자)
	var r = _notice(300, 32, UI.GOLD, Color(0.048, 0.055, 0.063, 0.82), Color(1, 0.77, 0.19, 0.55))
	banner_box = r[0]
	banner_lb = r[1]
	r = _notice(196, 24, UI.TEXT, Color(0.096, 0.111, 0.126, 0.86), Color(0.25, 0.71, 1.0, 0.6))
	aim_box = r[0]
	aim_hint = r[1]
	## 왼쪽 아래: 지원요청 카드 + 전건 + 입력 표시/취소
	cards = _canvas(_draw_cards)
	cards.anchor_top = 1.0; cards.anchor_bottom = 1.0
	cards.offset_left = 16; cards.offset_right = 16 + CARD_W
	cards.offset_top = -212 - (CARD_H + CARD_GAP) * 5; cards.offset_bottom = -212
	key = _canvas(_draw_key)
	key.anchor_top = 1.0; key.anchor_bottom = 1.0
	key.offset_left = 16; key.offset_right = 192; key.offset_top = -196; key.offset_bottom = -20
	buf_glyph = Glyph.new().setup("", 0, 16)
	buf_glyph.anchor_top = 1.0; buf_glyph.anchor_bottom = 1.0
	buf_glyph.position = Vector2(206, 0)
	buf_glyph.offset_top = -176; buf_glyph.offset_bottom = -150
	add_child(buf_glyph)
	cancel_btn = UI.dark_button("취소", 24, Color("#8a463d"))
	cancel_btn.add_theme_color_override("font_color", Color("#ffbeb3"))
	cancel_btn.anchor_top = 1.0; cancel_btn.anchor_bottom = 1.0
	cancel_btn.offset_left = 206; cancel_btn.offset_right = 322; cancel_btn.offset_top = -92; cancel_btn.offset_bottom = -32
	cancel_btn.button_down.connect(func(): game.cancel_morse())
	add_child(cancel_btn)


func _canvas(fn: Callable) -> Control:
	var c = Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(fn)
	add_child(c)
	return c


## 화면 가운데 정렬된 안내 상자. [상자, 라벨]
func _notice(y: float, fs: int, col: Color, bg: Color, line: Color) -> Array:
	var cc = CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	cc.offset_top = y
	cc.offset_bottom = y + 90
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cc)
	var pc = PanelContainer.new()
	var sb = UI.pill(bg, line, 26, 10)
	sb.set_corner_radius_all(UI.RMAX)
	pc.add_theme_stylebox_override("panel", sb)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.visible = false
	cc.add_child(pc)
	var lb = UI.label("", fs, col, true, 6)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pc.add_child(lb)
	return [pc, lb]


## 전투 시작 시 지원요청 카드 구성
func build() -> void:
	card_nodes.clear()
	for s in game.strats:
		card_nodes.append({s = s, pop = 0.0, was = 0.0})
	hp_ghost = 1.0
	hp_last = 1.0


func banner(t: String) -> void:
	## 긴 문장은 두 줄로 (알약 폭이 화면을 넘지 않게)
	var f = UI.font(true)
	if f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x > 620:
		var cut = t.find("! ")
		if cut < 0:
			cut = t.find(". ")
		if cut < 0:
			cut = t.find(" · ")
		if cut < 0:
			cut = t.find(" ", t.length() / 2) - 1
		if cut > 0:
			t = t.substr(0, cut + 1).strip_edges() + "\n" + t.substr(cut + 1).strip_edges()
	banner_lb.text = t
	banner_t = 2.6


func morse_error() -> void:
	err_t = 0.3


## 화면 좌표가 HUD의 조작 부위 위인지 (게임 쪽 조이스틱이 무시하도록)
func blocks(pos: Vector2) -> bool:
	var rects = [key.get_global_rect(), cancel_btn.get_global_rect(), pause_btn.get_global_rect(), ammo_rect]
	for r in rects:
		if r.grow(10).has_point(pos):
			return true
	return false


## 전건: 터치(마우스는 터치로 에뮬레이트됨)를 직접 처리해 멀티터치에서도 이동과 동시에 누를 수 있게 한다
func _input(ev: InputEvent) -> void:
	if not visible or game == null or not game.active:
		return
	if ev is InputEventScreenTouch:
		if ev.pressed and ammo_rect.grow(8).has_point(ev.position):
			game.reload_now()
			get_viewport().set_input_as_handled()
			return
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
	var hpk = clampf(p.hp / p.maxhp, 0, 1)
	if hpk < hp_last - 0.001:
		hp_pulse = 0.35
	hp_last = hpk
	hp_pulse = maxf(0.0, hp_pulse - dt)
	hp_ghost = hpk if hpk > hp_ghost else maxf(hpk, hp_ghost - dt * 0.35)
	var b: String = game.M.buf
	for cn in card_nodes:
		var s: Dictionary = cn.s
		if cn.was > 0.0 and s.t <= 0.0:
			cn.pop = 0.5
		cn.was = s.t
		cn.pop = maxf(0.0, cn.pop - dt)
	err_t -= dt
	if err_t > 0:
		buf_glyph.col_on = UI.RED
		buf_glyph.set_code("--", 2)
	else:
		buf_glyph.col_on = UI.GOLD
		buf_glyph.set_code(b, b.length())
	var off: bool = b == "" and game.M.queue == null and game.M.pend == null and game.aim == null
	cancel_btn.modulate.a = 0.4 if off else 1.0
	if game.aim != null:
		var s: Dictionary = game.aim.s
		aim_hint.text = s.name + "\n" + ("터치한 곳에서 원하는 방향으로 슬라이드" if s.aim == "line" else "투하할 곳을 터치하고 떼세요")
		aim_box.visible = true
	else:
		aim_box.visible = false
	if banner_t > 0:
		banner_t -= dt
	banner_box.visible = banner_t > 0 and banner_lb.text != ""
	banner_box.modulate.a = clampf(banner_t / 0.4, 0, 1)
	for c in [top, cards, key, overlay]:
		c.queue_redraw()


## ---------- 그리기 헬퍼 ----------
func _text(ci: CanvasItem, pos: Vector2, t: String, fs: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0, outline := 0, bold := true) -> void:
	var f = UI.font(bold)
	if outline > 0:
		ci.draw_string_outline(f, pos, t, align, w, fs, outline, Color(0.021, 0.025, 0.028, 0.9 * col.a))
	ci.draw_string(f, pos, t, align, w, fs, col)


func _tw(t: String, fs: int) -> float:
	return UI.font(true).get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


## 둥근 막대 (배경 + 채움 + 윗면 광택)
func _gauge(ci: CanvasItem, r: Rect2, k: float, col: Color, radius := 8) -> void:
	ci.draw_style_box(UI.rbox(Color(0.037, 0.043, 0.049, 0.86), radius + 2, Color(1, 1, 1, 0.16), 2), r)
	var inner = r.grow(-4)
	if k > 0.0:
		var fr = Rect2(inner.position, Vector2(maxf(inner.size.y, inner.size.x * k), inner.size.y))
		ci.draw_style_box(UI.rbox(col, radius), fr)
		ci.draw_style_box(UI.rbox(Color(1, 1, 1, 0.22), radius), Rect2(fr.position + Vector2(2, 1), Vector2(fr.size.x - 4, fr.size.y * 0.42)))


## ---------- 상단: 계급 · 체력 · 경험치 · 증원 / 상태 · 목표 ----------
func _draw_top() -> void:
	if game == null or not game.active:
		return
	var p: Dictionary = game.p
	var W = top.size.x
	## 계급 배지
	var bc = Vector2(32, 32)
	top.draw_circle(bc + Vector2(0, 3), 32, Color(0, 0, 0, 0.4), true, -1.0, true)
	top.draw_circle(bc, 32, Color("#1f2429"), true, -1.0, true)
	top.draw_arc(bc, 30.5, 0, TAU, 48, UI.GOLD_D, 3, true)
	top.draw_arc(bc, 30.5, -PI / 2, -PI / 2 + TAU * clampf(float(p.xp) / p.next, 0, 1), 48, UI.GOLD, 3, true)
	_text(top, Vector2(0, 43), str(p.lvl), 30, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 64)
	## 체력
	var hx = 76.0
	var hw = W - hx - 64 - 10 - 92 - 10
	var hpk = clampf(p.hp / p.maxhp, 0, 1)
	var hr = Rect2(hx, 2, hw, 36)
	var hc = Color("#70d05e") if hpk > 0.6 else Color("#e18c16") if hpk > 0.3 else Color("#ff655a")
	if hpk <= 0.3:
		hc = hc.lerp(Color.WHITE, 0.25 * (0.5 + 0.5 * sin(game.rt * 10)))
	top.draw_style_box(UI.rbox(Color(0.037, 0.043, 0.049, 0.86), 12, Color(1, 1, 1, 0.16) if hp_pulse <= 0 else Color(1, 0.4, 0.3, 0.9), 2), hr)
	var inner = hr.grow(-4)
	if hp_ghost > hpk:
		top.draw_style_box(UI.rbox(Color(1, 0.92, 0.85, 0.7), 9), Rect2(inner.position, Vector2(maxf(inner.size.y, inner.size.x * hp_ghost), inner.size.y)))
	if hpk > 0:
		var fr = Rect2(inner.position, Vector2(maxf(inner.size.y, inner.size.x * hpk), inner.size.y))
		top.draw_style_box(UI.rbox(hc, 9), fr)
		top.draw_style_box(UI.rbox(Color(1, 1, 1, 0.25), 8), Rect2(fr.position + Vector2(2, 1), Vector2(fr.size.x - 4, fr.size.y * 0.42)))
	_text(top, Vector2(hx, 28), "%d / %d" % [maxi(0, ceili(p.hp)), p.maxhp], 20, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER, hw, 6)
	## 경험치
	_gauge(top, Rect2(hx, 44, hw, 16), clampf(float(p.xp) / p.next, 0, 1), UI.GOLD, 4)
	## 증원(남은 목숨)
	var lr = Rect2(hx + hw + 10, 8, 92, 48)
	top.draw_style_box(UI.rbox(GLASS, 24, GLASS_LINE, 2), lr)
	Icon.paint(top, "heart", Rect2(lr.position + Vector2(12, 11), Vector2(26, 26)), UI.RED if p.lives > 0 else UI.MUTE)
	_text(top, lr.position + Vector2(40, 34), str(p.lives), 28, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 44)
	## ----- 둘째 줄: 상태 + 목표 칩 -----
	var y = 74.0
	var h = 40.0
	var x = 0.0
	var st = "교전" if game.alertN > 0 else "수색" if game.susN > 0 else "은신"
	var stc = {"교전": [Color("#c23f35"), Color.WHITE, Color("#ff9c8e")], "수색": [Color("#806623"), Color("#fff2bc"), Color("#ed9c2b")], "은신": [Color(0.04, 0.1, 0.08, 0.86), Color("#b0e87d"), Color("#569a48")]}
	var sw = _tw(st, 21) + 52
	top.draw_style_box(UI.rbox(stc[st][0], 20, stc[st][2], 2), Rect2(x, y, sw, h))
	Icon.paint(top, "eye", Rect2(x + 12, y + 9, 22, 22), stc[st][1])
	_text(top, Vector2(x + 40, y + 28), st, 21, stc[st][1])
	x += sw + 8
	var terms_done = 0
	for o in game.map.objs:
		if o.type == "term" and o.done:
			terms_done += 1
	for o in game.map.objs:
		var main: bool = o.type == "term" or o.type == "boss"
		var known: bool = o.known or o.done
		var r = Rect2(x, y, 40, h)
		var jam: bool = not o.done and ((o.type == "aa" and game.in_aa()) or (o.type == "jam" and game.in_jam()))
		if o.type == "jam":
			jam = false
		var bg = Color(0.1, 0.3, 0.12, 0.9) if o.done else Color(0.55, 0.1, 0.08, 0.92) if jam and int(game.rt * 4) % 2 == 0 else GLASS
		var line = Color("#7ed365") if o.done else Color(1, 0.77, 0.19, 0.75) if main else GLASS_LINE
		top.draw_style_box(UI.rbox(bg, 12, line, 2), r)
		var ic = Color("#c0f0ac") if o.done else (UI.GOLD if main else UI.TEXT) if known else UI.MUTE
		Icon.paint(top, o.type if known else "unknown", r.grow(-8), ic)
		if o.done:
			top.draw_circle(r.end - Vector2(7, 7), 9, Color("#3f9a3b"), true, -1.0, true)
			Icon.paint(top, "check", Rect2(r.end - Vector2(14, 14), Vector2(14, 14)), Color.WHITE)
		x += 45
	## 탈출
	var es: String = game.ext.state
	var et = " %d" % ceili(game.ext.t) if es == "wait" else ""
	var ew = 40.0 + (_tw(et, 21) + 6 if et != "" else 0.0)
	var ebg = UI.GOLD if es == "call" else Color(0.1, 0.3, 0.12, 0.9) if es != "locked" else GLASS
	if es == "call":
		ebg = ebg.lerp(Color.WHITE, 0.3 * (0.5 + 0.5 * sin(game.rt * 6)))
	top.draw_style_box(UI.rbox(ebg, 12, Color("#7ed365") if es != "locked" and es != "call" else GLASS_LINE, 2), Rect2(x, y, ew, h))
	Icon.paint(top, "heli", Rect2(x + 7, y + 7, 26, 26), Color("#181205") if es == "call" else UI.TEXT if es != "locked" else UI.MUTE)
	if et != "":
		_text(top, Vector2(x + 32, y + 28), et, 21, UI.TEXT)
	## 오른쪽: 시간 · 획득 골드
	var gt = str(game.gold_now())
	var gw = _tw(gt, 21) + 48
	var gx = W - gw
	top.draw_style_box(UI.rbox(GLASS, 20, Color(1, 0.77, 0.19, 0.45), 2), Rect2(gx, y, gw, h))
	Icon.paint(top, "gem", Rect2(gx + 12, y + 9, 22, 22), UI.GOLD)
	_text(top, Vector2(gx + 38, y + 28), gt, 21, UI.GOLD)
	var mm = "%d:%02d" % [int(game.t / 60), int(game.t) % 60]
	var tw2 = _tw("0:00", 21) + 28 + (12 if game.t >= 600 else 0)
	_text(top, Vector2(gx - 8 - tw2, y + 28), mm, 21, Color(0.88, 0.92, 0.97), HORIZONTAL_ALIGNMENT_RIGHT, tw2, 6)


## ---------- 지원요청 카드 ----------
func _draw_cards() -> void:
	if game == null or not game.active:
		return
	var b: String = game.M.buf
	var jam: bool = game.in_aa()
	var list: Array = []
	var cc = game.ctx_code()
	if cc != null:
		list.append({ctx = cc})
	for cn in card_nodes:
		list.append(cn)
	var y = cards.size.y - list.size() * (CARD_H + CARD_GAP) + CARD_GAP
	for it in list:
		var is_ctx: bool = it.has("ctx")
		var code: String = it.ctx.code if is_ctx else it.s.code
		var nm: String = it.ctx.name if is_ctx else it.s.name
		var col: Color = Color("#ff9400") if is_ctx else RAR_C[it.s.rar]
		var cd: float = 0.0 if is_ctx else it.s.t
		var blocked: bool = not is_ctx and (cd > 0 or jam)
		var hit: bool = b != "" and code.begins_with(b) and not blocked
		var dim: float = 0.5 if (b != "" and not hit) else 0.72 if blocked else 1.0
		var pop: float = 0.0 if is_ctx else it.pop / 0.5
		var r = Rect2(0, y, CARD_W, CARD_H)
		if hit:
			r = r.grow_individual(0, 0, 10, 0)
		## 그림자 + 바탕
		cards.draw_style_box(UI.rbox(Color(0, 0, 0, 0.35 * dim), 16), Rect2(r.position + Vector2(0, 4), r.size))
		var bg = Color(0.067, 0.077, 0.088, 0.9).lerp(col, 0.1 + 0.25 * pop)
		if is_ctx:
			bg = Color(0.2, 0.11, 0.04, 0.92)
		cards.draw_style_box(UI.rbox(Color(bg, bg.a * dim), 16, Color(UI.GOLD if hit else col, (1.0 if hit else 0.55) * dim), 3 if hit else 2), r)
		## 아이콘 타일
		var tr = Rect2(r.position + Vector2(7, 7), Vector2(48, 48))
		cards.draw_style_box(UI.rbox(Color(col.darkened(0.45), dim), 12, Color(col, 0.9 * dim), 2), tr)
		if blocked:
			cards.draw_style_box(UI.rbox(Color(0.021, 0.025, 0.028, 0.78), 12), tr)
			if cd > 0:
				var mx: float = maxf(0.1, game.comms_max(it.s))
				cards.draw_arc(tr.get_center(), 19, -PI / 2, -PI / 2 + TAU * (1.0 - clampf(cd / mx, 0, 1)), 32, Color(col, 0.9), 4, true)
				_text(cards, Vector2(tr.position.x, tr.position.y + 32), str(ceili(cd)), 22, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 48)
			else:
				_text(cards, Vector2(tr.position.x, tr.position.y + 30), "교란", 17, UI.RED, HORIZONTAL_ALIGNMENT_CENTER, 48)
		else:
			Icon.paint(cards, "radio" if is_ctx else it.s.id, tr.grow(-8), Color(1, 1, 1, dim))
		## 이름 + 부호
		_text(cards, r.position + Vector2(66, 26), nm, 20, Color(UI.TEXT, dim))
		Glyph.paint(cards, r.position + Vector2(66, 44), code, b.length() if hit else 0, 10.0, UI.GOLD, Color(1, 1, 1, 0.55 * dim))
		## 통신 드론 재사용 대기 (진화 후)
		if not is_ctx and game.comms != null:
			var dc: float = game.comms.cd.get(it.s.id, 0.0)
			var dk = 1.0 - clampf(dc / maxf(0.1, game.comms_max(it.s)), 0, 1)
			var dr = Rect2(r.end.x - 70, r.position.y + 12, 58, 6)
			Icon.paint(cards, "drone", Rect2(dr.position + Vector2(-22, -6), Vector2(18, 18)), Color("#a1d5e4"))
			cards.draw_style_box(UI.rbox(Color(0.037, 0.043, 0.049, 0.9), 3), dr)
			cards.draw_style_box(UI.rbox(Color("#a1d5e4") if dc <= 0 else Color("#5e8592"), 3), Rect2(dr.position, Vector2(maxf(6, dr.size.x * dk), 6)))
		if pop > 0:
			cards.draw_style_box(UI.rbox(Color(1, 1, 1, 0.35 * pop), 16), r)
		y += CARD_H + CARD_GAP


## ---------- 전건 ----------
func _draw_key() -> void:
	var c = key.size / 2
	var r = key.size.x / 2 - 12
	var down: bool = game != null and game.M.down
	var pr: float = game.key_progress() if game else 0.0
	var aim_mode: bool = game != null and game.aim != null
	var dash: bool = down and pr >= 1.0
	key.draw_circle(c + Vector2(0, 8), r + 8, Color(0, 0, 0, 0.45), true, -1.0, true)
	## 금속 테두리
	key.draw_circle(c, r + 8, Color("#101215"), true, -1.0, true)
	key.draw_arc(c, r + 6, 0, TAU, 64, UI.RED if aim_mode else Color("#373f48"), 4, true)
	key.draw_arc(c, r + 6, -PI * 0.95, -PI * 0.05, 32, Color(1, 1, 1, 0.22), 2, true)
	var body = Color("#242a30")
	var rim = Color("#384049")
	if aim_mode:
		body = Color("#3a242b"); rim = Color("#6a393f")
	elif dash:
		body = UI.GOLD; rim = Color("#ffecb1")
	elif down:
		body = Color("#667692"); rim = Color("#b5cdf2")
	var off = Vector2(0, 4 if down else 0)
	if not down:
		key.draw_circle(c + Vector2(0, 6), r, Color("#131619"), true, -1.0, true)
	key.draw_circle(c + off, r, rim, true, -1.0, true)
	key.draw_circle(c + off + Vector2(0, 2), r - 3, body, true, -1.0, true)
	key.draw_circle(c + off + Vector2(0, -r * 0.28), r * 0.62, Color(1, 1, 1, 0.05), true, -1.0, true)
	if down:
		key.draw_arc(c, r + 6, -PI / 2, -PI / 2 + TAU * pr, 64, UI.GOLD, 6, true)
	var col = Color("#271b09") if dash else UI.TEXT
	if aim_mode:
		Icon.paint(key, "x", Rect2(c + off - Vector2(26, 40), Vector2(52, 52)), Color("#ffbeb3"))
		_text(key, Vector2(0, c.y + 44) + off, "취소", 24, Color("#ffbeb3"), HORIZONTAL_ALIGNMENT_CENTER, key.size.x)
	else:
		## 점 / 선 표시
		Glyph.paint(key, c + off + Vector2(-27 if dash else -9, -14), "-" if dash else ".", 1, 18.0 if not dash else 21.6, col, col)
		_text(key, Vector2(0, c.y + 40) + off, "전건", 24, Color(col, 0.85), HORIZONTAL_ALIGNMENT_CENTER, key.size.x)


## ---------- 화면 밖 목표 화살표 · 미니맵 · 연속 처치 · 탄약 · 화면 효과 ----------
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
			var c = Color("#9fd1f2") if o.type == "cap" else UI.RED if game.is_dest(o) or o.type == "boss" else UI.GOLD
			tg.append([o.x, o.y, c, o.type])
	if game.ext.state != "locked":
		tg.append([game.ext.x, game.ext.y, Color("#7ed365"), "heli"])
	if game.rcall != null:
		tg.append([game.rcall.x, game.rcall.y, Color("#ff584a") if int(game.t * 6) % 2 == 0 else Color("#ffbcae"), "!"])
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
		var hw = vs.x / 2 - 48
		var hh = vs.y / 2 - 210
		var k = minf(hw / maxf(absf(cos(a)), 1e-4), hh / maxf(absf(sin(a)), 1e-4))
		var ap = ctr + Vector2(cos(a), sin(a)) * k + Vector2(0, 20)
		var d1 = Vector2(cos(a), sin(a))
		var n1 = Vector2(-d1.y, d1.x)
		overlay.draw_colored_polygon(PackedVector2Array([ap + d1 * 40, ap + d1 * 24 + n1 * 11, ap + d1 * 24 - n1 * 11]), q[2])
		overlay.draw_circle(ap + Vector2(0, 3), 23, Color(0, 0, 0, 0.4), true, -1.0, true)
		overlay.draw_circle(ap, 23, Color(0.053, 0.062, 0.070, 0.94), true, -1.0, true)
		overlay.draw_arc(ap, 21.5, 0, TAU, 40, q[2], 3, true)
		if q[3] == "!":
			overlay.draw_string(f, ap + Vector2(-20, 10), "!", HORIZONTAL_ALIGNMENT_CENTER, 40, 28, q[2])
		else:
			Icon.paint(overlay, q[3], Rect2(ap - Vector2(13, 13), Vector2(26, 26)), q[2])
		var dm = roundi(Vector2(q[0] - p.x, q[1] - p.y).length() / 10)
		_text(overlay, ap + Vector2(-40, 46), "%dm" % dm, 18, UI.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 80, 6)
	## 미니맵
	var ms = 132.0
	var mp = Vector2(vs.x - ms - 22, 146)
	var W: float = game.WORLD
	overlay.draw_style_box(UI.rbox(Color(0, 0, 0, 0.35), 16), Rect2(mp - Vector2(6, 2), Vector2(ms + 12, ms + 12)))
	overlay.draw_style_box(UI.rbox(Color(0.053, 0.062, 0.070, 0.92), 16, Color(1, 1, 1, 0.2), 2), Rect2(mp - Vector2(6, 6), Vector2(ms + 12, ms + 12)))
	overlay.draw_style_box(UI.rbox(Color(game.map.biome.g[1]).darkened(0.42), 10), Rect2(mp, Vector2(ms, ms)))
	var rc = Color(Color(game.map.biome.road).lightened(0.12), 0.9)
	for rd in game.map.roads:
		if rd.v:
			overlay.draw_rect(Rect2(mp + Vector2(rd.p / W * ms - 1.5, 3), Vector2(3, ms - 6)), rc)
		else:
			overlay.draw_rect(Rect2(mp + Vector2(3, rd.p / W * ms - 1.5), Vector2(ms - 6, 3)), rc)
	var jammed: bool = game.in_jam()
	if game.intel or game.radar or game.satT > 0:
		for e in game.en:
			if game.intel or game.satT > 0 or Vector2(e.x - p.x, e.y - p.y).length() < 560:
				overlay.draw_rect(Rect2(mp + Vector2(e.x, e.y) / W * ms - Vector2(1.5, 1.5), Vector2(3, 3)), Color(1, 0.3, 0.22, 0.9))
	if game.rcall != null and int(game.t * 4) % 2 == 0:
		overlay.draw_circle(mp + Vector2(game.rcall.x, game.rcall.y) / W * ms, 6, Color("#ff584a"))
	for q in tg:
		if q[3] == "!":
			continue
		var mq = mp + Vector2(q[0], q[1]) / W * ms
		overlay.draw_circle(mq, 6.5, Color(0.027, 0.031, 0.035, 0.9), true, -1.0, true)
		overlay.draw_circle(mq, 4.5, q[2], true, -1.0, true)
	## 진행 중인 원격 지원 표시 (미니맵 왼쪽. 아래쪽은 배너 자리라 비워 둔다)
	var sy0 = mp.y + 10
	for q in [["sniper", game.snipe.t if game.snipe != null else 0.0, 15.0], ["emp", game.empT, 20.0], ["sat", game.satT, 30.0]]:
		if q[1] <= 0:
			continue
		var sr = Rect2(mp.x - 22 - 150, sy0 - 16, 150, 28)
		overlay.draw_style_box(UI.rbox(GLASS, 5, GLASS_LINE, 2), sr)
		overlay.draw_style_box(UI.rbox(Color(UI.GOLD, 0.28), 3), Rect2(sr.position + Vector2(3, 3), Vector2((sr.size.x - 6) * clampf(q[1] / q[2], 0, 1), sr.size.y - 6)))
		Icon.paint(overlay, q[0], Rect2(sr.position + Vector2(8, 4), Vector2(20, 20)), UI.GOLD)
		_text(overlay, sr.position + Vector2(34, 21), "%s %d초" % [Data.strat(q[0]).name, ceili(q[1])], 17, UI.TEXT)
		sy0 += 32
	## 플레이어: 진행 방향 화살촉
	var pp = mp + Vector2(p.x, p.y) / W * ms
	var pa: float = p.face
	var pd = Vector2(cos(pa), sin(pa))
	var pn = Vector2(-pd.y, pd.x)
	overlay.draw_colored_polygon(PackedVector2Array([pp + pd * 9, pp - pd * 6 + pn * 6.5, pp - pd * 2.5, pp - pd * 6 - pn * 6.5]), Color.WHITE)
	if jammed:
		## 교란: 지도를 잡음으로 덮는다
		overlay.draw_style_box(UI.rbox(Color(0.053, 0.062, 0.070, 0.94), 10), Rect2(mp, Vector2(ms, ms)))
		var sd = int(game.rt * 14)
		for i in 46:
			var hx = fposmod(sin(i * 12.9898 + sd * 78.233) * 43758.5453, 1.0)
			var hy = fposmod(sin(i * 39.346 + sd * 11.135) * 24634.6345, 1.0)
			overlay.draw_rect(Rect2(mp + Vector2(hx * (ms - 22), hy * (ms - 4)), Vector2(6 + hx * 16, 2)), Color(0.75, 0.5, 1.0, 0.25 + 0.5 * hy))
		_text(overlay, mp + Vector2(0, ms / 2 + 9), "신호 교란", 22, Color("#dfb5ff"), HORIZONTAL_ALIGNMENT_CENTER, ms, 6)
	## 보스 체력 (칩 아래 왼쪽)
	var by0 = 0.0
	if game.boss != null and game.boss.hp > 0:
		var bk: float = clampf(game.boss.hp / game.boss.maxhp, 0, 1)
		var br = Rect2(16, 162, vs.x - 16 - (ms + 22 + 12 + 166), 24)
		_text(overlay, Vector2(18, 156), game.boss.T.n, 19, UI.RED if game.boss.awake else UI.MUTE, HORIZONTAL_ALIGNMENT_LEFT, -1, 6)
		_gauge(overlay, br, bk, Color("#d8402e") if game.boss.awake else Color("#7a4a44"), 6)
		for q in [0.75, 0.5, 0.25]:
			overlay.draw_rect(Rect2(br.position.x + br.size.x * q - 1, br.position.y + 4, 2, br.size.y - 8), Color(0, 0, 0, 0.5))
		by0 = 54.0
	## 연속 처치 (왼쪽 위, 칩 아래)
	if game.combo >= 5:
		var col = UI.RED if game.combo >= 100 else Color("#ed8a00") if game.combo >= 50 else UI.GOLD
		var cp = Vector2(20, 196 + by0)
		var ct = "x%d" % game.combo
		var ck: float = clampf(game.comboT / 2.6, 0, 1)
		_text(overlay, cp, ct, 46, col, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		_text(overlay, cp + Vector2(_tw(ct, 46) + 10, -4), "연속 처치", 19, UI.TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, 6)
		overlay.draw_style_box(UI.rbox(Color(0.037, 0.043, 0.049, 0.86), 4), Rect2(cp + Vector2(0, 12), Vector2(150, 8)))
		overlay.draw_style_box(UI.rbox(col, 4), Rect2(cp + Vector2(0, 12), Vector2(maxf(8, 150 * ck), 8)))
	## 탄약 (오른쪽 아래)
	var ar = Rect2(vs.x - 206, vs.y - 92, 190, 64)
	ammo_rect = Rect2(overlay.global_position + ar.position, ar.size)
	overlay.draw_style_box(UI.rbox(Color(0, 0, 0, 0.35), 20), Rect2(ar.position + Vector2(0, 4), ar.size))
	overlay.draw_style_box(UI.rbox(GLASS, 20, GLASS_LINE, 2), ar)
	var reloading: bool = p.reload > 0 and not p.evo.has("lmg")
	if reloading:
		var rk: float = 1.0 - clampf(p.reload / maxf(0.01, p.w.reload * p.m.rl), 0, 1)
		overlay.draw_style_box(UI.rbox(Color(1, 0.77, 0.19, 0.3), 16), Rect2(ar.position + Vector2(4, 4), Vector2(maxf(32, (ar.size.x - 8) * rk), ar.size.y - 8)))
	var low: bool = not reloading and not p.evo.has("lmg") and p.ammo <= maxi(1, int(game.mag_size() * 0.2))
	Icon.paint(overlay, "bullet", Rect2(ar.position + Vector2(10, 12), Vector2(40, 40)), UI.GOLD if not low else UI.RED)
	var mounted: bool = p.get("mount") != null
	if mounted:
		reloading = false
	var at = "∞" if p.evo.has("lmg") or mounted else "재장전" if reloading else str(p.ammo)
	if reloading or p.evo.has("lmg") or mounted:
		_text(overlay, ar.position + Vector2(50, 43), at, 28, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 130)
	else:
		var mt = " / %d" % game.mag_size()
		var aw = _tw(at, 36)
		var tot = aw + _tw(mt, 22)
		var ax = ar.position.x + 50 + (130 - tot) / 2
		_text(overlay, Vector2(ax, ar.position.y + 46), at, 36, UI.RED if low else UI.TEXT)
		_text(overlay, Vector2(ax + aw, ar.position.y + 44), mt, 22, UI.MUTE)
	_text(overlay, Vector2(ar.position.x, ar.position.y - 10), "거치 기관총" if p.get("mount") != null else p.w.name, 17, Color(0.85, 0.9, 0.96, 0.85), HORIZONTAL_ALIGNMENT_RIGHT, ar.size.x - 6, 5)
	## 조이스틱
	var j: Dictionary = game.joy
	if j.id != -1:
		overlay.draw_circle(Vector2(j.ox, j.oy), 92, Color(0.064, 0.074, 0.084, 0.28), true, -1.0, true)
		overlay.draw_arc(Vector2(j.ox, j.oy), 92, 0, TAU, 48, Color(1, 1, 1, 0.4), 3, true)
		overlay.draw_circle(Vector2(j.x, j.y), 40, Color(1, 0.77, 0.19, 0.35), true, -1.0, true)
		overlay.draw_arc(Vector2(j.x, j.y), 40, 0, TAU, 32, UI.GOLD, 3, true)
	## 화면 효과: 피격·섬광·조준 중
	if game.aim != null:
		overlay.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.107, 0.123, 0.140, 0.22))
	if p.hurtT > 0:
		overlay.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.8, 0.08, 0.04, p.hurtT * 1.1))
	if p.hp / p.maxhp <= 0.3 and p.hp > 0:
		## 빈사: 가장자리가 붉게 맥동
		overlay.draw_texture_rect(UI.vignette(0.42), Rect2(Vector2.ZERO, vs), false, Color(1, 0.1, 0.05, 0.55 + 0.35 * sin(game.rt * 5)))
	if game.sirenT > 0:
		## 경보: 가장자리가 사이렌 박자에 맞춰 붉게 번쩍인다
		overlay.draw_texture_rect(UI.vignette(0.42), Rect2(Vector2.ZERO, vs), false, Color(1, 0.12, 0.06, (0.35 + 0.45 * absf(sin(game.rt * 2.85))) * minf(1.0, game.sirenT)))
	if game.flash > 0:
		overlay.draw_rect(Rect2(Vector2.ZERO, vs), Color(1, 0.98, 0.92, minf(0.8, game.flash * 1.6)))
	## 진화 알림: 무기 이름 띠 (게임은 멈추지 않는다)
	if game.evoT > 0:
		var el: float = game.EVO_DUR - game.evoT
		var al: float = clampf(game.evoT / 0.3, 0, 1)
		var c: Color = game.evo_col
		var pop: float = 1.0 + 0.6 * maxf(0.0, 1.0 - el / 0.18)
		var cy = vs.y * 0.3
		var band = Rect2(0, cy - 66, vs.x, 112)
		overlay.draw_rect(band, Color(0.027, 0.031, 0.035, 0.72 * al))
		overlay.draw_rect(Rect2(0, band.position.y, vs.x, 3), Color(c, al))
		overlay.draw_rect(Rect2(0, band.end.y - 3, vs.x, 3), Color(c, al))
		var s1 = roundi(22 * pop)
		var s2 = roundi(50 * pop)
		_text(overlay, Vector2(0, cy - 32), "무기 진화", s1, Color(1, 1, 1, al), HORIZONTAL_ALIGNMENT_CENTER, vs.x, 6)
		_text(overlay, Vector2(0, cy + 36), game.evo_name, s2, Color(c, al), HORIZONTAL_ALIGNMENT_CENTER, vs.x, 12)
