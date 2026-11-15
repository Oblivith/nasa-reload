# Code generated with AI assistance (Claude). Reviewed by team.
class_name RocketModel
extends Node3D
## 3D model of a rocket design built from toy bricks (BrickKit: round brick stacks,
## stepped round-plate noses and engine bells, fins of sideways plates),
## built from RocketEvaluator's geometry so it matches the sheet's side view exactly.
## Stands on its tail at the node origin, nose up, scaled to `model_height` metres.
## Also builds the little catalogue pieces that sit on the Design Bay shelves.

const STAGE_COLORS := [Color("fbf5e6"), Color("e9c46a"), Color("8fc1b5"), Color("e7a17a")]
const ENGINE_COLOR := Color("8c8577")
const PAYLOAD_COLOR := Color("2a7b7b")
const FIN_COLOR := Color("c8551f")
const NOSE_COLOR := Color("fbf5e6")
const TOWER_COLOR := Color("c0392b")
const STEEL_TINT := Color("b7b2a8")

@export var model_height: float = 3.0

## World metres per real metre after the last build() (0 when empty).
var scale_factor: float = 0.0
var height_m: float = 0.0
var radius_m: float = 0.0


## Rebuilds the model. `report` is RocketEvaluator.evaluate() output for `design`.
func build(design: Dictionary, report: Dictionary) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var geometry: Dictionary = report.get("geometry", {})
	var segments: Array = geometry.get("segments", [])
	if segments.is_empty():
		scale_factor = 0.0
		height_m = 0.0
		return
	var length := float(geometry.get("length_m", 1.0))
	var x_min := 0.0
	for segment: Dictionary in segments:
		x_min = minf(x_min, float(segment["x_top_m"]))
	var d0 := float(geometry.get("diameter_m", 1.0))
	var bell := d0 * 0.45
	var total := length - x_min + bell
	var s := model_height / maxf(total, 0.1)
	scale_factor = s
	height_m = total * s
	radius_m = float(geometry.get("max_diameter_m", d0)) * s * 0.5
	# y of a point x metres below the nose tip.
	var base := bell * s
	var to_y := func(x: float) -> float: return base + (length - x) * s
	var stages: Array = design.get("stages", [])
	var nose_shape := str((design.get("nose", {}) as Dictionary).get("shape", "cone"))

	var kit := BrickKit.new(model_height / 32.0)
	for segment: Dictionary in segments:
		var kind := str(segment["kind"])
		var top: float = to_y.call(float(segment["x_top_m"]))
		var seg_len := float(segment["length_m"]) * s
		var r := float(segment["diameter_m"]) * s * 0.5
		var stage := int(segment.get("stage", -1))
		match kind:
			"nose":
				kit.add_profile(Vector3(0, top - seg_len, 0), nose_profile(nose_shape, 14), r, seg_len, NOSE_COLOR)
			"payload":
				kit.add_cylinder(Vector3(0, top - seg_len / 2.0, 0), r, seg_len, PAYLOAD_COLOR)
			"body":
				var color: Color = STAGE_COLORS[clampi(stage, 0, STAGE_COLORS.size() - 1)]
				if stage >= 0 and stage < stages.size():
					var material_id := str(((stages[stage] as Dictionary).get("body", {}) as Dictionary).get("material", ""))
					if material_id == "steel":
						color = color.lerp(STEEL_TINT, 0.35)
				var band := minf(seg_len * 0.06, kit.pitch * BrickKit.PLATE_H)
				kit.add_cylinder(Vector3(0, top - band - (seg_len - band) / 2.0, 0), r, seg_len - band, color)
				# Dark round plate at the top of each tank.
				kit.add_cylinder(Vector3(0, top - band / 2.0, 0), r * 1.02, band, Color("2b2622"))
			"engine":
				kit.add_cylinder(Vector3(0, top - seg_len / 2.0, 0), r, seg_len, ENGINE_COLOR)
				var count := 1
				if stage >= 0 and stage < stages.size():
					count = maxi(1, int(((stages[stage] as Dictionary).get("engine", {}) as Dictionary).get("count", 1)))
				bells_into(kit, Vector3(0, top - seg_len, 0), r, count, (bell if stage == 0 else bell * 0.6) * s)
			"escape_tower":
				kit.add_cylinder(Vector3(0, top - seg_len / 2.0, 0), maxf(r * 0.12, 0.01), seg_len, TOWER_COLOR)
	_fins(kit, design.get("fins", {}), to_y.call(float(geometry.get("fin_root_le_x_m", length))), d0 * s * 0.5, s)
	kit.commit(self)


