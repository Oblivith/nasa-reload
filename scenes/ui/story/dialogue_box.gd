# Code generated with AI assistance (Claude). Reviewed by team.
class_name StoryDialogueBox
extends Control
## The one dialogue box the story uses: speaker name + text with a typewriter reveal.
## E / Space / Enter / click = next line, Esc = skip to the end.
##
## Lines are Dictionaries (built by Story.lines() from data/story_dialogue.json):
##   speaker  name shown above the text ("" = narration, no name)
##   text     the line
##   auto     seconds to wait after the text is fully shown, then advance by itself
##            (missing or < 0 = wait for the player)
##   confirm  true = a yes / no line: E carries on, Esc ends the box with finished(false)
##   hint     overrides the key hint for this line
##   call     Callable run when the line appears
##
## `passive` turns it into captions: it never takes input and every line advances on
## its own (used for launch callouts while another scene is running).

signal line_shown(index: int, line: Dictionary)
## `completed` is false only when the player said no to a `confirm` line.
signal finished(completed: bool)

var passive: bool = false
## Esc jumps to the end of the conversation. Off = Esc only advances one line.
var esc_skips_all: bool = true
var chars_per_second: float = 60.0
## Seconds a caption stays up when a passive line has no `auto` of its own.
var caption_seconds: float = 2.6
var hint_next: String = "[E] next"
var hint_close: String = "[E] close"

var _lines: Array = []
var _index: int = -1
var _reveal: float = 0.0
var _auto_left: float = -1.0
var _done: bool = false
var _panel: PanelContainer
var _speaker: Label
var _text: Label
var _hint: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE if passive else Control.MOUSE_FILTER_STOP
	set_process_unhandled_key_input(not passive)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", ConsoleTheme.panel(ConsoleTheme.PAPER, ConsoleTheme.INK, 5, 14, 22))
	_panel.anchor_left = 0.14
	_panel.anchor_right = 0.86
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_top = -250
	_panel.offset_bottom = -44
	add_child(_panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	_panel.add_child(column)
	_speaker = ConsoleTheme.heading("", 26, ConsoleTheme.TEAL_DARK)
	_speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_speaker)
	_text = ConsoleTheme.body("", 28)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_override("font", ConsoleTheme.typewriter())
	column.add_child(_text)
	_hint = ConsoleTheme.body("", 16, ConsoleTheme.INK_SOFT)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(_hint)
	if not _lines.is_empty() and _index < 0:
		_show(0)


## Starts (or restarts) the box on `lines`. Safe to call before it is in the tree.
func start(lines: Array) -> void:
	_lines = lines
	_index = -1
	_done = false
	if is_node_ready():
		_show(0)


func line_count() -> int:
	return _lines.size()


func current_index() -> int:
	return _index


func is_revealed() -> bool:
	return _text == null or _text.visible_ratio >= 1.0


## Shows the whole line at once, or goes to the next one if it is already shown.
func advance() -> void:
	if _done or _index < 0:
		return
	if not is_revealed():
		_text.visible_ratio = 1.0
		_reveal = float(_text.text.length())
		_arm_auto()
		return
	_show(_index + 1)


## Esc: ends the conversation (a `confirm` line still in the way is answered "no").
## Lines that are skipped still run their `call`, so nothing they trigger is lost.
func skip_all() -> void:
	if _done:
		return
	if not esc_skips_all and not _is_confirm(_index):
		advance()
		return
	for i in range(maxi(_index, 0), _lines.size()):
		if _is_confirm(i):
			_finish(false)
			return
		if i > _index:
			_run_call(i)
	_finish(true)


func _is_confirm(index: int) -> bool:
	return index >= 0 and index < _lines.size() and bool((_lines[index] as Dictionary).get("confirm", false))


func _run_call(index: int) -> void:
	var entry: Dictionary = _lines[index]
	var callback: Variant = entry.get("call")
	if callback is Callable and (callback as Callable).is_valid():
		(callback as Callable).call()


func _show(index: int) -> void:
	if index >= _lines.size():
		_finish(true)
		return
	_index = index
	var entry: Dictionary = _lines[index]
	_speaker.text = str(entry.get("speaker", ""))
	_speaker.visible = _speaker.text != ""
	_text.text = str(entry.get("text", ""))
	_text.visible_ratio = 0.0
	_reveal = 0.0
	_auto_left = -1.0
	if passive:
		_hint.text = ""
	elif entry.has("hint"):
		_hint.text = str(entry["hint"])
	else:
		_hint.text = "%d / %d    %s" % [index + 1, _lines.size(), hint_close if index == _lines.size() - 1 else hint_next]
	_run_call(index)
	line_shown.emit(index, entry)


func _arm_auto() -> void:
	var entry: Dictionary = _lines[_index]
	var seconds := float(entry.get("auto", -1.0))
	if passive and seconds < 0.0:
		seconds = caption_seconds
	_auto_left = seconds


func _finish(completed: bool) -> void:
	if _done:
		return
	_done = true
	finished.emit(completed)
	queue_free()


func _process(delta: float) -> void:
	if _done or _index < 0 or _text == null:
		return
	if not is_revealed():
		_reveal += delta * chars_per_second
		_text.visible_ratio = minf(1.0, _reveal / maxf(1.0, float(_text.text.length())))
		if is_revealed():
			_arm_auto()
	elif _auto_left >= 0.0:
		_auto_left -= delta
		if _auto_left < 0.0:
			_show(_index + 1)


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		advance()
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var code := key.keycode if key.keycode != KEY_NONE else key.physical_keycode
	if code == KEY_E or code == KEY_SPACE or code == KEY_ENTER or code == KEY_KP_ENTER or key.physical_keycode == KEY_E:
		advance()
		get_viewport().set_input_as_handled()
	elif code == KEY_ESCAPE:
		skip_all()
		get_viewport().set_input_as_handled()
