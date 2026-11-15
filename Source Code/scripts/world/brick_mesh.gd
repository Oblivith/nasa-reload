# SI assistance metadata: This code used the help of SI.
class_name BrickMesh
extends RefCounted

const SHADER_DIR := "res://scripts/world/shaders/"
const OPAQUE := {
	"matte": [0, 0.8, 0.34, 0.0, 1],
	"gloss": [0, 0.8, 0.16, 0.0, 1],
	"metal": [0, 0.8, 0.26, 0.35, 0],
	"tile": [1, 0.8, 0.2, 0.0, 1],
	"grid": [2, 0.8, 0.5, 0.0, 0],
	"concrete": [3, 3.2, 0.42, 0.0, 1],
	"carpet": [4, 0.8, 0.55, 0.0, 1],
	"wood": [5, 0.16, 0.28, 0.0, 1],
}

const STUD_PITCH := 0.4
const STUD_R := 0.12
const STUD_H := 0.07
const STUD_SIDES := 8

const STUD_BAKE_MAX := 64

static var _materials: Dictionary = {}
static var _stud_mesh: ArrayMesh
static var _unit: PackedVector3Array = PackedVector3Array()
static var _unit_n: PackedVector3Array = PackedVector3Array()
static var _unit_r: PackedVector3Array = PackedVector3Array()
static var _unit_u: PackedVector3Array = PackedVector3Array()

var _v: Dictionary = {}
var _n: Dictionary = {}
var _c: Dictionary = {}
var _uv: Dictionary = {}
var _uv2: Dictionary = {}
var _tan: Dictionary = {}
var colliders: Array = []
var boxes: int = 0

var auto_studs: bool = true

var stud_world_grid: bool = false

var stud_clip: Rect2 = Rect2()

var stud_exclude: Array = []

var solids: Array = []
var _tops: Array = []

static func material(surface: String) -> Material:
	if _materials.has(surface):
		return _materials[surface]
	var result: Material
	if OPAQUE.has(surface):
		var spec: Array = OPAQUE[surface]
		var sm := ShaderMaterial.new()
		sm.shader = load(SHADER_DIR + "surface.gdshader")
		sm.set_shader_parameter("pattern", spec[0])
		sm.set_shader_parameter("scale", spec[1])
		sm.set_shader_parameter("rough", spec[2])
		sm.set_shader_parameter("metal", spec[3])
		result = sm
	elif surface == "beam":
		var beam := ShaderMaterial.new()
		beam.shader = load(SHADER_DIR + "beam.gdshader")
		result = beam
	elif surface == "glass":
		var gm := StandardMaterial3D.new()
		gm.vertex_color_use_as_albedo = true
		gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gm.roughness = 0.08
		gm.cull_mode = BaseMaterial3D.CULL_DISABLED
		result = gm
	else:
		var em := ShaderMaterial.new()
		em.shader = load(SHADER_DIR + "glow.gdshader")
		em.set_shader_parameter("energy", 1.25 if surface == "screen" else 1.7)
		em.set_shader_parameter("blink", surface == "blink")
		em.set_shader_parameter("scanlines", surface == "screen")
		result = em
	_materials[surface] = result
	return result

