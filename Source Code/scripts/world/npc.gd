# SI assistance metadata: This code used the help of SI.
class_name WorldNpc
extends Node3D

const WALK_SPEED := 1.35
const GLANCE_RANGE := 4.5
const BARK_RANGE := 2.7

static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}

var role: String = ""
var pose: String = "stand"
var bark_key: String = ""
var world: FacilityWorld
var room_id: String = ""
var is_walker: bool = false

var _parts: Dictionary = {}
var _rig: Node3D
var _imported_figure: Node3D
var _t: float = 0.0
var _seed: float = 0.0
var _head_yaw: float = 0.0
var _bubble: Label3D
var _bubble_left: float = 0.0
var _bark_cooldown: float = 0.0
var _barks: Array = []
var _base_yaw: float = 0.0
var _gait_phase: float = 0.0
var _gait_blend: float = 0.0
var _model_parts: Dictionary = {}
var _model_rest: Dictionary = {}
const ROLE_MODELS := {"guard": "astronaut", "engineer": "protagonist", "technician": "astronaut", "operator": "girl", "typist": "girl", "clerk": "dot", "draftsman": "protagonist", "controller": "astronaut", "sparks": "astronaut", "visitor": "girl", "cook": "dot"}

var _route: Array = []
var _leg: int = 0
var _lift_state: int = 0
var _lift_wait: float = 0.0
var _pause: float = 0.0
var _check: float = 0.0

func setup(facility_world: FacilityWorld, look: Dictionary, npc_pose: String, layers: int, barks: Array) -> void:
	world = facility_world
	pose = npc_pose
	_barks = barks
	_seed = randf() * 20.0
	_base_yaw = rotation.y
	build_figure(look, layers)
	_apply_static_pose()

func set_route(route: Array) -> void:
	_route = route
	is_walker = true
	pose = "walk"
	_apply_static_pose()
	if not _route.is_empty() and _route[0] is Array:
		position = _point(_route[0])
	_leg = 1

func set_active(on: bool) -> void:
	visible = on
	if not is_walker:
		set_process(on)

static func _box(size: Vector3) -> BoxMesh:
	if not _meshes.has(size):
		var m := BoxMesh.new()
		m.size = size
		_meshes[size] = m
	return _meshes[size]

static func _mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.45
		_materials[key] = m
	return _materials[key]

func _part(part_name: String, parent: Node3D, pivot: Vector3, size: Vector3, offset: Vector3, color: Color, layers: int) -> Node3D:
	var node := Node3D.new()
	node.name = part_name
	node.position = pivot
	parent.add_child(node)
	var mi := MeshInstance3D.new()
	mi.mesh = _box(size)
	mi.material_override = _mat(color)
	mi.position = offset
	mi.layers = layers
	mi.visibility_range_end = 45.0
	node.add_child(mi)
	_parts[part_name] = node
	return node

