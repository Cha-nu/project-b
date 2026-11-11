extends Control
## 벡터 아이콘 (폰트 기호에 기대지 않고 직접 그린다).
## 공용: gun globe radio gear gem medal pause heart clock check star lock left right play x bullet eye
## 지원요청: Data.STRATS의 id 그대로 (air supply turret strafe mines napalm shield heal stun carpet drone mortar missiles gunship thermo moab)
## 무기: ar sg lmg rail / 목표: cap nest aa term heli unknown
var kind := "globe"
var col := Color.WHITE


func setup(k: String, c := Color.WHITE, sz := 48.0) -> Control:
	kind = k
	col = c
	custom_minimum_size = Vector2(sz, sz)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	return self


func _draw() -> void:
	paint(self, kind, Rect2(Vector2.ZERO, size), col)


static func _pl(ci: CanvasItem, o: Vector2, s: float, pts: Array, c: Color) -> void:
	var arr := PackedVector2Array()
	for i in range(0, pts.size(), 2):
		arr.append(o + Vector2(pts[i], pts[i + 1]) * s)
	ci.draw_colored_polygon(arr, c)


static func _rc(ci: CanvasItem, o: Vector2, s: float, x: float, y: float, w: float, h: float, c: Color) -> void:
	ci.draw_rect(Rect2(o + Vector2(x, y) * s, Vector2(w, h) * s), c)


static func _ln(ci: CanvasItem, o: Vector2, s: float, x0: float, y0: float, x1: float, y1: float, c: Color, w: float) -> void:
	ci.draw_line(o + Vector2(x0, y0) * s, o + Vector2(x1, y1) * s, c, w, true)


static func _ci(ci: CanvasItem, o: Vector2, s: float, x: float, y: float, r: float, c: Color) -> void:
	ci.draw_circle(o + Vector2(x, y) * s, r * s, c, true, -1.0, true)


static func _arc(ci: CanvasItem, o: Vector2, s: float, x: float, y: float, r: float, a0: float, a1: float, c: Color, w: float) -> void:
	ci.draw_arc(o + Vector2(x, y) * s, r * s, a0, a1, 28, c, w, true)


## 폭탄 (cx, cy 중심, k 배율). 머리가 아래
static func _bomb(ci: CanvasItem, o: Vector2, s: float, cx: float, cy: float, k: float, c: Color) -> void:
	_ci(ci, o, s, cx, cy + 0.12 * k, 0.22 * k, c)
	_pl(ci, o, s, [cx - 0.2 * k, cy + 0.06 * k, cx + 0.2 * k, cy + 0.06 * k, cx + 0.09 * k, cy - 0.26 * k, cx - 0.09 * k, cy - 0.26 * k], c)
	_pl(ci, o, s, [cx - 0.2 * k, cy - 0.42 * k, cx + 0.2 * k, cy - 0.42 * k, cx + 0.1 * k, cy - 0.22 * k, cx - 0.1 * k, cy - 0.22 * k], c)


