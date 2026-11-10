extends Control
## 벡터 아이콘 (폰트 기호에 기대지 않고 직접 그린다). kind: gun / globe / radio / gear / gem / medal
var kind := "globe"
var col := Color.WHITE


func setup(k: String, c := Color.WHITE, sz := 48.0) -> Control:
	kind = k
	col = c
	custom_minimum_size = Vector2(sz, sz)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	return self


func _draw() -> void:
	var s = minf(size.x, size.y)
	var o = (size - Vector2(s, s)) / 2
	var P = func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	var w = maxf(2.0, s * 0.07)
	match kind:
		"globe":
			var c = P.call(0.5, 0.5)
			draw_arc(c, s * 0.4, 0, TAU, 40, col, w, true)
			draw_line(P.call(0.1, 0.5), P.call(0.9, 0.5), col, w * 0.7, true)
			for k in [0.2]:
				var pts = PackedVector2Array()
				for i in 25:
					var a = -PI / 2 + PI * i / 24.0
					pts.append(c + Vector2(cos(a) * s * k, sin(a) * s * 0.4))
				draw_polyline(pts, col, w * 0.7, true)
				var pts2 = PackedVector2Array()
				for p in pts:
					pts2.append(Vector2(2 * c.x - p.x, p.y))
				draw_polyline(pts2, col, w * 0.7, true)
		"gun":
			draw_rect(Rect2(P.call(0.08, 0.36), Vector2(s * 0.7, s * 0.14)), col)
			draw_rect(Rect2(P.call(0.78, 0.39), Vector2(s * 0.16, s * 0.07)), col)
			draw_colored_polygon(PackedVector2Array([P.call(0.16, 0.5), P.call(0.3, 0.5), P.call(0.24, 0.74), P.call(0.1, 0.74)]), col)
			draw_colored_polygon(PackedVector2Array([P.call(0.42, 0.5), P.call(0.52, 0.5), P.call(0.56, 0.68), P.call(0.46, 0.68)]), col)
			draw_rect(Rect2(P.call(0.34, 0.27), Vector2(s * 0.2, s * 0.07)), col)
		"radio":
			draw_rect(Rect2(P.call(0.22, 0.38), Vector2(s * 0.56, s * 0.5)), col, false, w)
			draw_line(P.call(0.66, 0.38), P.call(0.8, 0.08), col, w, true)
			draw_circle(P.call(0.38, 0.62), s * 0.08, col)
			for i in 3:
				draw_line(P.call(0.52, 0.52 + i * 0.1), P.call(0.68, 0.52 + i * 0.1), col, w * 0.7)
		"gear":
			var c = P.call(0.5, 0.5)
			for i in 8:
				var a = i * TAU / 8
				draw_line(c + Vector2(cos(a), sin(a)) * s * 0.26, c + Vector2(cos(a), sin(a)) * s * 0.42, col, s * 0.13)
			draw_circle(c, s * 0.3, col)
			draw_circle(c, s * 0.12, Color(0.07, 0.1, 0.15))
		"gem":
			draw_colored_polygon(PackedVector2Array([P.call(0.5, 0.08), P.call(0.92, 0.42), P.call(0.5, 0.94), P.call(0.08, 0.42)]), col)
			draw_colored_polygon(PackedVector2Array([P.call(0.5, 0.08), P.call(0.92, 0.42), P.call(0.5, 0.42)]), col.lightened(0.45))
			draw_colored_polygon(PackedVector2Array([P.call(0.08, 0.42), P.call(0.5, 0.42), P.call(0.5, 0.94)]), col.darkened(0.25))
		"medal":
			draw_colored_polygon(PackedVector2Array([P.call(0.28, 0.0), P.call(0.45, 0.0), P.call(0.56, 0.4), P.call(0.4, 0.4)]), Color("#3fb6ff"))
			draw_colored_polygon(PackedVector2Array([P.call(0.55, 0.0), P.call(0.72, 0.0), P.call(0.6, 0.4), P.call(0.44, 0.4)]), Color("#ff4a3d"))
			draw_circle(P.call(0.5, 0.64), s * 0.3, col)
			draw_circle(P.call(0.5, 0.64), s * 0.2, col.darkened(0.25))
