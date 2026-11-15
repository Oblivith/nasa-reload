# SI assistance metadata: This code used the help of SI.
class_name Interactable
extends Node3D

signal used(player: Player)
signal use_denied(player: Player)
signal focused(player: Player)
signal unfocused(player: Player)
signal interaction_ended(player: Player)

enum Framing {
	NONE,
	OVER_SHOULDER,
	TWO_SHOT,
	CAMERA_POINT,
}

const GROUP := &"interactable"

@export var prompt: String = "Use"
@export var enabled: bool = true
@export var locked: bool = false
@export var locked_prompt: String = "Locked"

@export_range(0.5, 10.0, 0.1) var radius: float = 2.6

@export_range(5.0, 90.0, 1.0) var look_angle_deg: float = 32.0

@export var focus_offset: Vector3 = Vector3(0, 1.0, 0)

@export var prompt_offset: Vector3 = Vector3(0, 0.45, 0)

@export var needs_line_of_sight: bool = true

@export_group("Framing")
@export var framing: Framing = Framing.NONE

@export var camera_point: Node3D

@export var look_point: Node3D

@export var stand_point: Node3D
@export_range(20.0, 90.0, 1.0) var shot_fov: float = 50.0
@export_range(0.0, 3.0, 0.05) var blend_seconds: float = 0.7

@export var hold_player: bool = false

@export var free_mouse: bool = true

@export var cancel_with_key: bool = true

@export var hide_player: bool = false

@export var pose: StringName = &""

var _user: Player = null
var _key_cancel_blocked: bool = false

func _enter_tree() -> void:
	add_to_group(GROUP)

func is_in_use() -> bool:
	return _user != null

func holds_player() -> bool:
	return framing != Framing.NONE or hold_player or stand_point != null

func current_prompt() -> String:
	return locked_prompt if locked else prompt

func focus_point() -> Vector3:
	return global_transform * focus_offset

func prompt_point() -> Vector3:
	return focus_point() + prompt_offset

func look_target() -> Vector3:
	return look_point.global_position if look_point != null else focus_point()

func end_interaction() -> void:
	if _user != null:
		_user.end_interaction()

func hold_while(node: Node) -> void:
	if node == null or _user == null:
		return
	_key_cancel_blocked = true
	node.tree_exited.connect(end_interaction, CONNECT_ONE_SHOT)

func can_cancel_with_key() -> bool:
	return cancel_with_key and not _key_cancel_blocked

func owns_collider(collider: Object) -> bool:
	var node := collider as Node
	var host := get_parent()
	if node == null or host == null:
		return false
	return node == host or host.is_ancestor_of(node)

func shot_transform(stand: Vector3, eye_height: float, side: float, space: PhysicsDirectSpaceState3D,
		exclude: Array[RID] = []) -> Transform3D:
	var target := look_target()
	if framing == Framing.CAMERA_POINT and camera_point != null:
		var at := camera_point.global_position
		if look_point != null and not at.is_equal_approx(target):
			return Transform3D(Basis.looking_at(target - at), at)
		return Transform3D(camera_point.global_basis.orthonormalized(), at)
	var chest := stand + Vector3.UP * eye_height
	var dir := Vector3(target.x - stand.x, 0.0, target.z - stand.z)
	var gap := dir.length()
	dir = dir / gap if gap > 0.01 else Vector3.FORWARD
	var right := dir.cross(Vector3.UP)
	if framing == Framing.TWO_SHOT:
		var mid := (chest + target) * 0.5
		var aim := mid
		var best := Transform3D.IDENTITY
		var best_len := -1.0
		for s: float in [side, -side]:
			var want := mid + right * s * (2.3 + gap * 0.6) - dir * (0.2 + gap * 0.05) + Vector3.UP * 0.1
			var got := _clear_point(aim, want, space, exclude)
			var length := aim.distance_to(got)
			if length > best_len + 0.4:
				best_len = length
				best = Transform3D(Basis.looking_at(aim - got), got)
			if length >= aim.distance_to(want) - 0.05:
				break
		return best

	var want := chest - dir * 2.0 + right * side * 1.05 + Vector3.UP * 0.5
	var got := _clear_point(chest, want, space, exclude)
	var aim := target.lerp(chest, 0.18) - right * side * 0.1
	return Transform3D(Basis.looking_at(aim - got), got)

func _begin(player: Player) -> void:
	_user = player
	_key_cancel_blocked = false

func _finish(player: Player) -> void:
	_user = null
	_key_cancel_blocked = false
	interaction_ended.emit(player)

func _clear_point(from: Vector3, want: Vector3, space: PhysicsDirectSpaceState3D, exclude: Array[RID]) -> Vector3:
	if space == null:
		return want
	var query := PhysicsRayQueryParameters3D.create(from, want, 1, exclude)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return want
	var point: Vector3 = hit["position"]
	var back := (from - want).normalized()
	if from.distance_to(point) < 0.3:
		return from
	return point + back * 0.25
