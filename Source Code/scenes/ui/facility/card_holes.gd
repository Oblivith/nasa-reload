# SI assistance metadata: This code used the help of SI.
class_name CardHoles
extends Control

const COLUMNS := 80
const ROWS := 12
const HOLE_COLOR := Color("2b2622")
const PRINT_COLOR := Color(0.55, 0.45, 0.35, 0.35)

var text: String = "":
	set(value):
		text = value
		queue_redraw()

func _init() -> void:
	custom_minimum_size = Vector2(0, 60)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var cw := size.x / float(COLUMNS)
	var rh := size.y / float(ROWS)
	for c in COLUMNS:
		for r in range(2, ROWS):
			draw_rect(Rect2(c * cw + cw * 0.3, r * rh + rh * 0.3, cw * 0.4, rh * 0.4), PRINT_COLOR)
	var upper := text.to_upper()
	for i in mini(upper.length(), COLUMNS):
		var ch := upper[i]
		var rows: Array[int] = []
		if ch >= "0" and ch <= "9":
			rows.append(2 + int(ch))
		elif ch == ".":
			rows.append_array([0, 5, 10])
		elif ch == "-":
			rows.append(1)
		elif ch >= "A" and ch <= "Z":
			var n := ch.unicode_at(0) - 65
			rows.append(n / 9)
			rows.append(2 + 1 + n % 9)
		for r in rows:
			draw_rect(Rect2(i * cw + cw * 0.18, r * rh + rh * 0.1, cw * 0.64, rh * 0.8), HOLE_COLOR)
