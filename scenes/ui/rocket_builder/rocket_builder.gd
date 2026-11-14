# Code generated with AI assistance (Claude). Reviewed by team.
extends Control
## Rocket Builder screen (Sim Spec v2, section 3). Three input modes edit ONE real-unit
## design; RocketEvaluator judges it live. UI only: physics lives in /scripts/sim,
## conversions in DesignModes / DesignBuilder, content in /data.
##
## Debug: run with `-- --screenshot=<png path> [--mode=easy|medium|hard] [--burnout]
##   [--reference] [--budget=<$M>]`
## to save a screenshot of the screen and quit.

enum InputMode { EASY, MEDIUM, HARD }
const MODE_NAMES := ["EASY", "MEDIUM", "HARD"]
const MODE_TIPS := [
	"Pick simple parts with pictures. Results as ticks and crosses.",
	"Sliders around a real reference rocket (0.5 = the real one). Results as gauges.",
	"Type real numbers for every part. Results as raw values and formulas.",
]
const LAUNCH_SCENE := "res://scenes/world/launch.tscn"
const DEFAULT_LEVEL := "L1"
const NOTICE_SECONDS := 12.0

@onready var _brief_box: VBoxContainer = %BriefBox
@onready var _mode_box: VBoxContainer = %ModeBox
@onready var _notice_panel: PanelContainer = %NoticePanel
@onready var _notice_label: Label = %NoticeLabel
@onready var _left_vbox: VBoxContainer = %LeftVBox
@onready var _left_content: VBoxContainer = %LeftContent
@onready var _centre_header: HBoxContainer = %CentreHeader
@onready var _rocket_view: RocketView = %RocketView
@onready var _right_vbox: VBoxContainer = %RightVBox
@onready var _right_content: VBoxContainer = %RightContent
@onready var _bottom_bar: HBoxContainer = %BottomBar

var _level_id: String = DEFAULT_LEVEL
var _level: Dictionary = {}
var _reference: Dictionary = {}
var _ui: Dictionary = {}
var _sim_data: Dictionary = {}
var _min_factor: float = 0.5
var _max_factor: float = 2.0
var _ref_values: Dictionary = {}

var _mode: int = InputMode.EASY
var _design: Dictionary = {}
var _report: Dictionary = {}
var _easy_selections: Dictionary = {}

var _mode_buttons: Array[Button] = []
var _left_title: Label
var _right_title: Label
var _slider_rows: Dictionary = {}   # slider id -> {slider: HSlider, value: Label, def: Dictionary}
var _setting_sliders: bool = false
var _budget_bar: BudgetBar
var _cost_label: Label
var _name_edit: LineEdit
var _load_button: OptionButton
var _launch_button: Button
var _notice_timer: Timer
var _brief_info: Label


func _ready() -> void:
	theme = ConsoleTheme.build()
	_ui = DataLoader.builder_ui
	_sim_data = DataLoader.sim_data()
	_level_id = GameState.current_level if DataLoader.levels.has(GameState.current_level) else DEFAULT_LEVEL
	if GameState.current_level == "":
		GameState.set_level(_level_id)
	_level = DataLoader.levels.get(_level_id, {})
	_reference = DataLoader.reference_rockets.get(str(_level.get("reference_rocket", "")), {})
	var slider_range: Dictionary = _reference.get("slider_range", {})
	_min_factor = float(slider_range.get("min_factor", 0.5))
	_max_factor = float(slider_range.get("max_factor", 2.0))
	_ref_values = DesignModes.reference_values(_reference, DataLoader.engines, _ui.get("medium_sliders", []))
	# The level's budget becomes the live limit when a level starts; event cards may
	# change GameState.budget later and the builder follows it.
	if GameState.budget <= 0.0 or str(GameState.builder_state.get("level", "")) != _level_id:
		GameState.budget = float(_level.get("budget", 0.0))
	GameState.budget_changed.connect(_on_budget_changed)

	_notice_timer = Timer.new()
	_notice_timer.one_shot = true
	_notice_timer.timeout.connect(func() -> void: _notice_panel.visible = false)
	add_child(_notice_timer)

	_build_brief()
	_build_mode_switch()
	_build_centre_header()
	_build_bottom_bar()
	_left_title = ConsoleTheme.heading("", 22, ConsoleTheme.CREAM)
	_left_vbox.add_child(_wrap_placard(_left_title))
	_left_vbox.move_child(_left_vbox.get_child(_left_vbox.get_child_count() - 1), 0)
	_right_title = ConsoleTheme.heading("", 22, ConsoleTheme.CREAM)
	_right_vbox.add_child(_wrap_placard(_right_title))
	_right_vbox.move_child(_right_vbox.get_child(_right_vbox.get_child_count() - 1), 0)

	_restore_or_default()
	_apply_cmdline()
	_rebuild_left()
	_refresh()
	_maybe_screenshot()


# --- Setup ---------------------------------------------------------------------------

func _restore_or_default() -> void:
	var state: Dictionary = GameState.builder_state
	if not GameState.current_design.is_empty() and str(state.get("level", "")) == _level_id:
		_design = GameState.current_design.duplicate(true)
		_easy_selections = (state.get("easy_selections", {}) as Dictionary).duplicate()
		_mode = int(state.get("mode", InputMode.EASY))
	else:
		_easy_selections = (_ui.get("easy_defaults", {}) as Dictionary).duplicate()
		_mode = _mode_from_game_state()
		_design = _easy_design()
	_update_mode_buttons()


func _apply_cmdline() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			var wanted := arg.trim_prefix("--mode=").to_upper()
			var index := MODE_NAMES.find(wanted)
			if index >= 0 and index != _mode:
				_switch_mode(index, false)
		elif arg == "--burnout":
			_rocket_view.show_burnout = true
		elif arg.begins_with("--budget="):
			GameState.budget = float(arg.trim_prefix("--budget="))
		elif arg == "--reference":
			_design = DesignModes.reference_design(_reference, DataLoader.engines, _level,
					DesignBuilder.upper_stages_default_on(_reference))


func _maybe_screenshot() -> void:
	var path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			path = arg.trim_prefix("--screenshot=")
	if path == "":
		return
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(path)
	print("RocketBuilder: screenshot %s (%dx%d) -> %s" % [path, image.get_width(), image.get_height(), error_string(err)])
	get_tree().quit()


