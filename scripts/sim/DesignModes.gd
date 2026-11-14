# Code generated with AI assistance (Claude). Reviewed by team.
class_name DesignModes
extends RefCounted
## Conversions between the Rocket Builder's three input modes (Sim Spec v2, section 3).
## Pure data, no UI. The real-unit design is always the source of truth:
##   Easy -> Medium -> Hard: the design is kept as it is (nothing to convert).
##   Medium/Hard -> Easy: snap_to_easy() picks the nearest preset per part.
##   Any -> Medium: slider_positions() shows where each value sits on its slider.
## Also: the level's payload and mission, and the design's cost.


## Level payload in the RocketGeometry format (levels.json entry).
static func level_payload(level: Dictionary) -> Dictionary:
	return {
		"length_m": float(level.get("payload_length_m", 1.0)),
		"mass_kg": float(level.get("payload_mass_kg", 0.0)),
	}


## Level mission in the MissionBudget format: the level's "mission" block plus the
## launch site's latitude.
static func level_mission(level: Dictionary) -> Dictionary:
	var mission: Dictionary = (level.get("mission", {}) as Dictionary).duplicate(true)
	mission.erase("note")
	var site: Dictionary = level.get("launch_site", {})
	if not mission.has("latitude_deg"):
		mission["latitude_deg"] = float(site.get("latitude_deg", 0.0))
	return mission


## The reference rocket as a Medium-mode starting design for this level: every slider
## at 0.5, with the level's payload and mission. An escape tower is dropped when the
## level is uncrewed (it would only be dead weight).
static func reference_design(reference: Dictionary, engines: Dictionary, level: Dictionary,
		with_upper_stage: bool) -> Dictionary:
	var design := DesignBuilder.from_sliders(reference, {}, engines, with_upper_stage)
	design["name"] = str(reference.get("name", "Reference"))
	design["payload"] = level_payload(level)
	design["mission"] = level_mission(level)
	var options: Dictionary = design.get("options", {})
	if not bool(design["mission"].get("crewed", false)):
		options.erase("escape_tower")
	design["options"] = options
	return design


# --- Medium: slider positions ------------------------------------------------------------

## Reference value at every path the Medium sliders use (upper-stage paths only exist
## when the reference has an optional upper stage).
static func reference_values(reference: Dictionary, engines: Dictionary, slider_defs: Array) -> Dictionary:
	var stacked := DesignBuilder.from_sliders(reference, {}, engines, true)
	var values := {}
	for slider: Dictionary in slider_defs:
		for path in slider.get("paths", []):
			var value: Variant = path_get(stacked, str(path))
			if value != null:
				values[str(path)] = float(value)
	return values


## For each slider def: {id -> {slider: 0..1, value, reference, in_range: bool}}, read
## from the design's first path. A value outside min..max factor is "out of range":
## its slider sits at the end but the design keeps the real value.
static func slider_positions(design: Dictionary, slider_defs: Array, ref_values: Dictionary,
		min_factor: float, max_factor: float) -> Dictionary:
	var result := {}
	for slider: Dictionary in slider_defs:
		var paths: Array = slider.get("paths", [])
		if paths.is_empty():
			continue
		var path := str(paths[0])
		var ref := float(ref_values.get(path, 0.0))
		var raw: Variant = path_get(design, path)
		if raw == null:
			continue
		var value := float(raw)
		var in_range := true
		if ref > 0.0:
			var ratio := value / ref
			in_range = ratio >= min_factor - 0.0005 and ratio <= max_factor + 0.0005
		result[str(slider["id"])] = {
			"slider": DesignBuilder.value_to_slider(value, ref, min_factor, max_factor),
			"value": value,
			"reference": ref,
			"in_range": in_range,
		}
	return result


# --- Easy: snap to the nearest presets ---------------------------------------------------

