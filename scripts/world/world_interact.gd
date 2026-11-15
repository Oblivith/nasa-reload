# Code generated with AI assistance (Claude). Reviewed by team.
class_name WorldInteract
extends RefCounted
## Builds the player's Interactable (scripts/player/interactable.gd) for world props,
## doors, lift buttons and stations. Replaces the old InteractStub placeholder.
##
## `at` is the point the player looks at (local to `parent`). With `frame_from`, the
## camera eases to a hand-placed shot from there (Framing.CAMERA_POINT) and the player
## is held until E / Esc or until the caller ends it; without, `used` fires straight away.


static func make(parent: Node3D, id: String, prompt: String, at: Vector3, frame_from: Vector3 = Vector3.INF) -> Interactable:
	var it := Interactable.new()
	it.name = "Interact_" + id
	it.set_meta("interact_id", id)
	it.prompt = clean_prompt(prompt)
	it.focus_offset = Vector3.ZERO
	it.prompt_offset = Vector3(0, 0.35, 0)
	it.radius = 2.8
	parent.add_child(it)
	it.position = at
	if frame_from != Vector3.INF and not frame_from.is_equal_approx(at):
		var marker := Marker3D.new()
		marker.name = "CameraPoint"
		it.add_child(marker)
		marker.position = frame_from - at
		var look := at - frame_from
		if look.length() > 0.01 and absf(look.normalized().dot(Vector3.UP)) < 0.99:
			marker.basis = Basis.looking_at(look, Vector3.UP)
		it.camera_point = marker
		it.framing = Interactable.Framing.CAMERA_POINT
	return it


## Data prompts carry the old "E  " key prefix; the player's prompt draws its own key cap.
static func clean_prompt(text: String) -> String:
	var t := text.strip_edges()
	if t.begins_with("E ") or t.begins_with("[E]"):
		t = t.trim_prefix("[E]").trim_prefix("E").strip_edges()
	return t
