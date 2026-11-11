extends RefCounted
## UI 공통: 테마·스타일박스·라벨/버튼 생성 헬퍼. 기준 해상도 720 x 1280 (세로)
## 택티컬 슈터 톤: 모서리를 딴 패널, 비스듬한 버튼, 모서리 브래킷, 검은 강철 바탕 + 주황 강조

## 팔레트: 검은 강철 바탕 + 주황빛 강조색 (식별자 GOLD는 "강조색"이라는 뜻으로 그대로 쓴다)
const GOLD := Color("#ffa524")
const GOLD_D := Color("#b86a00")
const INK := Color("#07090b")
const PANEL := Color("#12161a")
const PANEL2 := Color("#1a2026")
const LINE := Color("#36414b")
const TEXT := Color("#f2f4f6")
const MUTE := Color("#8893a0")
const RED := Color("#ff5140")
const GREEN := Color("#86d94f")
const BLUE := Color("#52c7ee")
const R := 5
const RMAX := 5
## 패널 모서리를 따 내는 크기 (왼쪽 위 · 오른쪽 아래)
const CUT := 12
## 버튼 기울기
const SKEW := 0.16

static var _font: Font
static var _font_b: Font
static var _tex := {}


## 번들 폰트(Pretendard). 없는 글리프(기호)와 가져오기 전 상태는 시스템 폰트로 받친다
static func font(bold := false) -> Font:
	if _font == null:
		var sys := SystemFont.new()
		sys.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR", "Noto Sans KR", "Apple SD Gothic Neo", "sans-serif"])
		var sys_b := SystemFont.new()
		sys_b.font_names = sys.font_names
		sys_b.font_weight = 800
		_font = _load_font("res://fonts/Pretendard-Medium.otf", sys)
		_font_b = _load_font("res://fonts/Pretendard-ExtraBold.otf", sys_b)
	return _font_b if bold else _font


static func _load_font(path: String, fallback: Font) -> Font:
	if ResourceLoader.exists(path):
		var f = load(path)
		if f is FontFile:
			f.fallbacks = [fallback]
			return f
	return fallback


## 세로 그라디언트 텍스처 (화면 위·아래 어둡게 깔기)
static func vgrad(top: Color, bottom: Color) -> GradientTexture2D:
	var key := "v" + top.to_html() + bottom.to_html()
	if not _tex.has(key):
		var g := Gradient.new()
		g.set_color(0, top)
		g.set_color(1, bottom)
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = 4
		t.height = 128
		t.fill_from = Vector2(0, 0)
		t.fill_to = Vector2(0, 1)
		_tex[key] = t
	return _tex[key]


## 가장자리가 어두워지는 비네트
static func vignette(strength := 0.42) -> GradientTexture2D:
	var key := "vg%.2f" % strength
	if not _tex.has(key):
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.021, 0.025, 0.028, strength)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = 128
		t.height = 128
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 1.0)
		_tex[key] = t
	return _tex[key]


## 모서리를 딴 상자 (왼쪽 위·오른쪽 아래를 45도로 잘라 낸다)
static func _chamfer(s: StyleBoxFlat, cut: int) -> void:
	s.set_corner_radius_all(0)
	s.corner_radius_top_left = cut
	s.corner_radius_bottom_right = cut
	s.corner_detail = 1
	s.anti_aliasing = true


## 그리기용 상자 (draw_style_box에 쓰는 캐시)
static var _sb := {}
static func rbox(bg: Color, radius := 12, border := Color(0, 0, 0, 0), bw := 0) -> StyleBoxFlat:
	var key := "%s|%d|%s|%d" % [bg.to_html(), radius, border.to_html(), bw]
	if not _sb.has(key):
		var s := StyleBoxFlat.new()
		s.bg_color = bg
		_chamfer(s, mini(radius, 8))
		s.border_color = border
		s.set_border_width_all(bw)
		_sb[key] = s
	return _sb[key]


static func make_theme() -> Theme:
	var th := Theme.new()
	th.default_font = font()
	th.default_font_size = 26
	th.set_color("font_color", "Label", TEXT)
	th.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	th.set_constant("outline_size", "Label", 0)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		th.set_stylebox(st, "Button", box(PANEL2 if st != "pressed" else PANEL, LINE, 1, 0))
	th.set_color("font_color", "Button", TEXT)
	th.set_color("font_hover_color", "Button", TEXT)
	th.set_color("font_pressed_color", "Button", GOLD)
	th.set_font("font", "Button", font(true))
	th.set_stylebox("panel", "PanelContainer", box(PANEL, LINE, 1, 0))
	th.set_stylebox("panel", "Panel", box(PANEL, LINE, 1, 0))
	## 얇은 스크롤바
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.18)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 3; sb.content_margin_right = 3
	th.set_stylebox("grabber", "VScrollBar", sb)
	th.set_stylebox("grabber_highlight", "VScrollBar", sb)
	th.set_stylebox("grabber_pressed", "VScrollBar", sb)
	th.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	return th