## Nearest Easy preset for every part of a real-unit design.
## Returns {selections: {part -> id}, changed: [part names whose values move],
##          dropped: [plain notes on things Easy cannot hold (gimbal, tower, extra stages)]}.
static func snap_to_easy(design: Dictionary, presets: Dictionary, engines: Dictionary,
		materials: Dictionary) -> Dictionary:
	var stages: Array = design.get("stages", [])
	var first: Dictionary = stages[0] if not stages.is_empty() else {}
	var body: Dictionary = first.get("body", {})
	var engine: Dictionary = first.get("engine", {})
	var nose: Dictionary = design.get("nose", {})
	var fins: Dictionary = design.get("fins", {})
	var diameter := float(body.get("diameter_m", 1.0))
	var selections := {}
	var changed: Array = []
	var dropped: Array = []

	# Nose: shape first, then length-to-diameter ratio.
	var nose_ld := float(nose.get("length_m", 0.0)) / maxf(diameter, 0.01)
	var best := _nearest(presets.get("nose", {}), func(p: Dictionary) -> float:
		return (0.0 if str(p.get("shape", "")) == str(nose.get("shape", "")) else 1.0) \
				+ absf(float(p.get("length_to_diameter", 1.0)) - nose_ld) / 3.0)
	selections["nose"] = best["id"]
	if best["score"] > 0.02:
		changed.append("nose")

	# Body: length, diameter and fuel, each relative.
	best = _nearest(presets.get("body", {}), func(p: Dictionary) -> float:
		return _rel(float(body.get("length_m", 0.0)), float(p.get("length_m", 1.0))) \
				+ _rel(diameter, float(p.get("diameter_m", 1.0))) \
				+ _rel(float(body.get("propellant_mass_kg", 0.0)), float(p.get("propellant_mass_kg", 1.0))))
	selections["body"] = best["id"]
	if best["score"] > 0.02 or body.has("dry_mass_kg"):
		changed.append("body")

	# Engine: total sea-level thrust of the first stage, same engine type preferred.
	var thrust := _engine_thrust(engine) * float(engine.get("count", 1))
	best = _nearest(presets.get("engine", {}), func(p: Dictionary) -> float:
		var preset_engine: Dictionary = engines.get(str(p.get("engine_id", "")), {})
		var same := str(p.get("engine_id", "")) == str(engine.get("engine_id", ""))
		return _rel(thrust, _engine_thrust(preset_engine) * float(p.get("count", 1))) + (0.0 if same else 0.5))
	selections["engine"] = best["id"]
	if best["score"] > 0.02 or _engine_overridden(engine, engines):
		changed.append("engine")

	# Fins: root chord and span.
	if int(fins.get("count", 0)) <= 0:
		best = _nearest(presets.get("fins", {}), func(p: Dictionary) -> float: return float(p.get("span_m", 0.0)))
		selections["fins"] = best["id"]
		changed.append("fins")
	else:
		best = _nearest(presets.get("fins", {}), func(p: Dictionary) -> float:
			return _rel(float(fins.get("root_chord_m", 0.0)), float(p.get("root_chord_m", 1.0))) \
					+ _rel(float(fins.get("span_m", 0.0)), float(p.get("span_m", 1.0))) \
					+ _rel(float(fins.get("tip_chord_m", 0.0)), float(p.get("tip_chord_m", 1.0))) * 0.5 \
					+ (0.0 if int(fins.get("count", 0)) == int(p.get("count", 4)) else 0.5))
		selections["fins"] = best["id"]
		if best["score"] > 0.02:
			changed.append("fins")

	# Material: same id if a preset uses it, else the nearest areal density.
	var material_id := str(body.get("material", ""))
	var density := float((materials.get(material_id, {}) as Dictionary).get("areal_density_kg_m2", 0.0))
	best = _nearest(presets.get("material", {}), func(p: Dictionary) -> float:
		if str(p.get("material", "")) == material_id:
			return 0.0
		var other := float((materials.get(str(p.get("material", "")), {}) as Dictionary).get("areal_density_kg_m2", 0.0))
		return 1.0 + absf(other - density))
	selections["material"] = best["id"]
	if best["score"] > 0.0:
		changed.append("material")

	# Upper stage: none, or the nearest fuel load.
	if stages.size() <= 1:
		best = _nearest(presets.get("upper_stage", {}), func(p: Dictionary) -> float:
			return 0.0 if p.get("engine_id", null) == null else 1.0)
		selections["upper_stage"] = best["id"]
	else:
		var upper_body: Dictionary = (stages[1] as Dictionary).get("body", {})
		var upper_prop := float(upper_body.get("propellant_mass_kg", 0.0))
		best = _nearest(presets.get("upper_stage", {}), func(p: Dictionary) -> float:
			if p.get("engine_id", null) == null:
				return 100.0
			return _rel(upper_prop, float(p.get("propellant_mass_kg", 1.0))))
		selections["upper_stage"] = best["id"]
		if best["score"] > 0.02:
			changed.append("upper_stage")
		if stages.size() > 2:
			dropped.append("Easy mode holds one upper stage; the extra stages were removed.")

	var options: Dictionary = design.get("options", {})
	if bool(options.get("gimballed", false)):
		dropped.append("Easy rockets have fixed engines, so the steerable (gimballed) engine was switched off.")
	if float((options.get("escape_tower", {}) as Dictionary).get("mass_kg", 0.0)) > 0.0:
		dropped.append("Easy mode has no escape tower, so it was removed.")
	return {"selections": selections, "changed": changed, "dropped": dropped}


# --- Cost --------------------------------------------------------------------------------

