# Code generated with AI assistance (Claude). Reviewed by team.
class_name StatusIcon
extends Control
## Drawn status marks, so they never depend on a font having the glyph:
##   kind "pass" = tick, "warn" = warning triangle, "fail" = cross, "stars" = star rating.

var kind: String = "pass":
	set(value):
		kind = value
		queue_redraw()
var stars: int = 0:
	set(value):
		stars = value
		queue_redraw()


static func make(status: String, size: float = 34.0) -> StatusIcon:
	var icon := StatusIcon.new()
	icon.kind = status
	icon.custom_minimum_size = Vector2(size, size)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


static func make_stars(count: int, height: float = 40.0) -> StatusIcon:
	var icon := StatusIcon.new()
	icon.kind = "stars"
	icon.stars = count
	icon.custom_minimum_size = Vector2(height * 3.3, height)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := Vector2(s, s) / 2.0
	match kind:
		"pass":
			draw_circle(c, s * 0.47, ConsoleTheme.PASS)
			draw_arc(c, s * 0.47, 0, TAU, 32, ConsoleTheme.INK, 2.0, true)
			draw_polyline(PackedVector2Array([c + Vector2(-0.22, 0.0) * s, c + Vector2(-0.05, 0.18) * s,
					c + Vector2(0.24, -0.17) * s]), ConsoleTheme.PAPER, s * 0.12, true)
		"warn":
			var tri := PackedVector2Array([c + Vector2(0, -0.45) * s, c + Vector2(0.48, 0.4) * s, c + Vector2(-0.48, 0.4) * s])
			draw_colored_polygon(tri, ConsoleTheme.WARN)
			tri.append(tri[0])
			draw_polyline(tri, ConsoleTheme.INK, 2.0, true)
			draw_line(c + Vector2(0, -0.2) * s, c + Vector2(0, 0.12) * s, ConsoleTheme.INK, s * 0.1)
			draw_circle(c + Vector2(0, 0.27) * s, s * 0.06, ConsoleTheme.INK)
		"fail":
			draw_circle(c, s * 0.47, ConsoleTheme.FAIL)
			draw_arc(c, s * 0.47, 0, TAU, 32, ConsoleTheme.INK, 2.0, true)
			var a := s * 0.2
			draw_line(c + Vector2(-a, -a), c + Vector2(a, a), ConsoleTheme.PAPER, s * 0.12, true)
			draw_line(c + Vector2(a, -a), c + Vector2(-a, a), ConsoleTheme.PAPER, s * 0.12, true)
		"stars":
			var h := size.y
			for i in 3:
				var centre := Vector2(h * 0.55 + i * h * 1.1, h * 0.52)
				var points := _star_points(centre, h * 0.48, h * 0.2)
				draw_colored_polygon(points, ConsoleTheme.MUSTARD if i < stars else Color("d8cfb8"))
				points.append(points[0])
				draw_polyline(points, ConsoleTheme.INK, 2.0, true)


func _star_points(centre: Vector2, outer: float, inner: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 10:
		var r := outer if i % 2 == 0 else inner
		var angle := -PI / 2.0 + i * PI / 5.0
		points.append(centre + Vector2(cos(angle), sin(angle)) * r)
	return points