func _build_brief() -> void:
	var goal: Dictionary = _level.get("required_goal", {})
	var optional: Dictionary = _level.get("optional_goal", {})
	_brief_box.add_child(_wrap_placard(ConsoleTheme.heading("MISSION BRIEF  //  LEVEL %d: %s  (%s)" % [
			int(_level.get("number", 1)), str(_level.get("name", "")), str(_level.get("year", ""))], 20, ConsoleTheme.CREAM)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	_brief_box.add_child(row)
	var left := ConsoleTheme.body(str(_level.get("description", "")), 18)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.8
	row.add_child(left)
	var goals := VBoxContainer.new()
	goals.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goals.add_theme_constant_override("separation", 2)
	row.add_child(goals)
	var required := ConsoleTheme.body("REQUIRED: %s (perigee >= %d km)" % [str(goal.get("description", "")),
			int(goal.get("min_perigee_km", 0))], 17)
	required.add_theme_font_override("font", ConsoleTheme.typewriter())
	goals.add_child(required)
	goals.add_child(ConsoleTheme.body("OPTIONAL: %s" % str(optional.get("description", "")), 17, ConsoleTheme.TEAL_DARK))
	_brief_info = ConsoleTheme.body(_brief_info_text(), 16, ConsoleTheme.INK_SOFT)
	goals.add_child(_brief_info)


func _brief_info_text() -> String:
	var site: Dictionary = _level.get("launch_site", {})
	var mission := DesignModes.level_mission(_level)
	return "Payload %d kg  |  Budget $%.1fM  |  %s, %.1f deg N  |  Checked for: orbit, perigee %d km" % [
			int(_level.get("payload_mass_kg", 0)), _budget_limit(), str(site.get("name", "")),
			float(site.get("latitude_deg", 0.0)),
			int(mission.get("target_perigee_km", mission.get("target_altitude_km", 0)))]


func _build_mode_switch() -> void:
	_mode_box.add_child(_wrap_placard(ConsoleTheme.heading("INPUT MODE", 20, ConsoleTheme.CREAM)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_mode_box.add_child(row)
	var group := ButtonGroup.new()
	for i in MODE_NAMES.size():
		var button := Button.new()
		button.text = MODE_NAMES[i]
		button.toggle_mode = true
		button.button_group = group
		button.tooltip_text = MODE_TIPS[i]
		button.custom_minimum_size = Vector2(140, 56)
		button.add_theme_font_size_override("font_size", 22)
		button.pressed.connect(_switch_mode.bind(i, true))
		row.add_child(button)
		_mode_buttons.append(button)


func _build_centre_header() -> void:
	var title := _wrap_placard(ConsoleTheme.heading("SIDE VIEW", 20, ConsoleTheme.CREAM))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_centre_header.add_child(title)
	var label := ConsoleTheme.body("CG AT", 17)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_centre_header.add_child(label)
	var group := ButtonGroup.new()
	for burnout: bool in [false, true]:
		var button := Button.new()
		button.text = "BURNOUT" if burnout else "LIFTOFF"
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = burnout == _rocket_view.show_burnout
		button.tooltip_text = "Centre of mass with all fuel aboard." if not burnout else "Centre of mass when the first stage's fuel is used up."
		button.custom_minimum_size = Vector2(110, 44)
		button.pressed.connect(func() -> void: _rocket_view.show_burnout = burnout)
		_centre_header.add_child(button)


func _build_bottom_bar() -> void:
	_bottom_bar.add_theme_constant_override("separation", 14)
	_bottom_bar.add_child(ConsoleTheme.heading("BUDGET", 22))
	_budget_bar = BudgetBar.new()
	_budget_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bottom_bar.add_child(_budget_bar)
	_cost_label = ConsoleTheme.body("", 16, ConsoleTheme.INK_SOFT)
	_cost_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_cost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bottom_bar.add_child(_cost_label)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Design name"
	_name_edit.custom_minimum_size = Vector2(240, 48)
	_bottom_bar.add_child(_name_edit)
	var save := Button.new()
	save.text = "SAVE DESIGN"
	save.custom_minimum_size = Vector2(170, 52)
	save.pressed.connect(_on_save)
	_bottom_bar.add_child(save)
	_load_button = OptionButton.new()
	_load_button.custom_minimum_size = Vector2(220, 52)
	_load_button.item_selected.connect(_on_load)
	_bottom_bar.add_child(_load_button)
	_refresh_load_list()
	_launch_button = Button.new()
	_launch_button.text = "LAUNCH  >>"
	_launch_button.custom_minimum_size = Vector2(230, 60)
	_launch_button.add_theme_font_size_override("font_size", 26)
	var launch_style := ConsoleTheme.panel(ConsoleTheme.ORANGE, ConsoleTheme.INK, 4, 10, 10)
	launch_style.shadow_size = 1
	launch_style.shadow_offset = Vector2(0, 4)
	_launch_button.add_theme_stylebox_override("normal", launch_style)
	var launch_hover := launch_style.duplicate() as StyleBoxFlat
	launch_hover.bg_color = ConsoleTheme.ORANGE.lightened(0.15)
	_launch_button.add_theme_stylebox_override("hover", launch_hover)
	_launch_button.add_theme_color_override("font_color", ConsoleTheme.PAPER)
	_launch_button.add_theme_color_override("font_hover_color", ConsoleTheme.PAPER)
	_launch_button.pressed.connect(_on_launch)
	_bottom_bar.add_child(_launch_button)


# --- Mode switching ------------------------------------------------------------------

func _switch_mode(new_mode: int, announce: bool) -> void:
	if new_mode == _mode:
		_update_mode_buttons()
		return
	var notice := ""
	if new_mode == InputMode.EASY:
		var snap := DesignModes.snap_to_easy(_design, DataLoader.presets, DataLoader.engines, DataLoader.materials)
		_easy_selections = snap["selections"]
		var changes: PackedStringArray = []
		for part in snap["changed"]:
			changes.append("%s -> %s" % [_part_label(str(part)), _preset_label(str(part), str(_easy_selections[part]))])
		if not changes.is_empty():
			notice = "Easy mode only has presets, so your rocket was snapped to the nearest ones: %s." % ", ".join(changes)
		for note in snap["dropped"]:
			notice += (" " if notice != "" else "") + str(note)
		_design = _easy_design()
	elif new_mode == InputMode.MEDIUM:
		var positions := _slider_positions()
		var outside: PackedStringArray = []
		for slider: Dictionary in _ui.get("medium_sliders", []):
			var pos: Dictionary = positions.get(str(slider["id"]), {})
			if not pos.is_empty() and not bool(pos["in_range"]):
				outside.append(str(slider["label"]))
		if not outside.is_empty():
			notice = "Medium sliders run from %.1fx to %.0fx the %s values. Outside that range: %s. Those sliders sit at the end and keep your real value until you move them." % [
				_min_factor, _max_factor, str(_reference.get("name", "reference")), ", ".join(outside)]
	_mode = new_mode
	GameState.set_mode(_game_mode_for(_mode))
	_update_mode_buttons()
	_rebuild_left()
	_refresh()
	if announce and notice != "":
		_show_notice(notice)
	elif notice != "":
		_show_notice(notice)


func _update_mode_buttons() -> void:
	for i in _mode_buttons.size():
		_mode_buttons[i].set_pressed_no_signal(i == _mode)


func _game_mode_for(mode: int) -> GameState.Mode:
	match mode:
		InputMode.MEDIUM:
			return GameState.Mode.ENGINEER
		InputMode.HARD:
			return GameState.Mode.FLIGHT_DIRECTOR
	return GameState.Mode.CADET


func _mode_from_game_state() -> int:
	match GameState.mode:
		GameState.Mode.ENGINEER:
			return InputMode.MEDIUM
		GameState.Mode.FLIGHT_DIRECTOR:
			return InputMode.HARD
	return InputMode.EASY


# --- Evaluate + redraw ---------------------------------------------------------------

func _refresh() -> void:
	_design["payload"] = DesignModes.level_payload(_level)
	_design["mission"] = DesignModes.level_mission(_level)
	_design["mission"]["budget_musd"] = _budget_limit()
	_report = RocketEvaluator.evaluate(_design, _sim_data)
	_rocket_view.show_report(_report, _design)
	_rebuild_right()
	_update_bottom()
	GameState.set_design(_design.duplicate(true), _report, {
		"level": _level_id, "mode": _mode, "easy_selections": _easy_selections.duplicate()})


func _update_bottom() -> void:
	var cost := _cost(_design)
	var lines: PackedStringArray = []
	for item: Dictionary in cost["items"]:
		lines.append("%-40s $%5.2fM" % [str(item["label"]), float(item["cost"])])
	_brief_info.text = _brief_info_text()
	var budget := _budget_limit()
	_budget_bar.set_values(float(cost["total"]), budget, "\n".join(lines))
	var status := CostModel.budget_status(float(cost["total"]), budget, DataLoader.cost_model)
	var spare := float(status["left_musd"])
	if spare < 0.0:
		_cost_label.text = "$%.1fM OVER BUDGET" % -spare
	else:
		_cost_label.text = "$%.1fM left%s" % [spare, "  +budget star" if bool(status["budget_star"]) else ""]
	_cost_label.tooltip_text = "Keep at least %d%% of the budget unspent to earn the budget star." % int(
			round(float(DataLoader.cost_model.get("budget_star_min_left_fraction", 0.0)) * 100.0))
	_cost_label.add_theme_color_override("font_color", ConsoleTheme.INK_SOFT if spare >= 0.0 else ConsoleTheme.FAIL)

	var blocked := ""
	if (_design.get("stages", []) as Array).is_empty():
		blocked = "There is no rocket to launch."
	elif spare < 0.0:
		blocked = "Over budget by $%.1fM: the budget is $%.1fM now. Make the rocket cheaper to launch." % [-spare, budget]
	else:
		for check: Dictionary in _report.get("checks", []):
			if str(check["id"]) == "liftoff" and str(check["status"]) == "fail":
				blocked = str(check["plain"])
	_launch_button.disabled = blocked != ""
	_launch_button.tooltip_text = blocked if blocked != "" else "Roll it out to the pad. Warnings and failures still fly: the launch tells the story."


# --- Left panel: inputs --------------------------------------------------------------

func _rebuild_left() -> void:
	_clear(_left_content)
	_slider_rows.clear()
	match _mode:
		InputMode.EASY:
			_left_title.text = "PARTS  //  PICK ONE OF EACH"
			_build_easy()
		InputMode.MEDIUM:
			_left_title.text = "TUNE  //  VS %s" % str(_reference.get("name", "REFERENCE")).to_upper()
			_build_medium()
		InputMode.HARD:
			_left_title.text = "SPECIFICATION  //  REAL UNITS"
			_build_hard()


func _build_easy() -> void:
	var current_cost := _total(_design)
	for part_def: Dictionary in _ui.get("easy_parts", []):
		var part := str(part_def["part"])
		var table: Dictionary = DataLoader.presets.get(part, {})
		var header := ConsoleTheme.heading(str(part_def["label"]).to_upper(), 18, ConsoleTheme.TEAL_DARK)
		_left_content.add_child(header)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_left_content.add_child(row)
		var group := ButtonGroup.new()
		var scale_ref := _preset_scale(table)
		for id in table:
			var preset: Dictionary = table[id]
			var picks := _easy_selections.duplicate()
			picks[part] = str(id)
			var option_cost := _cost(DesignBuilder.from_easy(picks, DataLoader.presets, DataLoader.engines,
					DesignModes.level_payload(_level), DesignModes.level_mission(_level)))
			var selected := str(_easy_selections.get(part, "")) == str(id)
			var affordable := selected or _affordable(float(option_cost["total"]), current_cost)
			var price := _easy_part_cost(part, option_cost)
			var button := Button.new()
			button.toggle_mode = true
			button.button_group = group
			button.button_pressed = selected
			button.disabled = not affordable
			button.custom_minimum_size = Vector2(0, 84)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.tooltip_text = str(preset.get("description", ""))
			if not affordable:
				button.tooltip_text += "\nOver budget: the rocket would cost $%.1fM of $%.1fM." % [float(option_cost["total"]), _budget_limit()]
			button.pressed.connect(_on_easy_pick.bind(part, str(id)))
			var inner := HBoxContainer.new()
			inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			inner.offset_left = 6
			inner.offset_right = -6
			inner.add_theme_constant_override("separation", 6)
			var icon := PartIcon.new()
			icon.part = part
			icon.preset = preset
			icon.scale_ref = scale_ref
			icon.custom_minimum_size = Vector2(64, 72)
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			inner.add_child(icon)
			var label := Label.new()
			label.text = str(preset.get("label", id))
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.size_flags_vertical = Control.SIZE_FILL
			label.add_theme_font_override("font", ConsoleTheme.typewriter())
			label.add_theme_font_size_override("font_size", 17)
			var text_box := VBoxContainer.new()
			text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			text_box.alignment = BoxContainer.ALIGNMENT_CENTER
			text_box.add_theme_constant_override("separation", 0)
			text_box.add_child(label)
			var price_label := Label.new()
			price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			price_label.text = "free" if price <= 0.0 else _money(price)
			price_label.add_theme_font_size_override("font_size", 14)
			price_label.add_theme_color_override("font_color", ConsoleTheme.FAIL if not affordable else ConsoleTheme.INK_SOFT)
			if selected:
				price_label.add_theme_color_override("font_color", ConsoleTheme.PAPER)
			text_box.add_child(price_label)
			inner.add_child(text_box)
			button.add_child(inner)
			row.add_child(button)
	var hint := ConsoleTheme.body("Hover a part to read about it. Every picture stands for real numbers: switch to HARD to see them.", 15, ConsoleTheme.INK_SOFT)
	_left_content.add_child(hint)


func _build_medium() -> void:
	var intro := ConsoleTheme.body("0.5 = the real %s.  0 = %.1fx,  1 = %.0fx its value." % [
			str(_reference.get("name", "reference")), _min_factor, _max_factor], 16, ConsoleTheme.INK_SOFT)
	_left_content.add_child(intro)

	var discrete := GridContainer.new()
	discrete.columns = 2
	discrete.add_theme_constant_override("h_separation", 12)
	discrete.add_theme_constant_override("v_separation", 6)
	_left_content.add_child(discrete)
	_add_option_row(discrete, "Nose shape", DataLoader.nose_shapes, str(DesignModes.path_get(_design, "nose/shape")),
			func(id: String) -> void: _set_value("nose/shape", id))
	_add_option_row(discrete, "Material", DataLoader.materials, str(DesignModes.path_get(_design, "stages/0/body/material")),
			func(id: String) -> void: _set_material(id))
	var cost := _cost(_design)
	var gimbal := CheckBox.new()
	var engine_count: Variant = DesignModes.path_get(_design, "stages/0/engine/count")
	gimbal.text = "Steerable engine  (+%s)" % _money(float(DataLoader.cost_model.get("gimbal_cost_per_engine", 0.0))
			* (int(engine_count) if engine_count != null else 1))
	gimbal.button_pressed = bool(DesignModes.path_get(_design, "options/gimballed"))
	gimbal.toggled.connect(func(on: bool) -> void: _set_value("options/gimballed", on))
	var upper := CheckBox.new()
	var upper_cost := 0.0
	for i in range(1, (_design.get("stages", []) as Array).size()):
		upper_cost += CostModel.stage_cost(cost, i)
	upper.text = "Upper stages  (%s)" % _money(upper_cost) if upper_cost > 0.0 else "Upper stages"
	upper.button_pressed = (_design.get("stages", []) as Array).size() > 1
	upper.toggled.connect(_on_medium_upper)
	discrete.add_child(gimbal)
	discrete.add_child(upper)

	var positions := _slider_positions()
	var group_name := ""
	var has_upper := (_design.get("stages", []) as Array).size() > 1
	for slider_def: Dictionary in _ui.get("medium_sliders", []):
		if bool(slider_def.get("upper", false)) and not has_upper:
			continue
		var pos: Dictionary = positions.get(str(slider_def["id"]), {})
		if pos.is_empty():
			continue
		if str(slider_def.get("group", "")) != group_name:
			group_name = str(slider_def.get("group", ""))
			_left_content.add_child(ConsoleTheme.heading("%s  //  %s" % [group_name.to_upper(), _group_cost_text(slider_def, cost)],
					18, ConsoleTheme.TEAL_DARK))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var name_label := ConsoleTheme.body(str(slider_def["label"]), 16)
		name_label.custom_minimum_size = Vector2(170, 0)
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.clip_text = true
		row.add_child(name_label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.custom_minimum_size = Vector2(0, 30)
		row.add_child(slider)
		var value_label := ConsoleTheme.body("", 15)
		value_label.custom_minimum_size = Vector2(150, 0)
		value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value_label)
		_left_content.add_child(row)
		_slider_rows[str(slider_def["id"])] = {"slider": slider, "value": value_label, "def": slider_def}
		_setting_sliders = true
		slider.value = float(pos["slider"])
		_setting_sliders = false
		_update_slider_label(str(slider_def["id"]), pos)
		slider.value_changed.connect(_on_slider.bind(str(slider_def["id"])))

	var reset := Button.new()
	reset.text = "RESET TO %s" % str(_reference.get("name", "REFERENCE")).to_upper()
	reset.custom_minimum_size = Vector2(0, 46)
	reset.pressed.connect(func() -> void:
		_try_change(func(_d: Dictionary) -> Dictionary:
			return DesignModes.reference_design(_reference, DataLoader.engines, _level,
					DesignBuilder.upper_stages_default_on(_reference)))
		_rebuild_left()
		_refresh())
	_left_content.add_child(reset)


func _build_hard() -> void:
	var fields: Dictionary = _ui.get("hard_fields", {})
	var stages: Array = _design.get("stages", [])

	_left_content.add_child(ConsoleTheme.heading("NOSE CONE", 18, ConsoleTheme.TEAL_DARK))
	var nose_grid := _field_grid()
	_add_option_row(nose_grid, "Shape", DataLoader.nose_shapes, str(DesignModes.path_get(_design, "nose/shape")),
			func(id: String) -> void: _set_value("nose/shape", id))
	_add_fields(nose_grid, fields.get("nose", []), "nose")

	_left_content.add_child(ConsoleTheme.heading("PAYLOAD (FIXED BY THE MISSION)", 18, ConsoleTheme.TEAL_DARK))
	var payload := DesignModes.level_payload(_level)
	_left_content.add_child(ConsoleTheme.body("%.0f kg, %.2f m long" % [float(payload["mass_kg"]), float(payload["length_m"])], 16))

	var cost := _cost(_design)
	for i in stages.size():
		var header := HBoxContainer.new()
		var title := ConsoleTheme.heading("STAGE %d%s  //  %s" % [i + 1, "  (FIRST)" if i == 0 else "  (UPPER)",
				_money(CostModel.items_cost(cost, ["stage_%d_engine" % i, "stage_%d_tanks" % i]))], 18, ConsoleTheme.TEAL_DARK)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(title)
		if i > 0 and i == stages.size() - 1:
			var remove := Button.new()
			remove.text = "REMOVE"
			remove.pressed.connect(func() -> void:
				var kept: Array = (_design["stages"] as Array).slice(0, i)
				_design["stages"] = kept
				_rebuild_left()
				_refresh())
			header.add_child(remove)
		_left_content.add_child(header)
		var grid := _field_grid()
		var base := "stages/%d/" % i
		_add_option_row(grid, "Material", DataLoader.materials, str(DesignModes.path_get(_design, base + "body/material")),
				func(id: String) -> void: _set_value(base + "body/material", id))
		_add_fields(grid, fields.get("body", []), base + "body")
		var engine_options := {}
		for engine_id in (_level.get("unlocked_parts", {}) as Dictionary).get("engines", DataLoader.engines.keys()):
			if DataLoader.engines.has(str(engine_id)):
				engine_options[str(engine_id)] = DataLoader.engines[str(engine_id)]
		_add_option_row(grid, "Engine", engine_options, str(DesignModes.path_get(_design, base + "engine/engine_id")),
				func(id: String) -> void: _set_engine(i, id))
		_add_fields(grid, fields.get("engine", []), base + "engine")

	var add := Button.new()
	add.text = "+ ADD UPPER STAGE"
	add.custom_minimum_size = Vector2(0, 44)
	var offered := DesignBuilder.upper_stage_specs(_reference)
	add.disabled = offered.is_empty()
	add.pressed.connect(func() -> void:
		var next := clampi((_design["stages"] as Array).size() - 1, 0, offered.size() - 1)
		_try_change(func(d: Dictionary) -> Dictionary:
			return DesignBuilder.add_upper_stage(d, offered[next], DataLoader.engines))
		_rebuild_left()
		_refresh())
	_left_content.add_child(add)

	_left_content.add_child(ConsoleTheme.heading("FINS  //  %s" % _money(CostModel.items_cost(cost, ["fins"])), 18, ConsoleTheme.TEAL_DARK))
	_add_fields(_field_grid(), fields.get("fins", []), "fins")

	_left_content.add_child(ConsoleTheme.heading("OPTIONS  //  %s" % _money(CostModel.items_cost(cost, ["gimbal", "escape_tower"])),
			18, ConsoleTheme.TEAL_DARK))
	var gimbal := CheckBox.new()
	gimbal.text = "Gimballed first-stage engine  (+%s each)" % _money(float(DataLoader.cost_model.get("gimbal_cost_per_engine", 0.0)))
	gimbal.button_pressed = bool(DesignModes.path_get(_design, "options/gimballed"))
	gimbal.toggled.connect(func(on: bool) -> void: _set_value("options/gimballed", on))
	_left_content.add_child(gimbal)
	_add_fields(_field_grid(), fields.get("escape_tower", []), "options/escape_tower")

	_left_content.add_child(ConsoleTheme.heading("LAUNCH + YOUR OWN SUMS", 18, ConsoleTheme.TEAL_DARK))
	var launch_grid := _field_grid()
	_add_fields(launch_grid, fields.get("launch", []), "launch")
	_add_fields(launch_grid, fields.get("predictions", []), "predictions")
	_left_content.add_child(ConsoleTheme.body("Your predictions are compared with the sim after the launch.", 15, ConsoleTheme.INK_SOFT))


func _field_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 5)
	_left_content.add_child(grid)
	return grid


func _add_fields(grid: GridContainer, defs: Array, prefix: String) -> void:
	for field: Dictionary in defs:
		var path := "%s/%s" % [prefix, str(field["key"])]
		var unit := str(field.get("unit", ""))
		var label := ConsoleTheme.body("%s%s" % [str(field["label"]), (" (%s)" % unit) if unit != "" else ""], 16)
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(label)
		var edit := LineEdit.new()
		edit.custom_minimum_size = Vector2(240, 38)
		edit.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		edit.placeholder_text = str(field.get("hint", ""))
		var current: Variant = DesignModes.path_get(_design, path)
		if current == null and field.has("default"):
			current = field["default"]
			DesignModes.path_set(_design, path, float(current))
		edit.text = _fmt(float(current)) if current != null else ""
		edit.text_changed.connect(_on_field.bind(path, field, edit))
		edit.text_submitted.connect(func(_text: String) -> void: _commit_field(path, field, edit))
		edit.focus_exited.connect(func() -> void: _commit_field(path, field, edit))
		grid.add_child(edit)


func _add_option_row(grid: GridContainer, label_text: String, table: Dictionary, selected: String, on_pick: Callable) -> void:
	var label := ConsoleTheme.body(label_text, 16)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(label)
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(240, 40)
	option.fit_to_longest_item = false
	option.clip_text = true
	var ids: Array = []
	for id in table:
		var entry: Dictionary = table[id]
		option.add_item(str(entry.get("name", id)))
		ids.append(str(id))
	if not ids.has(selected):
		option.add_item("(custom: %s)" % selected)
		ids.append(selected)
	option.select(ids.find(selected))
	option.item_selected.connect(func(index: int) -> void: on_pick.call(str(ids[index])))
	grid.add_child(option)


# --- Input handlers ------------------------------------------------------------------

func _on_easy_pick(part: String, id: String) -> void:
	var picks := _easy_selections.duplicate()
	picks[part] = id
	var applied := _try_change(func(_d: Dictionary) -> Dictionary:
		return DesignBuilder.from_easy(picks, DataLoader.presets, DataLoader.engines,
				DesignModes.level_payload(_level), DesignModes.level_mission(_level)))
	if applied:
		_easy_selections = picks
		_design["name"] = "Easy rocket"
	_rebuild_left.call_deferred()
	_refresh()


func _on_slider(value: float, slider_id: String) -> void:
	if _setting_sliders:
		return
	var row: Dictionary = _slider_rows.get(slider_id, {})
	var slider_def: Dictionary = row.get("def", {})
	var moves: Array = []   # [path, from, to]
	for path in slider_def.get("paths", []):
		var current: Variant = DesignModes.path_get(_design, str(path))
		if current == null:
			continue   # e.g. a vacuum-only engine has no sea-level thrust to scale
		var ref := float(_ref_values.get(str(path), float(current)))
		moves.append([str(path), float(current), DesignBuilder.slider_to_value(value, ref, _min_factor, _max_factor)])
	var t := _limited_change(func(design: Dictionary, at: float) -> void:
		for move: Array in moves:
			DesignModes.path_set(design, move[0], lerpf(move[1], move[2], at))
			if str(move[0]).contains("/body/propellant"):
				var stage := int(str(move[0]).split("/")[1])
				if stage >= 1:
					DesignBuilder.recompute_tank_length(((design["stages"] as Array)[stage] as Dictionary)["body"]))
	var positions := _slider_positions()
	if t < 0.999:
		var slider: HSlider = row["slider"]
		_setting_sliders = true
		slider.set_value_no_signal(float((positions.get(slider_id, {"slider": value}) as Dictionary)["slider"]))
		_setting_sliders = false
	_update_slider_label(slider_id, positions.get(slider_id, {}))
	_refresh()


func _on_medium_upper(on: bool) -> void:
	_try_change(func(d: Dictionary) -> Dictionary:
		var result := DesignBuilder.without_upper_stages(d)
		if on:
			for spec: Dictionary in DesignBuilder.upper_stage_specs(_reference):
				result = DesignBuilder.add_upper_stage(result, spec, DataLoader.engines)
		return result)
	_rebuild_left.call_deferred()
	_refresh()


func _on_field(text: String, path: String, field: Dictionary, edit: LineEdit) -> void:
	var trimmed := text.strip_edges()
	if trimmed == "":
		if bool(field.get("optional", false)):
			DesignModes.path_erase(_design, path)
		elif bool(field.get("nullable", false)):
			DesignModes.path_set(_design, path, null)
		else:
			_mark_field(edit, false)
			return
		_mark_field(edit, true)
		_refresh()
		return
	if not trimmed.is_valid_float() or float(trimmed) < 0.0:
		_mark_field(edit, false)
		return
	var value: Variant = float(trimmed)
	if bool(field.get("integer", false)):
		if not trimmed.is_valid_int():
			_mark_field(edit, false)
			return
		value = int(trimmed)
	# While typing: apply only what the budget allows. Over budget = orange, applied
	# (clamped) when the player presses Enter or leaves the field.
	var trial := _design.duplicate(true)
	DesignModes.path_set(trial, path, value)
	if not _affordable(_total(trial), _total(_design)):
		edit.add_theme_color_override("font_color", ConsoleTheme.ORANGE)
		edit.tooltip_text = "Over budget: that makes the rocket $%.1fM of $%.1fM. Press Enter to use the most you can afford." % [
				_total(trial), _budget_limit()]
		return
	_mark_field(edit, true)
	edit.tooltip_text = ""
	_design = trial
	_refresh()


## Enter / leaving a field: clamp an over-budget value to the most the budget allows.
func _commit_field(path: String, field: Dictionary, edit: LineEdit) -> void:
	var trimmed := edit.text.strip_edges()
	if not trimmed.is_valid_float() or float(trimmed) < 0.0:
		return
	var current: Variant = DesignModes.path_get(_design, path)
	if current == null or is_equal_approx(float(current), float(trimmed)):
		return
	var from := float(current)
	var to := float(trimmed)
	var integer := bool(field.get("integer", false))
	var t := _limited_change(func(design: Dictionary, at: float) -> void:
		var v := lerpf(from, to, at)
		DesignModes.path_set(design, path, int(floor(v)) if integer else v))
	var applied: Variant = DesignModes.path_get(_design, path)
	if t < 0.999:
		edit.text = _fmt(float(applied))
	_mark_field(edit, true)
	edit.tooltip_text = ""
	_refresh()


func _set_value(path: String, value: Variant) -> void:
	if not _try_change(func(d: Dictionary) -> Dictionary:
		DesignModes.path_set(d, path, value)
		return d):
		_rebuild_left.call_deferred()
	_refresh()


func _set_material(id: String) -> void:
	if not _try_change(func(d: Dictionary) -> Dictionary:
		for stage: Dictionary in d.get("stages", []):
			(stage["body"] as Dictionary)["material"] = id
		return d):
		_rebuild_left.call_deferred()
	_refresh()


func _set_engine(stage_index: int, engine_id: String) -> void:
	_try_change(func(d: Dictionary) -> Dictionary:
		var stage: Dictionary = (d["stages"] as Array)[stage_index]
		var old: Dictionary = stage.get("engine", {})
		stage["engine"] = DesignBuilder.resolve_engine({
			"engine_id": engine_id,
			"count": old.get("count", 1),
			"section_length_m": old.get("section_length_m", 0.0),
		}, DataLoader.engines)
		return d)
	_rebuild_left.call_deferred()
	_refresh()


func _on_save() -> void:
	var design_name := _name_edit.text.strip_edges()
	if design_name == "":
		design_name = "Design %d" % (GameState.saved_designs.size() + 1)
	_design["name"] = design_name
	GameState.save_design(design_name, {
		"level": _level_id,
		"mode": _mode,
		"easy_selections": _easy_selections.duplicate(),
		"design": _design.duplicate(true),
	})
	_refresh_load_list()
	_show_notice("Saved \"%s\" to the design file." % design_name)
	_refresh()


func _on_load(index: int) -> void:
	if index <= 0:
		return
	var design_name := _load_button.get_item_text(index)
	_load_button.select(0)
	var saved: Dictionary = GameState.saved_designs.get(design_name, {})
	if saved.is_empty():
		return
	_design = (saved.get("design", {}) as Dictionary).duplicate(true)
	_easy_selections = (saved.get("easy_selections", _easy_selections) as Dictionary).duplicate()
	_mode = int(saved.get("mode", _mode))
	_name_edit.text = design_name
	GameState.set_mode(_game_mode_for(_mode))
	_update_mode_buttons()
	_rebuild_left()
	_refresh()
	_show_notice("Loaded \"%s\"." % design_name)


func _refresh_load_list() -> void:
	_load_button.clear()
	_load_button.add_item("LOAD DESIGN..." if not GameState.saved_designs.is_empty() else "NO SAVED DESIGNS")
	for design_name in GameState.saved_designs:
		var saved: Dictionary = GameState.saved_designs[design_name]
		if str(saved.get("level", _level_id)) == _level_id:
			_load_button.add_item(str(design_name))
	_load_button.select(0)


func _on_launch() -> void:
	GameState.set_design(_design.duplicate(true), _report, {
		"level": _level_id, "mode": _mode, "easy_selections": _easy_selections.duplicate()})
	if ResourceLoader.exists(LAUNCH_SCENE):
		SceneManager.change_scene(LAUNCH_SCENE)
	else:
		_show_notice("Design locked in and stored for the launch. (The launch sim scene is not built yet.)")


# --- Right panel: results ------------------------------------------------------------

func _rebuild_right() -> void:
	_clear(_right_content)
	var checks: Array = _report.get("checks", [])
	var stars := int(_report.get("stars", 0))
	var success := str(_report.get("outcome", "")) == "success"

	var summary := HBoxContainer.new()
	summary.add_theme_constant_override("separation", 14)
	summary.add_child(StatusIcon.make_stars(stars, 40.0 if _mode == InputMode.EASY else 30.0))
	var verdict := ConsoleTheme.heading("GO FOR LAUNCH" if success else "NO-GO", 24,
			ConsoleTheme.PASS if success else ConsoleTheme.FAIL)
	summary.add_child(verdict)
	_right_content.add_child(summary)
	var tagline := "Every check passes." if stars == 3 else ("Flies, with %d warning%s." % [
			(_report.get("tips", []) as Array).size(), "" if (_report.get("tips", []) as Array).size() == 1 else "s"]) if success \
			else "Fix the red crosses before this one can fly."
	_right_content.add_child(ConsoleTheme.body(tagline, 16, ConsoleTheme.INK_SOFT))
	var budget: Dictionary = _report.get("budget", {})
	if not budget.is_empty():
		var budget_row := HBoxContainer.new()
		budget_row.add_theme_constant_override("separation", 10)
		var star := bool(budget["budget_star"])
		var over := bool(budget["over"])
		budget_row.add_child(StatusIcon.make("fail" if over else ("pass" if star else "warn"), 24.0))
		var text := "Budget left: $%.1fM of $%.1fM" % [float(budget["left_musd"]), float(budget["budget_musd"])]
		if over:
			text = "Over budget by $%.1fM: cannot launch" % -float(budget["left_musd"])
		elif star:
			text += "  (budget star)"
		else:
			text += "  (keep %d%% for the budget star)" % int(round(float(DataLoader.cost_model.get("budget_star_min_left_fraction", 0.0)) * 100.0))
		var budget_label := ConsoleTheme.body(text, 16)
		budget_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		budget_row.add_child(budget_label)
		_right_content.add_child(budget_row)
	_right_content.add_child(HSeparator.new())

	match _mode:
		InputMode.EASY:
			_right_title.text = "PRE-FLIGHT CHECKS"
			for check: Dictionary in checks:
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 12)
				var icon := StatusIcon.make(str(check["status"]), 36.0)
				icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
				row.add_child(icon)
				var text := VBoxContainer.new()
				text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				text.add_theme_constant_override("separation", 0)
				text.add_child(ConsoleTheme.heading(_short_name(check).to_upper(), 18))
				text.add_child(ConsoleTheme.body(str(check["plain"]), 16))
				row.add_child(text)
				_right_content.add_child(row)
		InputMode.MEDIUM:
			_right_title.text = "GAUGES  //  HOVER FOR NUMBERS"
			for check: Dictionary in checks:
				_right_content.add_child(_gauge_for(check))
		InputMode.HARD:
			_right_title.text = "RAW VALUES  //  FORMULAS"
			_build_raw()


func _gauge_for(check: Dictionary) -> Control:
	var gauges: Dictionary = _ui.get("gauges", {})
	var id := str(check["id"])
	var numbers: Dictionary = _report.get("numbers", {})
	var status := str(check["status"])
	var value := float(check["value"])
	var bands: Array = []
	var key := id
	var readout := "%s %.2f %s  (needs %s)" % [_short_name(check), value, str(check["unit"]), str(check["threshold"])]
	if id.begins_with("stability"):
		key = "stability"
	elif id.begins_with("upper_twr"):
		key = "upper_twr"
	var scale: Dictionary = gauges.get(key, {"min": 0.0, "max": 1.0})
	var lo := float(scale.get("min", 0.0))
	var hi := float(scale.get("max", 1.0))
	var u := func(v: float) -> float: return (v - lo) / (hi - lo)
	match key:
		"liftoff":
			bands = [[0.0, u.call(RocketEvaluator.TWR_MIN_LIFTOFF), "fail"],
					[u.call(RocketEvaluator.TWR_MIN_LIFTOFF), u.call(RocketEvaluator.TWR_GOOD_LIFTOFF), "warn"],
					[u.call(RocketEvaluator.TWR_GOOD_LIFTOFF), 1.0, "pass"]]
		"stability":
			var gimballed := bool(numbers.get("gimballed", false))
			var flyable := Stability.MARGIN_GIMBAL_MIN if gimballed else Stability.MARGIN_STABLE_MIN
			bands = [[0.0, u.call(flyable), "fail"], [u.call(flyable), u.call(Stability.MARGIN_STABLE_MIN), "warn"],
					[u.call(Stability.MARGIN_STABLE_MIN), u.call(Stability.MARGIN_OVER_STABLE), "pass"],
					[u.call(Stability.MARGIN_OVER_STABLE), 1.0, "warn"]]
		"range":
			var safe := float((_sim_data["delta_v"]["margins"] as Dictionary).get("safe_range_ratio", MissionBudget.DEFAULT_SAFE_RATIO))
			bands = [[0.0, u.call(1.0), "fail"], [u.call(1.0), u.call(safe), "warn"], [u.call(safe), 1.0, "pass"]]
			readout = "Range %.2f x what the trip needs  (%.0f / %.0f m/s)" % [value,
					float(numbers.get("delta_v_available_ms", 0.0)), float(numbers.get("delta_v_required_ms", 0.0))]
		"structure":
			var limit := float(numbers.get("q_limit_pa", 1.0))
			var warn_fraction := float((_sim_data["q_limit_model"] as Dictionary).get("warn_fraction", 0.85))
			value = float(numbers.get("q_max_pa", 0.0)) / maxf(limit, 1.0)
			bands = [[0.0, u.call(warn_fraction), "pass"], [u.call(warn_fraction), u.call(1.0), "warn"], [u.call(1.0), 1.0, "fail"]]
			readout = "Max-Q %.1f of %.1f kPa  (%.0f%% of limit)" % [float(numbers.get("q_max_pa", 0.0)) / 1000.0,
					limit / 1000.0, value * 100.0]
		"upper_twr":
			bands = [[0.0, u.call(RocketEvaluator.TWR_MIN_UPPER), "warn"], [u.call(RocketEvaluator.TWR_MIN_UPPER), 1.0, "pass"]]
		_:
			# Yes/no checks (escape tower, design): full bar in the check's colour.
			value = hi if status == "pass" else lo
			bands = [[0.0, 1.0, status]]
			readout = str(check["plain"])
	var gauge := CheckGauge.new()
	gauge.setup(_short_name(check), u.call(value), bands, status, readout,
			"%s\nValue: %.3f %s\nNeeds: %s\n\n%s" % [str(check["name"]), float(check["value"]), str(check["unit"]),
			str(check["threshold"]), str(check["plain"])])
	return gauge


func _build_raw() -> void:
	var n: Dictionary = _report.get("numbers", {})
	if not n.has("x_cp_m"):
		for check: Dictionary in _report.get("checks", []):
			_right_content.add_child(ConsoleTheme.body(str(check["technical"]), 15))
		return
	var b: Dictionary = n.get("barrowman", {})
	var status_of := {}
	for check: Dictionary in _report.get("checks", []):
		status_of[str(check["id"])] = str(check["status"])

	_raw_section("STABILITY (BARROWMAN)", [
		["Static margin, liftoff", "%.2f cal" % float(n["static_margin_liftoff_cal"]), status_of.get("stability_liftoff", "")],
		["Static margin, burnout", "%.2f cal" % float(n["static_margin_burnout_cal"]), status_of.get("stability_burnout", "")],
		["X_cp", "%.2f m" % float(n["x_cp_m"]), ""],
		["X_cg liftoff / burnout", "%.2f / %.2f m" % [float(n["x_cg_liftoff_m"]), float(n["x_cg_burnout_m"])], ""],
		["CNa nose / fins", "%.2f / %.2f" % [float(b.get("cn_alpha_nose", 0.0)), float(b.get("cn_alpha_fins", 0.0))], ""],
		["X_nose / X_fins", "%.2f / %.2f m" % [float(b.get("x_nose_m", 0.0)), float(b.get("x_fins_m", 0.0))], ""],
	], "X_cp = (CNa_n*X_n + CNa_f*X_f) / (CNa_n + CNa_f);  margin = (X_cp - X_cg) / d")

	var dv_rows: Array = []
	var dv_stages: Array = n.get("delta_v_stages", [])
	for i in dv_stages.size():
		var s: Dictionary = dv_stages[i]
		dv_rows.append(["dv stage %d (Isp %.0f s)" % [i + 1, float(s["isp_s"])], "%.0f m/s" % float(s["delta_v_ms"]), ""])
	dv_rows.append(["Total dv vs required", "%.0f / %.0f m/s" % [float(n["delta_v_available_ms"]), float(n["delta_v_required_ms"])], status_of.get("range", "")])
	dv_rows.append(["Range ratio", "%.3f" % float(n["range_ratio"]), status_of.get("range", "")])
	_raw_section("RANGE (TSIOLKOVSKY)", dv_rows, "dv = Isp * g0 * ln(m0 / mf), summed over stages")

	var lift_rows: Array = [["TWR at liftoff", "%.3f" % float(n["twr_liftoff"]), status_of.get("liftoff", "")],
		["Thrust SL / liftoff mass", "%.0f kN / %.0f kg" % [float(n["thrust_sl_N"]) / 1000.0, float(n["liftoff_mass_kg"])], ""]]
	for check: Dictionary in _report.get("checks", []):
		if str(check["id"]).begins_with("upper_twr"):
			lift_rows.append([str(check["name"]), "%.3f" % float(check["value"]), str(check["status"])])
	_raw_section("LIFTOFF", lift_rows, "TWR = thrust_SL / (m_total * g0)")

	var ascent: Dictionary = n.get("ascent_estimate", {})
	_raw_section("STRUCTURE (MAX-Q)", [
		["Max-Q vs limit", "%.1f / %.1f kPa" % [float(n["q_max_pa"]) / 1000.0, float(n["q_limit_pa"]) / 1000.0], status_of.get("structure", "")],
		["At", "T+%.0f s, %.1f km" % [float(ascent.get("q_max_time_s", 0.0)), float(ascent.get("q_max_altitude_m", 0.0)) / 1000.0], ""],
		["Cd / fineness L/d", "%.3f / %.1f" % [float(n["cd"]), float(n["fineness"])], ""],
	], "q = 1/2 * rho * v^2,  rho = 1.225 * e^(-h / 8500)")

	_raw_section("MASS", [
		["Liftoff / dry / propellant", "%.0f / %.0f / %.0f kg" % [float(n["liftoff_mass_kg"]), float(n["dry_mass_kg"]), float(n["propellant_mass_kg"])], ""],
		["Length / diameter", "%.2f / %.2f m" % [float(n["length_m"]), float(n["diameter_m"])], ""],
	], "")

	_right_content.add_child(ConsoleTheme.heading("WORKING (FROM THE SIM)", 18, ConsoleTheme.TEAL_DARK))
	for check: Dictionary in _report.get("checks", []):
		var line := ConsoleTheme.body("[%s] %s" % [str(check["status"]).to_upper(), str(check["technical"])], 14,
				ConsoleTheme.status_color(str(check["status"])).darkened(0.25))
		_right_content.add_child(line)
	var predictions: Dictionary = _design.get("predictions", {})
	if not predictions.is_empty():
		_right_content.add_child(ConsoleTheme.body("Your predictions are logged (%s). They are compared after the launch." % ", ".join(
				PackedStringArray(predictions.keys().map(func(k): return "%s = %s" % [k, _fmt(float(predictions[k]))]))), 15, ConsoleTheme.INK_SOFT))


func _raw_section(title: String, rows: Array, formula: String) -> void:
	_right_content.add_child(ConsoleTheme.heading(title, 18, ConsoleTheme.TEAL_DARK))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 2)
	for row: Array in rows:
		var name_label := ConsoleTheme.body(str(row[0]), 16)
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(name_label)
		var value_label := ConsoleTheme.body(str(row[1]), 16)
		value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(value_label)
		var status := str(row[2])
		if status != "":
			grid.add_child(StatusIcon.make(status, 20.0))
		else:
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(20, 20)
			grid.add_child(spacer)
	_right_content.add_child(grid)
	if formula != "":
		_right_content.add_child(ConsoleTheme.body(formula, 14, ConsoleTheme.INK_SOFT))


# --- Budget: a live limit while building -------------------------------------------
# Every change goes through _try_change (discrete: accept or refuse) or _limited_change
# (continuous: clamp to the most the budget allows). A change that does not raise the
# cost is always allowed, so a design that is over a cut budget can still be fixed.

func _budget_limit() -> float:
	return GameState.budget if GameState.budget > 0.0 else float(_level.get("budget", 0.0))


func _cost(design: Dictionary) -> Dictionary:
	return CostModel.design_cost(design, DataLoader.engines, DataLoader.materials, DataLoader.cost_model)


func _total(design: Dictionary) -> float:
	return float(_cost(design)["total"])


func _affordable(new_cost: float, old_cost: float) -> bool:
	return new_cost <= _budget_limit() + 0.0001 or new_cost <= old_cost + 0.0001


## Discrete change: `apply` takes a copy of the design and returns the changed design.
## Refused (with a line from Pike) if it would break the budget. Returns true if applied.
func _try_change(apply: Callable) -> bool:
	var old_cost := _total(_design)
	var changed: Dictionary = apply.call(_design.duplicate(true))
	var new_cost := _total(changed)
	if not _affordable(new_cost, old_cost):
		_show_notice("Not in the budget: that makes the rocket $%.1fM. PIKE: \"%s\"" % [new_cost,
				_pike_line("over_budget", new_cost, old_cost)])
		return false
	_design = changed
	return true


## Continuous change: `apply_at(design, t)` sets the design to the change at fraction t
## (0 = as it is now, 1 = all of it). Applies as much as the budget allows; returns t.
func _limited_change(apply_at: Callable) -> float:
	var base := _design.duplicate(true)
	var old_cost := _total(base)
	var cost_at := func(t: float) -> float:
		var copy := base.duplicate(true)
		apply_at.call(copy, t)
		return _total(copy)
	var t := CostModel.affordable_fraction(cost_at, maxf(_budget_limit(), old_cost))
	var result := base.duplicate(true)
	apply_at.call(result, t)
	_design = result
	if t < 0.999:
		var kind := "clamped" if t > 0.001 else "over_budget"
		_show_notice("Clamped to what the budget allows. PIKE: \"%s\"" % _pike_line(kind, float(cost_at.call(1.0)), old_cost))
	return t


func _pike_line(kind: String, cost: float, before_cost: float) -> String:
	var lines: Array = (DataLoader.raw.get("pike_lines", {}) as Dictionary).get(kind, [])
	if lines.is_empty():
		return "No."
	var budget := _budget_limit()
	return str(lines[randi() % lines.size()]).replace("{cost}", "%.1f" % cost).replace("{budget}", "%.1f" % budget) \
			.replace("{over}", "%.1f" % maxf(cost - budget, 0.0)).replace("{left}", "%.1f" % maxf(budget - before_cost, 0.0))


func _money(value: float) -> String:
	return "$%.2fM" % value


## Easy: what one part costs in the rocket it would make (its share of the cost items).
func _easy_part_cost(part: String, cost: Dictionary) -> float:
	match part:
		"body", "material":
			return CostModel.items_cost(cost, ["stage_0_tanks"])
		"engine":
			return CostModel.items_cost(cost, ["stage_0_engine"])
		"fins":
			return CostModel.items_cost(cost, ["fins"])
		"upper_stage":
			var total := 0.0
			for i in range(1, 8):
				total += CostModel.stage_cost(cost, i)
			return total
	return 0.0


## Medium: the cost of what a slider group controls ("" when it is free).
func _group_cost_text(slider_def: Dictionary, cost: Dictionary) -> String:
	var path := str((slider_def.get("paths", [""]) as Array)[0])
	var parts := path.split("/")
	if parts[0] == "fins":
		return _money(CostModel.items_cost(cost, ["fins"]))
	if parts[0] != "stages" or parts.size() < 3:
		return "no cost"
	var stage := int(parts[1])
	if stage > 0:
		return _money(CostModel.stage_cost(cost, stage))
	if parts[2] == "engine":
		return _money(CostModel.items_cost(cost, ["stage_0_engine", "gimbal"]))
	return _money(CostModel.items_cost(cost, ["stage_0_tanks"]))


func _on_budget_changed(_new_budget: float) -> void:
	if not is_inside_tree():
		return
	_rebuild_left()
	_refresh()
	var cost := _total(_design)
	if cost > _budget_limit():
		_show_notice("PIKE: \"%s\"" % _pike_line("budget_cut", cost, cost))


# --- Helpers -------------------------------------------------------------------------

func _easy_design() -> Dictionary:
	var design := DesignBuilder.from_easy(_easy_selections, DataLoader.presets, DataLoader.engines,
			DesignModes.level_payload(_level), DesignModes.level_mission(_level))
	design["name"] = "Easy rocket"
	return design


func _slider_positions() -> Dictionary:
	return DesignModes.slider_positions(_design, _ui.get("medium_sliders", []), _ref_values, _min_factor, _max_factor)


func _update_slider_label(slider_id: String, pos: Dictionary) -> void:
	var row: Dictionary = _slider_rows.get(slider_id, {})
	if row.is_empty() or pos.is_empty():
		return
	var slider_def: Dictionary = row["def"]
	var divisor := float(slider_def.get("display_divisor", 1.0))
	var label: Label = row["value"]
	var value := float(pos["value"]) / divisor
	label.text = "%s %s" % [_fmt(value), str(slider_def.get("unit", ""))]
	var slider: HSlider = row["slider"]
	if bool(pos["in_range"]):
		label.add_theme_color_override("font_color", ConsoleTheme.INK)
		slider.tooltip_text = "Slider %.2f. Reference: %s %s." % [float(pos["slider"]), _fmt(float(pos["reference"]) / divisor), str(slider_def.get("unit", ""))]
	else:
		label.add_theme_color_override("font_color", ConsoleTheme.ORANGE)
		slider.tooltip_text = "Outside the slider's range (reference %s %s). Moving it sets a value inside the range." % [
				_fmt(float(pos["reference"]) / divisor), str(slider_def.get("unit", ""))]
	label.tooltip_text = slider.tooltip_text


func _recompute_upper_length(stage_index: int) -> void:
	var stages: Array = _design.get("stages", [])
	if stage_index < 1 or stage_index >= stages.size():
		return
	DesignBuilder.recompute_tank_length((stages[stage_index] as Dictionary)["body"])


func _preset_scale(table: Dictionary) -> Dictionary:
	var result := {}
	for id in table:
		var preset: Dictionary = table[id]
		for key in ["length_m", "diameter_m", "root_chord_m", "propellant_mass_kg"]:
			if preset.has(key) and preset[key] != null:
				result[key] = maxf(float(result.get(key, 0.0)), float(preset[key]))
	return result


func _part_label(part: String) -> String:
	for part_def: Dictionary in _ui.get("easy_parts", []):
		if str(part_def["part"]) == part:
			return str(part_def["label"])
	return part


func _preset_label(part: String, id: String) -> String:
	var entry: Dictionary = (DataLoader.presets.get(part, {}) as Dictionary).get(id, {})
	return str(entry.get("label", id))


func _short_name(check: Dictionary) -> String:
	return str(check["name"]).replace(" (thrust-to-weight)", "").replace(" (delta-v)", "").replace(" (Max-Q)", "")


func _mark_field(edit: LineEdit, ok: bool) -> void:
	if ok:
		edit.remove_theme_color_override("font_color")
	else:
		edit.add_theme_color_override("font_color", ConsoleTheme.FAIL)


func _show_notice(text: String) -> void:
	_notice_label.text = text
	_notice_panel.visible = true
	_notice_timer.start(NOTICE_SECONDS)


func _wrap_placard(label: Label) -> PanelContainer:
	var strip := PanelContainer.new()
	var box := ConsoleTheme.panel(ConsoleTheme.TEAL, ConsoleTheme.INK, 3, 6, 6)
	box.content_margin_left = 12
	strip.add_theme_stylebox_override("panel", box)
	strip.add_child(label)
	return strip


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


static func _fmt(value: float) -> String:
	if absf(value) >= 1000.0:
		return "%.0f" % value
	var text := "%.3f" % value
	text = text.rstrip("0").rstrip(".")
	return text if text != "" and text != "-" else "0"
