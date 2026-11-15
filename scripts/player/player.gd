# Code generated with AI assistance (Claude). Reviewed by team.
class_name Player
extends CharacterBody3D
## The protagonist: third-person movement, over-the-shoulder camera, and look + E
## interaction. Instance scenes/player/Player.tscn into any level; it brings its own
## camera, figure and prompt. The node's -Z at spawn is the way the player faces.
##
##   WASD / arrows  move (relative to the camera)     Shift  sprint
##   Mouse          look (click to capture the cursor) Q      swap shoulder
##   E              use what you are looking at        Esc    leave / free the cursor
##
## World code talks to it through:
##   Interactable                    attach to objects (see interactable.gd)
##   focus_changed / interaction_started / interaction_ended / footstep signals
##   set_control_enabled(false)      freeze the player and free the mouse (menus, cutscenes)
##   teleport(position, facing)      move with no camera lag (lifts, room starts)
##   camera_rig.add_shake(...)       lift rides, engine rumble
##   set_carrying(true), hand_anchor()  hold a part in the right hand
##
## Collision: body on layer 1, collides with layer 1. Floors may carry
## set_meta("surface", &"lino") and it is passed along with the footstep signal.

signal focus_changed(interactable: Interactable)
signal interaction_started(interactable: Interactable)
signal interaction_ended(interactable: Interactable)
signal footstep(surface: StringName, running: bool)

const GROUP := &"player"
const EYE_HEIGHT := 1.45

@export_group("Movement")
@export var walk_speed: float = 3.4
@export var sprint_speed: float = 6.2
@export var acceleration: float = 26.0
@export var deceleration: float = 34.0
@export var turn_speed_deg: float = 640.0
@export var turn_in_place_deg: float = 300.0
@export var gravity: float = 24.0
## Tallest ledge the player walks straight up (stair risers). 0 turns stepping off.
@export var step_height: float = 0.26

@export_group("Interaction")
@export var interact_enabled: bool = true
## Capture the mouse for looking around. Off for tests and screenshot runs.
@export var capture_mouse: bool = true
@export_flags_3d_physics var sight_mask: int = 1
## A small dot at the centre of the screen, so it is clear what "looking at" means.
@export var show_reticle: bool = true

@onready var figure: BrickFigure = $Figure
@onready var camera_rig: PlayerCamera = $CameraRig
@onready var prompt: InteractionPrompt = $PromptLayer/Prompt

var control_enabled: bool = true
var sprinting: bool = false

var _yaw: float = 0.0
var _turn_rate: float = 0.0
var _focus: Interactable = null
var _active: Interactable = null
var _stand_pos: Vector3 = Vector3.ZERO
var _step_grace: float = 0.0
var _visual_y: float = 0.0
var _overlook_time: float = 0.0
var _turning_to_focus: bool = false
var _shot_hides_figure: bool = false
var _carrying: bool = false
var _surface: StringName = &"default"


func _ready() -> void:
	PlayerInput.ensure_actions()
	add_to_group(GROUP)
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(46.0)
	var facing := -global_basis.z
	var at := global_position
	global_transform = Transform3D(Basis.IDENTITY, at)
	_yaw = atan2(facing.x, facing.z)
	_visual_y = at.y
	figure.rotation.y = _yaw
	figure.animator.walk_speed = walk_speed
	figure.animator.run_speed = sprint_speed
	figure.animator.footstep.connect(_on_footstep)
	camera_rig.target = self
	camera_rig.exclude(self)
	camera_rig.face(facing)
	camera_rig.snap()
	_update_mouse()


func _exit_tree() -> void:
	if _active != null:
		var it := _active
		_active = null
		it._finish(self)
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# --- Public API ------------------------------------------------------------------------

## The interactable the player is looking at (null for none).
func focused() -> Interactable:
	return _focus


## The interactable currently holding the player (null for none).
func active_interactable() -> Interactable:
	return _active


func is_interacting() -> bool:
	return _active != null


## False freezes movement, look and interaction and shows the mouse (menus, cutscenes).
func set_control_enabled(on: bool) -> void:
	control_enabled = on
	if not on:
		_set_focus(null)
	_update_mouse()


