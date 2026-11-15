# SI assistance metadata: This code used the help of SI.
class_name WorldRoom
extends Node3D

const CHUNK := 8.0
const WALL_T := 0.15
const DADO_H := 1.05
const MAX_PROP_LIGHTS := 6

var room_id: String = ""
var data: Dictionary = {}
var rect: Rect2
var base_y: float = 0.0
var height: float = 3.3
var layer_bit: int = 1
var props: Array[KitProp] = []
var people: Array = []
var lights: Array = []
var active: bool = false
var cast_shadows: bool = false

var _chunks: Dictionary = {}
var _solid: BrickMesh = BrickMesh.new()
var _flickers: Array = []
var _prop_lights: int = 0
var _kit_cache: Dictionary = {}
var _solids_seen: Array = []
var _stud_shell: bool = false

func setup(entry: Dictionary, bit: int) -> void:
	data = entry
	room_id = str(entry["id"])
	name = room_id
	layer_bit = bit
	var r: Array = entry["rect"]
	rect = Rect2(float(r[0]), float(r[1]), float(r[2]) - float(r[0]), float(r[3]) - float(r[1]))
	base_y = float(entry.get("y", 0.0))
	height = float(entry.get("h", 3.3))
	cast_shadows = bool(entry.get("sun", false))

func contains(p: Vector3) -> bool:
	return p.y >= base_y - 0.35 and p.y < base_y + height + 0.3 and rect.has_point(Vector2(p.x, p.z))

func local_point(lx: float, ly: float, lz: float) -> Vector3:
	return Vector3(rect.position.x + lx, base_y + ly, rect.position.y + lz)

func _bm_at(center: Vector3) -> BrickMesh:
	var key := Vector2i(int(floor(center.x / CHUNK)), int(floor(center.z / CHUNK)))
	if not _chunks.has(key):
		var bm := BrickMesh.new()
		bm.stud_world_grid = true
		bm.solids = _solids_seen
		bm.auto_studs = false
		_chunks[key] = bm
	return _chunks[key]

func shell(a: Vector3, b: Vector3, color: Color, surface: String = "matte", lo: float = 1.0, hi: float = 1.0) -> void:
	var p0 := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var p1 := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	var nx := maxi(1, int(ceil((p1.x - p0.x) / CHUNK)))
	var nz := maxi(1, int(ceil((p1.z - p0.z) / CHUNK)))
	for i in nx:
		for j in nz:
			var q0 := Vector3(lerpf(p0.x, p1.x, float(i) / nx), p0.y, lerpf(p0.z, p1.z, float(j) / nz))
			var q1 := Vector3(lerpf(p0.x, p1.x, float(i + 1) / nx), p1.y, lerpf(p0.z, p1.z, float(j + 1) / nz))
			var bm := _bm_at((q0 + q1) * 0.5)
			bm.auto_studs = _stud_shell
			bm.slab(q0, q1, color, surface, lo, hi)
			bm.auto_studs = false

func solid(a: Vector3, b: Vector3) -> void:
	_solid.collide((a + b) * 0.5, (b - a).abs())

func build_shell(openings: Array) -> void:
	var x0 := rect.position.x
	var x1 := rect.end.x
	var z0 := rect.position.y
	var z1 := rect.end.y
	if bool(data.get("has_floor", true)):
		_stud_shell = true
		shell(Vector3(x0, base_y - 0.2, z0), Vector3(x1, base_y, z1), Color(str(data.get("floor", "c9b28a"))), str(data.get("floor_surface", "tile")))
		_stud_shell = false
		solid(Vector3(x0, base_y - 0.5, z0), Vector3(x1, base_y, z1))
	if bool(data.get("has_ceiling", true)):
		var top := base_y + height
		shell(Vector3(x0, top, z0), Vector3(x1, top + 0.1, z1), Color(str(data.get("ceiling", "f4efe2"))), str(data.get("ceiling_surface", "grid")))
		solid(Vector3(x0, top, z0), Vector3(x1, top + 0.3, z1))
	var sides := str(data.get("sides", "nsew"))
	for side in ["n", "s", "e", "w"]:
		if sides.contains(side):
			_build_wall(side, openings)

