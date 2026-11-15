# SI assistance metadata: This code used the help of SI.
extends Node

signal objective_changed(id: String, text: String)

const DIALOGUE_FILE := "story_dialogue"
const FLOW_FILE := "story_level1"

const REF_PREFIX := "@"

var dialogue: Dictionary = {}
var flow: Dictionary = {}

var autoplay: bool = true

var _layer: CanvasLayer
var _host: Node = null
var _captions: StoryDialogueBox = null
var _queue: Array = []
var _tracker: ObjectiveTracker
var _selftest: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	dialogue = DataLoader.raw.get(DIALOGUE_FILE, {})
	flow = DataLoader.raw.get(FLOW_FILE, {})
	autoplay = OS.get_cmdline_user_args().is_empty()
	_selftest = "--storytest" in OS.get_cmdline_user_args()
	for file: String in flow.get("line_refs_in", []):
		if DataLoader.raw.has(file):
			DataLoader.raw[file] = _resolve_refs(DataLoader.raw[file])
	_layer = CanvasLayer.new()
	_layer.name = "StoryLayer"
	_layer.layer = 20
	add_child(_layer)
	_tracker = ObjectiveTracker.new()
	_tracker.visible = false
	_layer.add_child(_tracker)
	_tracker.set_labels(text("ui.tracker_title"), text("ui.tracker_done"))
	StoryTriggers.event_fired.connect(_on_event)
	StoryTriggers.area_entered.connect(_on_area)
	SceneManager.scene_changed.connect(_on_scene_changed)

func line(ref: String) -> Dictionary:
	var dot := ref.find(".")
	if dot < 0:
		return {}
	var scene: Dictionary = (dialogue.get("scenes", {}) as Dictionary).get(ref.left(dot), {})
	var entry: Variant = scene.get(ref.substr(dot + 1))
	return entry if entry is Dictionary else {}

func has_line(ref: String) -> bool:
	return not line(ref).is_empty()

func text(ref: String) -> String:
	var entry := line(ref)
	if entry.is_empty():
		push_warning("Story: no line '%s' in %s.json" % [ref, DIALOGUE_FILE])
		return "[%s]" % ref
	return str(entry.get("text", ""))

func speaker(ref: String) -> String:
	var key := str(line(ref).get("speaker", ""))
	return str((dialogue.get("speakers", {}) as Dictionary).get(key, key.to_upper()))

func entry(ref: String, extra: Dictionary = {}) -> Dictionary:
	var result := {"id": ref, "speaker": speaker(ref), "text": text(ref)}
	result.merge(extra, true)
	return result

func lines(refs: Array, extra: Dictionary = {}) -> Array:
	var result: Array = []
	for ref in refs:
		result.append(entry(str(ref), extra))
	return result

func ui_number(key: String, fallback: float) -> float:
	return float((flow.get("ui", {}) as Dictionary).get(key, fallback))

func _resolve_refs(value: Variant) -> Variant:
	if value is String:
		var s: String = value
		if s.begins_with(REF_PREFIX) and has_line(s.substr(REF_PREFIX.length())):
			return text(s.substr(REF_PREFIX.length()))
		return s
	if value is Array:
		var list: Array = value
		for i in list.size():
			list[i] = _resolve_refs(list[i])
		return list
	if value is Dictionary:
		var dict: Dictionary = value
		for key in dict:
			dict[key] = _resolve_refs(dict[key])
		return dict
	return value

func _all_set(flags: Variant) -> bool:
	if flags is Array:
		for flag in flags:
			if not GameState.has_flag(str(flag)):
				return false
	return true

func _none_set(flags: Variant) -> bool:
	if flags is Array:
		for flag in flags:
			if GameState.has_flag(str(flag)):
				return false
	return true

func _set_flags(flags: Variant) -> void:
	if flags is Array:
		for flag in flags:
			GameState.set_flag(str(flag))

func make_box(box_lines: Array, passive: bool = false) -> StoryDialogueBox:
	var box := StoryDialogueBox.new()
	box.passive = passive
	box.chars_per_second = ui_number("chars_per_second", 60.0)
	box.caption_seconds = ui_number("caption_seconds", 2.6)
	box.hint_next = "%s    %s" % [text("ui.hint_next"), text("ui.hint_skip_line")]
	box.hint_close = text("ui.hint_close")
	box.start(box_lines)
	return box

func present(box_lines: Array, options: Dictionary = {}) -> StoryDialogueBox:
	if box_lines.is_empty():
		return null
	var box := make_box(box_lines)
	box.esc_skips_all = bool(options.get("esc_skips_all", true))
	if _has_host():
		_host.call("open_story_overlay", box)
		var player := get_tree().get_first_node_in_group("player") as Player
		if player != null and player.active_interactable() != null:
			player.active_interactable().hold_while(box)
	else:
		_layer.add_child(box)
	return box

