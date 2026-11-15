# SI assistance metadata: This code used the help of SI.
class_name RocketView
extends Control

var report: Dictionary = {}
var design: Dictionary = {}
var show_burnout: bool = false:
	set(value):
		show_burnout = value
		queue_redraw()

const STAGE_COLORS := [Color("fbf5e6"), Color("e9c46a"), Color("8fc1b5"), Color("e7a17a")]
const ENGINE_COLOR := Color("8c8577")
const PAYLOAD_COLOR := Color("2a7b7b")
const NOSE_COLOR := Color("fbf5e6")

func show_report(new_report: Dictionary, new_design: Dictionary) -> void:
	report = new_report
	design = new_design
	queue_redraw()

func _draw() -> void:
	var ink := ConsoleTheme.INK
	var font := ConsoleTheme.mono()
	var head := ConsoleTheme.typewriter()
	draw_rect(Rect2(Vector2.ZERO, size), ConsoleTheme.PAPER)
	_draw_grid()
	var geometry: Dictionary = report.get("geometry", {})
	var segments: Array = geometry.get("segments", [])
	if segments.is_empty():
		draw_string(head, Vector2(0, size.y / 2.0), "NO ROCKET ON THE PAD", HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, ink)
		return
	var numbers: Dictionary = report.get("numbers", {})
	var stages: Array = design.get("stages", [])
	var fins: Dictionary = design.get("fins", {})
	var d0 := float(geometry.get("diameter_m", 1.0))
	var length := float(geometry.get("length_m", 1.0))
	var max_d := maxf(float(geometry.get("max_diameter_m", d0)), d0)
	var span := float(fins.get("span_m", 0.0)) if int(fins.get("count", 0)) > 0 else 0.0
	var bell_h := d0 * 0.45

	var x_min := 0.0
	for segment: Dictionary in segments:
		x_min = minf(x_min, float(segment["x_top_m"]))
	var x_max := length + bell_h
	var width_m := maxf(max_d, d0 + 2.0 * span)
	var top_pad := 46.0
	var bottom_pad := 54.0
	var side_room := 380.0
	var k := minf((size.y - top_pad - bottom_pad) / maxf(x_max - x_min, 0.1), (size.x - side_room) / maxf(width_m, 0.1))
	var cx := size.x * 0.5 - 40.0
	var y0 := top_pad - x_min * k
	var to_y := func(x_m: float) -> float: return y0 + x_m * k

	_draw_ruler(x_min, length, k, y0)

	var fin_count := int(fins.get("count", 0))
	var fin_le := float(geometry.get("fin_root_le_x_m", length))
	var fin_poly := PackedVector2Array()
	if fin_count > 0 and span > 0.0:
		var root := float(fins.get("root_chord_m", 0.0)) * k
		var tip := float(fins.get("tip_chord_m", 0.0)) * k
		var sweep := float(fins.get("sweep_m", 0.0)) * k
		var r := d0 / 2.0 * k
		var top_y: float = to_y.call(fin_le)
		var shown_span := span * k * (0.87 if fin_count == 3 else 1.0)
		for side: float in [-1.0, 1.0]:
			var pts := PackedVector2Array([
				Vector2(cx + side * r, top_y), Vector2(cx + side * (r + shown_span), top_y + sweep),
				Vector2(cx + side * (r + shown_span), top_y + sweep + tip), Vector2(cx + side * r, top_y + root)])
			_poly(self, pts, ConsoleTheme.ORANGE)
		if fin_count != 2:
			fin_poly = PackedVector2Array([Vector2(cx - 3, top_y), Vector2(cx + 3, top_y),
					Vector2(cx + 3, top_y + root), Vector2(cx - 3, top_y + root)])

	for segment: Dictionary in segments:
		var kind := str(segment["kind"])
		var x_top := float(segment["x_top_m"])
		var seg_len := float(segment["length_m"]) * k
		var r := float(segment["diameter_m"]) / 2.0 * k
		var y: float = to_y.call(x_top)
		var stage := int(segment["stage"])
		match kind:
			"escape_tower":
				_draw_tower(Vector2(cx, y), seg_len, maxf(d0 * 0.18 * k, 6.0))
			"nose":
				var shape := str((design.get("nose", {}) as Dictionary).get("shape", "cone"))
				_poly(self, nose_outline(shape, Vector2(cx, y), seg_len, r, 24), NOSE_COLOR)
			"payload":
				var rect := Rect2(cx - r, y, 2.0 * r, seg_len)
				draw_brick(self, rect, PAYLOAD_COLOR, maxf(2.0 * r, 8.0))
				if seg_len > 14.0 and r > 8.0:
					var c := rect.get_center()
					var pr := minf(seg_len, 2.0 * r) * 0.22
					draw_circle(c, pr, Color("e9f2ef"))
					draw_arc(c, pr, 0, TAU, 20, ink, 2.0, true)
			"body":
				var rect := Rect2(cx - r, y, 2.0 * r, seg_len)
				draw_brick(self, rect, STAGE_COLORS[stage % STAGE_COLORS.size()], maxf(2.0 * r, 8.0))
				_draw_roll_pattern(rect, stage)
			"engine":
				var rect := Rect2(cx - r, y, 2.0 * r, seg_len)
				if stage == 0:
					draw_brick(self, rect, ENGINE_COLOR, maxf(2.0 * r, 8.0))
				else:
					draw_rect(rect, Color("4a4740"))
					var lattice := PackedVector2Array()
					var n := maxi(2, int(rect.size.x / maxf(rect.size.y, 4.0)) * 2)
					for i in n:
						var x0 := rect.position.x + rect.size.x * i / n
						var x1 := rect.position.x + rect.size.x * (i + 1) / n
						lattice.append_array([Vector2(x0, rect.position.y), Vector2(x1, rect.end.y),
								Vector2(x1, rect.position.y), Vector2(x0, rect.end.y)])
					draw_multiline(lattice, Color("a39a88"), 1.5)
					draw_rect(rect, ink, false, 2.5)

	if not fin_poly.is_empty():
		_poly(self, fin_poly, ConsoleTheme.ORANGE.darkened(0.15))

	if not stages.is_empty():
		var engine: Dictionary = (stages[0] as Dictionary).get("engine", {})
		var count := maxi(1, int(engine.get("count", 1)))
		var tail_y: float = to_y.call(length)
		var bell_w := minf(d0 * k * 0.8 / count, d0 * k * 0.55)
		for i in count:
			var bx := cx + (i - (count - 1) / 2.0) * bell_w * 1.1
			draw_bell(self, Vector2(bx, tail_y), bell_w, bell_h * k)

	var x_cp := float(numbers.get("x_cp_m", 0.0))
	var x_cg := float(numbers.get("x_cg_burnout_m" if show_burnout else "x_cg_liftoff_m", 0.0))
	var margin := float(numbers.get("static_margin_burnout_cal" if show_burnout else "static_margin_liftoff_cal", 0.0))
	var cp_y: float = to_y.call(x_cp)
	var cg_y: float = to_y.call(x_cg)
	var label_x := cx + (d0 / 2.0 + span) * k + 34.0
	var bracket_x := cx - (d0 / 2.0 + span) * k - 30.0
	draw_line(Vector2(bracket_x, cg_y), Vector2(bracket_x, cp_y), ConsoleTheme.INK_SOFT, 3.0)
	draw_line(Vector2(bracket_x - 7, cg_y), Vector2(bracket_x + 7, cg_y), ConsoleTheme.CG_BLUE, 3.0)
	draw_line(Vector2(bracket_x - 7, cp_y), Vector2(bracket_x + 7, cp_y), ConsoleTheme.CP_RED, 3.0)
	draw_string(font, Vector2(bracket_x - 150, (cg_y + cp_y) / 2.0 + 6), "%+.2f cal" % margin,
			HORIZONTAL_ALIGNMENT_RIGHT, 140, 18, ConsoleTheme.status_color(_margin_status()))
	_draw_cp(Vector2(cx, cp_y))
	_draw_cg(Vector2(cx, cg_y))
	draw_dashed_line(Vector2(cx + 16, cp_y), Vector2(label_x - 6, cp_y), ConsoleTheme.CP_RED, 2.0, 6.0)
	draw_dashed_line(Vector2(cx + 16, cg_y), Vector2(label_x - 6, cg_y), ConsoleTheme.CG_BLUE, 2.0, 6.0)
	var cp_text_y := cp_y + 6.0
	var cg_text_y := cg_y + 6.0
	if absf(cp_text_y - cg_text_y) < 24.0:
		if cg_text_y <= cp_text_y:
			cg_text_y = cp_text_y - 24.0
		else:
			cg_text_y = cp_text_y + 24.0
	draw_string(head, Vector2(label_x, cp_text_y), "CP %.2f m" % x_cp, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, ConsoleTheme.CP_RED)
	draw_string(head, Vector2(label_x, cg_text_y), "CG %.2f m" % x_cg, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, ConsoleTheme.CG_BLUE)

	var caption := "LENGTH %.1f m   DIA %.2f m   LIFTOFF %.1f t   CG AT %s" % [
		length, d0, float(numbers.get("liftoff_mass_kg", 0.0)) / 1000.0, "BURNOUT" if show_burnout else "LIFTOFF"]
	draw_string(font, Vector2(0, size.y - 18), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x, 17, ink)

