# SI assistance metadata: This code used the help of SI.
class_name DesignSession
extends RefCounted

enum InputMode { EASY, MEDIUM, HARD }
const DEFAULT_LEVEL := "L1"

var level_id: String = DEFAULT_LEVEL
var level: Dictionary = {}
var reference: Dictionary = {}
var sim_data: Dictionary = {}
var design: Dictionary = {}
var report: Dictionary = {}
var easy_selections: Dictionary = {}
var input_mode: int = InputMode.EASY

func _init() -> void:
	load_from_game_state()

func load_from_game_state() -> void:
	sim_data = DataLoader.sim_data()
	level_id = GameState.current_level if DataLoader.levels.has(GameState.current_level) else DEFAULT_LEVEL
	if GameState.current_level == "":
		GameState.set_level(level_id)
	level = DataLoader.levels.get(level_id, {})
	reference = DataLoader.reference_rockets.get(str(level.get("reference_rocket", "")), {})
	var state: Dictionary = GameState.builder_state
	if GameState.budget <= 0.0 or str(state.get("level", "")) != level_id:
		GameState.budget = float(level.get("budget", 0.0))
	if not GameState.current_design.is_empty() and str(state.get("level", "")) == level_id:
		design = GameState.current_design.duplicate(true)
		easy_selections = (state.get("easy_selections", {}) as Dictionary).duplicate()
		input_mode = int(state.get("mode", InputMode.EASY))
	else:
		easy_selections = (DataLoader.builder_ui.get("easy_defaults", {}) as Dictionary).duplicate()
		input_mode = _input_mode_from_game_state()
		design = _easy_design(easy_selections)
	refresh()

func refresh() -> void:
	design["payload"] = DesignModes.level_payload(level)
	design["mission"] = DesignModes.level_mission(level)
	design["mission"]["budget_musd"] = budget_limit()
	report = RocketEvaluator.evaluate(design, sim_data)
	GameState.set_design(design.duplicate(true), report, {
		"level": level_id, "mode": input_mode, "easy_selections": easy_selections.duplicate()})

func current_selections() -> Dictionary:
	if input_mode == InputMode.EASY:
		return easy_selections
	return DesignModes.snap_to_easy(design, DataLoader.presets, DataLoader.engines, DataLoader.materials)["selections"]

func fit_part(part: String, id: String) -> Dictionary:
	var notice := ""
	var picks := current_selections().duplicate()
	if input_mode != InputMode.EASY:
		notice = "The bench only takes catalogue parts, so the rest of the rocket was matched to the nearest ones."
	picks[part] = id
	var candidate := _easy_design(picks)
	var old_cost := total_cost(design)
	var new_cost := total_cost(candidate)
	if not affordable(new_cost, old_cost):
		return {"ok": false, "notice": "PIKE: \"%s\"" % pike_line("over_budget", new_cost, old_cost)}
	design = candidate
	easy_selections = picks
	_set_input_mode(InputMode.EASY)
	refresh()
	return {"ok": true, "notice": notice}

func part_option(part: String, id: String) -> Dictionary:
	var picks := current_selections().duplicate()
	var fitted := str(picks.get(part, "")) == id
	picks[part] = id
	var cost := total_cost(_easy_design(picks))
	return {"cost": cost, "fitted": fitted, "affordable": fitted or affordable(cost, total_cost(design))}

func submit_deck(new_design: Dictionary) -> Dictionary:
	var old_cost := total_cost(design)
	var new_cost := total_cost(new_design)
	if not affordable(new_cost, old_cost):
		return {"ok": false, "notice": "DECK REJECTED BY ACCOUNTS. That rocket costs $%.1fM of $%.1fM. PIKE: \"%s\"" % [
				new_cost, budget_limit(), pike_line("over_budget", new_cost, old_cost)]}
	design = new_design.duplicate(true)
	_set_input_mode(InputMode.HARD)
	refresh()
	return {"ok": true, "notice": ""}

func with_extra_stage(d: Dictionary) -> Dictionary:
	var offered := DesignBuilder.upper_stage_specs(reference)
	if offered.is_empty():
		return d
	var next := clampi((d.get("stages", []) as Array).size() - 1, 0, offered.size() - 1)
	return DesignBuilder.add_upper_stage(d, offered[next], DataLoader.engines)

func launch_blocker() -> String:
	if (design.get("stages", []) as Array).is_empty():
		return "There is no rocket to launch."
	var spare := budget_limit() - total_cost(design)
	if spare < 0.0:
		return "Over budget by $%.1fM: the budget is $%.1fM now. Make the rocket cheaper to launch." % [-spare, budget_limit()]
	for check: Dictionary in report.get("checks", []):
		if str(check["id"]) == "liftoff" and str(check["status"]) == "fail":
			return str(check["plain"])
	return ""

func budget_limit() -> float:
	return GameState.budget if GameState.budget > 0.0 else float(level.get("budget", 0.0))

func cost_breakdown(d: Dictionary) -> Dictionary:
	return CostModel.design_cost(d, DataLoader.engines, DataLoader.materials, DataLoader.cost_model)

func total_cost(d: Dictionary) -> float:
	return float(cost_breakdown(d)["total"])

func affordable(new_cost: float, old_cost: float) -> bool:
	return new_cost <= budget_limit() + 0.0001 or new_cost <= old_cost + 0.0001

func pike_line(kind: String, cost: float, before_cost: float) -> String:
	var lines: Array = (DataLoader.raw.get("pike_lines", {}) as Dictionary).get(kind, [])
	if lines.is_empty():
		return "No."
	var budget := budget_limit()
	return str(lines[randi() % lines.size()]).replace("{cost}", "%.1f" % cost).replace("{budget}", "%.1f" % budget) \
			.replace("{over}", "%.1f" % maxf(cost - budget, 0.0)).replace("{left}", "%.1f" % maxf(budget - before_cost, 0.0))

func _easy_design(picks: Dictionary) -> Dictionary:
	var d := DesignBuilder.from_easy(picks, DataLoader.presets, DataLoader.engines,
			DesignModes.level_payload(level), DesignModes.level_mission(level))
	d["name"] = "Easy rocket"
	return d

func _set_input_mode(mode: int) -> void:
	input_mode = mode
	match mode:
		InputMode.MEDIUM:
			GameState.set_mode(GameState.Mode.ENGINEER)
		InputMode.HARD:
			GameState.set_mode(GameState.Mode.FLIGHT_DIRECTOR)
		_:
			GameState.set_mode(GameState.Mode.CADET)

func _input_mode_from_game_state() -> int:
	match GameState.mode:
		GameState.Mode.ENGINEER:
			return InputMode.MEDIUM
		GameState.Mode.FLIGHT_DIRECTOR:
			return InputMode.HARD
	return InputMode.EASY