## 패널. top: 위쪽 색 띠 두께, left: 왼쪽 색 띠. radius가 10 이상이면 크게, 아니면 작게 모서리를 딴다 (0이면 안 딴다)
static func box(bg: Color, border := LINE, bw := 1, top := 0, top_col := GOLD, pad := 10, left := 0, left_col := GOLD, radius := R) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	_chamfer(s, 0 if radius == 0 else CUT if radius >= 10 else 6)
	s.content_margin_left = pad + left
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	if top > 0 or left > 0:
		s.border_color = top_col if top > 0 else left_col
		if top > 0:
			s.border_width_top = top
		if left > 0:
			s.border_width_left = left
	return s


## 그림자 진 카드 (큰 모서리 따기 + 얇은 테두리)
static func card(bg := PANEL2, border := LINE, pad := 18, radius := 22) -> StyleBoxFlat:
	var s := box(bg, border, 1, 0, GOLD, pad, 0, GOLD, radius)
	_chamfer(s, 16)
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 12
	s.shadow_offset = Vector2(0, 6)
	return s


static func label(text: String, size := 26, col := TEXT, bold := false, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if bold:
		l.add_theme_font_override("font", font(true))
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## 비스듬한 버튼: 평행사변형 면 + 아래쪽 굵은 띠 (눌리면 띠가 얇아지며 내려앉는다)
static func bevel(face: Color, edge: Color, _hi: Color, pressed := false, pad := 18, _radius := R) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = face.darkened(0.12) if pressed else face
	s.skew = Vector2(SKEW, 0)
	s.set_corner_radius_all(0)
	s.anti_aliasing = true
	s.border_color = edge
	s.set_border_width_all(0)
	s.border_width_bottom = 2 if pressed else 5
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 0 if pressed else 6
	s.shadow_offset = Vector2(0, 3)
	s.content_margin_left = pad + 6
	s.content_margin_right = pad + 6
	s.content_margin_top = pad + (2 if pressed else 0)
	s.content_margin_bottom = pad - (2 if pressed else 0)
	return s


static func _styled(b: Button, face: Color, edge: Color, hi: Color, txt: Color, pad := 18) -> Button:
	b.add_theme_color_override("font_color", txt)
	b.add_theme_color_override("font_hover_color", txt)
	b.add_theme_color_override("font_pressed_color", txt)
	b.add_theme_color_override("font_focus_color", txt)
	b.add_theme_color_override("font_disabled_color", Color(txt, 0.5))
	b.add_theme_stylebox_override("normal", bevel(face, edge, hi, false, pad))
	b.add_theme_stylebox_override("hover", bevel(face.lightened(0.06), edge, hi, false, pad))
	b.add_theme_stylebox_override("pressed", bevel(face, edge, hi, true, pad))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("disabled", bevel(Color("#2c333a"), Color("#181c20"), Color("#353d45"), false, pad))
	return b


## 금색 주 버튼 (출격·계속하기)
static func gold_button(text: String, size := 40) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_font_override("font", font(true))
	return _styled(b, GOLD, GOLD_D, GOLD, Color("#1a0f00"))


static func dark_button(text: String, size := 28, accent := LINE) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	var face = PANEL2.lerp(accent, 0.3).lightened(0.06)
	return _styled(b, face, Color("#080a0b"), face.lightened(0.18), TEXT, 14)


static func color_button(text: String, size: int, face: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_font_override("font", font(true))
	return _styled(b, face, face.darkened(0.45), face.lightened(0.35), Color.WHITE, 14)


## 태그·재화 칸 (작게 모서리를 딴 띠)
static func pill(bg: Color, border := Color(1, 1, 1, 0.12), pad_h := 16, pad_v := 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	_chamfer(s, 6)
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	return s


## 등급 칸: 어두운 바탕 + 아래쪽 등급 색 띠
static func rar_box(rar: int, pad := 8) -> StyleBoxFlat:
	const C := ["#a8b2bf", "#52c7ee", "#c59bff", "#ffa524"]
	var c := Color(C[rar])
	var s := box(PANEL2.lerp(c, 0.1), Color(c, 0.75), 1, 0, GOLD, pad)
	s.border_width_bottom = 5
	s.shadow_color = Color(0, 0, 0, 0.4)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 3)
	return s


## ---------- 장식 ----------
## 네 귀퉁이 브래킷 (부모를 가득 채우는 겹침 장식)
static func brackets(col := GOLD, length := 18.0, width := 3.0, inset := 0.0) -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var r := Rect2(Vector2(inset, inset), c.size - Vector2(inset, inset) * 2)
		for q in [[r.position, 1.0, 1.0], [Vector2(r.end.x, r.position.y), -1.0, 1.0], [r.end, -1.0, -1.0], [Vector2(r.position.x, r.end.y), 1.0, -1.0]]:
			var o: Vector2 = q[0]
			c.draw_line(o, o + Vector2(q[1] * length, 0), col, width)
			c.draw_line(o, o + Vector2(0, q[2] * length), col, width))
	return c


## 배경 무늬: 옅은 빗금 + 가로 눈금선
static func hatch(alpha := 0.035) -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var w := c.size.x
		var h := c.size.y
		var x := -h
		while x < w:
			c.draw_line(Vector2(x, h), Vector2(x + h, 0), Color(1, 1, 1, alpha), 1.0)
			x += 34.0
		var y := 0.0
		while y < h:
			c.draw_line(Vector2(0, y), Vector2(w, y), Color(1, 1, 1, alpha * 0.6), 1.0)
			y += 136.0)
	return c