## Moves the player with no camera lag. `facing` is a floor-plane direction (optional).
func teleport(to: Vector3, facing: Vector3 = Vector3.ZERO) -> void:
	global_position = to
	velocity = Vector3.ZERO
	_visual_y = to.y
	figure.position.y = 0.0
	if Vector2(facing.x, facing.z).length() > 0.001:
		_yaw = atan2(facing.x, facing.z)
		figure.rotation.y = _yaw
		camera_rig.face(facing)
	reset_physics_interpolation()
	camera_rig.snap()


## Unit vector the figure faces on the floor plane.
func facing_direction() -> Vector3:
	return Vector3(sin(_yaw), 0.0, cos(_yaw))


func head_position() -> Vector3:
	return figure.head_position()


## Right-hand node: parent a small prop here to have the player hold it.
func hand_anchor() -> Node3D:
	return figure.part(&"HandR")


## Raises the right arm as if holding something.
func set_carrying(on: bool) -> void:
	_carrying = on


## Uses the focused interactable (same as pressing E). Returns true if it was used.
func try_interact() -> bool:
	if _focus == null or _active != null or not control_enabled or not interact_enabled:
		return false
	var it := _focus
	if it.locked:
		it.use_denied.emit(self)
		return false
	if it.holds_player():
		begin_interaction(it)
	else:
		it.used.emit(self)
	return true


## Holds the player on `it`: no walking, camera eases to its framed shot.
func begin_interaction(it: Interactable) -> void:
	if it == null:
		return
	if _active != null:
		end_interaction()
	_active = it
	_set_focus(null)
	it._begin(self)
	_stand_pos = it.stand_point.global_position if it.stand_point != null else global_position
	camera_rig.look_enabled = false
	if it.framing != Interactable.Framing.NONE:
		camera_rig.begin_shot(_shot_for(it), it.shot_fov, it.blend_seconds)
	_update_mouse()
	interaction_started.emit(it)
	it.used.emit(self)


## Releases the player: camera eases back, control returns.
func end_interaction() -> void:
	if _active == null:
		return
	var it := _active
	_active = null
	camera_rig.end_shot(it.blend_seconds * 0.85)
	camera_rig.look_enabled = true
	_update_mouse()
	it._finish(self)
	interaction_ended.emit(it)


# --- Input -----------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and control_enabled and camera_rig.look_enabled:
			var s := camera_rig.mouse_sensitivity
			camera_rig.rotate_look(-motion.relative.x * s, -motion.relative.y * s * (-1.0 if camera_rig.invert_y else 1.0))
		return
	var button := event as InputEventMouseButton
	if button != null:
		# Browsers only lock the pointer after a click, so any click re-captures it.
		if button.pressed and _wants_mouse() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
		return
	if event.is_echo():
		return
	if event.is_action_pressed(PlayerInput.INTERACT):
		if _active != null:
			if _active.can_cancel_with_key():
				end_interaction()
				get_viewport().set_input_as_handled()
		elif try_interact():
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed(PlayerInput.CANCEL):
		if _active != null:
			if _active.can_cancel_with_key():
				end_interaction()
				get_viewport().set_input_as_handled()
		elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE    # not consumed: levels may also use Esc
	elif event.is_action_pressed(PlayerInput.SWAP_SHOULDER):
		if control_enabled and _active == null:
			camera_rig.swap_shoulder()
			get_viewport().set_input_as_handled()


func _wants_mouse() -> bool:
	if not capture_mouse or not control_enabled:
		return false
	return _active == null or not _active.free_mouse


func _update_mouse() -> void:
	if not capture_mouse or DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _wants_mouse() else Input.MOUSE_MODE_VISIBLE