static func lamp_material(color: Color, energy: float = 1.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color * energy
	return m

static func _ensure_unit() -> void:
	if not _unit.is_empty():
		return
	var ups := [
		[Vector3.RIGHT, Vector3.UP], [Vector3.LEFT, Vector3.UP],
		[Vector3.FORWARD, Vector3.UP], [Vector3.BACK, Vector3.UP],
		[Vector3.UP, Vector3.FORWARD], [Vector3.DOWN, Vector3.BACK],
	]
	for pair: Array in ups:
		var n: Vector3 = pair[0]
		var u: Vector3 = pair[1]
		var r := u.cross(n)
		var bl := (n - r - u) * 0.5
		var tl := (n - r + u) * 0.5
		var tr := (n + r + u) * 0.5
		var br := (n + r - u) * 0.5
		for p: Vector3 in [bl, tl, tr, bl, tr, br]:
			_unit.append(p)
			_unit_n.append(n)
			_unit_r.append(r)
			_unit_u.append(u)

func _ensure(surface: String) -> void:
	if not _v.has(surface):
		_v[surface] = PackedVector3Array()
		_n[surface] = PackedVector3Array()
		_c[surface] = PackedColorArray()
		_uv[surface] = PackedVector2Array()
		_uv2[surface] = PackedVector2Array()
		_tan[surface] = PackedFloat32Array()

func box(center: Vector3, size: Vector3, color: Color, surface: String = "matte", basis: Basis = Basis.IDENTITY,
		shade_lo: float = 1.0, shade_hi: float = 1.0, uv: Vector2 = Vector2.ZERO) -> void:
	_ensure_unit()
	_ensure(surface)
	var v: PackedVector3Array = _v[surface]
	var n: PackedVector3Array = _n[surface]
	var c: PackedColorArray = _c[surface]
	var t: PackedVector2Array = _uv[surface]
	var t2: PackedVector2Array = _uv2[surface]
	var tg: PackedFloat32Array = _tan[surface]
	var face := OPAQUE.has(surface)
	var lo := Color(color.r * shade_lo, color.g * shade_lo, color.b * shade_lo, color.a)
	var hi := Color(color.r * shade_hi, color.g * shade_hi, color.b * shade_hi, color.a)
	var plain := basis == Basis.IDENTITY
	for i in 36:
		var u := _unit[i]
		var p := u * size
		if plain:
			v.append(center + p)
			n.append(_unit_n[i])
		else:
			v.append(center + basis * p)
			n.append(basis * _unit_n[i])
		c.append(hi if u.y > 0.0 else lo)
		var fr := _unit_r[i]
		var fu := _unit_u[i]
		if face:
			t.append(Vector2(p.dot(fr), p.dot(fu)))
			t2.append(Vector2(absf(size.dot(fr)), absf(size.dot(fu))) * 0.5)
		else:
			t.append(uv)
			t2.append(Vector2.ZERO)
		var tr := fr if plain else basis * fr
		tg.append(tr.x)
		tg.append(tr.y)
		tg.append(tr.z)
		tg.append(1.0)
	_v[surface] = v
	_n[surface] = n
	_c[surface] = c
	_uv[surface] = t
	_uv2[surface] = t2
	_tan[surface] = tg
	boxes += 1
	if plain:
		solids.append(AABB(center - size.abs() * 0.5, size.abs()))
	if auto_studs and face and int(OPAQUE[surface][4]) > 0 and (plain or basis.y.y > 0.95) \
			and absf(size.x) >= STUD_PITCH * 0.92 and absf(size.z) >= STUD_PITCH * 0.92:
		_tops.append([center + (Vector3.UP if plain else basis.y) * absf(size.y) * 0.5, basis, absf(size.x) * 0.5, absf(size.z) * 0.5, hi, surface])

func slab(a: Vector3, b: Vector3, color: Color, surface: String = "matte", shade_lo: float = 1.0, shade_hi: float = 1.0) -> void:
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	box((lo + hi) * 0.5, hi - lo, color, surface, Basis.IDENTITY, shade_lo, shade_hi)

func cyl(center: Vector3, radius: float, height: float, color: Color, surface: String = "matte", axis: int = 1,
		sides: int = 10, top_radius: float = -1.0, uv: Vector2 = Vector2.ZERO, bottom_cap: bool = true) -> void:
	_ensure(surface)
	var v: PackedVector3Array = _v[surface]
	var n: PackedVector3Array = _n[surface]
	var c: PackedColorArray = _c[surface]
	var t: PackedVector2Array = _uv[surface]
	var t2: PackedVector2Array = _uv2[surface]
	var tg: PackedFloat32Array = _tan[surface]
	var face := OPAQUE.has(surface)
	var basis := Basis.IDENTITY
	if axis == 0:
		basis = Basis(Vector3(0, 0, 1), -PI / 2.0)
	elif axis == 2:
		basis = Basis(Vector3(1, 0, 0), PI / 2.0)
	var rt := radius if top_radius < 0.0 else top_radius
	var h := height * 0.5
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var bl := d1 * radius + Vector3(0, -h, 0)
		var tl := d1 * rt + Vector3(0, h, 0)
		var tr := d0 * rt + Vector3(0, h, 0)
		var br := d0 * radius + Vector3(0, -h, 0)
		var quad := [bl, tl, tr, bl, tr, br]
		var normals := [d1, d1, d0, d1, d0, d0]
		var around := basis * Vector3(-sin(a0), 0, cos(a0))
		for k in 6:
			v.append(center + basis * (quad[k] as Vector3))
			n.append(basis * (normals[k] as Vector3))
			c.append(color)

			t.append(Vector2(0.0, (quad[k] as Vector3).y) if face else uv)
			t2.append(Vector2(1000.0, h) if face else Vector2.ZERO)
			for x: float in [around.x, around.y, around.z, -1.0]:
				tg.append(x)

		var mid := (d0 + d1).normalized()
		var caps := []
		if rt > 0.001:
			caps.append([Vector3.UP, rt, [[Vector3(0, h, 0), mid, 0.0], [tr, d0, rt], [tl, d1, rt]]])
		if bottom_cap:
			caps.append([Vector3.DOWN, radius, [[Vector3(0, -h, 0), mid, 0.0], [bl, d1, radius], [br, d0, radius]]])
		for cap: Array in caps:
			for corner: Array in cap[2]:
				v.append(center + basis * (corner[0] as Vector3))
				n.append(basis * (cap[0] as Vector3))
				c.append(color)
				t.append(Vector2(float(corner[2]), 0.0) if face else uv)
				t2.append(Vector2(float(cap[1]), 1000.0) if face else Vector2.ZERO)
				var radial := basis * (corner[1] as Vector3)
				for x: float in [radial.x, radial.y, radial.z, 1.0]:
					tg.append(x)
	_v[surface] = v
	_n[surface] = n
	_c[surface] = c
	_uv[surface] = t
	_uv2[surface] = t2
	_tan[surface] = tg
	if axis == 1:
		var reach := maxf(radius, rt)
		solids.append(AABB(center - Vector3(reach, h, reach), Vector3(reach, h, reach) * 2.0))

func collide(center: Vector3, size: Vector3, basis: Basis = Basis.IDENTITY) -> void:
	colliders.append([Transform3D(basis, center), size])

func is_empty() -> bool:
	return _v.is_empty()

func vertex_count() -> int:
	var total := 0
	for key in _v:
		total += (_v[key] as PackedVector3Array).size()
	return total

func commit(parent: Node3D, layers: int = 1, node_name: String = "Mesh") -> MeshInstance3D:
	var stud_sets := _build_studs()
	var mesh := ArrayMesh.new()
	for surface: String in _v:
		var verts: PackedVector3Array = _v[surface]
		if verts.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = _n[surface]
		arrays[Mesh.ARRAY_COLOR] = _c[surface]
		arrays[Mesh.ARRAY_TEX_UV] = _uv[surface]
		arrays[Mesh.ARRAY_TEX_UV2] = _uv2[surface]
		arrays[Mesh.ARRAY_TANGENT] = _tan[surface]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material(surface))
	if mesh.get_surface_count() == 0:
		return null
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.layers = layers
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	for surface: String in stud_sets:
		var points: Array = stud_sets[surface]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = stud_mesh()
		mm.instance_count = points.size()
		for i in points.size():
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, (points[i] as Array)[0]))
			mm.set_instance_color(i, (points[i] as Array)[1])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Studs_" + surface
		mmi.multimesh = mm
		mmi.material_override = material(surface)
		mmi.layers = layers
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 46.0
		mmi.visibility_range_end_margin = 4.0
		mi.add_child(mmi)
	return mi

