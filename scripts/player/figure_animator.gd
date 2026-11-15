# Code generated with AI assistance (Claude). Reviewed by team.
class_name FigureAnimator
extends RefCounted
## Procedural animation for the named-part rig (Head/Torso/ArmL/ArmR/HandL/HandR/
## LegL/LegR). No AnimationPlayer: every pose is computed from a few inputs each frame,
## so it works unchanged on the placeholder bricks and on a .glb with the same names.
##
## Inputs (set them, then call update(delta) once per frame):
##   speed        horizontal speed in m/s      -> walk / run cycle, arm swing, body bob
##   turn_rate    body yaw rate in rad/s       -> turn-in-place shuffle, lean into turns
##   look_target  world point (has_look_target) -> head and a little torso turn toward it
##   pose         "", "type", "sit", "sit_type", "talk", "carry", "write"
##
## Outputs: footstep(left_foot) each time a foot lands; look_yaw_raw is how far round
## the look target is from straight ahead (the player uses it to turn in place).
##
## Axes: the figure faces +Z, its left is +X. Rotating a limb by -x swings it forward.

signal footstep(left_foot: bool)

## Speeds the cycle is tuned for (metres per second).
var walk_speed: float = 3.4
var run_speed: float = 6.2

var speed: float = 0.0
var turn_rate: float = 0.0
var look_target: Vector3 = Vector3.ZERO
var has_look_target: bool = false
var pose: StringName = &""
## Small unprompted head movements while standing still (for NPCs; the player's head
## follows the camera instead).
var idle_glance: bool = false
## How far the seat is below standing hip height when sitting.
var sit_drop: float = 0.2

## Read-only state.
var look_yaw_raw: float = 0.0
var phase: float = 0.0
var move_blend: float = 0.0
var run_blend: float = 0.0
var turn_blend: float = 0.0

var _root: Node3D
var _parts: Dictionary = {}       # StringName -> Node3D
var _rest: Dictionary = {}        # StringName -> Transform3D
var _root_rest: Transform3D = Transform3D.IDENTITY
var _time: float = 0.0
var _turn_phase: float = 0.0
var _step_index: int = 0
var _head_yaw: float = 0.0
var _head_pitch: float = 0.0
var _lean_roll: float = 0.0
var _w: Dictionary = {&"sit": 0.0, &"type": 0.0, &"talk": 0.0, &"carry": 0.0, &"write": 0.0}

const POSE_FLAGS := {
	&"": [],
	&"type": [&"type"],
	&"sit": [&"sit"],
	&"sit_type": [&"sit", &"type"],
	&"sit_write": [&"sit", &"write"],
	&"write": [&"write"],
	&"talk": [&"talk"],
	&"carry": [&"carry"],
}


## Finds the rig parts under `root` by name and remembers their rest pose.
func bind(root: Node3D) -> void:
	_root = root
	_parts.clear()
	_rest.clear()
	if root == null:
		return
	_root_rest = root.transform
	for part_name in BrickFigure.PART_NAMES:
		var node := root.find_child(String(part_name), true, false) as Node3D
		if node != null:
			_parts[part_name] = node
			_rest[part_name] = node.transform
	_time = randf() * 10.0    # so a room full of figures does not breathe in unison


func part(part_name: StringName) -> Node3D:
	return _parts.get(part_name) as Node3D


func is_bound() -> bool:
	return _root != null and is_instance_valid(_root) and not _parts.is_empty()