## rect 안에 kind 아이콘을 col로 그린다
static func paint(ci: CanvasItem, kind: String, rect: Rect2, col: Color) -> void:
	var s := minf(rect.size.x, rect.size.y)
	var o := rect.position + (rect.size - Vector2(s, s)) / 2
	var w := maxf(2.0, s * 0.07)
	var ink := Color(0.03, 0.05, 0.09, 0.7)
	match kind:
		"globe":
			var c := o + Vector2(0.5, 0.5) * s
			ci.draw_arc(c, s * 0.4, 0, TAU, 40, col, w, true)
			_ln(ci, o, s, 0.1, 0.5, 0.9, 0.5, col, w * 0.7)
			var pts := PackedVector2Array()
			var pts2 := PackedVector2Array()
			for i in 25:
				var a := -PI / 2 + PI * i / 24.0
				pts.append(c + Vector2(cos(a) * s * 0.2, sin(a) * s * 0.4))
				pts2.append(c + Vector2(-cos(a) * s * 0.2, sin(a) * s * 0.4))
			ci.draw_polyline(pts, col, w * 0.7, true)
			ci.draw_polyline(pts2, col, w * 0.7, true)
		"gun", "ar":
			_rc(ci, o, s, 0.08, 0.36, 0.7, 0.14, col)
			_rc(ci, o, s, 0.78, 0.39, 0.16, 0.07, col)
			_pl(ci, o, s, [0.16, 0.5, 0.3, 0.5, 0.24, 0.74, 0.1, 0.74], col)
			_pl(ci, o, s, [0.42, 0.5, 0.52, 0.5, 0.56, 0.68, 0.46, 0.68], col)
			_rc(ci, o, s, 0.34, 0.27, 0.2, 0.07, col)
		"sg":
			_rc(ci, o, s, 0.2, 0.36, 0.5, 0.13, col)
			_rc(ci, o, s, 0.7, 0.37, 0.26, 0.06, col)
			_rc(ci, o, s, 0.56, 0.46, 0.34, 0.055, col)
			_pl(ci, o, s, [0.2, 0.36, 0.2, 0.49, 0.03, 0.68, 0.03, 0.5], col)
			_pl(ci, o, s, [0.3, 0.49, 0.41, 0.49, 0.37, 0.68, 0.26, 0.68], col)
		"lmg":
			_rc(ci, o, s, 0.14, 0.33, 0.56, 0.16, col)
			_rc(ci, o, s, 0.7, 0.38, 0.27, 0.06, col)
			_rc(ci, o, s, 0.36, 0.5, 0.2, 0.2, col)
			_ln(ci, o, s, 0.84, 0.44, 0.76, 0.74, col, w * 0.8)
			_ln(ci, o, s, 0.84, 0.44, 0.93, 0.74, col, w * 0.8)
			_pl(ci, o, s, [0.14, 0.33, 0.14, 0.49, 0.02, 0.57, 0.02, 0.38], col)
		"rail":
			_rc(ci, o, s, 0.32, 0.31, 0.64, 0.07, col)
			_rc(ci, o, s, 0.32, 0.5, 0.64, 0.07, col)
			_rc(ci, o, s, 0.08, 0.29, 0.28, 0.3, col)
			_pl(ci, o, s, [0.14, 0.59, 0.26, 0.59, 0.22, 0.78, 0.1, 0.78], col)
			for i in 3:
				_ci(ci, o, s, 0.5 + i * 0.16, 0.44, 0.035, col)
		"radio":
			ci.draw_rect(Rect2(o + Vector2(0.22, 0.38) * s, Vector2(0.56, 0.5) * s), col, false, w)
			_ln(ci, o, s, 0.66, 0.38, 0.8, 0.08, col, w)
			_ci(ci, o, s, 0.38, 0.62, 0.08, col)
			for i in 3:
				_ln(ci, o, s, 0.52, 0.52 + i * 0.1, 0.68, 0.52 + i * 0.1, col, w * 0.7)
		"gear":
			var c := o + Vector2(0.5, 0.5) * s
			for i in 8:
				var a := i * TAU / 8
				ci.draw_line(c + Vector2(cos(a), sin(a)) * s * 0.26, c + Vector2(cos(a), sin(a)) * s * 0.42, col, s * 0.13)
			ci.draw_circle(c, s * 0.3, col)
			ci.draw_circle(c, s * 0.12, Color(0.07, 0.1, 0.15))
		"gem":
			_pl(ci, o, s, [0.5, 0.08, 0.92, 0.42, 0.5, 0.94, 0.08, 0.42], col)
			_pl(ci, o, s, [0.5, 0.08, 0.92, 0.42, 0.5, 0.42], col.lightened(0.45))
			_pl(ci, o, s, [0.08, 0.42, 0.5, 0.42, 0.5, 0.94], col.darkened(0.25))
		"medal":
			_pl(ci, o, s, [0.28, 0.0, 0.45, 0.0, 0.56, 0.4, 0.4, 0.4], Color("#3fb6ff"))
			_pl(ci, o, s, [0.55, 0.0, 0.72, 0.0, 0.6, 0.4, 0.44, 0.4], Color("#ff4a3d"))
			_ci(ci, o, s, 0.5, 0.64, 0.3, col)
			_ci(ci, o, s, 0.5, 0.64, 0.2, col.darkened(0.25))
		"pause":
			_rc(ci, o, s, 0.24, 0.2, 0.18, 0.6, col)
			_rc(ci, o, s, 0.58, 0.2, 0.18, 0.6, col)
		"heart":
			_ci(ci, o, s, 0.32, 0.36, 0.2, col)
			_ci(ci, o, s, 0.68, 0.36, 0.2, col)
			_pl(ci, o, s, [0.135, 0.44, 0.865, 0.44, 0.5, 0.88], col)
		"clock":
			_arc(ci, o, s, 0.5, 0.5, 0.36, 0, TAU, col, w)
			_ln(ci, o, s, 0.5, 0.5, 0.5, 0.28, col, w)
			_ln(ci, o, s, 0.5, 0.5, 0.66, 0.58, col, w)
		"check":
			ci.draw_polyline(PackedVector2Array([o + Vector2(0.16, 0.52) * s, o + Vector2(0.4, 0.76) * s, o + Vector2(0.86, 0.24) * s]), col, w * 1.8, true)
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI / 2 + i * TAU / 10
				var r := 0.46 if i % 2 == 0 else 0.2
				pts.append(o + (Vector2(0.5, 0.53) + Vector2(cos(a), sin(a)) * r) * s)
			ci.draw_colored_polygon(pts, col)
		"lock":
			_rc(ci, o, s, 0.22, 0.44, 0.56, 0.44, col)
			_arc(ci, o, s, 0.5, 0.44, 0.19, PI, TAU, col, w * 1.3)
		"left":
			_pl(ci, o, s, [0.7, 0.14, 0.7, 0.86, 0.22, 0.5], col)
		"right", "play":
			_pl(ci, o, s, [0.3, 0.14, 0.3, 0.86, 0.78, 0.5], col)
		"x":
			_ln(ci, o, s, 0.22, 0.22, 0.78, 0.78, col, w * 1.6)
			_ln(ci, o, s, 0.78, 0.22, 0.22, 0.78, col, w * 1.6)
		"bullet":
			_rc(ci, o, s, 0.36, 0.38, 0.28, 0.52, col)
			_ci(ci, o, s, 0.5, 0.38, 0.14, col)
			_pl(ci, o, s, [0.36, 0.38, 0.64, 0.38, 0.5, 0.06], col)
			_rc(ci, o, s, 0.36, 0.72, 0.28, 0.05, ink)
		"eye":
			var pts := PackedVector2Array()
			for i in 13:
				pts.append(o + Vector2(0.06 + 0.88 * i / 12.0, 0.5 - sin(PI * i / 12.0) * 0.3) * s)
			for i in 13:
				pts.append(o + Vector2(0.94 - 0.88 * i / 12.0, 0.5 + sin(PI * i / 12.0) * 0.3) * s)
			ci.draw_colored_polygon(pts, col)
			_ci(ci, o, s, 0.5, 0.5, 0.16, ink)
		## ---------- 지원요청 ----------
		"air":
			_bomb(ci, o, s, 0.5, 0.56, 1.0, col)
		"carpet":
			_bomb(ci, o, s, 0.22, 0.46, 0.5, col)
			_bomb(ci, o, s, 0.5, 0.66, 0.5, col)
			_bomb(ci, o, s, 0.78, 0.46, 0.5, col)
		"moab":
			_bomb(ci, o, s, 0.5, 0.58, 1.12, col)
			_pl(ci, o, s, [0.5, 0.5, 0.62, 0.7, 0.5, 0.9, 0.38, 0.7], ink)
			_arc(ci, o, s, 0.5, 0.66, 0.42, -0.5, 0.5, col, w * 0.8)
			_arc(ci, o, s, 0.5, 0.66, 0.42, PI - 0.5, PI + 0.5, col, w * 0.8)
		"thermo":
			_arc(ci, o, s, 0.5, 0.5, 0.42, 0, TAU, Color(col, col.a * 0.55), w * 0.8)
			_arc(ci, o, s, 0.5, 0.5, 0.28, 0, TAU, col, w)
			_ci(ci, o, s, 0.5, 0.5, 0.13, col)
		"supply":
			_rc(ci, o, s, 0.14, 0.34, 0.72, 0.54, col)
			_rc(ci, o, s, 0.1, 0.26, 0.8, 0.12, col)
			_rc(ci, o, s, 0.44, 0.46, 0.12, 0.34, ink)
			_rc(ci, o, s, 0.33, 0.57, 0.34, 0.12, ink)
		"turret":
			_ln(ci, o, s, 0.48, 0.58, 0.2, 0.92, col, w)
			_ln(ci, o, s, 0.48, 0.58, 0.76, 0.92, col, w)
			_ln(ci, o, s, 0.48, 0.58, 0.48, 0.94, col, w)
			_rc(ci, o, s, 0.24, 0.3, 0.42, 0.28, col)
			_rc(ci, o, s, 0.66, 0.37, 0.3, 0.09, col)
			_ci(ci, o, s, 0.36, 0.44, 0.06, ink)
		"strafe":
			for i in 3:
				_ln(ci, o, s, 0.4 + i * 0.23, 0.1, 0.2 + i * 0.23, 0.62, col, w * 1.1)
				_ci(ci, o, s, 0.16 + i * 0.23, 0.8, 0.07, col)
		"mines":
			_rc(ci, o, s, 0.14, 0.58, 0.72, 0.2, col)
			_pl(ci, o, s, [0.26, 0.58, 0.74, 0.58, 0.64, 0.42, 0.36, 0.42], col)
			_rc(ci, o, s, 0.465, 0.24, 0.07, 0.2, col)
			_ci(ci, o, s, 0.5, 0.2, 0.08, col)
		"napalm":
			_pl(ci, o, s, [0.52, 0.04, 0.74, 0.38, 0.82, 0.62, 0.72, 0.84, 0.5, 0.95, 0.28, 0.84, 0.18, 0.62, 0.3, 0.38, 0.4, 0.5], col)
			_pl(ci, o, s, [0.5, 0.52, 0.63, 0.72, 0.5, 0.88, 0.37, 0.72], ink)
		"shield":
			_pl(ci, o, s, [0.5, 0.06, 0.86, 0.2, 0.86, 0.52, 0.5, 0.94, 0.14, 0.52, 0.14, 0.2], col)
			_pl(ci, o, s, [0.5, 0.2, 0.72, 0.29, 0.72, 0.5, 0.5, 0.76], ink)
		"heal":
			_rc(ci, o, s, 0.37, 0.12, 0.26, 0.76, col)
			_rc(ci, o, s, 0.12, 0.37, 0.76, 0.26, col)
		"stun":
			var pts := PackedVector2Array()
			for i in 16:
				var a := i * TAU / 16
				var r := 0.46 if i % 2 == 0 else 0.2
				pts.append(o + (Vector2(0.5, 0.5) + Vector2(cos(a), sin(a)) * r) * s)
			ci.draw_colored_polygon(pts, col)
			_ci(ci, o, s, 0.5, 0.5, 0.09, ink)
		"drone":
			_ln(ci, o, s, 0.22, 0.28, 0.78, 0.72, col, w)
			_ln(ci, o, s, 0.78, 0.28, 0.22, 0.72, col, w)
			for q in [[0.22, 0.28], [0.78, 0.28], [0.22, 0.72], [0.78, 0.72]]:
				_arc(ci, o, s, q[0], q[1], 0.15, 0, TAU, col, w * 0.7)
			_ci(ci, o, s, 0.5, 0.5, 0.14, col)
		"hmg":
			_rc(ci, o, s, 0.2, 0.28, 0.46, 0.17, col)
			_rc(ci, o, s, 0.66, 0.33, 0.3, 0.07, col)
			_rc(ci, o, s, 0.28, 0.45, 0.18, 0.15, col)
			_pl(ci, o, s, [0.2, 0.28, 0.2, 0.45, 0.07, 0.52, 0.07, 0.33], col)
			_ln(ci, o, s, 0.46, 0.46, 0.24, 0.92, col, w)
			_ln(ci, o, s, 0.46, 0.46, 0.7, 0.92, col, w)
		"sniper":
			_arc(ci, o, s, 0.5, 0.5, 0.34, 0, TAU, col, w)
			_ln(ci, o, s, 0.5, 0.06, 0.5, 0.36, col, w)
			_ln(ci, o, s, 0.5, 0.64, 0.5, 0.94, col, w)
			_ln(ci, o, s, 0.06, 0.5, 0.36, 0.5, col, w)
			_ln(ci, o, s, 0.64, 0.5, 0.94, 0.5, col, w)
			_ci(ci, o, s, 0.5, 0.5, 0.06, col)
		"naval":
			_pl(ci, o, s, [0.04, 0.62, 0.96, 0.62, 0.82, 0.86, 0.16, 0.86], col)
			_rc(ci, o, s, 0.4, 0.44, 0.26, 0.18, col)
			_rc(ci, o, s, 0.48, 0.26, 0.08, 0.18, col)
			_ln(ci, o, s, 0.4, 0.52, 0.1, 0.36, col, w * 1.2)
			_ln(ci, o, s, 0.66, 0.52, 0.92, 0.4, col, w)
		"smoke":
			_ci(ci, o, s, 0.34, 0.56, 0.22, col)
			_ci(ci, o, s, 0.62, 0.6, 0.26, col)
			_ci(ci, o, s, 0.5, 0.36, 0.22, col)
			_rc(ci, o, s, 0.2, 0.64, 0.6, 0.2, col)
		"emp":
			_pl(ci, o, s, [0.6, 0.04, 0.22, 0.54, 0.46, 0.54, 0.36, 0.96, 0.8, 0.4, 0.54, 0.4], col)
		"sat":
			_rc(ci, o, s, 0.38, 0.36, 0.24, 0.28, col)
			_rc(ci, o, s, 0.06, 0.4, 0.28, 0.2, col)
			_rc(ci, o, s, 0.66, 0.4, 0.28, 0.2, col)
			_ln(ci, o, s, 0.5, 0.64, 0.5, 0.78, col, w)
			_arc(ci, o, s, 0.5, 0.98, 0.2, PI + 0.5, TAU - 0.5, col, w * 0.8)
		"mortar":
			_ln(ci, o, s, 0.28, 0.82, 0.66, 0.18, col, s * 0.17)
			_ln(ci, o, s, 0.1, 0.88, 0.62, 0.88, col, w * 1.2)
			_ln(ci, o, s, 0.56, 0.42, 0.84, 0.88, col, w)
		"missiles":
			ci.draw_set_transform(o + Vector2(0.5, 0.5) * s, PI / 4, Vector2.ONE)
			var z := Vector2.ZERO
			_rc(ci, z, s, -0.1, -0.24, 0.2, 0.46, col)
			_pl(ci, z, s, [-0.1, -0.24, 0.1, -0.24, 0.0, -0.48], col)
			_pl(ci, z, s, [-0.1, 0.02, -0.25, 0.26, -0.1, 0.22], col)
			_pl(ci, z, s, [0.1, 0.02, 0.25, 0.26, 0.1, 0.22], col)
			_pl(ci, z, s, [-0.07, 0.27, 0.07, 0.27, 0.0, 0.46], Color(col, col.a * 0.6))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"gunship":
			_rc(ci, o, s, 0.44, 0.06, 0.12, 0.86, col)
			_pl(ci, o, s, [0.5, 0.28, 0.96, 0.5, 0.96, 0.6, 0.5, 0.5, 0.04, 0.6, 0.04, 0.5], col)
			_pl(ci, o, s, [0.5, 0.74, 0.74, 0.86, 0.74, 0.93, 0.5, 0.87, 0.26, 0.93, 0.26, 0.86], col)
		## ---------- 목표 ----------
		"cap":
			_ln(ci, o, s, 0.5, 0.2, 0.24, 0.92, col, w)
			_ln(ci, o, s, 0.5, 0.2, 0.76, 0.92, col, w)
			_ln(ci, o, s, 0.37, 0.56, 0.63, 0.56, col, w * 0.8)
			_ln(ci, o, s, 0.3, 0.76, 0.7, 0.76, col, w * 0.8)
			_ci(ci, o, s, 0.5, 0.16, 0.07, col)
			_arc(ci, o, s, 0.5, 0.16, 0.2, -0.9, 0.9, col, w * 0.7)
			_arc(ci, o, s, 0.5, 0.16, 0.2, PI - 0.9, PI + 0.9, col, w * 0.7)
		"nest":
			_ln(ci, o, s, 0.26, 0.08, 0.26, 0.92, col, w * 1.1)
			_pl(ci, o, s, [0.26, 0.12, 0.84, 0.3, 0.26, 0.52], col)
		"aa":
			_ln(ci, o, s, 0.3, 0.68, 0.6, 0.12, col, w * 1.3)
			_ln(ci, o, s, 0.5, 0.72, 0.8, 0.18, col, w * 1.3)
			_rc(ci, o, s, 0.16, 0.68, 0.68, 0.2, col)
		"term":
			_rc(ci, o, s, 0.12, 0.16, 0.76, 0.52, col)
			_rc(ci, o, s, 0.19, 0.23, 0.62, 0.38, ink)
			_rc(ci, o, s, 0.44, 0.68, 0.12, 0.12, col)
			_rc(ci, o, s, 0.28, 0.8, 0.44, 0.07, col)
			_ln(ci, o, s, 0.27, 0.35, 0.5, 0.35, col, w * 0.7)
			_ln(ci, o, s, 0.27, 0.48, 0.66, 0.48, col, w * 0.7)
		"jam":
			_ln(ci, o, s, 0.5, 0.34, 0.5, 0.9, col, w * 1.2)
			_rc(ci, o, s, 0.3, 0.84, 0.4, 0.08, col)
			_ci(ci, o, s, 0.5, 0.3, 0.08, col)
			for k in [0.2, 0.34]:
				_arc(ci, o, s, 0.5, 0.3, k, -0.8, 0.8, col, w * 0.7)
				_arc(ci, o, s, 0.5, 0.3, k, PI - 0.8, PI + 0.8, col, w * 0.7)
			_ln(ci, o, s, 0.14, 0.72, 0.86, 0.1, col, w * 0.9)
		"fac":
			_pl(ci, o, s, [0.06, 0.9, 0.06, 0.5, 0.28, 0.36, 0.28, 0.5, 0.5, 0.36, 0.5, 0.5, 0.64, 0.5, 0.64, 0.1, 0.8, 0.1, 0.8, 0.5, 0.94, 0.5, 0.94, 0.9], col)
			_rc(ci, o, s, 0.16, 0.64, 0.14, 0.12, ink)
			_rc(ci, o, s, 0.4, 0.64, 0.14, 0.12, ink)
		## ---------- 진급 보급 ----------
		"up_dmg":
			## 고폭탄: 큰 탄두 + 터지는 불꽃
			_rc(ci, o, s, 0.16, 0.42, 0.26, 0.48, col)
			_pl(ci, o, s, [0.16, 0.42, 0.42, 0.42, 0.29, 0.12], col)
			_rc(ci, o, s, 0.16, 0.76, 0.26, 0.05, ink)
			var pts := PackedVector2Array()
			for i in 12:
				var a := i * TAU / 12
				var r := 0.26 if i % 2 == 0 else 0.11
				pts.append(o + (Vector2(0.7, 0.4) + Vector2(cos(a), sin(a)) * r) * s)
			ci.draw_colored_polygon(pts, col)
		"up_rate":
			## 속사: 탄환 셋이 줄지어 날아간다
			for i in 3:
				var y := 0.24 + i * 0.26
				var x := 0.5 - i * 0.12
				_rc(ci, o, s, x, y - 0.06, 0.26, 0.12, col)
				_pl(ci, o, s, [x + 0.26, y - 0.06, x + 0.26, y + 0.06, x + 0.44, y], col)
				_ln(ci, o, s, x - 0.3, y, x - 0.08, y, Color(col, col.a * 0.6), w * 0.8)
		"up_pierce":
			## 철갑탄: 판을 뚫고 나가는 화살
			_rc(ci, o, s, 0.42, 0.1, 0.14, 0.3, col)
			_rc(ci, o, s, 0.42, 0.6, 0.14, 0.3, col)
			_ln(ci, o, s, 0.06, 0.5, 0.74, 0.5, col, w * 1.4)
			_pl(ci, o, s, [0.68, 0.34, 0.68, 0.66, 0.96, 0.5], col)
		"up_mag":
			## 탄창: 휜 상자 + 탄
			_pl(ci, o, s, [0.3, 0.14, 0.66, 0.2, 0.72, 0.9, 0.34, 0.9], col)
			for i in 3:
				_ln(ci, o, s, 0.38, 0.36 + i * 0.16, 0.64, 0.38 + i * 0.16, ink, w * 0.8)
			_rc(ci, o, s, 0.36, 0.06, 0.2, 0.1, col)
		"up_multi":
			## 이중 총열
			_rc(ci, o, s, 0.06, 0.26, 0.7, 0.16, col)
			_rc(ci, o, s, 0.06, 0.56, 0.7, 0.16, col)
			_rc(ci, o, s, 0.04, 0.2, 0.14, 0.6, col)
			_ci(ci, o, s, 0.86, 0.34, 0.07, col)
			_ci(ci, o, s, 0.86, 0.64, 0.07, col)
		"up_spd":
			## 군화 + 속도선
			_pl(ci, o, s, [0.4, 0.1, 0.62, 0.1, 0.62, 0.52, 0.92, 0.66, 0.92, 0.84, 0.36, 0.84], col)
			_rc(ci, o, s, 0.34, 0.86, 0.6, 0.06, col)
			for i in 3:
				_ln(ci, o, s, 0.04, 0.3 + i * 0.2, 0.26, 0.3 + i * 0.2, Color(col, col.a * 0.7), w * 0.8)
		"up_hp":
			## 방탄판: 조끼 모양 + 십자
			_pl(ci, o, s, [0.2, 0.08, 0.38, 0.08, 0.5, 0.2, 0.62, 0.08, 0.8, 0.08, 0.88, 0.5, 0.78, 0.92, 0.22, 0.92, 0.12, 0.5], col)
			_rc(ci, o, s, 0.44, 0.4, 0.12, 0.36, ink)
			_rc(ci, o, s, 0.32, 0.52, 0.36, 0.12, ink)
		"up_magnet":
			## 수거 장치: 말굽 자석
			_arc(ci, o, s, 0.5, 0.48, 0.28, PI, TAU, col, s * 0.16)
			_rc(ci, o, s, 0.14, 0.48, 0.16, 0.3, col)
			_rc(ci, o, s, 0.7, 0.48, 0.16, 0.3, col)
			_rc(ci, o, s, 0.14, 0.8, 0.16, 0.1, Color(col, col.a * 0.55))
			_rc(ci, o, s, 0.7, 0.8, 0.16, 0.1, Color(col, col.a * 0.55))
		"up_gren":
			## 수류탄: 몸통 + 안전손잡이 + 고리
			_ci(ci, o, s, 0.46, 0.6, 0.3, col)
			_rc(ci, o, s, 0.36, 0.2, 0.2, 0.16, col)
			_pl(ci, o, s, [0.5, 0.2, 0.74, 0.26, 0.82, 0.5, 0.74, 0.52, 0.68, 0.34, 0.5, 0.3], col)
			_arc(ci, o, s, 0.26, 0.2, 0.1, 0, TAU, col, w * 0.8)
			_ln(ci, o, s, 0.2, 0.6, 0.72, 0.6, ink, w * 0.7)
			_ln(ci, o, s, 0.46, 0.34, 0.46, 0.86, ink, w * 0.7)
		"squad":
			## 부대원: 헬멧 쓴 세 사람 (가운데가 앞)
			for q in [[0.22, 0.42, 0.8], [0.78, 0.42, 0.8], [0.5, 0.36, 1.0]]:
				var k: float = q[2]
				var qc := Color(col, col.a * (1.0 if k == 1.0 else 0.6))
				_ci(ci, o, s, q[0], q[1], 0.13 * k, qc)
				_pl(ci, o, s, [q[0] - 0.19 * k, 0.9, q[0] - 0.19 * k, q[1] + 0.3 * k, q[0] - 0.09 * k, q[1] + 0.17 * k, q[0] + 0.09 * k, q[1] + 0.17 * k, q[0] + 0.19 * k, q[1] + 0.3 * k, q[0] + 0.19 * k, 0.9], qc)
		"tank", "ltank":
			## 전차 옆모습: 궤도 + 차체 + 포탑 + 포신 (경전차는 포신이 가늘고 짧다)
			var lt: bool = kind == "ltank"
			_pl(ci, o, s, [0.08, 0.62, 0.92, 0.62, 0.84, 0.82, 0.16, 0.82], col)
			_pl(ci, o, s, [0.14, 0.46, 0.8, 0.46, 0.9, 0.6, 0.1, 0.6], col)
			_pl(ci, o, s, [0.3, 0.3, 0.58, 0.3, 0.64, 0.44, 0.24, 0.44] if lt else [0.24, 0.26, 0.6, 0.26, 0.68, 0.44, 0.18, 0.44], col)
			_ln(ci, o, s, 0.6, 0.36, 0.86 if lt else 0.98, 0.36, col, w * (0.7 if lt else 1.3))
			for q in [0.26, 0.42, 0.58, 0.74]:
				_ci(ci, o, s, q, 0.72, 0.055, ink)
		"up_heli", "apache":
			## 공격헬기 옆모습
			_pl(ci, o, s, [0.14, 0.44, 0.5, 0.36, 0.62, 0.44, 0.62, 0.62, 0.3, 0.66, 0.14, 0.56], col)
			_pl(ci, o, s, [0.6, 0.46, 0.94, 0.4, 0.94, 0.46, 0.6, 0.58], col)
			_pl(ci, o, s, [0.86, 0.2, 0.96, 0.2, 0.94, 0.46, 0.84, 0.44], col)
			_ln(ci, o, s, 0.04, 0.26, 0.74, 0.26, col, w)
			_ln(ci, o, s, 0.4, 0.26, 0.4, 0.4, col, w)
			_ln(ci, o, s, 0.2, 0.8, 0.56, 0.8, col, w * 0.8)
			_ln(ci, o, s, 0.3, 0.66, 0.28, 0.8, col, w * 0.7)
			_ln(ci, o, s, 0.48, 0.64, 0.5, 0.8, col, w * 0.7)
			_ln(ci, o, s, 0.06, 0.6, 0.2, 0.62, col, w * 0.9)
		"boss":
			## 보스: 뿔 달린 방패
			_pl(ci, o, s, [0.5, 0.2, 0.84, 0.3, 0.84, 0.56, 0.5, 0.96, 0.16, 0.56, 0.16, 0.3], col)
			_pl(ci, o, s, [0.16, 0.3, 0.06, 0.04, 0.34, 0.24], col)
			_pl(ci, o, s, [0.84, 0.3, 0.94, 0.04, 0.66, 0.24], col)
			_pl(ci, o, s, [0.3, 0.44, 0.46, 0.5, 0.42, 0.6, 0.3, 0.56], ink)
			_pl(ci, o, s, [0.7, 0.44, 0.54, 0.5, 0.58, 0.6, 0.7, 0.56], ink)
		"heli":
			_rc(ci, o, s, 0.2, 0.16, 0.15, 0.68, col)
			_rc(ci, o, s, 0.65, 0.16, 0.15, 0.68, col)
			_rc(ci, o, s, 0.2, 0.43, 0.6, 0.14, col)
		"unknown":
			_arc(ci, o, s, 0.5, 0.36, 0.2, -PI, PI * 0.5, col, w * 1.4)
			_ln(ci, o, s, 0.5, 0.56, 0.5, 0.66, col, w * 1.4)
			_ci(ci, o, s, 0.5, 0.84, 0.07, col)
		_:
			_ci(ci, o, s, 0.5, 0.5, 0.3, col)