func _build_wall(side: String, openings: Array) -> void:
	var along_x := side == "n" or side == "s"
	var a0 := rect.position.x if along_x else rect.position.y
	var a1 := rect.end.x if along_x else rect.end.y
	var c := 0.0
	match side:
		"n": c = rect.position.y
		"s": c = rect.end.y
		"w": c = rect.position.x
		"e": c = rect.end.x
	var top := base_y + height
	var cuts: Array = []
	for op: Dictionary in openings:
		if (str(op["axis"]) == "x") != along_x or room_id not in (op["rooms"] as Array):
			continue
		var oc := float(op["z"]) if along_x else float(op["x"])
		var al := float(op["x"]) if along_x else float(op["z"])
		if absf(oc - c) > 0.02 or al < a0 - 0.01 or al > a1 + 0.01:
			continue
		if float(op["y0"]) >= top - 0.01 or float(op["y1"]) <= base_y + 0.01:
			continue
		cuts.append({"lo": al - float(op["w"]) / 2.0, "hi": al + float(op["w"]) / 2.0,
				"y0": maxf(float(op["y0"]), base_y), "y1": minf(float(op["y1"]), top)})

	var edges: Array = [a0, a1]
	for cut: Dictionary in cuts:
		edges.append(clampf(float(cut["lo"]), a0, a1))
		edges.append(clampf(float(cut["hi"]), a0, a1))
	edges.sort()
	var run_lo := a0
	var run_key := "?"
	var run_cuts: Array = []
	for i in edges.size() - 1:
		var lo := float(edges[i])
		var hi := float(edges[i + 1])
		if hi - lo < 0.005:
			continue
		var covering: Array = []
		var key := ""
		for k in cuts.size():
			var cut: Dictionary = cuts[k]
			if float(cut["lo"]) <= lo + 0.005 and float(cut["hi"]) >= hi - 0.005:
				covering.append(cut)
				key += "%d," % k
		if key != run_key:
			if run_key != "?":
				_wall_slice(side, c, run_lo, lo, run_cuts)
			run_lo = lo
			run_key = key
			run_cuts = covering
	if run_key != "?":
		_wall_slice(side, c, run_lo, a1, run_cuts)

func _wall_slice(side: String, c: float, lo: float, hi: float, cuts: Array) -> void:
	var top := base_y + height
	cuts.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["y0"]) < float(q["y0"]))
	var cursor := base_y
	for cut: Dictionary in cuts:
		_wall_piece(side, c, lo, hi, cursor, float(cut["y0"]))
		cursor = maxf(cursor, float(cut["y1"]))
	_wall_piece(side, c, lo, hi, cursor, top)

func _wall_piece(side: String, c: float, lo: float, hi: float, y_lo: float, y_hi: float) -> void:
	if hi - lo < 0.02 or y_hi - y_lo < 0.02:
		return
	var along_x := side == "n" or side == "s"
	var inward := 1.0 if (side == "n" or side == "w") else -1.0
	var wall := Color(str(data.get("wall", "f2e8cf")))
	var top := base_y + height
	var corner := func(al: float, y: float, depth: float) -> Vector3:
		return Vector3(al, y, c + inward * depth) if along_x else Vector3(c + inward * depth, y, al)
	var a: Vector3 = corner.call(lo, y_lo, 0.0)
	var b: Vector3 = corner.call(hi, y_hi, WALL_T)
	solid(Vector3(minf(a.x, b.x), y_lo, minf(a.z, b.z)), Vector3(maxf(a.x, b.x), y_hi, maxf(a.z, b.z)))
	var dado_top := base_y + DADO_H
	var hi_shade := 0.86 if y_hi >= top - 0.01 else 1.0
	if data.has("dado") and y_lo < dado_top - 0.01:
		var dado := Color(str(data["dado"]))
		var split := minf(dado_top, y_hi)
		shell(a, corner.call(hi, split, WALL_T), dado, "matte", 0.74 if y_lo <= base_y + 0.01 else 1.0, 1.0)
		if y_lo <= base_y + 0.01:
			shell(corner.call(lo, y_lo, WALL_T), corner.call(hi, y_lo + 0.1, WALL_T + 0.02), dado.darkened(0.35))
		shell(corner.call(lo, split, WALL_T), corner.call(hi, split + 0.04, WALL_T + 0.015), dado.darkened(0.2))
		if y_hi > split + 0.01:
			shell(corner.call(lo, split, 0.0), b, wall, "matte", 1.0, hi_shade)
	else:
		shell(a, b, wall, "matte", 0.8 if y_lo <= base_y + 0.01 else 1.0, hi_shade)

