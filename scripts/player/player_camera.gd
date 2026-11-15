# Code generated with AI assistance (Claude). Reviewed by team.
class_name PlayerCamera
extends Node3D
## Third-person over-the-shoulder camera rig.
##
##   CameraRig (this, follows the target smoothly; yaw/pitch from mouse or right stick)
##    ├ ShoulderArm  SpringArm3D sideways to the shoulder (so the offset never enters a wall)
##    ├ BoomArm      SpringArm3D back from the shoulder (so the camera never clips a wall)
##    └ Camera3D
##
## Extras: shoulder swap, a little more FOV when sprinting, a shorter boom in small
## rooms (measured with a ring of rays), framed interaction shots that ease in and out
## (begin_shot / end_shot), and add_shake() for lifts and launches.

@export_group("Follow")
## Height of the pivot above the target's feet (shoulder height).
@export var pivot_height: float = 1.45
@export var follow_rate: float = 16.0
## Vertical follow is slower, so stairs feel smooth.
@export var follow_rate_vertical: float = 9.0

@export_group("Boom")
@export var distance_open: float = 3.1
@export var distance_tight: float = 1.75
@export var shoulder_open: float = 0.8
@export var shoulder_tight: float = 0.5
## Fixed boom length; a negative value means "measure the room" (the default).
@export var distance_override: float = -1.0
## Average wall distance (m) at which a room counts as fully tight / fully open.
@export var tight_room_m: float = 1.6
@export var open_room_m: float = 4.6
@export_flags_3d_physics var collision_mask: int = 1

@export_group("Look")
@export var mouse_sensitivity: float = 0.0023
@export var stick_speed: float = 2.8
@export var pitch_min_deg: float = -62.0
@export var pitch_max_deg: float = 38.0
@export var invert_y: bool = false

@export_group("Lens")
@export var base_fov: float = 64.0
@export var sprint_fov_boost: float = 7.0

## The node the rig follows (the Player sets this to itself).
var target: Node3D
## +1 right shoulder, -1 left.
var shoulder_side: float = 1.0
## 0..1, set by the player; widens the lens.
var sprint_amount: float = 0.0
var look_enabled: bool = true

var yaw: float = 0.0
var pitch: float = -0.16

@onready var camera: Camera3D = $Camera3D
@onready var _shoulder_arm: SpringArm3D = $ShoulderArm
@onready var _boom_arm: SpringArm3D = $BoomArm

var _pivot: Vector3 = Vector3.ZERO
var _side_blend: float = 1.0
var _lateral: float = 0.0
var _distance: float = 3.0
var _openness: float = 1.0
var _openness_goal: float = 1.0
var _probe_left: float = 0.0
var _fov_boost: float = 0.0
var _shot_active: bool = false
var _shot_xform: Transform3D = Transform3D.IDENTITY
var _shot_fov: float = 50.0
var _shot_t: float = 0.0
var _shot_seconds: float = 0.7
var _shake_strength: float = 0.0
var _shake_left: float = 0.0
var _shake_total: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	top_level = true
	_shoulder_arm.collision_mask = collision_mask
	_boom_arm.collision_mask = collision_mask
	_distance = distance_open
	_lateral = shoulder_open
	if target != null:
		snap()


## Bodies the camera should ignore (the player's own collider).
func exclude(body: CollisionObject3D) -> void:
	_shoulder_arm.add_excluded_object(body.get_rid())
	_boom_arm.add_excluded_object(body.get_rid())


## Adds mouse / stick movement (radians).
func rotate_look(yaw_delta: float, pitch_delta: float) -> void:
	yaw = wrapf(yaw + yaw_delta, -PI, PI)
	pitch = clampf(pitch + pitch_delta, deg_to_rad(pitch_min_deg), deg_to_rad(pitch_max_deg))


func swap_shoulder() -> void:
	shoulder_side = -shoulder_side


## Unit vector the camera looks along on the floor plane (movement is relative to it).
func forward_flat() -> Vector3:
	return Basis(Vector3.UP, yaw) * Vector3.FORWARD


## Points the gameplay camera along a floor-plane direction.
func face(direction: Vector3) -> void:
	if Vector2(direction.x, direction.z).length() > 0.001:
		yaw = atan2(-direction.x, -direction.z)


## Jumps straight to the target with no smoothing (after a teleport or scene load).
func snap() -> void:
	if target == null:
		return
	_pivot = target.global_position + Vector3.UP * pivot_height
	_side_blend = shoulder_side
	_probe_room()
	_openness = _openness_goal
	_distance = _wanted_distance()
	_lateral = _wanted_shoulder() * _side_blend
	_apply(0.0)


## Eases the camera to a framed shot. Keep calling update_shot() if the shot moves.
func begin_shot(xform: Transform3D, fov: float = 50.0, seconds: float = 0.7) -> void:
	_shot_active = true
	_shot_xform = xform
	_shot_fov = fov
	_shot_seconds = maxf(seconds, 0.001)


func update_shot(xform: Transform3D) -> void:
	_shot_xform = xform


## Eases back to the gameplay camera.
func end_shot(seconds: float = -1.0) -> void:
	_shot_active = false
	if seconds >= 0.0:
		_shot_seconds = maxf(seconds, 0.001)


func is_in_shot() -> bool:
	return _shot_active or _shot_t > 0.001


## 0 on the gameplay camera, 1 fully on the framed shot.
func shot_blend() -> float:
	return _shot_t