func build_figure(look: Dictionary, layers: int) -> void:
	_rig = Node3D.new()
	_rig.name = "Rig"
	add_child(_rig)
	var pick := func(key: String, fallback: String) -> Color:
		var v: Variant = look.get(key, fallback)
		if v is Array:
			return Color(str((v as Array)[randi() % (v as Array).size()]))
		return Color(str(v))
	var shirt: Color = pick.call("shirt", "fbf5e6")
	var legs: Color = pick.call("trousers", "2b2622")
	var skin: Color = pick.call("skin", "e9c46a")
	var hair: Color = pick.call("hair", "2b2622")
	_part("LegL", _rig, Vector3(-0.14, 0.75, 0), Vector3(0.24, 0.75, 0.27), Vector3(0, -0.375, 0), legs, layers)
	_part("LegR", _rig, Vector3(0.14, 0.75, 0), Vector3(0.24, 0.75, 0.27), Vector3(0, -0.375, 0), legs, layers)
	var torso := _part("Torso", _rig, Vector3(0, 0.75, 0), Vector3(0.6, 0.62, 0.34), Vector3(0, 0.31, 0), shirt, layers)
	var arm_l := _part("ArmL", torso, Vector3(-0.39, 0.56, 0), Vector3(0.17, 0.46, 0.2), Vector3(0, -0.2, 0), shirt, layers)
	var arm_r := _part("ArmR", torso, Vector3(0.39, 0.56, 0), Vector3(0.17, 0.46, 0.2), Vector3(0, -0.2, 0), shirt, layers)
	_part("HandL", arm_l, Vector3(0, -0.48, 0), Vector3(0.15, 0.14, 0.17), Vector3.ZERO, skin, layers)
	_part("HandR", arm_r, Vector3(0, -0.48, 0), Vector3(0.15, 0.14, 0.17), Vector3.ZERO, skin, layers)
	var head := _part("Head", torso, Vector3(0, 0.64, 0), Vector3(0.38, 0.36, 0.36), Vector3(0, 0.18, 0), skin, layers)
	var hair_mesh := MeshInstance3D.new()
	hair_mesh.mesh = _box(Vector3(0.4, 0.12, 0.38))
	hair_mesh.material_override = _mat(hair)
	hair_mesh.position = Vector3(0, 0.39, -0.01)
	hair_mesh.layers = layers
	hair_mesh.visibility_range_end = 30.0
	head.add_child(hair_mesh)
	if look.has("tie"):
		var tie := MeshInstance3D.new()
		tie.mesh = _box(Vector3(0.08, 0.36, 0.02))
		tie.material_override = _mat(pick.call("tie", "2b2622"))
		tie.position = Vector3(0, 0.36, 0.18)
		tie.layers = layers
		tie.visibility_range_end = 14.0
		torso.add_child(tie)
	if bool(look.get("headset", false)):
		var band := MeshInstance3D.new()
		band.mesh = _box(Vector3(0.46, 0.2, 0.1))
		band.material_override = _mat(Color("2b2622"))
		band.position = Vector3(0, 0.22, 0)
		band.layers = layers
		head.add_child(band)
	var model_path := str(look.get("model_scene", ""))
	if model_path.is_empty() and ROLE_MODELS.has(role):
		model_path = "res://assets/models/characters/%s.glb" % str(ROLE_MODELS[role])
	if model_path != "" and ResourceLoader.exists(model_path):
		var packed := load(model_path) as PackedScene
		if packed != null:
			_imported_figure = packed.instantiate() as Node3D
			if _imported_figure != null:
				_imported_figure.name = "LDrawMinifigure"
				add_child(_imported_figure)
				_rig.visible = false
				_cache_model_parts()

func set_layers(layers: int) -> void:
	var stack: Array = [_rig]
	if _imported_figure != null:
		stack.append(_imported_figure)
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			(node as MeshInstance3D).layers = layers
		stack.append_array(node.get_children())

func _p(part_name: String) -> Node3D:
	return _parts[part_name]

func _cache_model_parts() -> void:
	_model_parts.clear()
	_model_rest.clear()
	if _imported_figure == null:
		return
	for key in [&"Torso", &"Head", &"Hair", &"LegL", &"LegR", &"ArmL", &"ArmR"]:
		var node := _imported_figure.find_child(String(key), true, false) as Node3D
		if node != null:
			_model_parts[key] = node
			_model_rest[key] = node.transform

func _pose_imported(key: StringName, euler: Vector3) -> void:
	var node := _model_parts.get(key) as Node3D
	if node == null:
		return
	var rest: Transform3D = _model_rest.get(key, Transform3D.IDENTITY)
	node.transform = rest * Transform3D(Basis.from_euler(euler), Vector3.ZERO)

func _animate_imported(t: float) -> void:
	var talking := pose.begins_with("talk") or pose == "press"
	var writing := pose == "write" or pose == "type"
	var breath := sin(t * 1.9)
	var swing := sin(_gait_phase) * 0.62 * _gait_blend
	_imported_figure.position.y = absf(cos(_gait_phase)) * 0.035 * _gait_blend + breath * 0.007 * (1.0 - _gait_blend)
	_imported_figure.rotation.y = sin(t * 0.42) * 0.018
	_pose_imported(&"LegL", Vector3(swing, 0.0, 0.0))
	_pose_imported(&"LegR", Vector3(-swing, 0.0, 0.0))
	_pose_imported(&"ArmL", Vector3(-swing * 0.72, 0.0, 0.05))
	_pose_imported(&"ArmR", Vector3(swing * 0.72, 0.0, -0.05))
	_pose_imported(&"Torso", Vector3(0.02 * breath + (0.08 if writing else 0.0), sin(t * 0.7) * 0.025, sin(t * 0.5) * 0.018))
	_pose_imported(&"Head", Vector3(-0.06 * float(talking) + breath * 0.008, _head_yaw * 0.72, 0.0))
	if talking:
		_pose_imported(&"ArmR", Vector3(-0.34 - maxf(0.0, sin(t * 2.1)) * 0.58, 0.0, -0.09))
		_pose_imported(&"ArmL", Vector3(-0.12, 0.0, 0.07))
	if writing:
		_pose_imported(&"ArmL", Vector3(-0.78, 0.0, 0.12))
		_pose_imported(&"ArmR", Vector3(-0.96 + sin(t * 8.0) * 0.035, 0.0, -0.12))