func caption(box_lines: Array) -> StoryDialogueBox:
	if box_lines.is_empty():
		return null
	if _captions != null and is_instance_valid(_captions):
		_captions.queue_free()
	_captions = make_box(box_lines, true)
	_layer.add_child(_captions)
	return _captions

func _has_host() -> bool:
	return _host != null and is_instance_valid(_host) and _host.is_inside_tree()

func _screen_busy() -> bool:
	if not _has_host():
		return false
	if bool(_host.call("story_overlay_open")):
		return true
	var player := get_tree().get_first_node_in_group("player") as Player
	return player != null and player.is_interacting()

func play(trigger_id: String, context: Dictionary = {}) -> StoryDialogueBox:
	for case: Dictionary in (flow.get("triggers", {}) as Dictionary).get(trigger_id, []):
		if not _all_set(case.get("if")) or not _none_set(case.get("unless")):
			continue
		var box_lines := _case_lines(case, context)
		var box := present(box_lines)
		if box == null:
			_finish_case(case)
		else:
			box.finished.connect(func(_completed: bool) -> void: _finish_case(case))
		return box
	return null

func play_when_free(trigger_id: String) -> void:
	if not _queue.has(trigger_id):
		_queue.append(trigger_id)

func _case_lines(case: Dictionary, _context: Dictionary) -> Array:
	return lines(case.get("lines", []))

func _finish_case(case: Dictionary) -> void:
	_set_flags(case.get("set"))
	if str(case.get("fire", "")) != "":
		StoryTriggers.fire(str(case["fire"]))

func _on_event(event_id: String, payload: Dictionary) -> void:
	_objective_signal("event", event_id)
	if event_id == "tapes_all_heard":
		var protagonist := get_tree().get_first_node_in_group("player")
		if protagonist != null and protagonist.has_node("Figure"):
			protagonist.get_node("Figure").call("set_expression", "duel")
	if (flow.get("triggers", {}) as Dictionary).has(event_id):
		play(event_id, payload)

func _process(_delta: float) -> void:
	if not _queue.is_empty() and not _screen_busy():
		play(str(_queue.pop_front()))

func _on_area(area_id: String, _first_time: bool) -> void:
	_objective_signal("area", area_id)
	if not autoplay:
		return
	for auto: Dictionary in flow.get("autoplay", []):
		if str(auto.get("area", "")) == area_id and _all_set(auto.get("if")) and _none_set(auto.get("unless")):
			var trigger_id := str(auto.get("trigger", ""))
			get_tree().create_timer(float(auto.get("delay", 1.0))).timeout.connect(func() -> void:
				if _none_set(auto.get("unless")):
					play_when_free(trigger_id))

func attach_facility(facility: Node) -> void:
	_host = facility
	_tracker.visible = true
	_tracker.show_objective(objective_text())
	if _selftest:
		_selftest = false
		StorySelfTest.new().run.call_deferred(self, facility)

func _on_scene_changed(path: String) -> void:

	if not _has_host() or path.contains("title") or path.contains("cutscenes"):
		_tracker.visible = false

func objectives() -> Array:
	return flow.get("objectives", [])

func objective_index() -> int:
	var steps := objectives()
	for i in steps.size():
		if not GameState.has_flag("obj_" + str((steps[i] as Dictionary)["id"])):
			return i
	return -1

func objective_id() -> String:
	var i := objective_index()
	return str((objectives()[i] as Dictionary)["id"]) if i >= 0 else ""

func objective_text() -> String:
	var i := objective_index()
	return _step_text(objectives()[i]) if i >= 0 else ""

func objective_done(id: String) -> bool:
	return GameState.has_flag("obj_" + id)

func _step_text(step: Dictionary) -> String:
	return text(str(step.get("line", "objectives." + str(step["id"]))))

func _objective_signal(kind: String, value: String) -> void:
	var steps := objectives()
	var first := objective_index()
	if first < 0:
		return
	for j in range(first, steps.size()):
		var step: Dictionary = steps[j]
		if str((step.get("complete_on", {}) as Dictionary).get(kind, "")) == value:
			_complete_steps(first, j)
			return
		if bool(step.get("required", false)):
			return

func _complete_steps(from: int, to: int) -> void:
	var steps := objectives()
	var last_done := ""
	for k in range(from, to + 1):
		GameState.set_flag("obj_" + str((steps[k] as Dictionary)["id"]))
		last_done = _step_text(steps[k])

	var next := objective_index()
	while next >= 0 and GameState.has_flag(str((steps[next] as Dictionary).get("done_if_flag", "-"))):
		GameState.set_flag("obj_" + str((steps[next] as Dictionary)["id"]))
		last_done = _step_text(steps[next])
		next = objective_index()
	_tracker.show_objective(objective_text(), last_done)
	objective_changed.emit(objective_id(), objective_text())
	StoryTriggers.fire("objective_changed", {"id": objective_id()})