func build_window(op: Dictionary) -> void:
	var along_x := str(op["axis"]) == "x"
	var w := float(op["w"])
	var y0 := float(op["y0"])
	var y1 := float(op["y1"])
	var center := Vector3(float(op["x"]), (y0 + y1) / 2.0, float(op["z"]))
	var bm := _bm_at(center)
	var span := Vector3(w, 0, 0) if along_x else Vector3(0, 0, w)
	var thick := Vector3(0, 0, 1) if along_x else Vector3(1, 0, 0)
	var frame := Color(str(op.get("frame", "8c8577")))
	var glass_color := Color(0.72, 0.88, 0.94, float(op.get("alpha", 0.16)))
	bm.box(center, span + thick * 0.03 + Vector3(0, y1 - y0, 0), glass_color, "glass")
	for sy: float in [y0 + 0.04, y1 - 0.04]:
		bm.box(Vector3(center.x, sy, center.z), span + thick * 0.12 + Vector3(0, 0.08, 0), frame, "metal")
	var bays := maxi(1, int(round(w / float(op.get("bay", 1.6)))))
	for i in bays + 1:
		var k := float(i) / bays - 0.5
		bm.box(center + span * k, thick * 0.12 + Vector3(0, y1 - y0, 0) + span.normalized() * 0.07, frame, "metal")
	_solid.collide(center, span + thick * 0.2 + Vector3(0, y1 - y0, 0))

static func v3(a: Variant) -> Vector3:
	var arr: Array = a
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))

func build_structure(e: Dictionary) -> void:
	var color := Color(str(e.get("color", "c9c2b0")))
	var surface := str(e.get("surface", "matte"))
	match str(e.get("type", "platform")):
		"platform":
			var a := v3(e["a"])
			var b := v3(e["b"])
			_stud_shell = bool(e.get("studs", true))
			shell(a, b, color, surface, float(e.get("lo", 1.0)), 1.0)
			_stud_shell = false
			if bool(e.get("solid", true)):
				solid(Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z)), Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z)))
		"stairs":
			_build_stairs(e, color, surface)
		"rail":
			var from := v3(e["from"])
			var to := v3(e["to"])
			var flat := to - from
			var prop := add_prop("rail", (from + to) * 0.5, rad_to_deg(atan2(-flat.z, flat.x)), {"l": flat.length(), "color": str(e.get("color", "e9c46a"))}, true)
			prop.lod_range = 0.0

func _build_stairs(e: Dictionary, color: Color, surface: String) -> void:
	var from := v3(e["from"])
	var to := v3(e["to"])
	var width := float(e.get("width", 1.6))
	var rise := to.y - from.y
	var flat := Vector3(to.x - from.x, 0, to.z - from.z)
	var run := flat.length()
	var dir := flat / run
	var side := Vector3.UP.cross(dir)
	var steps := maxi(1, int(ceil(rise / 0.2)))
	var tread := run / steps
	var fill := bool(e.get("fill", true))
	var basis := Basis(side, Vector3.UP, dir)
	var bm := _bm_at((from + to) * 0.5)
	for i in steps:
		bm.auto_studs = true
		var top := from.y + rise * (i + 1) / steps
		var bottom := float(e.get("base", from.y)) if fill else top - 0.1
		var pos := from + dir * (tread * (i + 0.5))
		pos.y = (top + bottom) / 2.0
		bm.box(pos, Vector3(width, top - bottom, tread), color if i % 2 == 0 else color.darkened(0.06), surface, basis)
	bm.auto_studs = false

	var slope := (to - from).normalized()
	var ramp_y := slope.cross(side)
	var ramp_basis := Basis(side, ramp_y, slope)
	var length := (to - from).length()
	var mid := (from + to) * 0.5 - dir * (tread * 0.5) - ramp_y * 0.15
	_solid.collide(mid, Vector3(width, 0.3, length), ramp_basis)
	var rail_color := Color(str(e.get("rail_color", "e9c46a")))
	var rails := str(e.get("rail", ""))
	for sgn: float in [-1.0, 1.0]:
		if (sgn < 0.0 and not (rails == "left" or rails == "both")) or (sgn > 0.0 and not (rails == "right" or rails == "both")):
			continue
		var off := side * sgn * (width / 2.0 - 0.04)
		var rail_mid := (from + to) * 0.5 + off
		bm.box(rail_mid + Vector3(0, 1.0, 0), Vector3(0.06, 0.06, length), rail_color, "metal", ramp_basis)
		bm.box(rail_mid + Vector3(0, 0.5, 0), Vector3(0.04, 0.04, length), rail_color, "metal", ramp_basis)
		var posts := maxi(2, int(run / 1.5) + 1)
		for p in posts:
			var k := float(p) / (posts - 1)
			bm.box(from.lerp(to, k) + off + Vector3(0, 0.5, 0), Vector3(0.05, 1.05, 0.05), rail_color, "metal")
		_solid.collide(rail_mid + Vector3(0, 0.6, 0), Vector3(0.1, 1.5, length), ramp_basis)