## Top-of-model height in local space (for labels and the hover ring).
func top_y() -> float:
	return height_m


# --- Shelf pieces --------------------------------------------------------------------

## A small catalogue piece for one Easy preset. `scale_ref` = largest size of each field
## in that part's presets (so pieces compare honestly); `size` = the biggest piece's height.
static func part_piece(part: String, preset: Dictionary, scale_ref: Dictionary, size: float) -> Node3D:
	var root := Node3D.new()
	var kit := BrickKit.new(size / 12.0)
	match part:
		"nose":
			var r := size * 0.22
			var ld := float(preset.get("length_to_diameter", 1.0))
			var length := minf(size, r * 2.0 * ld * 0.5)
			kit.add_profile(Vector3(0, 0.05, 0), nose_profile(str(preset.get("shape", "cone")), 14), r, length - 0.05, NOSE_COLOR)
			kit.add_cylinder(Vector3(0, 0.025, 0), r, 0.05, FIN_COLOR)
		"body":
			var h := size * float(preset.get("length_m", 1.0)) / maxf(float(scale_ref.get("length_m", 1.0)), 0.01)
			var r := size * 0.2 * float(preset.get("diameter_m", 1.0)) / maxf(float(scale_ref.get("diameter_m", 1.0)), 0.01)
			kit.add_cylinder(Vector3(0, (h - 0.04) / 2.0, 0), r, h - 0.04, STAGE_COLORS[0])
			kit.add_cylinder(Vector3(0, h - 0.02, 0), r * 1.03, 0.04, Color("2b2622"))
		"engine":
			var count := maxi(1, int(preset.get("count", 1)))
			var r := size * 0.14 * (1.0 if count == 1 else 1.9)
			kit.add_cylinder(Vector3(0, size * 0.6, 0), r, size * 0.25, ENGINE_COLOR)
			bells_into(kit, Vector3(0, size * 0.48, 0), r, count, size * 0.45)
		"fins":
			var max_root := maxf(float(scale_ref.get("root_chord_m", 1.0)), 0.01)
			var k := size / max_root * 0.8
			kit.xform = Transform3D(Basis.IDENTITY, Vector3(-0.1, float(preset.get("root_chord_m", 1.0)) * k, 0))
			kit.add_fin(float(preset.get("root_chord_m", 1.0)) * k, float(preset.get("tip_chord_m", 0.5)) * k,
					float(preset.get("span_m", 0.5)) * k, float(preset.get("sweep_m", 0.5)) * k, 0.04, FIN_COLOR)
		"material":
			var steel := str(preset.get("material", "")) == "steel"
			var box := Vector3(size * 0.6, size * (0.12 if steel else 0.06), size * 0.4)
			kit.add_box(Vector3(0, box.y / 2.0, 0), box, STEEL_TINT.darkened(0.25) if steel else Color("dfe3e6"))
		"upper_stage":
			if preset.get("engine_id") == null:
				var crate := Vector3(size * 0.4, size * 0.25, size * 0.4)
				kit.add_box(Vector3(0, crate.y / 2.0, 0), crate, Color("6b5f53"))
			else:
				var max_prop := maxf(float(scale_ref.get("propellant_mass_kg", 1.0)), 1.0)
				var h := size * 0.75 * sqrt(float(preset.get("propellant_mass_kg", 0.0)) / max_prop)
				var r := size * 0.17
				kit.add_cylinder(Vector3(0, size * 0.2 + h / 2.0, 0), r, h, STAGE_COLORS[1])
				kit.add_cylinder(Vector3(0, size * 0.16, 0), r, size * 0.08, ENGINE_COLOR)
				bells_into(kit, Vector3(0, size * 0.12, 0), r, 1, size * 0.12)
	kit.commit(root)
	return root


# --- Mesh helpers --------------------------------------------------------------------