func build_body(parent: Node3D, layer: int = 1) -> StaticBody3D:
	if colliders.is_empty():
		return null
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = layer
	body.collision_mask = 0
	build_body_shapes(body)
	parent.add_child(body)
	return body

func build_body_shapes(body: CollisionObject3D) -> void:
	for entry: Array in colliders:
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = entry[1]
		shape.shape = bs
		shape.transform = entry[0]
		body.add_child(shape)

static func stud_mesh() -> ArrayMesh:
	if _stud_mesh != null:
		return _stud_mesh
	var bm := BrickMesh.new()
	bm.auto_studs = false
	bm.cyl(Vector3(0, STUD_H * 0.5, 0), STUD_R, STUD_H, Color.WHITE, "matte", 1, STUD_SIDES, -1.0, Vector2.ZERO, false)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = bm._v["matte"]
	arrays[Mesh.ARRAY_NORMAL] = bm._n["matte"]
	arrays[Mesh.ARRAY_COLOR] = bm._c["matte"]
	arrays[Mesh.ARRAY_TEX_UV] = bm._uv["matte"]
	arrays[Mesh.ARRAY_TEX_UV2] = bm._uv2["matte"]
	arrays[Mesh.ARRAY_TANGENT] = bm._tan["matte"]
	_stud_mesh = ArrayMesh.new()
	_stud_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _stud_mesh