func add_prop(kind: String, at: Vector3, rot_deg: float, options: Dictionary, world_space: bool = true) -> KitProp:
	var prop: KitProp = null
	if not _kit_cache.has(kind):
		var path := "res://scenes/world/kit/%s.tscn" % kind
		_kit_cache[kind] = load(path) if ResourceLoader.exists(path) else null
	var packed: PackedScene = _kit_cache[kind]
	if packed != null:
		prop = packed.instantiate() as KitProp
	if prop == null:
		prop = KitProp.new()
	prop.name = "%s_%d" % [kind, props.size()]
	prop.position = at if world_space else local_point(at.x, at.y, at.z)
	prop.rotation.y = deg_to_rad(rot_deg)
	var opts := options.duplicate()
	if not opts.has("seed"):
		opts["seed"] = props.size() + hash(room_id) % 1000
	prop.setup(kind, opts, layer_bit)
	if cast_shadows and prop.mesh_instance != null:
		prop.mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(prop)
	props.append(prop)
	for lamp: Dictionary in prop.lamps:
		_add_prop_light(prop, lamp)
	return prop

func _add_prop_light(prop: KitProp, lamp: Dictionary) -> void:
	if _prop_lights >= int(data.get("max_prop_lights", MAX_PROP_LIGHTS)):
		return
	_prop_lights += 1
	var light: Light3D
	if bool(lamp.get("spot", false)):
		var spot := SpotLight3D.new()
		spot.spot_range = float(lamp["range"])
		spot.spot_angle = 58.0
		spot.spot_attenuation = 0.7
		spot.rotation.x = -PI / 2.0
		light = spot
	else:
		var omni := OmniLight3D.new()
		omni.omni_range = float(lamp["range"])
		omni.omni_attenuation = 1.3
		light = omni
	light.light_color = lamp["color"]
	light.light_energy = float(lamp["energy"])
	light.light_specular = 0.3
	light.light_cull_mask = layer_bit | 1
	light.position = lamp["pos"]
	prop.add_child(light)
	lights.append({"light": light, "energy": light.light_energy})

func add_sign(e: Dictionary) -> Label3D:
	var at: Array = e["at"]
	var label := Label3D.new()
	label.text = str(e.get("text", ""))
	label.font = ConsoleTheme.typewriter()
	label.font_size = int(e.get("size", 64))
	label.pixel_size = 0.004
	label.modulate = Color(str(e.get("color", "2b2622")))
	label.outline_size = 0
	label.position = local_point(float(at[0]), float(at[1]), float(at[2]))
	label.rotation.y = {"s": 0.0, "n": PI, "e": PI / 2.0, "w": -PI / 2.0}.get(str(e.get("face", "s")), 0.0)
	label.layers = layer_bit
	label.visibility_range_end = float(e.get("range", 45.0))
	if e.has("width"):
		label.width = float(e["width"]) / 0.004
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
	return label

