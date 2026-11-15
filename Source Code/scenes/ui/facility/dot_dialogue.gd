# SI assistance metadata: This code used the help of SI.
class_name DotDialogue
extends Control

signal finished

const CHARS_PER_SECOND := 70.0

var _lines: PackedStringArray = []
var _index: int = 0
var _speaker: Label
var _text: Label
var _hint: Label
var _reveal: float = 0.0

static func lines_for(report: Dictionary, cost: float, budget: float, data: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	var checks: Array = report.get("checks", [])
	var numbers: Dictionary = report.get("numbers", {})
	var fills := {"mug": str(randi_range(1, 8)), "cost": "%.1f" % cost, "budget": "%.1f" % budget}
	if checks.is_empty() or not numbers.has("liftoff_mass_kg"):
		out.append(_fill(_pick(data.get("no_rocket", [])), fills))
		return out
	out.append(_fill(_pick(data.get("greeting", [])), fills))
	var templates: Dictionary = data.get("checks", {})

	var worst_stab: Dictionary = {}
	var rank := {"pass": 0, "warn": 1, "fail": 2}
	for check: Dictionary in checks:
		if str(check["id"]).begins_with("stability"):
			if worst_stab.is_empty() or int(rank.get(str(check["status"]), 0)) > int(rank.get(str(worst_stab["status"]), 0)):
				worst_stab = check

	for check: Dictionary in checks:
		var id := str(check["id"])
		var status := str(check["status"])
		var key := id
		var f := fills.duplicate()
		match id:
			"liftoff":
				f["twr"] = "%.2f" % float(check["value"])
			"stability_liftoff", "stability_burnout":
				if check != worst_stab:
					continue
				key = "stability"
				var margin := float(check["value"])
				f["margin"] = "%.2f" % margin
				f["when"] = "on the pad" if id == "stability_liftoff" else "once the fuel's gone"
				if status == "warn":
					status = "warn_stiff" if margin > Stability.MARGIN_OVER_STABLE else "warn_wobbly"
			"range":
				var pct := float(check["value"]) * 100.0
				f["pct"] = "%d" % int(round(pct))
				f["short"] = "%d" % int(round(maxf(0.0, 100.0 - pct)))
				f["spare"] = "%d" % int(round(maxf(0.0, pct - 100.0)))
			"structure":
				var q := float(numbers.get("q_max_pa", 0.0)) / 1000.0
				var limit := float(numbers.get("q_limit_pa", 1.0)) / 1000.0
				f["q"] = "%.0f" % q
				f["limit"] = "%.0f" % limit
				f["load"] = "%d" % int(round(q / maxf(limit, 0.001) * 100.0))
			"escape_tower":
				pass
			_:
				if id.begins_with("upper_twr"):
					key = "upper_twr"
					f["stage"] = id.trim_prefix("upper_twr_stage_")
					f["upper_twr"] = "%.2f" % float(check["value"])
		var by_status: Dictionary = templates.get(key, {})
		var line := _pick(by_status.get(status, []))
		if line == "":
			line = str(check["plain"])
		out.append(_fill(line, f))

	var budget_lines: Dictionary = data.get("budget", {})
	if budget > 0.0:
		out.append(_fill(_pick(budget_lines.get("over" if cost > budget + 0.0001 else "ok", [])), fills))
	out.append(_fill(_pick((data.get("summary", {}) as Dictionary).get(str(int(report.get("stars", 0))), [])), fills))
	var cleaned: PackedStringArray = []
	for line in out:
		if line.strip_edges() != "":
			cleaned.append(line)
	return cleaned

static func _pick(list: Variant) -> String:
	if not (list is Array) or (list as Array).is_empty():
		return ""
	return str(list[randi() % (list as Array).size()])

static func _fill(line: String, fills: Dictionary) -> String:
	for key in fills:
		line = line.replace("{%s}" % key, str(fills[key]))
	return line

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ConsoleTheme.panel(ConsoleTheme.PAPER, ConsoleTheme.INK, 5, 14, 22))
	panel.anchor_left = 0.12
	panel.anchor_right = 0.88
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -270
	panel.offset_bottom = -40
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	_speaker = ConsoleTheme.heading(str(DataLoader.raw.get("dot_lines", {}).get("speaker", "DOT")), 28, ConsoleTheme.TEAL_DARK)
	box.add_child(_speaker)
	_text = ConsoleTheme.body("", 26)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_override("font", ConsoleTheme.typewriter())
	box.add_child(_text)
	_hint = ConsoleTheme.body("", 16, ConsoleTheme.INK_SOFT)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_hint)

func start(lines: PackedStringArray) -> void:
	_lines = lines
	_index = 0
	_show_current()

func _show_current() -> void:
	if _index >= _lines.size():
		finished.emit()
		queue_free()
		return
	_text.text = _lines[_index]
	_text.visible_ratio = 0.0
	_reveal = 0.0
	_hint.text = "%d / %d    [E] next    [Esc] done" % [_index + 1, _lines.size()]

func _process(delta: float) -> void:
	if _text == null or _text.text == "":
		return
	_reveal += delta * CHARS_PER_SECOND
	_text.visible_ratio = minf(1.0, _reveal / maxf(1.0, float(_text.text.length())))

func advance() -> void:
	if _text.visible_ratio < 1.0:
		_text.visible_ratio = 1.0
		_reveal = float(_text.text.length())
		return
	_index += 1
	_show_current()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()
		accept_event()

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_E or key.keycode == KEY_SPACE or key.keycode == KEY_ENTER:
		advance()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_ESCAPE:
		_index = _lines.size()
		_show_current()
		get_viewport().set_input_as_handled()