## A short, gentle wobble (lift ride, rocket rumble). `strength` is in degrees.
func add_shake(strength: float = 0.4, seconds: float = 0.6) -> void:
	_shake_strength = maxf(_shake_strength, strength)
	_shake_left = maxf(_shake_left, seconds)
	_shake_total = maxf(_shake_left, 0.001)


## Current boom length in metres (shorter in small rooms and against walls).
func boom_length() -> float:
	return _distance


## 0 in a cramped room, 1 in an open one.
func openness() -> float:
	return _openness


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	_time += delta
	if look_enabled:
		var stick := Input.get_vector(PlayerInput.LOOK_LEFT, PlayerInput.LOOK_RIGHT, PlayerInput.LOOK_UP, PlayerInput.LOOK_DOWN)
		if stick.length_squared() > 0.0:
			rotate_look(-stick.x * stick_speed * delta, -stick.y * stick_speed * delta * (-1.0 if invert_y else 1.0))

	# Follow.
	var goal := target.global_position + Vector3.UP * pivot_height
	var flat := _damp_v(Vector3(_pivot.x, 0, _pivot.z), Vector3(goal.x, 0, goal.z), follow_rate, delta)
	_pivot = Vector3(flat.x, lerpf(_pivot.y, goal.y, 1.0 - exp(-follow_rate_vertical * delta)), flat.z)
	if _pivot.distance_to(goal) > 6.0:
		_pivot = goal

	# Room size.
	_probe_left -= delta
	if _probe_left <= 0.0:
		_probe_left = 0.15
		_probe_room()
	_openness = lerpf(_openness, _openness_goal, 1.0 - exp(-3.0 * delta))
	_side_blend = lerpf(_side_blend, shoulder_side, 1.0 - exp(-9.0 * delta))
	_fov_boost = lerpf(_fov_boost, sprint_fov_boost * sprint_amount, 1.0 - exp(-5.0 * delta))
	_shot_t = move_toward(_shot_t, 1.0 if _shot_active else 0.0, delta / _shot_seconds)
	_apply(delta)


func _apply(delta: float) -> void:
	global_transform = Transform3D(Basis.from_euler(Vector3(pitch, yaw, 0.0)), _pivot)

	# Sideways arm: how far the shoulder offset can go before a wall.
	var want_side := _wanted_shoulder() * _side_blend
	var sign_side := 1.0 if want_side >= 0.0 else -1.0
	_shoulder_arm.rotation = Vector3(0.0, sign_side * PI * 0.5, 0.0)
	_shoulder_arm.spring_length = maxf(absf(want_side), 0.01)
	var side_room := minf(absf(want_side), _shoulder_arm.get_hit_length())
	var lateral_goal := sign_side * side_room
	_lateral = lateral_goal if delta <= 0.0 else lerpf(_lateral, lateral_goal, 1.0 - exp(-18.0 * delta))
	if absf(_lateral) > side_room and signf(_lateral) == sign_side:
		_lateral = sign_side * side_room

	# Boom: back from the shoulder. Pull in at once, ease back out.
	var want_dist := _wanted_distance()
	_boom_arm.position = Vector3(_lateral, 0.0, 0.0)
	_boom_arm.spring_length = want_dist
	var room := minf(want_dist, _boom_arm.get_hit_length())
	if delta <= 0.0 or room < _distance:
		_distance = room
	else:
		_distance = lerpf(_distance, room, 1.0 - exp(-4.5 * delta))

	var gameplay := global_transform * Transform3D(Basis.IDENTITY, Vector3(_lateral, 0.0, _distance))
	var blend := smoothstep(0.0, 1.0, _shot_t)
	var final := gameplay.interpolate_with(_shot_xform, blend) if blend > 0.0 else gameplay
	if _shake_left > 0.0:
		_shake_left -= delta
		var fade := clampf(_shake_left / _shake_total, 0.0, 1.0)
		var amount := deg_to_rad(_shake_strength) * fade
		final.basis = final.basis * Basis.from_euler(Vector3(
				sin(_time * 31.0) * amount, sin(_time * 27.0 + 1.7) * amount, sin(_time * 23.0 + 0.4) * amount * 0.5))
		if _shake_left <= 0.0:
			_shake_strength = 0.0
	camera.global_transform = final
	camera.fov = lerpf(base_fov + _fov_boost, _shot_fov, blend)


func _wanted_distance() -> float:
	if distance_override > 0.0:
		return distance_override
	return lerpf(distance_tight, distance_open, _openness)


func _wanted_shoulder() -> float:
	return lerpf(shoulder_tight, shoulder_open, _openness)


## Looks around the pivot with a ring of rays. Walls on most sides mean a small room.
## The two nearest and two farthest readings are dropped, so hugging one wall of a big
## room does not count as "small" and a long corridor still does.
func _probe_room() -> void:
	if not is_inside_tree():
		return
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	var reach := 7.0
	var readings: Array[float] = []
	for i in 8:
		var dir := Basis(Vector3.UP, TAU * i / 8.0) * Vector3.FORWARD
		var query := PhysicsRayQueryParameters3D.create(_pivot, _pivot + dir * reach, collision_mask)
		var hit := space.intersect_ray(query)
		readings.append(reach if hit.is_empty() else _pivot.distance_to(hit["position"]))
	readings.sort()
	var middle := (readings[2] + readings[3] + readings[4] + readings[5]) / 4.0
	_openness_goal = clampf(inverse_lerp(tight_room_m, open_room_m, middle), 0.0, 1.0)


static func _damp_v(from: Vector3, to: Vector3, rate: float, delta: float) -> Vector3:
	return from.lerp(to, 1.0 - exp(-rate * delta))
