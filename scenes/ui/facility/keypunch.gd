# Code generated with AI assistance (Claude). Reviewed by team.
class_name Keypunch
extends Control
## IBM Computer Room terminal (Hard input). The rocket is a deck of punch cards, one per
## part, with the fields from builder_ui.json "hard_fields". SUBMIT DECK checks every
## card, the machine whirs and blinks, DesignSession applies the deck (budget rules
## included), and a fan-fold printout shows the full RocketEvaluator report.

signal closed

const CARD_COLOR := Color("f3e9c6")
const CARD_EDGE := Color("b8a57a")
const MACHINE := Color("4d5b63")
const LIGHT_ON := Color("ffcf5a")
const LIGHT_OFF := Color("3a3326")
const BUSY_SECONDS := 2.6

var session: DesignSession
var _cfg: Dictionary = {}
var _deck: Dictionary = {}            # the design being punched (a copy)
var _inputs: Array = []               # [{edit, path, field, card}]
var _cards: Array[PanelContainer] = []
var _deck_box: VBoxContainer
var _status: Label
var _submit: Button
var _lights: Array[ColorRect] = []
var _busy: float = -1.0
var _blink_t: float = 0.0
var _printout_layer: Control
var _printout: FanfoldPrintout
var _run_number: int = 41
var _audio: AudioStreamPlayer


func _ready() -> void:
	theme = ConsoleTheme.build()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_cfg = (DataLoader.raw.get("facility", {}) as Dictionary).get("keypunch", {})
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.08, 0.08, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	margin.add_child(row)

	# Left: the deck.
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	row.add_child(left)
	left.add_child(ConsoleTheme.placard(str(_cfg.get("title", "KEYPUNCH")), 22))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_deck_box = VBoxContainer.new()
	_deck_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_box.add_theme_constant_override("separation", 14)
	scroll.add_child(_deck_box)

	# Right: the machine.
	var machine := PanelContainer.new()
	machine.custom_minimum_size = Vector2(520, 0)
	machine.add_theme_stylebox_override("panel", ConsoleTheme.panel(MACHINE, ConsoleTheme.INK, 5, 8, 22))
	row.add_child(machine)
	var mbox := VBoxContainer.new()
	mbox.add_theme_constant_override("separation", 16)
	machine.add_child(mbox)
	mbox.add_child(ConsoleTheme.heading("CENTRAL PROCESSOR", 24, ConsoleTheme.CREAM))
	var grid := GridContainer.new()
	grid.columns = 12
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	mbox.add_child(grid)
	for i in 72:
		var light := ColorRect.new()
		light.custom_minimum_size = Vector2(26, 26)
		light.color = LIGHT_ON if randf() < 0.3 else LIGHT_OFF
		grid.add_child(light)
		_lights.append(light)
	_status = ConsoleTheme.body("READY. PUNCH YOUR CARDS, THEN SUBMIT THE DECK.", 20, ConsoleTheme.CREAM)
	_status.add_theme_font_override("font", ConsoleTheme.mono())
	_status.custom_minimum_size = Vector2(0, 150)
	mbox.add_child(_status)
	_submit = Button.new()
	_submit.text = str(_cfg.get("submit", "SUBMIT DECK"))
	_submit.custom_minimum_size = Vector2(0, 72)
	_submit.add_theme_font_size_override("font_size", 28)
	_submit.pressed.connect(_on_submit)
	mbox.add_child(_submit)
	var add := Button.new()
	add.text = str(_cfg.get("add_stage", "ADD STAGE"))
	add.custom_minimum_size = Vector2(0, 50)
	add.pressed.connect(_on_add_stage)
	mbox.add_child(add)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mbox.add_child(spacer)
	var close := Button.new()
	close.text = "LEAVE TERMINAL  [Esc]"
	close.custom_minimum_size = Vector2(0, 50)
	close.pressed.connect(_close)
	mbox.add_child(close)

	_audio = AudioStreamPlayer.new()
	_audio.stream = _whir_sound()
	_audio.volume_db = -8.0
	add_child(_audio)

	_build_printout_layer()
	_deck = session.design.duplicate(true)
	_rebuild_deck()


# --- Deck ----------------------------------------------------------------------------

