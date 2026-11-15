# Code generated with AI assistance (Claude). Reviewed by team.
class_name InteractionPrompt
extends Control
## The context prompt that floats next to whatever the player is looking at:
## a key cap and a short line ("E  Talk to Dot"). Follows the object on screen, stays
## inside the window, and pops in and out. Display only; never takes input.

const POP_SECONDS := 0.14
const EDGE_MARGIN := 24.0

var _panel: PanelContainer
var _key: Label
var _key_box: PanelContainer
var _text: Label
var _target: Interactable = null
var _camera: Camera3D = null
var _shown: float = 0.0
var _locked_look: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", ConsoleTheme.panel(ConsoleTheme.PAPER, ConsoleTheme.INK, 3, 10, 8))
	add_child(_panel)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	_panel.add_child(row)
	_key_box = PanelContainer.new()
	_key_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_key_box.custom_minimum_size = Vector2(42, 42)
	row.add_child(_key_box)
	_key = ConsoleTheme.heading("E", 24, ConsoleTheme.INK)
	_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_key_box.add_child(_key)
	_text = ConsoleTheme.heading("", 24, ConsoleTheme.INK)
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_text)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(2, 0)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pad)
	_panel.visible = false
	_style(false)


## Shows the prompt for `target` (null hides it). `camera` projects it onto the screen.
func show_for(target: Interactable, camera: Camera3D) -> void:
	_camera = camera
	if target == _target:
		_refresh()
		return
	_target = target
	if target != null:
		_shown = 0.0
	_refresh()


## The line currently displayed ("" when hidden). Handy for tests.
func text() -> String:
	return "%s  %s" % [_key.text, _text.text] if is_showing() else ""


func is_showing() -> bool:
	return _target != null and is_instance_valid(_target)


func _refresh() -> void:
	if not is_showing():
		return
	_key.text = PlayerInput.key_label(PlayerInput.INTERACT)
	_text.text = _target.current_prompt()
	if _target.locked != _locked_look:
		_style(_target.locked)


func _style(locked: bool) -> void:
	_locked_look = locked
	_key_box.add_theme_stylebox_override("panel", ConsoleTheme.panel(
			ConsoleTheme.CREAM.darkened(0.12) if locked else ConsoleTheme.MUSTARD, ConsoleTheme.INK, 3, 6, 2))
	_text.add_theme_color_override("font_color", ConsoleTheme.INK_SOFT if locked else ConsoleTheme.INK)


func _process(delta: float) -> void:
	var want := is_showing() and _camera != null and is_instance_valid(_camera)
	var anchor := Vector3.ZERO
	if want:
		anchor = _target.prompt_point()
		want = not _camera.is_position_behind(anchor)
	_shown = move_toward(_shown, 1.0 if want else 0.0, delta / POP_SECONDS)
	_panel.visible = _shown > 0.0
	if not _panel.visible:
		return
	_panel.reset_size()
	var size := _panel.size
	if want:
		var at := _camera.unproject_position(anchor)
		var pos := at - Vector2(size.x * 0.5, size.y)
		var bounds := get_viewport_rect().size
		pos.x = clampf(pos.x, EDGE_MARGIN, maxf(EDGE_MARGIN, bounds.x - size.x - EDGE_MARGIN))
		pos.y = clampf(pos.y, EDGE_MARGIN, maxf(EDGE_MARGIN, bounds.y - size.y - EDGE_MARGIN))
		_panel.position = pos.round()
	var ease_in := 1.0 - pow(1.0 - _shown, 3.0)
	_panel.pivot_offset = Vector2(size.x * 0.5, size.y)
	_panel.scale = Vector2.ONE * lerpf(0.82, 1.0, ease_in)
	_panel.modulate.a = ease_in
