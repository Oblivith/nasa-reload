# SI assistance metadata: This code used the help of SI.
class_name StorySelfTest
extends RefCounted

var story: Node
var facility: Node
var player: Player
var failures: PackedStringArray = []

func run(story_node: Node, facility_node: Node) -> void:
	story = story_node
	facility = facility_node
	player = facility.get("_player")
	print("STORY SELFTEST")
	await _settle(8)
	for step: String in ["_test_lobby", "_test_pike", "_test_design_bay", "_test_cafeteria", "_test_ibm",
			"_test_barks", "_test_launch", "_test_dad_office", "_test_ending"]:
		if has_method(step):
			await call(step)
	print("STORY SELFTEST %s" % ("PASS" if failures.is_empty() else "FAIL: " + " | ".join(failures)))
	facility.get_tree().quit(0 if failures.is_empty() else 1)

func _test_lobby() -> void:
	print(" LOBBY")
	_expect(story.objective_id() == "report_to_pike", "first objective is '%s'" % story.objective_text())
	story.play_when_free("moms_bag")
	await _settle(4)
	var note := await _read()
	_expect(note.size() == 1 and note[0].contains("Love, Mom"), "Mom's note shows on arrival")
	_expect(GameState.has_flag("mom_note_seen"), "the note is remembered as seen")
	_expect((await _use_and_read("moms_bag")).size() == 1, "E on the bag shows the note again")
	_expect((await _use_and_read("talk_guard")).size() == 2, "the guard has two lines")

func _expect(ok: bool, what: String) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		failures.append(what)

func _settle(frames: int = 6) -> void:
	for i in frames:
		await facility.get_tree().physics_frame
	await facility.get_tree().process_frame

func _interactable(id: String) -> Interactable:
	for node in facility.get_tree().get_nodes_in_group(Interactable.GROUP):
		if str(node.get_meta("interact_id", "")) == id:
			return node as Interactable
	return null

func _face(id: String) -> bool:
	var it := _interactable(id)
	if it == null:
		return false
	var focus := it.focus_point()
	var world: FacilityWorld = facility.get("world")
	var room_id := world.room_at(focus)
	var floor_y := (world.rooms[room_id] as WorldRoom).base_y if world.rooms.has(room_id) else focus.y - 1.0

	var dirs: Array[Vector3] = []
	if it.camera_point != null:
		var toward := it.camera_point.global_position - focus
		dirs.append(Vector3(toward.x, 0, toward.z).normalized())
	var forward := (it.get_parent() as Node3D).global_basis.z
	dirs.append(Vector3(forward.x, 0, forward.z).normalized())
	for k in 8:
		dirs.append(Vector3(sin(TAU * k / 8.0), 0, cos(TAU * k / 8.0)))
	for dir in dirs:
		for dist: float in [1.2, 1.7, 2.2]:
			var stand: Vector3 = focus + dir * dist

			stand.y = maxf(floor_y, focus.y - 1.6)
			if world.room_at(stand + Vector3(0, 0.9, 0)) != room_id:
				continue
			player.teleport(stand, focus - stand)
			await _settle(5)
			if player.focused() == it:
				return true
	return false

func _use_and_read(id: String) -> PackedStringArray:
	if not await _face(id):
		_expect(false, "can reach and look at '%s'" % id)
		return []
	player.try_interact()
	await _settle(3)
	return await _read()

func _read(decline_confirm: bool = false) -> PackedStringArray:
	var said: PackedStringArray = []
	var box := facility.get("_overlay") as StoryDialogueBox
	var guard := 0
	while box != null and is_instance_valid(box) and not box.is_queued_for_deletion() and guard < 400:
		guard += 1
		var index := box.current_index()
		var entry: Dictionary = box.get("_lines")[index]
		var text := "%s: %s" % [str(entry.get("speaker", "")), str(entry.get("text", ""))]
		if said.is_empty() or said[said.size() - 1] != text:
			said.append(text)
			print("      " + text)
		if bool(entry.get("confirm", false)) and decline_confirm:
			box.skip_all()
		else:
			box.advance()
			box.advance()
		await facility.get_tree().process_frame
		box = facility.get("_overlay") as StoryDialogueBox
	await _settle(3)
	return said