func build_lights() -> void:
	var spec: Dictionary = data.get("lights", {})
	var kind := str(spec.get("kind", "fluoro"))
	var top := base_y + height
	if kind == "fluoro":
		var nx := int(spec.get("nx", 2))
		var nz := int(spec.get("nz", 1))
		var color := Color(str(spec.get("color", "e4eeff")))
		var energy := float(spec.get("energy", 1.0))
		var cell := maxf(rect.size.x / nx, rect.size.y / nz)
		var flicker: Array = spec.get("flicker", [])
		var long_x := rect.size.x / nx >= rect.size.y / nz
		var panel_size := Vector3(1.3, 0.05, 0.34) if long_x else Vector3(0.34, 0.05, 1.3)
		var index := 0
		for i in nx:
			for j in nz:
				var p := Vector3(rect.position.x + (i + 0.5) * rect.size.x / nx, top - 0.03, rect.position.y + (j + 0.5) * rect.size.y / nz)
				var light := OmniLight3D.new()
				light.position = p - Vector3(0, minf(0.7, height * 0.2), 0)
				light.light_color = color
				light.light_energy = energy
				light.light_specular = 0.25
				light.omni_range = float(spec.get("range", cell * 0.8 + 3.0 + height * 0.3))
				light.omni_attenuation = float(spec.get("attenuation", 0.9))
				light.light_cull_mask = layer_bit | 1
				add_child(light)
				var entry := {"light": light, "energy": energy}
				var offsets := [Vector3.ZERO]
				if bool(spec.get("double", true)):
					offsets = [Vector3(0, 0, -0.3), Vector3(0, 0, 0.3)] if long_x else [Vector3(-0.3, 0, 0), Vector3(0.3, 0, 0)]
				if float(index) in flicker or index in flicker:
					var mi := MeshInstance3D.new()
					var bmesh := BoxMesh.new()
					bmesh.size = panel_size + (Vector3(0, 0, 0.6) if long_x else Vector3(0.6, 0, 0))
					mi.mesh = bmesh
					mi.position = p
					mi.layers = layer_bit
					mi.material_override = BrickMesh.lamp_material(color, 1.7)
					add_child(mi)
					entry["panel"] = mi.material_override
					entry["color"] = color
					entry["t"] = 0.0
					_flickers.append(entry)
				else:
					for off: Vector3 in offsets:
						_bm_at(p).box(p + off, panel_size, color, "glow")
				_bm_at(p).box(p + Vector3(0, 0.035, 0), Vector3(1.45, 0.03, 1.05) if long_x else Vector3(1.05, 0.03, 1.45), Color("d9d4c6"), "matte")
				lights.append(entry)
				index += 1
	for extra: Dictionary in spec.get("extra", []):
		var at: Array = extra["at"]
		var omni := OmniLight3D.new()
		omni.position = local_point(float(at[0]), float(at[1]), float(at[2]))
		omni.light_color = Color(str(extra.get("color", "ffe6c0")))
		omni.light_energy = float(extra.get("energy", 0.6))
		omni.omni_range = float(extra.get("range", 8.0))
		omni.omni_attenuation = float(extra.get("attenuation", 1.0))
		omni.light_specular = 0.2
		omni.light_cull_mask = layer_bit | 1
		add_child(omni)
		lights.append({"light": omni, "energy": omni.light_energy})

func finish() -> void:

	var flat: Array = []
	for prop in props:
		if prop.mesh_instance != null:
			var box: AABB = prop.transform * prop.mesh_instance.get_aabb()
			if box.size.y < 0.2 and box.size.x * box.size.z > 0.5:
				flat.append(box)
	var index := 0
	for key: Vector2i in _chunks:
		(_chunks[key] as BrickMesh).stud_exclude = flat
		var mi := (_chunks[key] as BrickMesh).commit(self, layer_bit, "Shell%d" % index)
		if mi != null:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		index += 1
	_solid.build_body(self)
	_chunks.clear()
	set_process(false)

func chunk_count() -> int:
	return _chunks.size()

func set_active(on: bool) -> void:
	if active == on:
		return
	active = on
	visible = on
	for prop in props:
		prop.set_active(on)
	for person: Node in people:
		person.call("set_active", on)
	set_process(on and not _flickers.is_empty())

func _process(delta: float) -> void:
	for f: Dictionary in _flickers:
		f["t"] = float(f["t"]) - delta
		if float(f["t"]) > 0.0:
			continue
		var on := randf() < 0.72
		f["t"] = randf_range(0.03, 0.18) if not on else randf_range(0.05, 1.6)
		var k := 1.0 if on else randf_range(0.05, 0.35)
		(f["light"] as Light3D).light_energy = float(f["energy"]) * k
		(f["panel"] as StandardMaterial3D).albedo_color = (f["color"] as Color) * (1.7 * k)
