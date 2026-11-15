# SI assistance metadata: This code used the help of SI.
class_name BrickFigure
extends Node3D

const PART_NAMES: Array[StringName] = [&"Head", &"Torso", &"ArmL", &"ArmR", &"HandL", &"HandR", &"LegL", &"LegR"]
const HAIR_STYLES: Array[String] = ["short", "side_part", "bun", "flat_top", "bald"]

@export var shirt_color: Color = Color("f2e8cf")
@export var vest_color: Color = Color("2a7b7b")
@export var pants_color: Color = Color("5a4636")
@export var skin_color: Color = Color("e9c46a")
@export var hair_color: Color = Color("4a2f1d")
@export var shoe_color: Color = Color("2b2622")
@export var tie_color: Color = Color("2b2622")
@export var hair_style: String = "side_part"
@export var model_scene: PackedScene
@export var expression_scenes: Dictionary = {}

@export var animate: bool = true

var animator: FigureAnimator = FigureAnimator.new()
var rig: Node3D
var _imported_model: Node3D
var _active_model_scene: PackedScene
var _model_parts: Dictionary = {}
var _model_rest: Dictionary = {}

static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}
static var _alive: int = 0

func _init() -> void:
	_alive += 1

func _notification(what: int) -> void:

	if what == NOTIFICATION_PREDELETE:
		_alive -= 1
		if _alive <= 0:
			_materials.clear()
			_meshes.clear()

func _ready() -> void:
	rebuild()

func _process(delta: float) -> void:
	if animate:
		animator.update(delta)
	if _imported_model != null and is_instance_valid(_imported_model):
		_animate_imported()

func rebuild() -> void:
	if _imported_model != null and is_instance_valid(_imported_model):
		remove_child(_imported_model)
		_imported_model.queue_free()
		_imported_model = null
	if rig != null:
		remove_child(rig)
		rig.queue_free()
	rig = _build_placeholder()
	add_child(rig)
	_active_model_scene = model_scene
	_spawn_imported_model()
	animator.bind(rig)

func set_expression(expression: String) -> void:
	var selected := expression_scenes.get(expression, model_scene) as PackedScene
	if selected == _active_model_scene:
		return
	_active_model_scene = selected
	_spawn_imported_model()

func _spawn_imported_model() -> void:
	if _imported_model != null and is_instance_valid(_imported_model):
		_imported_model.queue_free()
		_imported_model = null
	if _active_model_scene == null:
		rig.visible = true
		return
	_imported_model = _active_model_scene.instantiate() as Node3D
	if _imported_model == null:
		return
	_imported_model.name = "LDrawMinifigure"
	add_child(_imported_model)
	rig.visible = false
	_cache_model_parts()

func _cache_model_parts() -> void:
	_model_parts.clear()
	_model_rest.clear()
	if _imported_model == null:
		return
	for key in [&"Torso", &"Head", &"Hair", &"LegL", &"LegR", &"ArmL", &"ArmR"]:
		var node := _imported_model.find_child(String(key), true, false) as Node3D
		if node != null:
			_model_parts[key] = node
			_model_rest[key] = node.transform

func _animate_imported() -> void:
	if not animate:
		return
	var stride := clampf(animator.move_blend, 0.0, 1.0)
	var swing := sin(animator.phase) * lerpf(0.62, 0.88, animator.run_blend) * stride
	var breath := sin(Time.get_ticks_msec() * 0.0019 + float(get_instance_id() % 29))
	_imported_model.position.y = absf(cos(animator.phase)) * 0.035 * stride + breath * 0.008 * (1.0 - stride)
	_imported_model.rotation.z = clampf(-animator.turn_rate * 0.02, -0.08, 0.08) * stride
	_animate_part(&"LegL", Vector3(swing, 0.0, 0.0))
	_animate_part(&"LegR", Vector3(-swing, 0.0, 0.0))
	_animate_part(&"ArmL", Vector3(-swing * 0.72, 0.0, 0.05 + breath * 0.008))
	_animate_part(&"ArmR", Vector3(swing * 0.72, 0.0, -0.05 - breath * 0.008))
	var talk := 1.0 if animator.pose == &"talk" else 0.0
	var writing := 1.0 if animator.pose == &"write" else 0.0
	var gesture := (sin(Time.get_ticks_msec() * 0.0022) * 0.5 + 0.5) * talk
	_animate_part(&"Torso", Vector3(0.035 * stride + breath * 0.012, 0.0, sin(animator.phase) * 0.025 * stride))
	_animate_part(&"Head", Vector3(-0.08 * talk + 0.16 * writing + breath * 0.008, animator.look_yaw_raw * 0.72, 0.0))
	if talk > 0.0:
		_animate_part(&"ArmR", Vector3(-0.3 - gesture * 0.65, 0.0, -0.05 - gesture * 0.14))
		_animate_part(&"ArmL", Vector3(-0.12 - (1.0 - gesture) * 0.16, 0.0, 0.05))
	if writing > 0.0:
		_animate_part(&"ArmR", Vector3(-0.92 + breath * 0.035, 0.0, 0.1))
		_animate_part(&"ArmL", Vector3(-0.72, 0.0, -0.1))

func _animate_part(key: StringName, euler: Vector3) -> void:
	var node := _model_parts.get(key) as Node3D
	if node == null:
		return
	var rest: Transform3D = _model_rest.get(key, Transform3D.IDENTITY)
	node.transform = rest * Transform3D(Basis.from_euler(euler), Vector3.ZERO)