func _rebuild_deck() -> void:
	for child in _deck_box.get_children():
		_deck_box.remove_child(child)
		child.queue_free()
	_inputs.clear()
	_cards.clear()
	var fields: Dictionary = DataLoader.builder_ui.get("hard_fields", {})
	var stages: Array = _deck.get("stages", [])
	var nose := _card("NOSE CONE")
	_option(nose, "SHAPE", DataLoader.nose_shapes, "nose/shape")
	_fields(nose, fields.get("nose", []), "nose")
	for i in stages.size():
		var base := "stages/%d/" % i
		var body := _card("STAGE %d  TANKS%s" % [i + 1, "" if i == 0 else "  (UPPER)"], i if i > 0 and i == stages.size() - 1 else -1)
		_option(body, "MATERIAL", DataLoader.materials, base + "body/material")
		_fields(body, fields.get("body", []), base + "body")
		var engine := _card("STAGE %d  ENGINE" % (i + 1))
		var options := {}
		for engine_id in (session.level.get("unlocked_parts", {}) as Dictionary).get("engines", DataLoader.engines.keys()):
			if DataLoader.engines.has(str(engine_id)):
				options[str(engine_id)] = DataLoader.engines[str(engine_id)]
		_option(engine, "ENGINE TYPE", options, base + "engine/engine_id", i)
		_fields(engine, fields.get("engine", []), base + "engine")
	var fins := _card("FINS")
	_fields(fins, fields.get("fins", []), "fins")
	var opts := _card("OPTIONS")
	var gimbal := CheckBox.new()
	gimbal.text = "GIMBALLED FIRST-STAGE ENGINE"
	gimbal.button_pressed = bool(DesignModes.path_get(_deck, "options/gimballed"))
	gimbal.toggled.connect(func(on: bool) -> void: DesignModes.path_set(_deck, "options/gimballed", on))
	_card_grid(opts).add_child(gimbal)
	_card_grid(opts).add_child(Control.new())
	_fields(opts, fields.get("escape_tower", []), "options/escape_tower")
	var sums := _card("LAUNCH + YOUR OWN SUMS")
	_fields(sums, fields.get("launch", []), "launch")
	_fields(sums, fields.get("predictions", []), "predictions")
	_update_holes()


func _card(title: String, removable_stage: int = -1) -> PanelContainer:
	var card := PanelContainer.new()
	var style := ConsoleTheme.panel(CARD_COLOR, CARD_EDGE, 2, 4, 14)
	style.corner_radius_top_left = 0
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 4
	style.shadow_offset = Vector2(3, 4)
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var holes := CardHoles.new()
	box.add_child(holes)
	var header := HBoxContainer.new()
	box.add_child(header)
	var label := ConsoleTheme.heading("CARD %02d  //  %s" % [_cards.size() + 1, title], 18, ConsoleTheme.INK)
	label.add_theme_font_override("font", ConsoleTheme.mono())
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	if removable_stage > 0:
		var remove := Button.new()
		remove.text = str(_cfg.get("remove_stage", "DISCARD"))
		remove.pressed.connect(func() -> void:
			_deck["stages"] = (_deck["stages"] as Array).slice(0, removable_stage)
			_rebuild_deck())
		header.add_child(remove)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	card.set_meta("holes", holes)
	card.set_meta("grid", grid)
	_deck_box.add_child(card)
	_cards.append(card)
	return card


func _card_grid(card: PanelContainer) -> GridContainer:
	return card.get_meta("grid") as GridContainer


func _fields(card: PanelContainer, defs: Array, prefix: String) -> void:
	var grid := _card_grid(card)
	for field: Dictionary in defs:
		var path := "%s/%s" % [prefix, str(field["key"])]
		var unit := str(field.get("unit", ""))
		var label := ConsoleTheme.body("%s%s" % [str(field["label"]).to_upper(), (" (%s)" % unit) if unit != "" else ""], 15)
		label.add_theme_font_override("font", ConsoleTheme.mono())
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(label)
		var edit := LineEdit.new()
		edit.custom_minimum_size = Vector2(190, 36)
		edit.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		edit.add_theme_font_override("font", ConsoleTheme.mono())
		edit.placeholder_text = str(field.get("hint", ""))
		var current: Variant = DesignModes.path_get(_deck, path)
		if current == null and field.has("default"):
			current = field["default"]
		edit.text = _fmt(float(current)) if current != null else ""
		edit.text_changed.connect(func(_t: String) -> void:
			edit.remove_theme_color_override("font_color")
			_update_holes())
		grid.add_child(edit)
		_inputs.append({"edit": edit, "path": path, "field": field, "card": card})