func _apply_static_pose() -> void:
	for key: String in _parts:
		(_parts[key] as Node3D).rotation = Vector3.ZERO
	_rig.position = Vector3.ZERO
	if pose.begins_with("sit") or pose == "type" or pose == "write" or pose == "talk_sit":
		_rig.position.y = -0.3
		_p("LegL").rotation.x = -PI / 2.0
		_p("LegR").rotation.x = -PI / 2.0

func _process(delta: float) -> void:
	_t += delta
	if is_walker:
		_walk(delta)
		_check -= delta
		if _check <= 0.0:
			_check = 0.3
			var here := world.room_at(global_position + Vector3(0, 0.9, 0))
			if here != "" and here != room_id:
				room_id = here
				set_layers((FacilityWorld.LIFT_BIT if here == FacilityWorld.LIFT else (world.rooms[here] as WorldRoom).layer_bit) | 1)
			visible = world.visible_rooms.has(room_id)
		if not visible:
			return
	var t := _t + _seed
	var torso := _p("Torso")
	var arm_l := _p("ArmL")
	var arm_r := _p("ArmR")
	torso.scale.y = 1.0 + sin(t * 1.7) * 0.012
	match pose:
		"type":
			arm_l.rotation.x = 1.25 + sin(t * 13.0) * 0.08
			arm_r.rotation.x = 1.25 + sin(t * 11.0 + 1.0) * 0.08
			torso.rotation.x = 0.08
		"write":
			arm_r.rotation.x = 1.15 + sin(t * 5.0) * 0.06
			arm_r.rotation.z = sin(t * 2.3) * 0.12
			arm_l.rotation.x = 0.9
			torso.rotation.x = 0.16
		"sit_turn":
			torso.rotation.y = sin(t * 0.45) * 0.6 * smoothstep(0.2, 0.9, absf(sin(t * 0.21)))
			arm_l.rotation.x = 1.0
			arm_r.rotation.x = 1.0 + sin(t * 1.3) * 0.15
		"talk_sit", "talk":
			arm_r.rotation.x = 0.5 + maxf(0.0, sin(t * 2.1)) * 0.7
			arm_r.rotation.z = -sin(t * 3.1) * 0.15
			arm_l.rotation.x = 0.25 if pose == "talk" else 0.9
			torso.rotation.y = sin(t * 0.7) * 0.12
		"sit_read":
			arm_l.rotation.x = 1.3
			arm_r.rotation.x = 1.3
			torso.rotation.x = 0.12
		"tinker":
			arm_r.rotation.x = 1.1 + sin(t * 6.0) * 0.25
			arm_l.rotation.x = 0.9 + sin(t * 1.9) * 0.1
			torso.rotation.x = 0.2
			torso.rotation.y = sin(t * 0.5) * 0.2
		"press":
			var k := fmod(t, 5.0)
			arm_r.rotation.x = 1.5 * smoothstep(0.0, 0.4, k) * (1.0 - smoothstep(1.2, 1.7, k))
			torso.rotation.y = sin(t * 0.4) * 0.1
		"stand", "sit":
			torso.rotation.y = sin(t * 0.33) * 0.12
			arm_l.rotation.x = sin(t * 0.8) * 0.04
	_glance(delta)
	if _imported_figure != null:
		_animate_imported(t)
	if _bubble_left > 0.0:
		_bubble_left -= delta
		if _bubble_left <= 0.0 and _bubble != null:
			_bubble.visible = false
	_bark_cooldown = maxf(0.0, _bark_cooldown - delta)

func _glance(delta: float) -> void:
	var player := world.player()
	var want := 0.0
	if player != null:
		var to := player.global_position - global_position
		var dist := to.length()
		if dist < GLANCE_RANGE and absf(to.y) < 1.5:
			var local := global_transform.basis.inverse() * to
			want = clampf(atan2(local.x, local.z) - _p("Torso").rotation.y, -1.2, 1.2)
			if dist < BARK_RANGE and _bark_cooldown <= 0.0 and not _barks.is_empty():
				say(str(_barks[randi() % _barks.size()]))
	_head_yaw = lerpf(_head_yaw, want, minf(1.0, delta * 4.0))
	_p("Head").rotation.y = _head_yaw