func part(part_name: StringName) -> Node3D:
	return animator.part(part_name)

func look_at_point(world_position: Vector3) -> void:
	animator.look_target = world_position
	animator.has_look_target = true

func clear_look() -> void:
	animator.has_look_target = false

func head_position() -> Vector3:
	var head := part(&"Head")
	return head.global_position + Vector3.UP * 0.22 if head != null else global_position + Vector3.UP * 1.6

func _build_placeholder() -> Node3D:
	var root := Node3D.new()
	root.name = "Rig"

	for side: float in [1.0, -1.0]:
		var leg := _joint(root, "LegL" if side > 0.0 else "LegR", Vector3(0.145 * side, 0.66, 0))
		_box(leg, Vector3(0.25, 0.56, 0.28), Vector3(0, -0.28, 0), pants_color)
		_box(leg, Vector3(0.25, 0.11, 0.36), Vector3(0, -0.605, 0.04), shoe_color)

	var torso := _joint(root, "Torso", Vector3(0, 0.66, 0))
	_box(torso, Vector3(0.56, 0.14, 0.3), Vector3(0, 0.05, 0), pants_color.darkened(0.15))
	_box(torso, Vector3(0.6, 0.58, 0.33), Vector3(0, 0.41, 0), shirt_color)
	if vest_color.a > 0.01:
		_box(torso, Vector3(0.62, 0.44, 0.35), Vector3(0, 0.35, 0), vest_color)
	if tie_color.a > 0.01:
		_box(torso, Vector3(0.07, 0.3, 0.02), Vector3(0, 0.5, 0.176), tie_color)
		_box(torso, Vector3(0.1, 0.06, 0.025), Vector3(0, 0.665, 0.176), tie_color)

	for side: float in [1.0, -1.0]:
		var arm := _joint(torso, "ArmL" if side > 0.0 else "ArmR", Vector3(0.385 * side, 0.62, 0))
		_box(arm, Vector3(0.17, 0.26, 0.2), Vector3(0, -0.1, 0), shirt_color)
		_box(arm, Vector3(0.14, 0.24, 0.16), Vector3(0, -0.34, 0), skin_color)
		var hand := _joint(arm, "HandL" if side > 0.0 else "HandR", Vector3(0, -0.47, 0))
		_cylinder(hand, 0.085, 0.13, Vector3(0, -0.05, 0), skin_color)

	var head := _joint(torso, "Head", Vector3(0, 0.7, 0))
	_cylinder(head, 0.09, 0.08, Vector3(0, 0.03, 0), skin_color)
	_cylinder(head, 0.215, 0.34, Vector3(0, 0.24, 0), skin_color)
	for side: float in [1.0, -1.0]:
		var eye := _cylinder(head, 0.028, 0.02, Vector3(0.075 * side, 0.28, 0.212), Color("2b2622"))
		eye.rotation.x = PI / 2.0
	_box(head, Vector3(0.1, 0.022, 0.02), Vector3(0, 0.165, 0.21), Color("2b2622"))
	_build_hair(head)
	return root

func _build_hair(head: Node3D) -> void:
	match hair_style:
		"bald":
			_cylinder(head, 0.11, 0.05, Vector3(0, 0.43, 0), skin_color)
		"flat_top":
			_cylinder(head, 0.225, 0.11, Vector3(0, 0.44, 0), hair_color)
		"bun":
			_cylinder(head, 0.228, 0.12, Vector3(0, 0.4, 0), hair_color)
			_box(head, Vector3(0.44, 0.24, 0.12), Vector3(0, 0.28, -0.17), hair_color)
			_cylinder(head, 0.1, 0.12, Vector3(0, 0.5, -0.08), hair_color)
		"short":
			_cylinder(head, 0.228, 0.1, Vector3(0, 0.41, 0), hair_color)
			_box(head, Vector3(0.44, 0.2, 0.1), Vector3(0, 0.3, -0.18), hair_color)
		_:
			_cylinder(head, 0.228, 0.1, Vector3(0, 0.41, 0), hair_color)
			_box(head, Vector3(0.44, 0.2, 0.1), Vector3(0, 0.3, -0.18), hair_color)
			_box(head, Vector3(0.3, 0.08, 0.1), Vector3(0.08, 0.4, 0.17), hair_color)

func _joint(parent: Node3D, joint_name: String, at: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = joint_name
	node.position = at
	parent.add_child(node)
	return node

func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var key := "b%s" % size
	if not _meshes.has(key):
		var mesh := BoxMesh.new()
		mesh.size = size
		_meshes[key] = mesh
	return _piece(parent, _meshes[key], at, color)

func _cylinder(parent: Node3D, cyl_radius: float, height: float, at: Vector3, color: Color) -> MeshInstance3D:
	var key := "c%.3f/%.3f" % [cyl_radius, height]
	if not _meshes.has(key):
		var mesh := CylinderMesh.new()
		mesh.top_radius = cyl_radius
		mesh.bottom_radius = cyl_radius
		mesh.height = height
		mesh.radial_segments = 16
		mesh.rings = 1
		_meshes[key] = mesh
	return _piece(parent, _meshes[key], at, color)

func _piece(parent: Node3D, mesh: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.material_override = _material(color)
	parent.add_child(mi)
	return mi

static func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.42
		m.metallic_specular = 0.6
		_materials[key] = m
	return _materials[key]
