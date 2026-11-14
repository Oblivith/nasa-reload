# Code generated with AI assistance (Claude). Reviewed by team.
extends Node
## Loads all JSON game data from /data into dictionaries (autoload "DataLoader").
## Every list of entries is indexed by its "id" field. Data only; no sim or UI logic.

signal data_loaded

const DATA_DIR := "res://data/"
const FILES: Array[String] = [
	"engines", "tanks", "orbits", "power",
	"instruments", "comms", "structures", "levels",
]

## file name -> full parsed JSON Dictionary (includes "comment" and "notes").
var raw: Dictionary = {}

## category name -> { id -> entry Dictionary }.
## Categories: engines, propellant_types, tank_sizes, orbits, solar_panels, batteries,
## fuel_cells, instruments, radios, ground_stations, tape_recorders, heat_shields,
## structures (fairing, interstage, escape_tower), levels.
var tables: Dictionary = {}

## Convenience aliases into `tables`.
var engines: Dictionary = {}
var propellant_types: Dictionary = {}
var tank_sizes: Dictionary = {}
var orbits: Dictionary = {}
var solar_panels: Dictionary = {}
var batteries: Dictionary = {}
var fuel_cells: Dictionary = {}
var instruments: Dictionary = {}
var radios: Dictionary = {}
var ground_stations: Dictionary = {}
var tape_recorders: Dictionary = {}
var heat_shields: Dictionary = {}
var structures: Dictionary = {}
var levels: Dictionary = {}

var loaded: bool = false


func _ready() -> void:
	load_all()


func load_all() -> void:
	raw.clear()
	tables.clear()
	for file_name in FILES:
		var parsed := _load_json(DATA_DIR + file_name + ".json")
		raw[file_name] = parsed
	_index_all()
	loaded = true
	_print_summary()
	data_loaded.emit()


func _print_summary() -> void:
	var total := 0
	print("DataLoader: loaded %d data files" % raw.size())
	for category in tables:
		var count: int = tables[category].size()
		total += count
		print("  %s %d" % [String(category).rpad(18), count])
	print("DataLoader: %d entries total" % total)


## Returns the entry with `id` in `category`, or an empty Dictionary if missing.
func get_entry(category: String, id: String) -> Dictionary:
	return tables.get(category, {}).get(id, {})


## Returns the whole { id -> entry } table for a category.
func get_table(category: String) -> Dictionary:
	return tables.get(category, {})


## Returns the first line of the top-level "comment" for a data file.
func get_comment(file_name: String) -> String:
	return str(raw.get(file_name, {}).get("comment", ""))


func _index_all() -> void:
	var tanks: Dictionary = raw.get("tanks", {})
	var power: Dictionary = raw.get("power", {})
	var comms: Dictionary = raw.get("comms", {})
	var structs: Dictionary = raw.get("structures", {})

	tables["engines"] = _index(raw.get("engines", {}).get("engines", []))
	tables["propellant_types"] = _index(tanks.get("propellant_types", []))
	tables["tank_sizes"] = _index(tanks.get("sizes", []))
	tables["orbits"] = _index(raw.get("orbits", {}).get("orbits", []))
	tables["solar_panels"] = _index(power.get("solar_panels", []))
	tables["batteries"] = _index(power.get("batteries", []))
	tables["fuel_cells"] = _index(power.get("fuel_cells", []))
	tables["instruments"] = _index(raw.get("instruments", {}).get("instruments", []))
	tables["radios"] = _index(comms.get("radios", []))
	tables["ground_stations"] = _index(comms.get("ground_stations", []))
	tables["tape_recorders"] = _index(comms.get("tape_recorders", []))
	tables["heat_shields"] = _index(structs.get("heat_shields", []))
	tables["levels"] = _index(raw.get("levels", {}).get("levels", []))

	var struct_entries: Array = []
	for key in ["fairing", "interstage", "escape_tower"]:
		if structs.has(key):
			struct_entries.append(structs[key])
	tables["structures"] = _index(struct_entries)

	engines = tables["engines"]
	propellant_types = tables["propellant_types"]
	tank_sizes = tables["tank_sizes"]
	orbits = tables["orbits"]
	solar_panels = tables["solar_panels"]
	batteries = tables["batteries"]
	fuel_cells = tables["fuel_cells"]
	instruments = tables["instruments"]
	radios = tables["radios"]
	ground_stations = tables["ground_stations"]
	tape_recorders = tables["tape_recorders"]
	heat_shields = tables["heat_shields"]
	structures = tables["structures"]
	levels = tables["levels"]


func _index(entries: Array) -> Dictionary:
	var result: Dictionary = {}
	for entry in entries:
		if entry is Dictionary and entry.has("id"):
			result[str(entry["id"])] = entry
		else:
			push_warning("DataLoader: entry without an 'id' skipped: %s" % str(entry))
	return result


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("DataLoader: missing data file %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DataLoader: cannot open %s (error %d)" % [path, FileAccess.get_open_error()])
		return {}
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_error("DataLoader: JSON error in %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	if json.data is Dictionary:
		return json.data
	push_error("DataLoader: %s must contain a JSON object at the top level" % path)
	return {}