func say(line: String) -> void:
	_bark_cooldown = randf_range(25.0, 50.0)
	if _bubble == null:
		_bubble = Label3D.new()
		_bubble.font = ConsoleTheme.typewriter()
		_bubble.font_size = 30
		_bubble.pixel_size = 0.004
		_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_bubble.modulate = Color("fbf5e6")
		_bubble.outline_size = 10
		_bubble.outline_modulate = Color("2b2622")
		_bubble.no_depth_test = true
		_bubble.width = 620.0
		_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_bubble.position = Vector3(0, 2.25, 0)
		add_child(_bubble)
	_bubble.text = line
	_bubble.visible = true
	_bubble_left = 4.5
	StoryTriggers.fire("npc_bark", {"role": role, "line": line})

func _point(a: Variant) -> Vector3:
	var arr: Array = a
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))

func _walk(delta: float) -> void:
	if _route.is_empty():
		return
	var step: Variant = _route[_leg % _route.size()]
	var moving := false
	if step is Dictionary:
		moving = _ride_lift(int((step as Dictionary)["lift"]), delta)
	else:
		moving = _go_to(_point(step), delta)
		if not moving and _pause <= 0.0:
			_leg += 1
	var swing := sin(_t * 7.5) * 0.55 if moving else 0.0
	_gait_phase += delta * 7.5 if moving else delta * 1.3
	_gait_blend = lerpf(_gait_blend, 1.0 if moving else 0.0, minf(1.0, delta * 10.0))
	_p("LegL").rotation.x = lerpf(_p("LegL").rotation.x, swing, minf(1.0, delta * 12.0))
	_p("LegR").rotation.x = lerpf(_p("LegR").rotation.x, -swing, minf(1.0, delta * 12.0))
	_p("ArmL").rotation.x = -_p("LegL").rotation.x * 0.7
	_p("ArmR").rotation.x = -_p("LegR").rotation.x * 0.7
	_rig.position.y = absf(sin(_t * 7.5)) * 0.03 if moving else 0.0

func _go_to(target: Vector3, delta: float) -> bool:
	var to := target - global_position
	var flat := Vector3(to.x, 0, to.z)
	if flat.length() < 0.12:
		global_position = target
		return false
	_pause = maxf(0.0, _pause - delta)
	var dir := flat.normalized()
	var player := world.player()
	if player != null:
		var gap := player.global_position - global_position
		if absf(gap.y) < 1.2:
			var ahead := dir.dot(Vector3(gap.x, 0, gap.z))
			var side := dir.cross(Vector3.UP).dot(Vector3(gap.x, 0, gap.z))
			if ahead > 0.0 and ahead < 1.6 and absf(side) < 0.75:
				if ahead < 0.8:
					_pause = 0.4
				else:
					dir = (dir - dir.cross(Vector3.UP) * signf(side if side != 0.0 else 1.0) * 0.9).normalized()
	if _pause > 0.0:
		return false
	var pace := minf(WALK_SPEED * delta, flat.length())
	global_position += dir * pace
	var remaining := Vector3(target.x - global_position.x, 0, target.z - global_position.z).length()
	global_position.y = lerpf(global_position.y, target.y, clampf(pace / maxf(remaining + pace, 0.001), 0.0, 1.0))
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(1.0, delta * 8.0))
	return true

func _ride_lift(dest: int, delta: float) -> bool:
	var lift := world.lift
	if lift == null:
		_leg += 1
		return false
	var here := 0
	for i in lift.floors.size():
		if absf(float((lift.floors[i] as Dictionary).get("y", 0.0)) - global_position.y) < 1.0:
			here = i
	match _lift_state:
		0:
			if not _go_to(lift.wait_point(here), delta):
				lift.request(here)
				_lift_state = 1
				_lift_wait = 0.0
			else:
				return true
		1:
			_lift_wait += delta
			if lift.is_open_at(here):
				_lift_state = 2
			elif _lift_wait > 6.0:
				lift.request(here)
				_lift_wait = 0.0
		2:
			if not lift.portal_open(here):
				_lift_state = 1
			elif not _go_to(lift.ride_point(), delta):
				lift.request(dest)
				_lift_state = 3
			else:
				return true
		3:
			if lift.is_open_at(dest):
				_lift_state = 4
		4:
			if not _go_to(lift.wait_point(dest), delta):
				_lift_state = 0
				_leg += 1
			else:
				return true
	return false
