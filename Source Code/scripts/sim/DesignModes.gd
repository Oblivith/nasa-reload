# SI assistance metadata: This code used the help of SI.
class_name DesignModes
extends RefCounted

static func level_payload(level: Dictionary) -> Dictionary:
	return {
		"length_m": float(level.get("payload_length_m", 1.0)),
		"mass_kg": float(level.get("payload_mass_kg", 0.0)),
	}

static func level_mission(level: Dictionary) -> Dictionary:
	var mission: Dictionary = (level.get("mission", {}) as Dictionary).duplicate(true)
	mission.erase("note")
	var site: Dictionary = level.get("launch_site", {})
	if not mission.has("latitude_deg"):
		mission["latitude_deg"] = float(site.get("latitude_deg", 0.0))
	if float(level.get("budget", 0.0)) > 0.0:
		mission["budget_musd"] = float(level["budget"])
	return mission

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

static func reference_values(reference: Dictionary, engines: Dictionary, slider_defs: Array) -> Dictionary:
	var stacked := DesignBuilder.from_sliders(reference, {}, engines, true)
	var values := {}
	for slider: Dictionary in slider_defs:
		for path in slider.get("paths", []):
			var value: Variant = path_get(stacked, str(path))
			if value != null:
				values[str(path)] = float(value)
	return values

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

	var nose_ld := float(nose.get("length_m", 0.0)) / maxf(diameter, 0.01)
	var best := _nearest(presets.get("nose", {}), func(p: Dictionary) -> float:
		return (0.0 if str(p.get("shape", "")) == str(nose.get("shape", "")) else 1.0) \
				+ absf(float(p.get("length_to_diameter", 1.0)) - nose_ld) / 3.0)
	selections["nose"] = best["id"]
	if best["score"] > 0.02:
		changed.append("nose")

	best = _nearest(presets.get("body", {}), func(p: Dictionary) -> float:
		return _rel(float(body.get("length_m", 0.0)), float(p.get("length_m", 1.0))) \
				+ _rel(diameter, float(p.get("diameter_m", 1.0))) \
				+ _rel(float(body.get("propellant_mass_kg", 0.0)), float(p.get("propellant_mass_kg", 1.0))))
	selections["body"] = best["id"]
	if best["score"] > 0.02 or body.has("dry_mass_kg"):
		changed.append("body")

	var thrust := _engine_thrust(engine) * float(engine.get("count", 1))
	best = _nearest(presets.get("engine", {}), func(p: Dictionary) -> float:
		var preset_engine: Dictionary = engines.get(str(p.get("engine_id", "")), {})
		var same := str(p.get("engine_id", "")) == str(engine.get("engine_id", ""))
		return _rel(thrust, _engine_thrust(preset_engine) * float(p.get("count", 1))) + (0.0 if same else 0.5))
	selections["engine"] = best["id"]
	if best["score"] > 0.02 or _engine_overridden(engine, engines):
		changed.append("engine")

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

static func path_erase(root: Variant, path: String) -> void:
	var parent_path := path.get_base_dir()
	var parent: Variant = root if parent_path == "" else path_get(root, parent_path)
	if parent is Dictionary:
		(parent as Dictionary).erase(path.get_file())

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
