# Code generated with AI assistance (Claude). Reviewed by team.
class_name TempCam
extends CharacterBody3D
## TEMPORARY first-person walk / fly camera, used to test the world until Session A's
## third-person player (/scripts/player/) is merged. Delete it then.
##
## What the world expects from whatever replaces it (the "player contract"):
##   * the body is in group "player" (rooms, doors, lift, NPCs and audio look it up);
##   * it is a CharacterBody3D on collision layer 1 with gravity (stairs are ramps);
##   * optional `add_camera_shake(amount)`: the lift calls it during a ride;
##   * optional `frame_to(marker, seconds)` / `release_frame()` for interaction shots;
##   * optional `input_enabled` (bool): the world sets it false while riding the lift.
##
## Controls: click to capture the mouse, WASD + mouse, Shift run, V fly / noclip
## (Space / Ctrl = up / down while flying), Esc frees the mouse.

const WALK := 4.2
const RUN := 7.5
const FLY := 12.0
const GRAVITY := 22.0
const EYE := 1.62

var camera: Camera3D
var input_enabled: bool = true
var flying: bool = false
var surface_hint: String = ""

var _yaw: float = 0.0
var _pitch: float = 0.0
var _shake: float = 0.0
var _framing: Marker3D = null
var _frame_t: float = 0.0
var _frame_len: float = 0.5
var _frame_from: Transform3D
var _collider: CollisionShape3D
var _crosshair: Control


func _init() -> void:
	add_to_group("player")
	collision_layer = 1
	collision_mask = 1
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(50.0)
	_collider = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.75
	_collider.shape = capsule
	_collider.position.y = 0.875
	add_child(_collider)
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.near = 0.08
	camera.far = 160.0
	camera.position.y = EYE
	add_child(camera)


func _ready() -> void:
	camera.make_current()
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	_crosshair = ColorRect.new()
	(_crosshair as ColorRect).color = Color(1, 0.96, 0.85, 0.75)
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.offset_left = -3
	_crosshair.offset_top = -3
	_crosshair.offset_right = 3
	_crosshair.offset_bottom = 3
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_crosshair)


func set_yaw(yaw: float) -> void:
	_yaw = yaw
	_pitch = 0.0
	rotation.y = _yaw
	camera.rotation.x = 0.0


func mouse_captured() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func add_camera_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


## Eases the camera to `marker` (an interaction's framing point); release_frame() returns.
func frame_to(marker: Marker3D, seconds: float = 0.5) -> void:
	if marker == null:
		return
	_framing = marker
	_frame_from = camera.global_transform
	_frame_t = 0.0
	_frame_len = maxf(0.05, seconds)


func release_frame() -> void:
	_framing = null
	camera.top_level = false
	camera.position = Vector3(0, EYE, 0)
	camera.rotation = Vector3(_pitch, 0, 0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and mouse_captured() and input_enabled and _framing == null:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * 0.0026
		_pitch = clampf(_pitch - motion.relative.y * 0.0026, -1.45, 1.45)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and not mouse_captured() and input_enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var code := (event as InputEventKey).physical_keycode
		if code == KEY_ESCAPE and mouse_captured():
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif code == KEY_V and input_enabled:
			flying = not flying
			_collider.disabled = flying


func _physics_process(delta: float) -> void:
	_crosshair.visible = mouse_captured() and _framing == null
	rotation.y = _yaw
	var wish := Vector3.ZERO
	if input_enabled and _framing == null:
		var x := float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
		var z := float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
		wish = (global_transform.basis * Vector3(x, 0, z))
		wish.y = 0.0
		wish = wish.normalized()
	var running := Input.is_physical_key_pressed(KEY_SHIFT)
	if flying:
		var up := float(Input.is_physical_key_pressed(KEY_SPACE)) - float(Input.is_physical_key_pressed(KEY_CTRL))
		global_position += (wish + Vector3.UP * up) * FLY * (2.0 if running else 1.0) * delta
		velocity = Vector3.ZERO
	else:
		var speed := RUN if running else WALK
		velocity.x = move_toward(velocity.x, wish.x * speed, 40.0 * delta)
		velocity.z = move_toward(velocity.z, wish.z * speed, 40.0 * delta)
		velocity.y = -1.0 if is_on_floor() else velocity.y - GRAVITY * delta
		move_and_slide()
	camera.fov = lerpf(camera.fov, 76.0 if (running and wish != Vector3.ZERO) else 70.0, minf(1.0, delta * 6.0))
	_shake = move_toward(_shake, 0.0, delta * 1.5)
	if _framing != null and is_instance_valid(_framing):
		_frame_t = minf(1.0, _frame_t + delta / _frame_len)
		var k := smoothstep(0.0, 1.0, _frame_t)
		camera.top_level = true
		camera.global_transform = _frame_from.interpolate_with(_framing.global_transform, k)
	else:
		camera.rotation = Vector3(_pitch, 0, 0)
		camera.position = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.03 + Vector3(0, EYE, 0)
