# SI assistance metadata: This code used the help of SI.
class_name CheckGauge
extends Control

var title: String = ""
var position_01: float = 0.5
var bands: Array = []
var status: String = "pass"
var readout: String = ""

func _init() -> void:
	custom_minimum_size = Vector2(0, 74)
	mouse_filter = Control.MOUSE_FILTER_STOP

func setup(gauge_title: String, value_01: float, zone_bands: Array, check_status: String,
		value_text: String, tooltip: String) -> void:
	title = gauge_title
	position_01 = clampf(value_01, 0.0, 1.0)
	bands = zone_bands
	status = check_status
	readout = value_text
	tooltip_text = tooltip
	queue_redraw()

func _draw() -> void:
	var font := ConsoleTheme.typewriter()
	var mono := ConsoleTheme.mono()
	draw_string(font, Vector2(0, 20), title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ConsoleTheme.INK)
	draw_string(mono, Vector2(0, 20), "%.2f" % position_01, HORIZONTAL_ALIGNMENT_RIGHT, size.x, 18,
			ConsoleTheme.status_color(status))
	var bar := Rect2(0, 30, size.x, 24)
	draw_rect(bar, Color("c9bd9f"))
	for band: Array in bands:
		var from := clampf(float(band[0]), 0.0, 1.0)
		var to := clampf(float(band[1]), 0.0, 1.0)
		if to <= from:
			continue
		var color := ConsoleTheme.status_color(str(band[2]))
		draw_rect(Rect2(bar.position.x + from * bar.size.x, bar.position.y, (to - from) * bar.size.x, bar.size.y),
				color.lerp(ConsoleTheme.PAPER, 0.25))
	for i in 11:
		var x := bar.position.x + bar.size.x * i / 10.0
		var tick := 8.0 if i % 5 == 0 else 4.0
		draw_line(Vector2(x, bar.end.y - tick), Vector2(x, bar.end.y), ConsoleTheme.INK, 1.5)
	draw_rect(bar, ConsoleTheme.INK, false, 3.0)
	var nx := bar.position.x + position_01 * bar.size.x
	var needle := PackedVector2Array([Vector2(nx - 8, bar.position.y - 7), Vector2(nx + 8, bar.position.y - 7),
			Vector2(nx, bar.position.y + 6)])
	draw_line(Vector2(nx, bar.position.y), Vector2(nx, bar.end.y), ConsoleTheme.INK, 4.0)
	draw_colored_polygon(needle, ConsoleTheme.INK)
	draw_string(mono, Vector2(0, 72), readout, HORIZONTAL_ALIGNMENT_LEFT, size.x, 15, ConsoleTheme.INK_SOFT)
