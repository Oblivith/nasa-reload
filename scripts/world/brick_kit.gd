# Code generated with AI assistance (Claude). Reviewed by team.
class_name BrickKit
extends RefCounted
## Toy-brick construction kit: every non-character 3D thing in the game (floors, walls,
## furniture, machines, rockets) is assembled from these studded bricks.
##
## The brick geometry follows the open stud-brick standard used by the LDraw parts
## library (CC BY 2.0): 1 stud pitch = 20 LDU, brick height = 24 LDU (1.2 pitch),
## plate = 8 LDU (0.4 pitch), stud = 12 LDU across and 4 LDU tall. Meshes are built in
## code from those numbers (no imported files), in "pitch units", and scaled per brick.
##
## Usage:
##   var kit := BrickKit.new(0.4)          # 0.4 m stud pitch
##   kit.add_box(center, size, color)     # fills the box with a staggered brick bond
##   kit.add_cylinder(center, r, h, color)
##   kit.commit(parent)                   # one MultiMeshInstance3D per brick type

const BRICK_H := 1.2
const PLATE_H := 0.4
const STUD_R := 0.3
const STUD_H := 0.2
const GAP := 0.012        # seam between neighbouring bricks, per side

static var _meshes := {}
static var _materials := {}

## Default stud pitch in metres for this kit.
var pitch := 0.4
## Applied to everything added after it is set (e.g. a fin's holder transform).
var xform := Transform3D.IDENTITY
## Random lightness variation per brick, so walls read as individual bricks.
var jitter := 0.035
var _items := {}
var _rng := RandomNumberGenerator.new()


func _init(stud_pitch: float = 0.4, seed_value: int = 1) -> void:
	pitch = stud_pitch
	_rng.seed = seed_value


# --- Building ------------------------------------------------------------------------

## Fills an axis-aligned box (in kit space) with bricks, or plates when it is thin.
## Long horizontal axis gets 1x2 bricks in a running bond; only the shell is placed.
func add_box(center: Vector3, size: Vector3, color: Color, p: float = -1.0) -> void:
	if p <= 0.0:
		p = pitch
	size = size.abs()
	var along_x := size.x >= size.z
	var long_len := size.x if along_x else size.z
	var short_len := size.z if along_x else size.x
	var n_long := maxi(1, roundi(long_len / p))
	var n_short := maxi(1, roundi(short_len / p))
	var plates := size.y < 0.8 * BRICK_H * p
	var unit_h := PLATE_H if plates else BRICK_H
	var n_y := maxi(1, roundi(size.y / (unit_h * p)))
	var cl := long_len / n_long
	var cs := short_len / n_short
	var cy := size.y / n_y
	var rot := Basis.IDENTITY if along_x else Basis(Vector3.UP, PI / 2.0)
	var kind1 := "plate1" if plates else "brick1"
	var kind2 := "plate2" if plates else "brick2"
	for iy in n_y:
		var y := -size.y / 2.0 + cy * (iy + 0.5)
		for js in n_short:
			var s := -short_len / 2.0 + cs * (js + 0.5)
			var i := 0
			var first := true
			while i < n_long:
				var span := 2
				if (first and (iy + js) % 2 == 1) or i + 1 >= n_long:
					span = 1
				first = false
				var shell := iy == 0 or iy == n_y - 1 or js == 0 or js == n_short - 1 \
						or i == 0 or i + span >= n_long
				if shell:
					var l := -long_len / 2.0 + cl * (i + span / 2.0)
					var local := Vector3(l, y, s) if along_x else Vector3(s, y, l)
					var b := rot * Basis.from_scale(Vector3(cl, cy / unit_h, cs))
					_put(kind2 if span == 2 else kind1, Transform3D(b, center + local), color)
				i += span


## A vertical stack of round bricks (round plates when short). `center` is its middle.
func add_cylinder(center: Vector3, radius: float, height: float, color: Color, p: float = -1.0) -> void:
	if p <= 0.0:
		p = pitch
	height = maxf(height, 0.001)
	var plates := height < 0.8 * BRICK_H * p
	var unit_h := PLATE_H if plates else BRICK_H
	var n := maxi(1, roundi(height / (unit_h * p)))
	var lh := height / n
	for i in n:
		_round_layer(center + Vector3(0, -height / 2.0 + lh * (i + 0.5), 0), radius, lh, unit_h, color, p)