func update(delta: float) -> void:
	if not is_bound():
		return
	_time += delta
	var flags: Array = POSE_FLAGS.get(pose, [])
	for key: StringName in _w:
		_w[key] = _damp(_w[key], 1.0 if flags.has(key) else 0.0, 7.0, delta)
	var sit: float = _w[&"sit"]
	var typing: float = _w[&"type"]
	var talk: float = _w[&"talk"]
	var carry: float = _w[&"carry"]
	var writing: float = _w[&"write"]

	# --- Locomotion blends ---
	var moving := clampf(speed / (walk_speed * 0.45), 0.0, 1.0) * (1.0 - sit)
	move_blend = _damp(move_blend, moving, 10.0, delta)
	run_blend = _damp(run_blend, clampf(inverse_lerp(walk_speed * 1.15, run_speed * 0.95, speed), 0.0, 1.0), 6.0, delta)
	var stride := lerpf(1.55, 2.7, run_blend)                  # metres per two steps
	phase += speed * delta / stride * TAU
	var turning := (1.0 - move_blend) * (1.0 - sit) * clampf(absf(turn_rate) / 1.5, 0.0, 1.0)
	turn_blend = _damp(turn_blend, turning, 12.0, delta)
	_turn_phase += absf(turn_rate) * delta * 4.0               # two small steps per quarter turn
	var idle := (1.0 - move_blend) * (1.0 - turn_blend)

	var swing := sin(phase)
	var leg_amp := lerpf(0.5, 0.92, run_blend) * move_blend
	var arm_amp := lerpf(0.42, 1.05, run_blend) * move_blend
	var breath := sin(_time * 1.9)

	# Footfalls: a foot lands just after its forward swing peaks.
	var index := int(floor((phase - PI * 0.5) / PI))
	if index != _step_index:
		_step_index = index
		if move_blend > 0.35:
			footstep.emit(index % 2 == 0)

	# --- Body ---
	var bob := (cos(phase) * cos(phase) - 0.5) * lerpf(0.05, 0.1, run_blend) * move_blend
	bob += absf(sin(_turn_phase)) * 0.025 * turn_blend
	_lean_roll = _damp(_lean_roll, clampf(-turn_rate * 0.035, -0.12, 0.12) * move_blend, 6.0, delta)
	var root_rot := Vector3(0.0, 0.0, _lean_roll + sin(_time * 0.47) * 0.012 * idle * (1.0 - sit))
	_root.transform = _root_rest * Transform3D(Basis.from_euler(root_rot), Vector3(0.0, bob - sit_drop * sit, 0.0))

	# --- Head look ---
	var want_yaw := 0.0
	var want_pitch := 0.0
	look_yaw_raw = 0.0
	var head: Node3D = _parts.get(&"Head")
	if has_look_target and head != null:
		var body := _root.get_parent() as Node3D
		var frame := body.global_transform if body != null else _root.global_transform
		var local := frame.basis.orthonormalized().inverse() * (look_target - head.global_position)
		var flat := Vector2(local.x, local.z).length()
		if flat > 0.05 or absf(local.y) > 0.05:
			look_yaw_raw = atan2(local.x, local.z)
			if absf(look_yaw_raw) < 2.2:                           # not straight behind
				want_yaw = clampf(look_yaw_raw, -1.25, 1.25)
				want_pitch = clampf(-atan2(local.y, maxf(flat, 0.2)), -0.55, 0.6)
	elif idle_glance:
		want_yaw = (sin(_time * 0.37) * 0.22 + sin(_time * 0.13 + 1.3) * 0.18) * idle
		want_pitch = sin(_time * 0.21 + 0.7) * 0.05 * idle
	_head_yaw = _damp(_head_yaw, want_yaw, 7.0, delta)
	_head_pitch = _damp(_head_pitch, want_pitch, 7.0, delta)

	# --- Torso ---
	var twist := swing * 0.11 * move_blend
	var lead := clampf(turn_rate * 0.05, -0.18, 0.18) * turn_blend
	var torso_rot := Vector3(
			move_blend * lerpf(0.05, 0.2, run_blend) + breath * 0.012 * idle + typing * 0.07 + writing * 0.16,
			twist + _head_yaw * 0.22 + lead,
			cos(phase) * 0.03 * move_blend)
	_pose(&"Torso", torso_rot, Vector3(0.0, breath * 0.008 * idle, 0.0))

	# --- Head ---
	var nod := sin(_time * 3.1) * 0.05 * talk + sin(_time * 7.0) * 0.012 * typing
	var head_rot := Vector3(
			_head_pitch - breath * 0.01 * idle + nod + typing * 0.16 + writing * 0.3 - move_blend * run_blend * 0.1,
			_head_yaw * 0.78 - twist * 0.8 + clampf(turn_rate * 0.09, -0.3, 0.3) * turn_blend,
			0.0)
	_pose(&"Head", head_rot)

	# --- Legs ---
	var shuffle := sin(_turn_phase)
	var leg_l := -swing * leg_amp - maxf(0.0, shuffle) * 0.3 * turn_blend
	var leg_r := swing * leg_amp - maxf(0.0, -shuffle) * 0.3 * turn_blend
	_pose(&"LegL", Vector3(lerpf(leg_l, -PI * 0.5, sit), 0.0, 0.03 * sit))
	_pose(&"LegR", Vector3(lerpf(leg_r, -PI * 0.5, sit), 0.0, -0.03 * sit))

	# --- Arms ---
	var arm_l := swing * arm_amp
	var arm_r := -swing * arm_amp
	var out := 0.07 + breath * 0.015 * idle + run_blend * move_blend * 0.1
	var tap_l := sin(_time * 11.0) * 0.07 * typing
	var tap_r := sin(_time * 11.0 + 1.9) * 0.07 * typing
	var gesture := (sin(_time * 2.3) * 0.5 + 0.5) * (sin(_time * 0.9) * 0.5 + 0.5)
	arm_l = lerpf(arm_l, -1.12 + tap_l, typing)
	arm_r = lerpf(arm_r, -1.12 + tap_r, typing)
	arm_r = lerpf(arm_r, -1.0 + sin(_time * 5.0) * 0.06, writing)
	arm_l = lerpf(arm_l, -0.75, writing)
	arm_r = lerpf(arm_r, -0.45 - gesture * 0.7, talk)
	arm_l = lerpf(arm_l, -0.15 - (1.0 - gesture) * 0.2, talk)
	arm_r = lerpf(arm_r, -1.25, carry)
	var inward := typing * 0.16 + writing * 0.3
	_pose(&"ArmL", Vector3(arm_l, 0.0, out - inward))
	_pose(&"ArmR", Vector3(arm_r, 0.0, -out + inward + talk * gesture * 0.2))
	var wrist := -0.25 * move_blend * run_blend - 0.35 * typing - 0.3 * carry
	_pose(&"HandL", Vector3(wrist - swing * 0.2 * move_blend + tap_l * 2.0, 0.0, 0.0))
	_pose(&"HandR", Vector3(wrist + swing * 0.2 * move_blend + tap_r * 2.0 - talk * gesture * 0.5, 0.0, 0.0))


func _pose(part_name: StringName, euler: Vector3, offset: Vector3 = Vector3.ZERO) -> void:
	var node: Node3D = _parts.get(part_name)
	if node == null:
		return
	node.transform = (_rest[part_name] as Transform3D) * Transform3D(Basis.from_euler(euler), offset)


static func _damp(from: float, to: float, rate: float, delta: float) -> float:
	return lerpf(from, to, 1.0 - exp(-rate * delta))
