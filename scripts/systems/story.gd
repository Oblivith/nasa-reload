# Code generated with AI assistance (Claude). Reviewed by team.
extends Node
## Story director (autoload "Story"). Plays the Level 1 demo script on top of the
## facility: conversations, notes, objectives, launch callouts, Dad's tapes, the ending.
##
## No story text lives here. Two data files drive it:
##   data/story_dialogue.json   every line, keyed "scene.line_id" (the writers' file)
##   data/story_level1.json     the flow: which lines play on which trigger, in what order
##
## World code only reports what happened (StoryTriggers.fire / enter_area); this script
## listens and answers with a StoryDialogueBox. Progress is kept in GameState.story_flags.
##
##   Story.text("lobby.mom_note")              the words of one line
##   Story.lines(["lobby.guard_1", ...])       lines ready for a StoryDialogueBox
##   Story.present(lines)                      show them (freezes the player in the facility)
##   Story.play("talk_guard")                  run a trigger from story_level1.json

const DIALOGUE_FILE := "story_dialogue"
const FLOW_FILE := "story_level1"
## A string of this form in another data file is replaced by that line's text at load.
const REF_PREFIX := "@"

var dialogue: Dictionary = {}
var flow: Dictionary = {}
## False for debug runs (`-- --selftest`, `--room=...`): nothing pops up on its own.
var autoplay: bool = true

var _layer: CanvasLayer
var _host: Node = null                 # the facility scene, while one is running
var _captions: StoryDialogueBox = null
var _queue: Array = []                 # trigger ids waiting for the screen to be free


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	dialogue = DataLoader.raw.get(DIALOGUE_FILE, {})
	flow = DataLoader.raw.get(FLOW_FILE, {})
	autoplay = OS.get_cmdline_user_args().is_empty()
	for file: String in flow.get("line_refs_in", []):
		if DataLoader.raw.has(file):
			DataLoader.raw[file] = _resolve_refs(DataLoader.raw[file])
	_layer = CanvasLayer.new()
	_layer.name = "StoryLayer"
	_layer.layer = 20
	add_child(_layer)
	StoryTriggers.event_fired.connect(_on_event)


# --- Lines ---------------------------------------------------------------------------

## The raw entry for "scene.line_id" ({speaker?, text}); empty if it does not exist.
func line(ref: String) -> Dictionary:
	var dot := ref.find(".")
	if dot < 0:
		return {}
	var scene: Dictionary = (dialogue.get("scenes", {}) as Dictionary).get(ref.left(dot), {})
	var entry: Variant = scene.get(ref.substr(dot + 1))
	return entry if entry is Dictionary else {}


func has_line(ref: String) -> bool:
	return not line(ref).is_empty()


## The words of a line. A missing line shows its id, so a typo is easy to spot in game.
func text(ref: String) -> String:
	var entry := line(ref)
	if entry.is_empty():
		push_warning("Story: no line '%s' in %s.json" % [ref, DIALOGUE_FILE])
		return "[%s]" % ref
	return str(entry.get("text", ""))


## The name shown for a line's speaker ("" for narration).
func speaker(ref: String) -> String:
	var key := str(line(ref).get("speaker", ""))
	return str((dialogue.get("speakers", {}) as Dictionary).get(key, key.to_upper()))


## One line as a StoryDialogueBox entry; `extra` adds box options (auto, confirm, call).
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


## Replaces every "@scene.line_id" string inside a parsed data file with the line's text,
## so Pike's budget refusals, NPC barks and PA calls keep their words in one file.
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


# --- Flags ---------------------------------------------------------------------------

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


# --- Showing lines -------------------------------------------------------------------

## A dialogue box set up with the story's look and key hints (not yet in the tree).
func make_box(box_lines: Array, passive: bool = false) -> StoryDialogueBox:
	var box := StoryDialogueBox.new()
	box.passive = passive
	box.chars_per_second = ui_number("chars_per_second", 60.0)
	box.caption_seconds = ui_number("caption_seconds", 2.6)
	box.hint_next = "%s    %s" % [text("ui.hint_next"), text("ui.hint_skip_line")]
	box.hint_close = text("ui.hint_close")
	box.start(box_lines)
	return box


## Shows lines in the dialogue box. In the facility the player is held until it closes
## (and stays on the framed shot of whatever they pressed E on). Returns the box, or
## null when there is nothing to say.
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


## Shows lines as captions: no input, each one stays a moment and moves on. Used while
## something else has the screen (the launch).
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


## True while a screen (dialogue, keypunch, builder sheet) or a framed shot has the player.
func _screen_busy() -> bool:
	if not _has_host():
		return false
	if bool(_host.call("story_overlay_open")):
		return true
	var player := get_tree().get_first_node_in_group("player") as Player
	return player != null and player.is_interacting()


# --- Triggers ------------------------------------------------------------------------

## Runs a trigger from story_level1.json "triggers": the first case whose flags match is
## played. Returns the dialogue box (null if nothing was shown).
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


## Plays a trigger as soon as no other screen is open (lines that follow another screen).
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
	if (flow.get("triggers", {}) as Dictionary).has(event_id):
		play(event_id, payload)


func _process(_delta: float) -> void:
	if not _queue.is_empty() and not _screen_busy():
		play(str(_queue.pop_front()))