## Nose radius profile: points (t, r) from base (t = 0, r = 1) to tip (t = 1, r = 0).
static func nose_profile(shape: String, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / float(steps)
		var r := 1.0 - t
		match shape:
			"ogive", "parabolic", "von_karman":
				r = sqrt(maxf(0.0, 1.0 - t * t))
				r = lerpf(1.0 - t, r, 0.8) if t < 1.0 else 0.0
			"blunt", "hemisphere", "capsule":
				if t < 0.8:
					r = 1.0 - 0.55 * t
				else:
					var u := (t - 0.8) / 0.2
					r = 0.56 * sqrt(maxf(0.0, 1.0 - u * u))
		pts.append(Vector2(t, r))
	pts[pts.size() - 1] = Vector2(1.0, 0.0)
	return pts


## Surface of revolution: profile (t, r) scaled to `radius` and `length`, base at y = 0.
static func lathe(profile: PackedVector2Array, radius: float, length: float, sides: int = 20) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in profile.size() - 1:
		var a := profile[i]
		var b := profile[i + 1]
		for j in sides:
			var u0 := TAU * float(j) / float(sides)
			var u1 := TAU * float(j + 1) / float(sides)
			var p00 := Vector3(cos(u0) * a.y * radius, a.x * length, sin(u0) * a.y * radius)
			var p01 := Vector3(cos(u1) * a.y * radius, a.x * length, sin(u1) * a.y * radius)
			var p10 := Vector3(cos(u0) * b.y * radius, b.x * length, sin(u0) * b.y * radius)
			var p11 := Vector3(cos(u1) * b.y * radius, b.x * length, sin(u1) * b.y * radius)
			st.add_vertex(p00)
			st.add_vertex(p10)
			st.add_vertex(p11)
			st.add_vertex(p00)
			st.add_vertex(p11)
			st.add_vertex(p01)
	st.generate_normals()
	return st.commit()


## One flat fin in the XY plane: root along y (top at y = 0 going down), span along +x.
static func fin_mesh(root: float, tip: float, span: float, sweep: float, thickness: float) -> ArrayMesh:
	var outline := [Vector2(0, 0), Vector2(span, -sweep), Vector2(span, -sweep - tip), Vector2(0, -root)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := thickness / 2.0
	for z: float in [h, -h]:
		var tri := [0, 1, 2, 0, 2, 3] if z > 0 else [0, 2, 1, 0, 3, 2]
		for idx: int in tri:
			var p: Vector2 = outline[idx]
			st.add_vertex(Vector3(p.x, p.y, z))
	for i in 4:
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % 4]
		st.add_vertex(Vector3(a.x, a.y, h))
		st.add_vertex(Vector3(a.x, a.y, -h))
		st.add_vertex(Vector3(b.x, b.y, -h))
		st.add_vertex(Vector3(a.x, a.y, h))
		st.add_vertex(Vector3(b.x, b.y, -h))
		st.add_vertex(Vector3(b.x, b.y, h))
	st.generate_normals()
	return st.commit()


static func mat(color: Color, roughness: float = 0.55) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Engine bells as stepped cones of dark round plates, hanging below `at`.
static func bells_into(kit: BrickKit, at: Vector3, radius: float, count: int, height: float) -> void:
	var ring := 0.0 if count == 1 else radius * 0.55
	var bell_r := radius * (0.75 if count == 1 else clampf(1.2 / float(count), 0.3, 0.5))
	for i in count:
		var a := TAU * float(i) / float(count)
		kit.add_cone(at + Vector3(cos(a) * ring, -height, sin(a) * ring), bell_r, bell_r * 0.35, maxf(height, 0.001), Color("4a443d"))


func _fins(kit: BrickKit, fins: Dictionary, top_y: float, body_r: float, s: float) -> void:
	var count := int(fins.get("count", 0))
	var span := float(fins.get("span_m", 0.0)) * s
	if count <= 0 or span <= 0.0:
		return
	for i in count:
		var spin := Transform3D(Basis(Vector3.UP, TAU * float(i) / float(count) + PI / 4.0), Vector3.ZERO)
		kit.xform = spin * Transform3D(Basis.IDENTITY, Vector3(body_r * 0.95, top_y, 0))
		kit.add_fin(float(fins.get("root_chord_m", 0.0)) * s, float(fins.get("tip_chord_m", 0.0)) * s,
				span, float(fins.get("sweep_m", 0.0)) * s, maxf(0.02, body_r * 0.08), FIN_COLOR)
	kit.xform = Transform3D.IDENTITY


## Number of bricks in the current model (for tests).
func brick_count() -> int:
	var n := 0
	for holder in get_children():
		for mmi in holder.get_children():
			if mmi is MultiMeshInstance3D:
				n += (mmi as MultiMeshInstance3D).multimesh.instance_count
	return n