## Stepped cone of round plates from `r_bottom` at `base` up to `r_top` at base + height.
func add_cone(base: Vector3, r_bottom: float, r_top: float, height: float, color: Color, p: float = -1.0) -> void:
	var profile := PackedVector2Array([Vector2(0, 1), Vector2(1, r_top / maxf(r_bottom, 0.0001))])
	add_profile(base, profile, r_bottom, height, color, p)


## Stepped solid of revolution: profile points (t, r) from t = 0 at `base` to t = 1 on top.
func add_profile(base: Vector3, profile: PackedVector2Array, radius: float, length: float, color: Color, p: float = -1.0) -> void:
	if p <= 0.0:
		p = pitch
	length = maxf(length, 0.001)
	var n := maxi(2, roundi(length / (PLATE_H * p)))
	var lh := length / n
	for i in n:
		var r := radius * _profile_r(profile, (i + 0.5) / n)
		if r < radius * 0.04:
			continue
		_round_layer(base + Vector3(0, lh * (i + 0.5), 0), r, lh, PLATE_H, color, p)


## Flat fin in the XY plane (root along y going down from 0, span along +x), as rows of
## plates on their side: each row is as long as the fin is wide at that height.
func add_fin(root: float, tip: float, span: float, sweep: float, thickness: float, color: Color, p: float = -1.0) -> void:
	if p <= 0.0:
		p = pitch
	if span <= 0.0 or root <= 0.0:
		return
	var n_rows := maxi(1, roundi(root / p))
	var n_cols := maxi(1, roundi(span / p))
	var rh := root / n_rows
	var cw := span / n_cols
	for j in n_rows:
		var yc := -rh * (j + 0.5)
		for i in n_cols:
			var x := cw * (i + 0.5)
			var le := -sweep * x / span
			var te := -root + (root - sweep - tip) * x / span
			if yc <= le and yc >= te:
				# A 1x1 plate lying on its side: studs face +z.
				var b := Basis(Vector3.RIGHT, PI / 2.0) * Basis.from_scale(Vector3(cw, thickness / PLATE_H, rh))
				_put("plate1", Transform3D(b, Vector3(x, yc, 0)), color)


## Places one brick of `kind` with an explicit transform (scale in metres per pitch unit).
func add_brick(kind: String, t: Transform3D, color: Color) -> void:
	_put(kind, t, color)


func is_empty() -> bool:
	return _items.is_empty()


