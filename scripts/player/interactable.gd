# Code generated with AI assistance (Claude). Reviewed by team.
class_name Interactable
extends Node3D
## Makes its parent something the player can look at and use with E.
##
## Add one as a child of any object or NPC (position it at the object's base), set
## `prompt`, and connect `used`:
##
##   var it := Interactable.new()
##   it.prompt = "Talk to Dot"                       # shown as  [E] Talk to Dot
##   it.framing = Interactable.Framing.TWO_SHOT      # camera eases to a framed shot
##   it.used.connect(func(player: Player) -> void:
##       var dialogue := DotDialogue.new()
##       ui_layer.add_child(dialogue)
##       it.hold_while(dialogue))                    # shot ends when the UI closes
##   dot.add_child(it)
##
## With Framing.NONE (and hold_player off) `used` fires and the player keeps control.
## With any other framing the player is held (no walking, camera on the shot) until
## end_interaction() is called, the node given to hold_while() leaves the tree, or the
## player presses E / Esc (when cancel_with_key is on).
##
## A locked interactable shows `locked_prompt` and emits `use_denied` instead of `used`
## (doors jiggle on it). Set `enabled = false` to hide it from the player entirely.

signal used(player: Player)
signal use_denied(player: Player)
signal focused(player: Player)
signal unfocused(player: Player)
signal interaction_ended(player: Player)

enum Framing {
	NONE,            ## No camera move.
	OVER_SHOULDER,   ## Behind the player's shoulder, looking at the object (keypunch).
	TWO_SHOT,        ## Player and target both in frame from the side (conversations).
	CAMERA_POINT,    ## Exactly at `camera_point` (hand-placed shot).
}

const GROUP := &"interactable"

## Text after the key cap: "Talk to Dot", "Use keypunch".
@export var prompt: String = "Use"
@export var enabled: bool = true
@export var locked: bool = false
@export var locked_prompt: String = "Locked"
## How close the player must stand (metres, measured on the floor plane).
@export_range(0.5, 10.0, 0.1) var radius: float = 2.6
## How far off the centre of the screen the object may be and still count as "looked at".
@export_range(5.0, 90.0, 1.0) var look_angle_deg: float = 32.0
## Point the player looks at, relative to this node: the middle of the object.
@export var focus_offset: Vector3 = Vector3(0, 1.0, 0)
## Where the prompt floats, relative to the focus point.
@export var prompt_offset: Vector3 = Vector3(0, 0.45, 0)
## Walls between the player and the focus point block the interaction.
@export var needs_line_of_sight: bool = true

@export_group("Framing")
@export var framing: Framing = Framing.NONE
## Camera position and aim for Framing.CAMERA_POINT (a Marker3D; -Z is the view direction).
@export var camera_point: Node3D
## What the shot aims at. Defaults to the focus point.
@export var look_point: Node3D
## Where the player stands (and which way they face) while interacting. Optional.
@export var stand_point: Node3D
@export_range(20.0, 90.0, 1.0) var shot_fov: float = 50.0
@export_range(0.0, 3.0, 0.05) var blend_seconds: float = 0.7
## Hold the player even with Framing.NONE (a UI opens but the camera stays put).
@export var hold_player: bool = false
## Show the mouse cursor while interacting (for UI overlays and click-to-pick shelves).
@export var free_mouse: bool = true
## E or Esc ends the interaction. hold_while() turns this off for that interaction.
@export var cancel_with_key: bool = true
## Hide the player figure during the shot (close-ups of a shelf, a notice, a book).
@export var hide_player: bool = false
## Figure pose while interacting: "", "type", "sit", "sit_type", "talk" (FigureAnimator).
@export var pose: StringName = &""

var _user: Player = null
var _key_cancel_blocked: bool = false


func _enter_tree() -> void:
	add_to_group(GROUP)


## True while a player is held by this interactable.
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


## Ends the interaction started by `used` (camera returns, player gets control back).
func end_interaction() -> void:
	if _user != null:
		_user.end_interaction()


## Keeps the interaction going for as long as `node` (a UI overlay, a dialogue) is in
## the tree, then ends it. The overlay owns Esc, so key-cancel is off meanwhile.
func hold_while(node: Node) -> void:
	if node == null or _user == null:
		return
	_key_cancel_blocked = true
	node.tree_exited.connect(end_interaction, CONNECT_ONE_SHOT)


func can_cancel_with_key() -> bool:
	return cancel_with_key and not _key_cancel_blocked


## True when `collider` belongs to the object this interactable sits on, so it does not
## count as blocking the line of sight.
func owns_collider(collider: Object) -> bool:
	var node := collider as Node
	var host := get_parent()
	if node == null or host == null:
		return false
	return node == host or host.is_ancestor_of(node)


## Camera transform for the framed shot. `side` is +1 for the right shoulder, -1 left.
## `stand` is where the player's feet are, `eye_height` the height of their shoulders.
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
	# OVER_SHOULDER (also the fallback when a camera point is missing).
	var want := chest - dir * 2.0 + right * side * 1.05 + Vector3.UP * 0.5
	var got := _clear_point(chest, want, space, exclude)
	var aim := target.lerp(chest, 0.18) - right * side * 0.1
	return Transform3D(Basis.looking_at(aim - got), got)


# --- Called by Player ------------------------------------------------------------------

func _begin(player: Player) -> void:
	_user = player
	_key_cancel_blocked = false


func _finish(player: Player) -> void:
	_user = null
	_key_cancel_blocked = false
	interaction_ended.emit(player)


## Pulls `want` back toward `from` if a wall is in the way.
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