func _option(card: PanelContainer, label_text: String, table: Dictionary, path: String, engine_stage: int = -1) -> void:
	var grid := _card_grid(card)
	var label := ConsoleTheme.body(label_text, 15)
	label.add_theme_font_override("font", ConsoleTheme.mono())
	grid.add_child(label)
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(190, 36)
	option.clip_text = true
	var ids: Array = []
	var selected := str(DesignModes.path_get(_deck, path))
	for id in table:
		option.add_item(str((table[id] as Dictionary).get("name", id)))
		ids.append(str(id))
	if not ids.has(selected):
		option.add_item("(custom: %s)" % selected)
		ids.append(selected)
	option.select(ids.find(selected))
	option.item_selected.connect(func(index: int) -> void:
		var id := str(ids[index])
		if engine_stage >= 0:
			var stage: Dictionary = (_deck["stages"] as Array)[engine_stage]
			var old: Dictionary = stage.get("engine", {})
			stage["engine"] = DesignBuilder.resolve_engine({"engine_id": id, "count": old.get("count", 1),
					"section_length_m": old.get("section_length_m", 0.0)}, DataLoader.engines)
			_rebuild_deck()
		elif path.ends_with("body/material"):
			DesignModes.path_set(_deck, path, id)
		else:
			DesignModes.path_set(_deck, path, id))
	grid.add_child(option)


func _update_holes() -> void:
	var per_card := {}
	for input: Dictionary in _inputs:
		var card: PanelContainer = input["card"]
		per_card[card] = str(per_card.get(card, "")) + (input["edit"] as LineEdit).text.strip_edges() + " "
	for card in _cards:
		(card.get_meta("holes") as CardHoles).text = str(per_card.get(card, ""))


# --- Submit --------------------------------------------------------------------------

## Reads every card into a copy of the deck. Returns {ok, design, error}.
func read_deck() -> Dictionary:
	var trial := _deck.duplicate(true)
	for input: Dictionary in _inputs:
		var edit: LineEdit = input["edit"]
		var field: Dictionary = input["field"]
		var path := str(input["path"])
		var text := edit.text.strip_edges()
		if text == "":
			if bool(field.get("optional", false)):
				DesignModes.path_erase(trial, path)
				continue
			if bool(field.get("nullable", false)):
				DesignModes.path_set(trial, path, null)
				continue
			if DesignModes.path_get(trial, path) == null:
				continue   # a blank card column for a part the rocket does not have (e.g. no tower)
		var ok := text.is_valid_float() and float(text) >= 0.0
		if ok and bool(field.get("integer", false)):
			ok = text.is_valid_int()
		if not ok:
			edit.add_theme_color_override("font_color", ConsoleTheme.FAIL)
			var number := _cards.find(input["card"]) + 1
			return {"ok": false, "error": str(_cfg.get("bad_card", "CARD %02d REJECTED: '%s' / %s")) % [
					number, text, str(field["label"]).to_upper()]}
		DesignModes.path_set(trial, path, int(text) if bool(field.get("integer", false)) else float(text))
	for i in range(1, (trial.get("stages", []) as Array).size()):
		DesignBuilder.recompute_tank_length(((trial["stages"] as Array)[i] as Dictionary)["body"])
	return {"ok": true, "design": trial}


func _on_submit() -> void:
	if _busy >= 0.0:
		return
	var read := read_deck()
	if not bool(read["ok"]):
		_status.text = str(read["error"])
		_status.add_theme_color_override("font_color", ConsoleTheme.FAIL.lightened(0.3))
		return
	_status.remove_theme_color_override("font_color")
	_submit.disabled = true
	_busy = 0.0
	_audio.play()
	var result := session.submit_deck(read["design"])
	_pending_result = result


var _pending_result: Dictionary = {}


func _process(delta: float) -> void:
	_blink_t += delta
	var period := 0.07 if _busy >= 0.0 else 0.6
	if _blink_t >= period:
		_blink_t = 0.0
		for light in _lights:
			if randf() < (0.5 if _busy >= 0.0 else 0.08):
				light.color = LIGHT_ON if light.color == LIGHT_OFF else LIGHT_OFF
	if _busy < 0.0:
		return
	_busy += delta
	var steps: Array = _cfg.get("busy", ["PROCESSING"])
	var step := mini(int(_busy / BUSY_SECONDS * steps.size()), steps.size() - 1)
	_status.text = "%s%s" % [str(steps[step]), ".".repeat(1 + int(_busy * 4.0) % 3)]
	if _busy >= BUSY_SECONDS:
		_busy = -1.0
		_submit.disabled = false
		_finish_run(_pending_result)