# --- Movement --------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var can_move := control_enabled and _active == null
	var input := Vector2.ZERO
	if can_move:
		input = Input.get_vector(PlayerInput.MOVE_LEFT, PlayerInput.MOVE_RIGHT, PlayerInput.MOVE_FORWARD, PlayerInput.MOVE_BACK)
	var wish := Vector3.ZERO
	if input.length() > 0.01:
		wish = Basis(Vector3.UP, camera_rig.yaw) * Vector3(input.x, 0.0, input.y)
	sprinting = can_move and input.length() > 0.5 and Input.is_action_pressed(PlayerInput.SPRINT)
	var goal_velocity := wish * (sprint_speed if sprinting else walk_speed)

	# While interacting, walk the last few steps onto the stand point (if there is one).
	if _active != null and _active.stand_point != null:
		var to_stand := Vector3(_stand_pos.x - global_position.x, 0.0, _stand_pos.z - global_position.z)
		if to_stand.length() > 0.05:
			goal_velocity = to_stand.normalized() * minf(walk_speed, to_stand.length() * 6.0)

	var flat := Vector3(velocity.x, 0.0, velocity.z)
	flat = flat.move_toward(goal_velocity, (acceleration if goal_velocity != Vector3.ZERO else deceleration) * delta)
	velocity.x = flat.x
	velocity.z = flat.z
	_step_grace = maxf(0.0, _step_grace - delta)
	var before := global_position
	if is_on_floor() or _step_grace > 0.0:
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta
	if not _try_step_up(delta):
		move_and_slide()
		_note_floor_surface()
	var moved := (global_position - before) / maxf(delta, 0.0001)

	_update_facing(delta, wish)

	# Feed the figure.
	var animator := figure.animator
	animator.speed = Vector2(moved.x, moved.z).length()
	animator.turn_rate = lerpf(animator.turn_rate, _turn_rate, 0.4)
	if _active != null:
		animator.pose = _active.pose
		figure.look_at_point(_active.look_target())
	else:
		animator.pose = &"carry" if _carrying else &""
		if _focus != null:
			figure.look_at_point(_focus.focus_point())
		else:
			# Nothing to look at: the head follows where the camera is pointed.
			figure.look_at_point(figure.head_position() - camera_rig.camera.global_basis.z * 6.0)
	camera_rig.sprint_amount = clampf(inverse_lerp(walk_speed, sprint_speed, animator.speed), 0.0, 1.0)

	# Smooth the figure over stair steps (the collider itself snaps up each riser).
	_visual_y = lerpf(_visual_y, global_position.y, 1.0 - exp(-18.0 * delta))
	_visual_y = clampf(_visual_y, global_position.y - 0.4, global_position.y + 0.4)
	figure.position.y = _visual_y - global_position.y
	# Hide the figure when the camera is squeezed right up against it.
	if _active != null:
		_shot_hides_figure = _active.hide_player
	elif not camera_rig.is_in_shot():
		_shot_hides_figure = false
	if _shot_hides_figure:
		figure.visible = camera_rig.shot_blend() < 0.35
	else:
		figure.visible = camera_rig.is_in_shot() or camera_rig.boom_length() > 0.55

	if _active != null:
		if _active.framing != Interactable.Framing.NONE:
			camera_rig.update_shot(_shot_for(_active))
	elif control_enabled and interact_enabled:
		_set_focus(_find_focus())
	prompt.show_for(_focus, camera_rig.camera)
	prompt.set_reticle(show_reticle and control_enabled and _active == null and not camera_rig.is_in_shot())


func _update_facing(delta: float, wish: Vector3) -> void:
	var desired := _yaw
	var rate := deg_to_rad(turn_speed_deg)
	var in_place := false
	if _active != null:
		in_place = true
		var at_stand := _active.stand_point != null
		if at_stand and Vector2(_stand_pos.x - global_position.x, _stand_pos.z - global_position.z).length() < 0.4:
			var f := -_active.stand_point.global_basis.z
			desired = atan2(f.x, f.z)
		else:
			var to := _active.look_target() - global_position
			if Vector2(to.x, to.z).length() > 0.05:
				desired = atan2(to.x, to.z)
	elif wish != Vector3.ZERO:
		desired = atan2(wish.x, wish.z)
		_overlook_time = 0.0
		_turning_to_focus = false
	elif _focus != null:
		# Standing still with the thing we are looking at round to the side: after a
		# moment, shuffle round to face it (turn in place) and finish the turn.
		var to := _focus.focus_point() - global_position
		var off := absf(angle_difference(_yaw, atan2(to.x, to.z)))
		if _turning_to_focus:
			_turning_to_focus = off > 0.08
		elif off > 1.1:
			_overlook_time += delta
			_turning_to_focus = _overlook_time > 0.3
		else:
			_overlook_time = 0.0
		if _turning_to_focus:
			in_place = true
			desired = atan2(to.x, to.z)
	else:
		_overlook_time = 0.0
		_turning_to_focus = false
	var diff := angle_difference(_yaw, desired)
	if in_place:
		rate = deg_to_rad(turn_in_place_deg) * clampf(absf(diff) / 0.7, 0.2, 1.0)
	var step := clampf(diff, -rate * delta, rate * delta)
	_yaw = wrapf(_yaw + step, -PI, PI)
	_turn_rate = step / maxf(delta, 0.0001)
	figure.rotation.y = _yaw


