# Code generated with AI assistance (Claude). Reviewed by team.
class_name ObjectiveTracker
extends Control
## The objective tracker: a small card in the top-left corner (under the room name) that
## always shows the current objective. When a step is done it is ticked off for a
## moment, then the next one types in. Display only; never takes input.
## Story (autoload) owns the steps; the text comes from data/story_dialogue.json.

const DONE_SECONDS := 1.6
const CHARS_PER_SECOND := 45.0

var _panel: PanelContainer
var _title: Label
var _text: Label
var _title_text: String = "OBJECTIVE"
var _done_text: String = "DONE"
var _pending: Array = []          # [{done: String}] or [{show: String}]
var _hold: float = 0.0
var _reveal: float = -1.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := ConsoleTheme.panel(Color(ConsoleTheme.DESK_DARK, 0.9), ConsoleTheme.MUSTARD, 3, 8, 12)
	style.content_margin_left = 16
	style.content_margin_right = 18
	_panel.add_theme_stylebox_override("panel", style)
	_panel.position = Vector2(30, 122)
	_panel.custom_minimum_size = Vector2(380, 0)
	_panel.visible = false
	add_child(_panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	_panel.add_child(column)
	_title = ConsoleTheme.heading(_title_text, 16, ConsoleTheme.MUSTARD)
	column.add_child(_title)
	_text = ConsoleTheme.heading("", 24, ConsoleTheme.CREAM)
	column.add_child(_text)


func set_labels(title: String, done: String) -> void:
	_title_text = title
	_done_text = done
	if _title != null:
		_title.text = title


## Shows `text` as the current objective. With `completed` (the step just finished) that
## one is ticked off first. An empty `text` hides the tracker (after the tick).
func show_objective(text: String, completed: String = "") -> void:
	if completed != "":
		_pending.append({"done": completed})
	_pending.append({"show": text})


func current_text() -> String:
	for i in range(_pending.size() - 1, -1, -1):
		if (_pending[i] as Dictionary).has("show"):
			return str(_pending[i]["show"])
	return _text.text if _panel.visible else ""


func _process(delta: float) -> void:
	if _reveal >= 0.0:
		_reveal += delta * CHARS_PER_SECOND
		_text.visible_ratio = minf(1.0, _reveal / maxf(1.0, float(_text.text.length())))
		if _text.visible_ratio >= 1.0:
			_reveal = -1.0
	if _hold > 0.0:
		_hold -= delta
		return
	if _pending.is_empty():
		return
	var step: Dictionary = _pending.pop_front()
	if step.has("done"):
		_title.text = _done_text
		_title.add_theme_color_override("font_color", ConsoleTheme.PASS.lightened(0.35))
		_text.text = str(step["done"])
		_text.visible_ratio = 1.0
		_text.add_theme_color_override("font_color", ConsoleTheme.PASS.lightened(0.45))
		_panel.visible = true
		_hold = DONE_SECONDS
	else:
		_title.text = _title_text
		_title.add_theme_color_override("font_color", ConsoleTheme.MUSTARD)
		_text.add_theme_color_override("font_color", ConsoleTheme.CREAM)
		_text.text = str(step["show"])
		_text.visible_ratio = 0.0
		_reveal = 0.0
		_panel.visible = _text.text != ""
		_panel.reset_size()