## Turns everything added so far into MultiMeshInstance3Ds under `parent`; returns the holder.
func commit(parent: Node, node_name: String = "Bricks") -> Node3D:
	var holder := Node3D.new()
	holder.name = node_name
	for key: String in _items:
		var entry: Dictionary = _items[key]
		var parts := key.split("|")
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh(parts[0])
		var ts: Array = entry["t"]
		var cs: Array = entry["c"]
		mm.instance_count = ts.size()
		for i in ts.size():
			mm.set_instance_transform(i, ts[i])
			mm.set_instance_color(i, cs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = material(parts[1] == "a")
		holder.add_child(mmi)
	if parent != null:
		parent.add_child(holder)
	return holder


# --- Shared meshes and materials ----------------------------------------------------

## Brick meshes in pitch units, centred on their body: brick1, brick2, plate1, plate2,
## round, round_plate, round_big, round_big_plate (the big round is a 4x4 round brick).
static func mesh(kind: String) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := PLATE_H if kind.ends_with("plate") or kind.begins_with("plate") else BRICK_H
	match kind:
		"brick1", "plate1":
			_block(st, 1, h)
		"brick2", "plate2":
			_block(st, 2, h)
		"round", "round_plate":
			_cyl(st, Vector3(0, -h / 2.0, 0), 0.5 - GAP, h, 20, 1.0)
			_cyl(st, Vector3(0, h / 2.0, 0), STUD_R, STUD_H, 12, 1.0)
		"round_big", "round_big_plate":
			_cyl(st, Vector3(0, -h / 2.0, 0), 0.5 - GAP / 4.0, h, 28, 1.0)
			for gx in 4:
				for gz in 4:
					var c := Vector2(-0.375 + gx * 0.25, -0.375 + gz * 0.25)
					if c.length() < 0.45:
						_cyl(st, Vector3(c.x, h / 2.0, c.y), STUD_R / 4.0, STUD_H, 10, 1.0)
	var m := st.commit()
	_meshes[kind] = m
	return m


## Glossy ABS-plastic look; colour comes from each brick instance.
static func material(transparent: bool = false) -> Material:
	if _materials.has(transparent):
		return _materials[transparent]
	if not transparent:
		var sm := ShaderMaterial.new()
		sm.shader = load("res://scripts/world/shaders/brick.gdshader")
		_materials[transparent] = sm
		return sm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.08
	m.metallic_specular = 0.8
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_materials[transparent] = m
	return m


## A single brick as its own MeshInstance3D (for blinking lights and other lone pieces):
## `size` in metres, studs on top; pass a material to override the shared plastic.
static func single(kind: String, size: Vector3, color: Color, mat: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh(kind)
	var unit_w := 2.0 if kind.ends_with("2") else 1.0
	var unit_h := PLATE_H if kind.contains("plate") else BRICK_H
	mi.scale = Vector3(size.x / unit_w, size.y / unit_h, size.z)
	if mat == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.16
		m.metallic_specular = 0.75
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		if color.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat = m
	mi.material_override = mat
	return mi


# --- Internals -----------------------------------------------------------------------

func _round_layer(center: Vector3, radius: float, layer_h: float, unit_h: float, color: Color, p: float) -> void:
	var d := maxf(radius * 2.0, 0.002)
	var big := d >= 2.5 * p
	var kind := ("round_big" if big else "round") + ("_plate" if unit_h == PLATE_H else "")
	var mesh_h := PLATE_H if unit_h == PLATE_H else BRICK_H
	_put(kind, Transform3D(Basis.from_scale(Vector3(d, layer_h / mesh_h, d)), center), color)


func _put(kind: String, t: Transform3D, color: Color) -> void:
	var key := kind + ("|a" if color.a < 0.999 else "|o")
	if not _items.has(key):
		_items[key] = {"t": [], "c": []}
	var c := color
	if jitter > 0.0:
		var j := _rng.randf_range(-jitter, jitter)
		c = color.lightened(j) if j > 0.0 else color.darkened(-j)
		c.a = color.a
	(_items[key]["t"] as Array).append(xform * t)
	(_items[key]["c"] as Array).append(c)


static func _profile_r(profile: PackedVector2Array, t: float) -> float:
	for i in profile.size() - 1:
		var a := profile[i]
		var b := profile[i + 1]
		if t <= b.x:
			return lerpf(a.y, b.y, clampf((t - a.x) / maxf(b.x - a.x, 0.0001), 0.0, 1.0))
	return profile[profile.size() - 1].y


static func _block(st: SurfaceTool, nx: int, h: float) -> void:
	var hx := nx * 0.5 - GAP
	var hz := 0.5 - GAP
	_cuboid(st, Vector3(-hx, -h / 2.0, -hz), Vector3(hx, h / 2.0, hz))
	for i in nx:
		_cyl(st, Vector3(-nx * 0.5 + 0.5 + i, h / 2.0, 0), STUD_R, STUD_H, 12, 1.0)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	for v: Vector3 in [a, b, c, a, c, d]:
		st.set_normal(n)
		st.add_vertex(v)


static func _cuboid(st: SurfaceTool, lo: Vector3, hi: Vector3) -> void:
	var p := [
		Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z),
		Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)]
	_quad(st, p[4], p[5], p[6], p[7], Vector3.BACK)      # +z
	_quad(st, p[1], p[0], p[3], p[2], Vector3.FORWARD)   # -z
	_quad(st, p[5], p[1], p[2], p[6], Vector3.RIGHT)
	_quad(st, p[0], p[4], p[7], p[3], Vector3.LEFT)
	_quad(st, p[7], p[6], p[2], p[3], Vector3.UP)
	_quad(st, p[0], p[1], p[5], p[4], Vector3.DOWN)


## Closed cylinder from `bottom` up `h`.
static func _cyl(st: SurfaceTool, bottom: Vector3, r: float, h: float, sides: int, _unused: float) -> void:
	var top := bottom + Vector3(0, h, 0)
	for j in sides:
		var a0 := TAU * j / sides
		var a1 := TAU * (j + 1) / sides
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		for pair: Array in [[bottom + d0 * r, d0], [top + d0 * r, d0], [top + d1 * r, d1],
				[bottom + d0 * r, d0], [top + d1 * r, d1], [bottom + d1 * r, d1]]:
			st.set_normal(pair[1])
			st.add_vertex(pair[0])
		for v: Vector3 in [top, top + d1 * r, top + d0 * r]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
		for v: Vector3 in [bottom, bottom + d0 * r, bottom + d1 * r]:
			st.set_normal(Vector3.DOWN)
			st.add_vertex(v)
