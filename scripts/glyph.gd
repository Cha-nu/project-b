extends Control
## 모스 부호 표시 (둥근 점·선). on 개수만큼 앞에서부터 불이 들어온다.

var code := ""
var on := 0
var unit := 10.0
var col_off := Color(1, 1, 1, 0.4)
var col_on := Color("#ffc531")


func setup(c: String, lit := 0, u := 10.0) -> Control:
	code = c
	on = lit
	unit = u
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resize()
	return self


func set_code(c: String, lit: int) -> void:
	if c == code and lit == on:
		return
	code = c
	on = lit
	_resize()
	queue_redraw()


## 부호 전체 너비
static func width_of(c: String, u: float) -> float:
	var w := 0.0
	for ch in c:
		w += (u if ch == "." else u * 2.5) + u * 0.5
	return maxf(0.0, w - u * 0.5)


## 아무 CanvasItem에나 그릴 수 있는 버전. pos는 왼쪽 가운데
static func paint(ci: CanvasItem, pos: Vector2, c: String, lit: int, u: float, c_on: Color, c_off: Color) -> void:
	var x := pos.x
	var r := u * 0.5
	for i in c.length():
		var w := u if c[i] == "." else u * 2.5
		var col := c_on if i < lit else c_off
		if c[i] == ".":
			ci.draw_circle(Vector2(x + r, pos.y), r, col, true, -1.0, true)
		else:
			## 선: 양 끝이 둥근 막대를 다각형 하나로 그린다
			var pts := PackedVector2Array()
			for k in 9:
				var a := PI / 2 + PI * k / 8.0
				pts.append(Vector2(x + r + cos(a) * r, pos.y + sin(a) * r))
			for k in 9:
				var a := -PI / 2 + PI * k / 8.0
				pts.append(Vector2(x + w - r + cos(a) * r, pos.y + sin(a) * r))
			ci.draw_colored_polygon(pts, col)
		x += w + u * 0.5


func _resize() -> void:
	custom_minimum_size = Vector2(maxf(width_of(code, unit), unit), unit * 1.6)
	size = custom_minimum_size


func _draw() -> void:
	if code == "":
		return
	paint(self, Vector2(0, size.y / 2), code, on, unit, col_on, col_off)
