extends Control
## 모스 부호 표시 (점·선 막대). on 개수만큼 앞에서부터 불이 들어온다.

var code := ""
var on := 0
var unit := 10.0
var col_off := Color("#454b51")
var col_on := Color("#f2c21b")
var bg := Color("#0b0c0d")


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


func _resize() -> void:
	var w := unit * 0.8
	for ch in code:
		w += (unit if ch == "." else unit * 2.4) + unit * 0.45
	custom_minimum_size = Vector2(maxf(w, unit * 2), unit * 1.9)
	size = custom_minimum_size


func _draw() -> void:
	if code == "":
		return
	draw_rect(Rect2(Vector2.ZERO, size), bg)
	var x := unit * 0.6
	var h := unit * 0.7
	var y := (size.y - h) / 2
	for i in code.length():
		var w := unit if code[i] == "." else unit * 2.4
		var c := col_on if i < on else col_off
		draw_rect(Rect2(x, y, w, h), c)
		x += w + unit * 0.45
