# SI assistance metadata: This code used the help of SI.
class_name WorldInteract
extends RefCounted

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

static func clean_prompt(text: String) -> String:
	var t := text.strip_edges()
	if t.begins_with("E ") or t.begins_with("[E]"):
		t = t.trim_prefix("[E]").trim_prefix("E").strip_edges()
	return t
