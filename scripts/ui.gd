extends RefCounted
## UI 공통: 테마·스타일박스·라벨/버튼 생성 헬퍼. 기준 해상도 720 x 1280 (세로)
## 상용 모바일 게임 톤: 둥근 패널, 아래로 두꺼운 그림자가 지는 입체 버튼, 남색 바탕 + 금색 강조

const GOLD := Color("#ffc531")
const GOLD_D := Color("#b97a00")
const INK := Color("#070d16")
const PANEL := Color("#111b29")
const PANEL2 := Color("#1a2738")
const LINE := Color("#2b3f57")
const TEXT := Color("#f2f4f7")
const MUTE := Color("#8d9bb0")
const RED := Color("#ff4a3d")
const GREEN := Color("#6fd352")
const BLUE := Color("#3fb6ff")
const R := 16

static var _font: SystemFont
static var _font_b: SystemFont


static func font(bold := false) -> SystemFont:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR", "Noto Sans KR", "Apple SD Gothic Neo", "sans-serif"])
		_font_b = SystemFont.new()
		_font_b.font_names = _font.font_names
		_font_b.font_weight = 800
	return _font_b if bold else _font


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


## 둥근 패널. top: 위쪽 색 띠 두께, left: 왼쪽 색 띠
static func box(bg: Color, border := LINE, bw := 1, top := 0, top_col := GOLD, pad := 10, left := 0, left_col := GOLD, radius := R) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.corner_detail = 6
	s.anti_aliasing = true
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


## 그림자 진 카드
static func card(bg := PANEL2, border := LINE, pad := 18, radius := 22) -> StyleBoxFlat:
	var s := box(bg, border, 2, 0, GOLD, pad, 0, GOLD, radius)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 10
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


## 입체 버튼: 윗면 하이라이트 + 아래로 두꺼운 그림자(눌리면 내려앉음)
static func bevel(face: Color, edge: Color, hi: Color, pressed := false, pad := 18, radius := R) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = face.darkened(0.08) if pressed else face
	s.set_corner_radius_all(radius)
	s.corner_detail = 6
	s.anti_aliasing = true
	s.border_color = hi
	s.set_border_width_all(0)
	s.border_width_top = 0 if pressed else 3
	s.shadow_color = edge
	s.shadow_size = 1
	s.shadow_offset = Vector2(0, 2 if pressed else 8)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad + (4 if pressed else 0)
	s.content_margin_bottom = pad - (4 if pressed else 0)
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
	b.add_theme_stylebox_override("disabled", bevel(Color("#3c4552"), Color("#20262e"), Color("#4a5563"), false, pad))
	return b


## 금색 주 버튼 (출격·계속하기)
static func gold_button(text: String, size := 40) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_font_override("font", font(true))
	return _styled(b, GOLD, GOLD_D, Color("#ffe9a3"), Color("#2a1a00"))


static func dark_button(text: String, size := 28, accent := LINE) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	var face = PANEL2.lerp(accent, 0.25)
	return _styled(b, face, Color("#060a10"), face.lightened(0.18), TEXT, 14)


static func color_button(text: String, size: int, face: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_font_override("font", font(true))
	return _styled(b, face, face.darkened(0.45), face.lightened(0.35), Color.WHITE, 14)


## 둥근 알약 모양 (재화·태그)
static func pill(bg: Color, border := Color(1, 1, 1, 0.12), pad_h := 16, pad_v := 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(40)
	s.corner_detail = 8
	s.anti_aliasing = true
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	return s


static func rar_box(rar: int, pad := 8) -> StyleBoxFlat:
	const BG := ["#25303d", "#16334d", "#2d2145", "#3d2f10"]
	const C := ["#a4b0bf", "#3fb6ff", "#b77cff", "#ffc531"]
	var s := box(Color(BG[rar]), Color(C[rar]).darkened(0.2), 2, 5, Color(C[rar]), pad)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 4)
	return s