## Design cost in millions of USD: engines + body walls + fins + options.
## Returns {total, items: [{label, cost}]}.
static func design_cost(design: Dictionary, engines: Dictionary, materials: Dictionary,
		cost_model: Dictionary) -> Dictionary:
	var items: Array = []
	var stages: Array = design.get("stages", [])
	var engine_total := 0
	for i in stages.size():
		var stage: Dictionary = stages[i]
		var engine: Dictionary = stage.get("engine", {})
		var body: Dictionary = stage.get("body", {})
		var count := int(engine.get("count", 1))
		engine_total += count
		var entry: Dictionary = engines.get(str(engine.get("engine_id", "")), {})
		var unit_cost := float(entry.get("cost", cost_model.get("custom_engine_cost", 3.0)))
		items.append({"label": "Stage %d engines (%d x $%.1fM)" % [i + 1, count, unit_cost], "cost": unit_cost * count})
		var material: Dictionary = materials.get(str(body.get("material", "")), {})
		var wall := RocketGeometry.body_wall_area(float(body.get("diameter_m", 0.0)), float(body.get("length_m", 0.0)))
		items.append({"label": "Stage %d tanks (%.0f m2 %s)" % [i + 1, wall, str(material.get("name", "?"))],
				"cost": wall * float(material.get("cost_per_m2", 0.0))})
	var fins: Dictionary = design.get("fins", {})
	var fin_area := Aero.fin_planform_area(int(fins.get("count", 0)), float(fins.get("root_chord_m", 0.0)),
			float(fins.get("tip_chord_m", 0.0)), float(fins.get("span_m", 0.0)))
	if fin_area > 0.0:
		items.append({"label": "Fins (%.1f m2)" % fin_area, "cost": fin_area * float(cost_model.get("fin_cost_per_m2", 0.0))})
	var options: Dictionary = design.get("options", {})
	if bool(options.get("gimballed", false)):
		items.append({"label": "Gimbal mounts", "cost": engine_total * float(cost_model.get("gimbal_cost_per_engine", 0.0))})
	if float((options.get("escape_tower", {}) as Dictionary).get("mass_kg", 0.0)) > 0.0:
		items.append({"label": "Escape tower", "cost": float(cost_model.get("escape_tower_cost", 0.0))})
	var total := 0.0
	for item: Dictionary in items:
		total += float(item["cost"])
	return {"total": total, "items": items}


# --- Paths -------------------------------------------------------------------------------

## Reads "a/b/0/c" from nested dictionaries/arrays; null if missing.
static func path_get(root: Variant, path: String) -> Variant:
	var node: Variant = root
	for key in path.split("/"):
		if node is Dictionary and (node as Dictionary).has(key):
			node = node[key]
		elif node is Array and key.is_valid_int() and int(key) < (node as Array).size():
			node = node[int(key)]
		else:
			return null
	return node


## Writes "a/b/0/c", creating missing dictionaries on the way. Returns false if an
## array index is missing.
static func path_set(root: Variant, path: String, value: Variant) -> bool:
	var keys := path.split("/")
	var node: Variant = root
	for i in keys.size() - 1:
		var key := keys[i]
		if node is Array:
			if not key.is_valid_int() or int(key) >= (node as Array).size():
				return false
			node = node[int(key)]
		else:
			if not (node as Dictionary).has(key) or not (node[key] is Dictionary or node[key] is Array):
				node[key] = {}
			node = node[key]
	var last := keys[keys.size() - 1]
	if node is Array:
		if not last.is_valid_int() or int(last) >= (node as Array).size():
			return false
		node[int(last)] = value
	else:
		node[last] = value
	return true


## Removes the last key of a path (used for "auto" fields in Hard mode).
static func path_erase(root: Variant, path: String) -> void:
	var parent_path := path.get_base_dir()
	var parent: Variant = root if parent_path == "" else path_get(root, parent_path)
	if parent is Dictionary:
		(parent as Dictionary).erase(path.get_file())


# --- Helpers -----------------------------------------------------------------------------

static func _nearest(table: Dictionary, score: Callable) -> Dictionary:
	var best_id := ""
	var best_score := INF
	for id in table:
		var s := float(score.call(table[id]))
		if s < best_score:
			best_score = s
			best_id = str(id)
	return {"id": best_id, "score": best_score}


static func _rel(value: float, target: float) -> float:
	if target == 0.0:
		return absf(value)
	return absf(value - target) / absf(target)


static func _engine_thrust(engine: Dictionary) -> float:
	var value: Variant = engine.get("thrust_sl_N", 0.0)
	if value == null:
		value = engine.get("thrust_vac_N", 0.0)
	return float(value) if value != null else 0.0


## True if a Hard-mode player typed over the engine's table numbers.
static func _engine_overridden(engine: Dictionary, engines: Dictionary) -> bool:
	var entry: Dictionary = engines.get(str(engine.get("engine_id", "")), {})
	if entry.is_empty():
		return true
	for key in ["thrust_sl_N", "thrust_vac_N", "isp_sl", "isp_vac", "mass_kg"]:
		var a: Variant = engine.get(key, null)
		var b: Variant = entry.get(key, null)
		if (a == null) != (b == null):
			return true
		if a != null and absf(float(a) - float(b)) > 0.001 * maxf(1.0, absf(float(b))):
			return true
	return false