static func nose_outline(shape: String, tip: Vector2, length: float, radius: float, steps: int) -> PackedVector2Array:
	var right := PackedVector2Array()
	var rho := (radius * radius + length * length) / maxf(2.0 * radius, 0.001)
	for i in steps + 1:
		var t := float(i) / steps
		var r := 0.0
		match shape:
			"cone":
				r = radius * t
			"ogive":
				var y := t * length
				r = sqrt(maxf(rho * rho - (length - y) * (length - y), 0.0)) + radius - rho
			"parabolic":
				r = radius * (2.0 * t - t * t)
			"blunt":
				r = radius * (0.38 + 0.62 * t) if t > 0.08 else radius * (0.38 * sqrt(t / 0.08))
			_:
				r = radius * t
		right.append(Vector2(tip.x + maxf(r, 0.0), tip.y + t * length))
	var outline := PackedVector2Array()
	for i in range(right.size() - 1, -1, -1):
		outline.append(Vector2(2.0 * tip.x - right[i].x, right[i].y))
	for i in range(1, right.size()):
		outline.append(right[i])
	return outline

static func draw_brick(canvas: CanvasItem, rect: Rect2, color: Color, pitch: float) -> void:
	if rect.size.y <= 0.0 or rect.size.x <= 0.0:
		return
	canvas.draw_rect(rect, color)
	canvas.draw_rect(Rect2(rect.position.x + rect.size.x * 0.16, rect.position.y, rect.size.x * 0.12, rect.size.y),
			color.lightened(0.35))
	canvas.draw_rect(Rect2(rect.end.x - rect.size.x * 0.18, rect.position.y, rect.size.x * 0.18, rect.size.y),
			color.darkened(0.16))
	if pitch > 4.0:
		var y := rect.position.y + pitch
		while y < rect.end.y - 2.0:
			canvas.draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), color.darkened(0.25), 1.5)
			y += pitch
	canvas.draw_rect(rect, ConsoleTheme.INK, false, 2.5)

