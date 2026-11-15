# Code generated with AI assistance (Claude). Reviewed by team.
class_name BrickFigure
extends Node3D
## A toy-brick person on the named-part rig, with procedural animation.
##
## Rig (each part is a Node3D whose origin is its joint; the front of the figure is +Z,
## like an imported .glb):
##
##   Rig
##    ├ Torso ── Head, ArmL ── HandL, ArmR ── HandR
##    ├ LegL
##    └ LegR
##
## The placeholder is built from boxes and cylinders. To swap in art, set `model_scene`
## to a .glb whose nodes use the same eight names; the animation carries over unchanged.
##
## Used for the protagonist, and free to reuse for NPCs:
##
##   var npc := BrickFigure.new()
##   npc.shirt_color = Color("c8551f")
##   npc.hair_style = "bun"
##   add_child(npc)
##   npc.animator.pose = &"sit_type"          # seated, typing
##   npc.look_at_point(player.head_position()) # glance at the player
##
## Drive the walk cycle by setting animator.speed (m/s) and animator.turn_rate (rad/s).

const PART_NAMES: Array[StringName] = [&"Head", &"Torso", &"ArmL", &"ArmR", &"HandL", &"HandR", &"LegL", &"LegR"]
const HAIR_STYLES: Array[String] = ["short", "side_part", "bun", "flat_top", "bald"]

@export var shirt_color: Color = Color("f2e8cf")
@export var vest_color: Color = Color("2a7b7b")     ## Sleeveless pullover; alpha 0 for none.
@export var pants_color: Color = Color("5a4636")
@export var skin_color: Color = Color("e9c46a")
@export var hair_color: Color = Color("4a2f1d")
@export var shoe_color: Color = Color("2b2622")
@export var tie_color: Color = Color("2b2622")      ## Alpha 0 for no tie.
@export var hair_style: String = "side_part"
## A .glb (or scene) with nodes named like PART_NAMES. Replaces the placeholder.
@export var model_scene: PackedScene
## Animate in _process. Turn off to pose the figure by hand.
@export var animate: bool = true

var animator: FigureAnimator = FigureAnimator.new()
var rig: Node3D

static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}
static var _alive: int = 0


func _init() -> void:
	_alive += 1


func _notification(what: int) -> void:
	# The shared meshes and materials go when the last figure does (clean shutdown).
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


## Builds (or rebuilds) the figure from the exported colours or `model_scene`.
func rebuild() -> void:
	if rig != null:
		remove_child(rig)
		rig.queue_free()
	if model_scene != null:
		rig = model_scene.instantiate() as Node3D
		rig.name = "Rig"
		add_child(rig)
	else:
		rig = _build_placeholder()
		add_child(rig)
	animator.bind(rig)


## The rig node for a part name ("Head", "ArmL", ...), or null.
func part(part_name: StringName) -> Node3D:
	return animator.part(part_name)


## Turns the head (and a little of the torso) toward a world position.
func look_at_point(world_position: Vector3) -> void:
	animator.look_target = world_position
	animator.has_look_target = true


func clear_look() -> void:
	animator.has_look_target = false


## World position of the head, for other characters to look at.
func head_position() -> Vector3:
	var head := part(&"Head")
	return head.global_position + Vector3.UP * 0.22 if head != null else global_position + Vector3.UP * 1.6


# --- Placeholder build -----------------------------------------------------------------

func _build_placeholder() -> Node3D:
	var root := Node3D.new()
	root.name = "Rig"

	# Legs: pivot at the hip, block leg and a shoe that pokes forward.
	for side: float in [1.0, -1.0]:
		var leg := _joint(root, "LegL" if side > 0.0 else "LegR", Vector3(0.145 * side, 0.66, 0))
		_box(leg, Vector3(0.25, 0.56, 0.28), Vector3(0, -0.28, 0), pants_color)
		_box(leg, Vector3(0.25, 0.11, 0.36), Vector3(0, -0.605, 0.04), shoe_color)

	# Torso: pivot at the waist. Hips, shirt, optional pullover and tie.
	var torso := _joint(root, "Torso", Vector3(0, 0.66, 0))
	_box(torso, Vector3(0.56, 0.14, 0.3), Vector3(0, 0.05, 0), pants_color.darkened(0.15))
	_box(torso, Vector3(0.6, 0.58, 0.33), Vector3(0, 0.41, 0), shirt_color)
	if vest_color.a > 0.01:
		_box(torso, Vector3(0.62, 0.44, 0.35), Vector3(0, 0.35, 0), vest_color)
	if tie_color.a > 0.01:
		_box(torso, Vector3(0.07, 0.3, 0.02), Vector3(0, 0.5, 0.176), tie_color)
		_box(torso, Vector3(0.1, 0.06, 0.025), Vector3(0, 0.665, 0.176), tie_color)

	# Arms: pivot at the shoulder, sleeve then forearm, hand at the wrist.
	for side: float in [1.0, -1.0]:
		var arm := _joint(torso, "ArmL" if side > 0.0 else "ArmR", Vector3(0.385 * side, 0.62, 0))
		_box(arm, Vector3(0.17, 0.26, 0.2), Vector3(0, -0.1, 0), shirt_color)
		_box(arm, Vector3(0.14, 0.24, 0.16), Vector3(0, -0.34, 0), skin_color)
		var hand := _joint(arm, "HandL" if side > 0.0 else "HandR", Vector3(0, -0.47, 0))
		_cylinder(hand, 0.085, 0.13, Vector3(0, -0.05, 0), skin_color)

	# Head: pivot at the neck. Round toy head, dot eyes, a small smile, hair.
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
		_:  # side_part
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


## One shared plastic material per colour, so a crowd of figures stays cheap to draw.
static func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.42
		m.metallic_specular = 0.6
		_materials[key] = m
	return _materials[key]
