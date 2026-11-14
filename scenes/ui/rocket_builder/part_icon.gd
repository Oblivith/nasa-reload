# Code generated with AI assistance (Claude). Reviewed by team.
class_name PartIcon
extends Control
## Simple toy-brick picture of one Easy preset, drawn from its own numbers.
## part: nose / body / engine / fins / material / upper_stage. `scale_ref` holds the
## largest value of each size field among the presets, so pictures compare honestly.

var part: String = ""
var preset: Dictionary = {}
var scale_ref: Dictionary = {}
var material_entry: Dictionary = {}

const BODY_COLOR := Color("fbf5e6")
const ACCENT := ConsoleTheme.ORANGE


func _init() -> void:
	custom_minimum_size = Vector2(96, 96)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var w := size.x
	var h := size.y
	var ink := ConsoleTheme.INK
	match part:
		"nose":
			var ld := float(preset.get("length_to_diameter", 1.0))
			var radius := w * 0.2
			var length := minf(h * 0.85, radius * 2.0 * ld * 0.55)
			var base_y := h * 0.92
			var pts := RocketView.nose_outline(str(preset.get("shape", "cone")), Vector2(w / 2.0, base_y - length),
					length, radius, 14)
			_poly(pts, BODY_COLOR)
			draw_rect(Rect2(w / 2.0 - radius, base_y, radius * 2.0, h * 0.06), ACCENT)
		"body":
			var max_len := float(scale_ref.get("length_m", 1.0))
			var max_d := float(scale_ref.get("diameter_m", 1.0))
			var bh := h * 0.9 * float(preset.get("length_m", 1.0)) / max_len
			var bw := w * 0.42 * float(preset.get("diameter_m", 1.0)) / max_d
			var rect := Rect2(w / 2.0 - bw / 2.0, h * 0.95 - bh, bw, bh)
			RocketView.draw_brick(self, rect, BODY_COLOR, maxf(bw * 0.9, 10.0))
			draw_rect(Rect2(rect.position.x, rect.position.y + bh * 0.15, bw, bh * 0.1), ACCENT)
		"engine":
			var count := int(preset.get("count", 1))
			var skirt := Rect2(w * 0.18, h * 0.12, w * 0.64, h * 0.36)
			RocketView.draw_brick(self, skirt, Color("8c8577"), w * 0.3)
			var bell_w := minf(w * 0.6 / count, w * 0.32)
			for i in count:
				var cx := w / 2.0 + (i - (count - 1) / 2.0) * bell_w * 1.08
				RocketView.draw_bell(self, Vector2(cx, skirt.end.y), bell_w, h * 0.4)
		"fins":
			var max_root := float(scale_ref.get("root_chord_m", 1.0))
			var k := h * 0.85 / max_root
			var root := float(preset.get("root_chord_m", 1.0)) * k
			var tip := float(preset.get("tip_chord_m", 0.5)) * k
			var span := float(preset.get("span_m", 0.5)) * k
			var sweep := float(preset.get("sweep_m", 0.5)) * k
			var body_x := w * 0.3
			var top := h * 0.95 - root
			draw_rect(Rect2(body_x - w * 0.16, h * 0.04, w * 0.16, h * 0.92), BODY_COLOR)
			draw_rect(Rect2(body_x - w * 0.16, h * 0.04, w * 0.16, h * 0.92), ink, false, 2.0)
			var fin := PackedVector2Array([Vector2(body_x, top), Vector2(body_x + span, top + sweep),
					Vector2(body_x + span, top + sweep + tip), Vector2(body_x, top + root)])
			_poly(fin, ACCENT)
		"material":
			var steel := str(preset.get("material", "")) == "steel"
			var plate := Rect2(w * 0.1, h * 0.18, w * 0.8, h * 0.64)
			var color := Color("7d7f86") if steel else Color("d3d8dc")
			draw_rect(plate, color)
			draw_rect(Rect2(plate.position, Vector2(plate.size.x, plate.size.y * 0.25)), color.lightened(0.25))
			draw_rect(plate, ink, false, 3.0)
			for x: float in [0.18, 0.5, 0.82]:
				for y: float in [0.28, 0.72]:
					draw_circle(Vector2(w * x, h * y), 3.5, ink)
			var symbol := "Fe" if steel else "Al"
			draw_string(ConsoleTheme.typewriter(), Vector2(0, h * 0.62), symbol, HORIZONTAL_ALIGNMENT_CENTER, w, 28,
					ConsoleTheme.PAPER if steel else ink)
		"upper_stage":
			var prop := float(preset.get("propellant_mass_kg", 0.0))
			var base := Rect2(w * 0.28, h * 0.62, w * 0.44, h * 0.34)
			RocketView.draw_brick(self, base, Color("d8cfb8"), w * 0.4)
			if prop <= 0.0:
				draw_line(Vector2(w * 0.25, h * 0.1), Vector2(w * 0.75, h * 0.55), ConsoleTheme.FAIL, 5.0)
				draw_line(Vector2(w * 0.75, h * 0.1), Vector2(w * 0.25, h * 0.55), ConsoleTheme.FAIL, 5.0)
			else:
				var max_prop := float(scale_ref.get("propellant_mass_kg", prop))
				var uh := h * 0.46 * sqrt(prop / max_prop)
				var rect := Rect2(base.position.x, base.position.y - uh, base.size.x, uh)
				RocketView.draw_brick(self, rect, ConsoleTheme.MUSTARD, w * 0.4)
				draw_line(Vector2(rect.position.x, rect.end.y), rect.end, ink, 3.0)


func _poly(points: PackedVector2Array, fill: Color) -> void:
	draw_colored_polygon(points, fill)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, ConsoleTheme.INK, 2.5, true)