static func draw_bell(canvas: CanvasItem, top: Vector2, width: float, height: float) -> void:
	var throat := width * 0.32
	var pts := PackedVector2Array()
	var steps := 10
	for i in steps + 1:
		var t := float(i) / steps
		pts.append(Vector2(top.x - lerpf(throat, width, t * t * 0.6 + t * 0.4) / 2.0, top.y + t * height))
	for i in range(steps, -1, -1):
		var t := float(i) / steps
		pts.append(Vector2(top.x + lerpf(throat, width, t * t * 0.6 + t * 0.4) / 2.0, top.y + t * height))
	canvas.draw_colored_polygon(pts, Color("3d3a35"))
	canvas.draw_line(Vector2(top.x - throat * 0.2, top.y), Vector2(top.x - width * 0.3, top.y + height), Color("6d675e"), 2.0)
	pts.append(pts[0])
	canvas.draw_polyline(pts, ConsoleTheme.INK, 2.5, true)

static func _poly(canvas: CanvasItem, points: PackedVector2Array, fill: Color) -> void:
	if points.size() < 3:
		return
	canvas.draw_colored_polygon(points, fill)
	var closed := points.duplicate()
	closed.append(points[0])
	canvas.draw_polyline(closed, ConsoleTheme.INK, 2.5, true)

