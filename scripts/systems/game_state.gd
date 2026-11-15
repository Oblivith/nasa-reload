# Code generated with AI assistance (Claude). Reviewed by team.
extends Node
## Global game state (autoload "GameState").
## Holds data only; no sim or UI logic. Content definitions live in /data JSON.

signal budget_changed(new_budget: float)
signal level_changed(new_level: String)
signal mode_changed(new_mode: Mode)
signal part_unlocked(part_id: String)
signal design_saved(design_name: String)
signal design_changed
signal flag_changed(flag: String, value: bool)

enum Mode { CADET, ENGINEER, FLIGHT_DIRECTOR }

var current_level: String = ""
var unlocked_parts: Array[String] = []
## design name -> serializable Dictionary (format defined by the sim layer later).
var saved_designs: Dictionary = {}
var budget: float = 0.0:
	set(value):
		budget = value
		budget_changed.emit(budget)
var mode: Mode = Mode.CADET

## The rocket on the Rocket Builder right now (real units, RocketEvaluator format),
## its latest evaluator report, and the builder's own UI state (Easy selections etc.).
var current_design: Dictionary = {}
var current_report: Dictionary = {}
var builder_state: Dictionary = {}

## Story progress switches (flag name -> bool), e.g. "dad_office_unlocked". World scenes
## read them (locked doors); story systems set them.
var story_flags: Dictionary = {}


func set_level(level_id: String) -> void:
	current_level = level_id
	level_changed.emit(level_id)


func set_mode(new_mode: Mode) -> void:
	mode = new_mode
	mode_changed.emit(mode)


func unlock_part(part_id: String) -> void:
	if part_id not in unlocked_parts:
		unlocked_parts.append(part_id)
		part_unlocked.emit(part_id)


func is_part_unlocked(part_id: String) -> bool:
	return part_id in unlocked_parts


func set_flag(flag: String, value: bool = true) -> void:
	if bool(story_flags.get(flag, false)) == value:
		return
	story_flags[flag] = value
	flag_changed.emit(flag, value)


func has_flag(flag: String) -> bool:
	return bool(story_flags.get(flag, false))


func set_design(design: Dictionary, report: Dictionary, state: Dictionary) -> void:
	current_design = design
	current_report = report
	builder_state = state
	design_changed.emit()


func save_design(design_name: String, design: Dictionary) -> void:
	saved_designs[design_name] = design
	design_saved.emit(design_name)


func to_dict() -> Dictionary:
	return {
		"current_level": current_level,
		"unlocked_parts": unlocked_parts,
		"saved_designs": saved_designs,
		"budget": budget,
		"mode": mode,
		"current_design": current_design,
		"builder_state": builder_state,
		"story_flags": story_flags,
	}


func from_dict(d: Dictionary) -> void:
	current_level = d.get("current_level", "")
	unlocked_parts.assign(d.get("unlocked_parts", []))
	saved_designs = d.get("saved_designs", {})
	budget = d.get("budget", 0.0)
	mode = d.get("mode", Mode.CADET)
	current_design = d.get("current_design", {})
	builder_state = d.get("builder_state", {})
	story_flags = d.get("story_flags", {})