func _finish_run(result: Dictionary) -> void:
	_run_number += 1
	var header := str(_cfg.get("printout_header", "RUN %04d")) % _run_number
	var text := header + "\n" + "=".repeat(header.length()) + "\n\n"
	if not bool(result.get("ok", false)):
		text += str(result.get("notice", "DECK REJECTED.")) + "\n\nNO EVALUATION PERFORMED. THE DESIGN ON FILE IS UNCHANGED.\n"
		_status.text = "DECK REJECTED. SEE PRINTOUT."
	else:
		text += printout_text(session.report, session.design, session.total_cost(session.design), session.budget_limit())
		_status.text = "RUN %04d COMPLETE: %s, %d / 3 STARS." % [_run_number,
				str(session.report.get("outcome", "")).to_upper(), int(session.report.get("stars", 0))]
		_deck = session.design.duplicate(true)
		_rebuild_deck()
	_printout.set_text(text)
	_printout_layer.visible = true


## The printout body: the evaluator's own report plus the player's predictions vs the sim.
static func printout_text(report: Dictionary, design: Dictionary, cost: float, budget: float) -> String:
	var text := RocketEvaluator.format_report(report) + "\n"
	var n: Dictionary = report.get("numbers", {})
	text += "\n  COST $%.2fM OF BUDGET $%.2fM  (%s)\n" % [cost, budget, "OVER" if cost > budget else "WITHIN BUDGET"]
	var predictions: Dictionary = design.get("predictions", {})
	if not predictions.is_empty():
		text += "\n  YOUR SUMS VS THE MACHINE\n"
		if predictions.has("delta_v_ms") and n.has("delta_v_available_ms"):
			var sim_dv := float(n["delta_v_available_ms"])
			var mine := float(predictions["delta_v_ms"])
			text += "    TOTAL DV       YOURS %8.0f M/S   SIM %8.0f M/S   ERROR %+6.1f%%\n" % [mine, sim_dv, (mine - sim_dv) / maxf(sim_dv, 1.0) * 100.0]
		if predictions.has("static_margin_cal") and n.has("static_margin_liftoff_cal"):
			var sim_m := float(n["static_margin_liftoff_cal"])
			var mine_m := float(predictions["static_margin_cal"])
			text += "    STATIC MARGIN  YOURS %8.2f CAL     SIM %8.2f CAL     DIFF  %+6.2f\n" % [mine_m, sim_m, mine_m - sim_m]
	text += "\n  END OF RUN.\n"
	return text


func _on_add_stage() -> void:
	var read := read_deck()
	if bool(read["ok"]):
		_deck = read["design"]
	_deck = session.with_extra_stage(_deck)
	_rebuild_deck()


# --- Printout ------------------------------------------------------------------------

func _build_printout_layer() -> void:
	_printout_layer = Control.new()
	_printout_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_printout_layer.visible = false
	add_child(_printout_layer)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_printout_layer.add_child(shade)
	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_bottom = 1.0
	box.offset_left = -660
	box.offset_right = 660
	box.offset_top = 30
	box.offset_bottom = -30
	box.add_theme_constant_override("separation", 10)
	_printout_layer.add_child(box)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_printout = FanfoldPrintout.new()
	_printout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_printout)
	var tear := Button.new()
	tear.text = str(_cfg.get("close", "TEAR OFF"))
	tear.custom_minimum_size = Vector2(0, 56)
	tear.add_theme_font_size_override("font_size", 24)
	tear.pressed.connect(func() -> void: _printout_layer.visible = false)
	box.add_child(tear)


func printout_visible() -> bool:
	return _printout_layer.visible


func _close() -> void:
	closed.emit()
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		if _printout_layer.visible:
			_printout_layer.visible = false
		else:
			_close()
		get_viewport().set_input_as_handled()


# --- Sound ---------------------------------------------------------------------------

## A short machine whir: motor hum with relay clicks, made in code (no audio asset yet).
static func _whir_sound() -> AudioStreamWAV:
	var rate := 22050
	var seconds := BUSY_SECONDS
	var count := int(rate * seconds)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var phase := 0.0
	for i in count:
		var t := float(i) / rate
		var env := minf(1.0, t / 0.25) * minf(1.0, (seconds - t) / 0.4)
		var freq := 95.0 + 40.0 * minf(1.0, t / 0.6)
		phase += TAU * freq / rate
		var v := 0.35 * sin(phase) + 0.18 * sin(phase * 2.0) + 0.08 * (randf() * 2.0 - 1.0)
		if fmod(t, 0.19) < 0.004:
			v += 0.5 * (randf() * 2.0 - 1.0)
		bytes.encode_s16(i * 2, int(clampf(v * env, -1.0, 1.0) * 26000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = bytes
	return wav


static func _fmt(value: float) -> String:
	if absf(value) >= 1000.0:
		return "%.0f" % value
	var text := "%.3f" % value
	text = text.rstrip("0").rstrip(".")
	return text if text != "" and text != "-" else "0"