## Walks up a low ledge (a stair riser): lift the body, move it forward, set it down.
## Returns true when it moved the body itself, so move_and_slide is skipped this tick.
func _try_step_up(delta: float) -> bool:
	if step_height <= 0.0 or not (is_on_floor() or _step_grace > 0.0):
		return false
	var motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	if motion.length() < 0.0005:
		return false
	var start := global_transform
	var hit := KinematicCollision3D.new()
	if not test_move(start, motion, hit):
		return false
	if hit.get_normal().y > 0.72:
		return false                                  # a slope we can simply walk up
	if hit.get_position().y - global_position.y > step_height + 0.02:
		return false                                  # too tall: a wall or furniture
	var rise := Vector3.UP * step_height
	var up_hit := KinematicCollision3D.new()
	if test_move(start, rise, up_hit):
		rise = up_hit.get_travel()
	if rise.y < 0.05:
		return false
	var raised := start.translated(rise)
	var travel := motion
	var ahead_hit := KinematicCollision3D.new()
	if test_move(raised, motion, ahead_hit):
		travel = ahead_hit.get_travel()
		if travel.length() < motion.length() * 0.2:
			return false
	var over := raised.translated(travel)
	var down_hit := KinematicCollision3D.new()
	if not test_move(over, -rise - Vector3.UP * 0.05, down_hit):
		return false
	var landed := over.origin + down_hit.get_travel()
	if landed.y <= global_position.y + 0.004 or down_hit.get_normal().y < 0.2:
		return false
	global_position = landed
	velocity.y = 0.0
	_step_grace = 0.2
	return true


func _note_floor_surface() -> void:
	if not is_on_floor():
		return
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if collision.get_normal().y > 0.6:
			var collider := collision.get_collider()
			if collider != null:
				_surface = collider.get_meta(&"surface", &"default")
			return


func _on_footstep(_left_foot: bool) -> void:
	if is_on_floor() or _step_grace > 0.0:
		footstep.emit(_surface, sprinting)


# --- Interaction -----------------------------------------------------------------------

func _set_focus(it: Interactable) -> void:
	if it == _focus:
		return
	if _focus != null and is_instance_valid(_focus):
		_focus.unfocused.emit(self)
	_focus = it
	_overlook_time = 0.0
	_turning_to_focus = false
	if it != null:
		it.focused.emit(self)
	focus_changed.emit(it)


## Picks the interactable nearest the centre of the screen that is within reach.
func _find_focus() -> Interactable:
	var cam := camera_rig.camera
	var cam_pos := cam.global_position
	var cam_forward := -cam.global_basis.z
	var feet := global_position
	var eyes := feet + Vector3.UP * EYE_HEIGHT
	var facing := facing_direction()
	var best: Interactable = null
	var best_score := INF
	for node in get_tree().get_nodes_in_group(Interactable.GROUP):
		var it := node as Interactable
		if it == null or not it.enabled or not it.is_visible_in_tree():
			continue
		var point := it.focus_point()
		var flat := Vector3(point.x - feet.x, 0.0, point.z - feet.z)
		var reach := flat.length()
		if reach > it.radius or absf(point.y - eyes.y) > 2.0:
			continue
		var angle := rad_to_deg(cam_forward.angle_to(point - cam_pos))
		var limit := it.look_angle_deg + (8.0 if it == _focus else 0.0)
		if angle > limit:
			# Not centred, but right under the player's nose still counts.
			if not (reach < 1.3 and angle < 75.0 and rad_to_deg(facing.angle_to(flat)) < 40.0):
				continue
		if it.needs_line_of_sight and not _can_see(eyes, point, it):
			continue
		var score := angle + reach * 6.0 - (10.0 if it == _focus else 0.0)
		if score < best_score:
			best_score = score
			best = it
	return best


func _can_see(from: Vector3, point: Vector3, it: Interactable) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, point, sight_mask, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or it.owns_collider(hit["collider"]):
		return true
	return (hit["position"] as Vector3).distance_to(point) < 0.9


func _shot_for(it: Interactable) -> Transform3D:
	var exclude: Array[RID] = [get_rid()]
	return it.shot_transform(_stand_pos, EYE_HEIGHT, camera_rig.shoulder_side, get_world_3d().direct_space_state, exclude)