func _margin_status() -> String:
	for check: Dictionary in report.get("checks", []):
		if str(check["id"]) == ("stability_burnout" if show_burnout else "stability_liftoff"):
			return str(check["status"])
	return "pass"

func _draw_grid() -> void:
	var color := Color(ConsoleTheme.TEAL_LIGHT, 0.25)
	var step := 40.0
	var x := step
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), color, 1.0)
		x += step
	var y := step
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), color, 1.0)
		y += step

func _draw_ruler(x_min: float, length: float, k: float, y0: float) -> void:
	var font := ConsoleTheme.mono()
	var step_m := 1.0
	for candidate: float in [1.0, 2.0, 5.0, 10.0, 20.0, 50.0]:
		step_m = candidate
		if candidate * k >= 40.0:
			break
	var x := 26.0
	draw_line(Vector2(x, y0 + x_min * k), Vector2(x, y0 + length * k), ConsoleTheme.INK_SOFT, 2.0)
	var m := 0.0
	while m <= length + 0.001:
		var y := y0 + m * k
		draw_line(Vector2(x - 6, y), Vector2(x + 6, y), ConsoleTheme.INK_SOFT, 2.0)
		draw_string(font, Vector2(x + 10, y + 5), "%d m" % int(m), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ConsoleTheme.INK_SOFT)
		m += step_m

func _draw_roll_pattern(rect: Rect2, stage: int) -> void:

	if rect.size.y < 20.0 or rect.size.x < 12.0:
		return
	var band_h := minf(rect.size.x * 0.5, rect.size.y * 0.18)
	var y := rect.position.y + band_h * 0.6
	var half := rect.size.x / 2.0
	var dark := ConsoleTheme.INK if stage % 2 == 0 else ConsoleTheme.TEAL_DARK
	draw_rect(Rect2(rect.position.x, y, half, band_h / 2.0), dark)
	draw_rect(Rect2(rect.position.x + half, y + band_h / 2.0, half, band_h / 2.0), dark)
	draw_rect(Rect2(rect.position.x, y, rect.size.x, band_h), ConsoleTheme.INK, false, 1.5)

func _draw_tower(base: Vector2, height: float, half_width: float) -> void:
	var top := base - Vector2(0, height)
	var motor := Rect2(top.x - half_width * 0.6, top.y, half_width * 1.2, height * 0.3)
	draw_rect(motor, ConsoleTheme.ORANGE)
	draw_rect(motor, ConsoleTheme.INK, false, 2.0)
	var lattice_top := motor.end.y
	var lines := PackedVector2Array([Vector2(top.x - half_width * 0.4, lattice_top), Vector2(base.x - half_width, base.y),
			Vector2(top.x + half_width * 0.4, lattice_top), Vector2(base.x + half_width, base.y)])
	var n := 4
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		var w0 := lerpf(half_width * 0.4, half_width, t0)
		var w1 := lerpf(half_width * 0.4, half_width, t1)
		var y0 := lerpf(lattice_top, base.y, t0)
		var y1 := lerpf(lattice_top, base.y, t1)
		lines.append_array([Vector2(base.x - w0, y0), Vector2(base.x + w1, y1), Vector2(base.x + w0, y0), Vector2(base.x - w1, y1)])
	draw_multiline(lines, ConsoleTheme.INK, 2.0)

func _draw_cg(at: Vector2) -> void:

	var r := 13.0
	draw_circle(at, r + 2.0, ConsoleTheme.PAPER)
	draw_circle(at, r, ConsoleTheme.PAPER)
	for q: int in [0, 2]:
		var pts := PackedVector2Array([at])
		for i in 9:
			var a := q * PI / 2.0 + i * (PI / 2.0) / 8.0
			pts.append(at + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, ConsoleTheme.CG_BLUE)
	draw_arc(at, r, 0, TAU, 28, ConsoleTheme.CG_BLUE, 2.5, true)

func _draw_cp(at: Vector2) -> void:
	draw_circle(at, 13.0, ConsoleTheme.PAPER)
	draw_circle(at, 10.0, ConsoleTheme.CP_RED)
	draw_arc(at, 13.0, 0, TAU, 28, ConsoleTheme.CP_RED, 2.5, true)
