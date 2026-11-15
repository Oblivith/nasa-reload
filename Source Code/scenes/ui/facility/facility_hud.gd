# SI assistance metadata: This code used the help of SI.
class_name FacilityHud
extends Control

const NOTICE_SECONDS := 9.0

var _room: Label
var _subtitle: Label
var _prompt: PanelContainer
var _prompt_label: Label
var _hover: PanelContainer
var _hover_label: Label
var _status: Label
var _notice: PanelContainer
var _notice_label: Label
var _holding: Label
var _notice_left: float = 0.0

func _ready() -> void:
	theme = ConsoleTheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var prompts: Dictionary = (DataLoader.raw.get("facility", {}) as Dictionary).get("prompts", {})

	var top := VBoxContainer.new()
	top.position = Vector2(30, 24)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var room_panel := ConsoleTheme.placard("", 30)
	room_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_room = room_panel.get_child(0) as Label
	top.add_child(room_panel)
	_subtitle = _shadowed(ConsoleTheme.body("", 19, ConsoleTheme.PAPER))
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_OFF
	top.add_child(_subtitle)

	var status_panel := PanelContainer.new()
	status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_panel.add_theme_stylebox_override("panel", ConsoleTheme.panel(ConsoleTheme.PAPER, ConsoleTheme.INK, 4, 8, 12))
	status_panel.anchor_left = 1.0
	status_panel.anchor_right = 1.0
	status_panel.offset_left = -560
	status_panel.offset_right = -30
	status_panel.offset_top = 24
	add_child(status_panel)
	_status = ConsoleTheme.body("", 19)
	_status.add_theme_font_override("font", ConsoleTheme.typewriter())
	status_panel.add_child(_status)

	_prompt = PanelContainer.new()
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.add_theme_stylebox_override("panel", ConsoleTheme.panel(ConsoleTheme.MUSTARD, ConsoleTheme.INK, 4, 10, 14))
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_left = -300
	_prompt.offset_right = 300
	_prompt.offset_top = -150
	_prompt.offset_bottom = -90
	_prompt.visible = false
	add_child(_prompt)
	_prompt_label = ConsoleTheme.heading("", 26)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_child(_prompt_label)

	_holding = _shadowed(ConsoleTheme.heading("", 22, ConsoleTheme.MUSTARD))
	_holding.anchor_top = 1.0
	_holding.anchor_bottom = 1.0
	_holding.offset_left = 30
	_holding.offset_top = -80
	_holding.offset_right = 1400
	add_child(_holding)

	var help := _shadowed(ConsoleTheme.body(str(prompts.get("help", "")), 16, ConsoleTheme.CREAM))
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.anchor_left = 1.0
	help.anchor_right = 1.0
	help.offset_left = -700
	help.offset_right = -30
	help.offset_top = -44
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(help)

	_hover = PanelContainer.new()
	_hover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover.add_theme_stylebox_override("panel", ConsoleTheme.panel(ConsoleTheme.PAPER, ConsoleTheme.INK, 3, 8, 10))
	_hover.custom_minimum_size = Vector2(360, 0)
	_hover.visible = false
	add_child(_hover)
	_hover_label = ConsoleTheme.body("", 17)
	_hover_label.custom_minimum_size = Vector2(340, 0)
	_hover.add_child(_hover_label)

	_notice = PanelContainer.new()
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.add_theme_stylebox_override("panel", ConsoleTheme.panel(ConsoleTheme.MUSTARD, ConsoleTheme.INK, 4, 8, 16))
	_notice.anchor_left = 0.5
	_notice.anchor_right = 0.5
	_notice.offset_left = -520
	_notice.offset_right = 520
	_notice.offset_top = 150
	_notice.visible = false
	add_child(_notice)
	_notice_label = ConsoleTheme.body("", 20)
	_notice.add_child(_notice_label)

func _process(delta: float) -> void:
	if _notice_left > 0.0:
		_notice_left -= delta
		if _notice_left <= 0.0:
			_notice.visible = false

func set_room(title: String, subtitle: String) -> void:
	_room.text = title
	_subtitle.text = subtitle

func set_prompt(text: String) -> void:
	_prompt.visible = text != ""
	_prompt_label.text = text

func set_holding(text: String) -> void:
	_holding.text = text

func set_status(report: Dictionary, cost: float, budget: float) -> void:
	var stars := int(report.get("stars", 0))
	var verdict := "GO" if str(report.get("outcome", "")) == "success" else "NO-GO"
	_status.text = "%s   %s%s\nRocket $%.1fM of $%.1fM%s" % [verdict, "*".repeat(stars), "-".repeat(3 - stars),
			cost, budget, "   OVER BUDGET" if cost > budget + 0.0001 else ""]
	_status.add_theme_color_override("font_color", ConsoleTheme.INK if cost <= budget + 0.0001 else ConsoleTheme.FAIL)

func show_hover(text: String, at: Vector2) -> void:
	_hover.visible = text != ""
	_hover_label.text = text
	_hover.position = (at + Vector2(24, 24)).clamp(Vector2.ZERO, size - Vector2(380, 200))

func notice(text: String) -> void:
	if text == "":
		return
	_notice_label.text = text
	_notice.visible = true
	_notice_left = NOTICE_SECONDS

func notice_text() -> String:
	return _notice_label.text if _notice.visible else ""

func _shadowed(label: Label) -> Label:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label
