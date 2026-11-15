# Code generated with AI assistance (Claude). Reviewed by team.
class_name BrickMesh
extends RefCounted
## Builds placeholder geometry cheaply: boxes and cylinders are appended into ONE
## vertex-coloured ArrayMesh with a surface per material, so a whole room shell or prop
## costs a handful of draw calls instead of one per box (this is what keeps the Web
## export fast). Colliders are collected separately so only what should block does.
##
##   var bm := BrickMesh.new()
##   bm.box(Vector3(0, 0.5, 0), Vector3(2, 1, 1), Color("8c6a4a"))
##   bm.collide(Vector3(0, 0.5, 0), Vector3(2, 1, 1))
##   bm.commit(self); bm.build_body(self)
##
## Surfaces: matte, gloss, metal, tile, grid, concrete, carpet, wood (lit, see
## surface.gdshader); glow, screen, blink (unshaded emissive, glow.gdshader); glass.

const SHADER_DIR := "res://scripts/world/shaders/"
const OPAQUE := {
	"matte": [0, 1.0, 0.85, 0.0],      # pattern, scale, roughness, metallic
	"gloss": [0, 1.0, 0.32, 0.0],
	"metal": [0, 1.0, 0.38, 0.55],
	"tile": [1, 0.6, 0.4, 0.0],
	"grid": [2, 0.6, 0.9, 0.0],
	"concrete": [3, 3.0, 0.92, 0.0],
	"carpet": [4, 1.0, 1.0, 0.0],
	"wood": [5, 0.14, 0.6, 0.0],
}

static var _materials: Dictionary = {}
static var _unit: PackedVector3Array = PackedVector3Array()
static var _unit_n: PackedVector3Array = PackedVector3Array()

var _v: Dictionary = {}       # surface -> PackedVector3Array
var _n: Dictionary = {}
var _c: Dictionary = {}       # surface -> PackedColorArray
var _uv: Dictionary = {}      # surface -> PackedVector2Array
var colliders: Array = []     # [[Transform3D, Vector3 size], ...]
var boxes: int = 0


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


## A fresh emissive material (not shared), for lamps a script switches on and off.
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


func _ensure(surface: String) -> void:
	if not _v.has(surface):
		_v[surface] = PackedVector3Array()
		_n[surface] = PackedVector3Array()
		_c[surface] = PackedColorArray()
		_uv[surface] = PackedVector2Array()


## A box. `shade_lo` / `shade_hi` darken the bottom / top vertices (a baked-in
## ambient-occlusion gradient for walls). `uv` is free data for the blink shader.
func box(center: Vector3, size: Vector3, color: Color, surface: String = "matte", basis: Basis = Basis.IDENTITY,
		shade_lo: float = 1.0, shade_hi: float = 1.0, uv: Vector2 = Vector2.ZERO) -> void:
	_ensure_unit()
	_ensure(surface)
	var v: PackedVector3Array = _v[surface]
	var n: PackedVector3Array = _n[surface]
	var c: PackedColorArray = _c[surface]
	var t: PackedVector2Array = _uv[surface]
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
		t.append(uv)
	_v[surface] = v
	_n[surface] = n
	_c[surface] = c
	_uv[surface] = t
	boxes += 1


## Box given by two opposite corners.
func slab(a: Vector3, b: Vector3, color: Color, surface: String = "matte", shade_lo: float = 1.0, shade_hi: float = 1.0) -> void:
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	box((lo + hi) * 0.5, hi - lo, color, surface, Basis.IDENTITY, shade_lo, shade_hi)


## A cylinder (or cone/frustum with `top_radius`) along axis 0 = x, 1 = y, 2 = z.
func cyl(center: Vector3, radius: float, height: float, color: Color, surface: String = "matte", axis: int = 1,
		sides: int = 10, top_radius: float = -1.0, uv: Vector2 = Vector2.ZERO) -> void:
	_ensure(surface)
	var v: PackedVector3Array = _v[surface]
	var n: PackedVector3Array = _n[surface]
	var c: PackedColorArray = _c[surface]
	var t: PackedVector2Array = _uv[surface]
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
		for k in 6:
			v.append(center + basis * (quad[k] as Vector3))
			n.append(basis * (normals[k] as Vector3))
			c.append(color)
			t.append(uv)
		if rt > 0.001:
			for p: Vector3 in [Vector3(0, h, 0), tr, tl]:
				v.append(center + basis * p)
				n.append(basis * Vector3.UP)
				c.append(color)
				t.append(uv)
		for p: Vector3 in [Vector3(0, -h, 0), bl, br]:
			v.append(center + basis * p)
			n.append(basis * Vector3.DOWN)
			c.append(color)
			t.append(uv)
	_v[surface] = v
	_n[surface] = n
	_c[surface] = c
	_uv[surface] = t


## Marks a box as solid (it blocks the player once build_body() is called).
func collide(center: Vector3, size: Vector3, basis: Basis = Basis.IDENTITY) -> void:
	colliders.append([Transform3D(basis, center), size])


func is_empty() -> bool:
	return _v.is_empty()


func vertex_count() -> int:
	var total := 0
	for key in _v:
		total += (_v[key] as PackedVector3Array).size()
	return total


## Turns everything added so far into one MeshInstance3D under `parent`.
func commit(parent: Node3D, layers: int = 1, node_name: String = "Mesh") -> MeshInstance3D:
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
	return mi


## One StaticBody3D holding every collide() box.
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


## Adds every collide() box as a shape on an existing physics body.
func build_body_shapes(body: CollisionObject3D) -> void:
	for entry: Array in colliders:
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = entry[1]
		shape.shape = bs
		shape.transform = entry[0]
		body.add_child(shape)