func _build_studs() -> Dictionary:
	var sets := {}
	var total := 0
	var p := STUD_PITCH
	for top: Array in _tops:
		var at: Vector3 = top[0]
		var basis: Basis = top[1]
		var hx: float = top[2]
		var hz: float = top[3]
		var plain := basis == Basis.IDENTITY
		var locals: Array = []
		if stud_world_grid and plain:
			var reach := STUD_R + 0.02
			for i in range(int(ceil((at.x - hx + reach) / p - 0.5)), int(floor((at.x + hx - reach) / p - 0.5)) + 1):
				for j in range(int(ceil((at.z - hz + reach) / p - 0.5)), int(floor((at.z + hz - reach) / p - 0.5)) + 1):
					locals.append(Vector3((i + 0.5) * p - at.x, 0, (j + 0.5) * p - at.z))
		else:
			var nx := int(floor(2.0 * hx / p + 0.08))
			var nz := int(floor(2.0 * hz / p + 0.08))
			for i in nx:
				for j in nz:
					locals.append(Vector3((i + 0.5 - nx * 0.5) * p, 0, (j + 0.5 - nz * 0.5) * p))
		if locals.is_empty():
			continue

		var span := absf(basis.x.x) * hx + absf(basis.z.x) * hz
		var depth := absf(basis.x.z) * hx + absf(basis.z.z) * hz
		var layer := AABB(at + Vector3(-span, 0.015, -depth), Vector3(span * 2.0, 0.03, depth * 2.0))
		var margin := Vector3(STUD_R * 0.85, 0, STUD_R * 0.85)
		var blockers: Array = []
		for box: AABB in solids:
			if box.intersects(layer):
				blockers.append(AABB(box.position - margin, box.size + margin * 2.0))
		for box: AABB in stud_exclude:
			if box.grow(0.05).intersects(layer):
				blockers.append(AABB(box.position - margin - Vector3(0, 0.1, 0), box.size + margin * 2.0 + Vector3(0, 0.2, 0)))
		for local: Vector3 in locals:
			var pos: Vector3 = at + basis * local
			if stud_clip.has_area() and not stud_clip.has_point(Vector2(pos.x, pos.z)):
				continue
			var probe := pos + Vector3(0, 0.03, 0)
			var covered := false
			for box: AABB in blockers:
				if box.has_point(probe):
					covered = true
					break
			if covered:
				continue
			var surface: String = top[5]
			if not sets.has(surface):
				sets[surface] = []
			(sets[surface] as Array).append([pos, top[4]])
			total += 1
	_tops.clear()
	if total > STUD_BAKE_MAX:
		return sets
	var was := auto_studs
	auto_studs = false
	for surface: String in sets:
		for point: Array in sets[surface]:
			cyl((point[0] as Vector3) + Vector3(0, STUD_H * 0.5, 0), STUD_R, STUD_H, point[1], surface, 1, STUD_SIDES, -1.0, Vector2.ZERO, false)
	auto_studs = was
	return {}

static func set_sheen(value: float) -> void:
	for surface: String in OPAQUE:
		(material(surface) as ShaderMaterial).set_shader_parameter("sheen", value)
	var brick := BrickKit.material(false) as ShaderMaterial
	if brick != null:
		brick.set_shader_parameter("sheen", value)
