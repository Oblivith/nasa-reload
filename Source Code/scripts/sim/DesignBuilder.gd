# SI assistance metadata: This code used the help of SI.
class_name DesignBuilder
extends RefCounted

const DEFAULT_PROPELLANT_DENSITY := 1000.0
const DEFAULT_ULLAGE := 1.1

static func tank_length(propellant_mass_kg: float, density_kg_m3: float, ullage_factor: float, diameter_m: float) -> float:
	if density_kg_m3 <= 0.0 or diameter_m <= 0.0:
		return 0.0
	return propellant_mass_kg * ullage_factor / (density_kg_m3 * PI * diameter_m * diameter_m / 4.0)

static func resolve_engine(spec: Dictionary, engines: Dictionary) -> Dictionary:
	var engine: Dictionary = {}
	var engine_id: Variant = spec.get("engine_id", null)
	if engine_id != null and engines.has(str(engine_id)):
		engine = (engines[str(engine_id)] as Dictionary).duplicate(true)
	for key in spec:
		engine[key] = spec[key]
	if not engine.has("count"):
		engine["count"] = 1
	return engine

static func add_upper_stage(design: Dictionary, upper: Dictionary, engines: Dictionary) -> Dictionary:
	var result := design.duplicate(true)
	var stages: Array = result.get("stages", [])
	var below: Dictionary = (stages[stages.size() - 1] as Dictionary).get("body", {}) if not stages.is_empty() else {}
	var spec_body: Dictionary = upper.get("body", {})
	var body := {}
	for key in spec_body:
		body[key] = spec_body[key]
	if not body.has("diameter_m"):
		body["diameter_m"] = float(below.get("diameter_m", 0.0))
	if not body.has("material"):
		body["material"] = str(below.get("material", ""))
	if not body.has("length_m"):
		body["length_m"] = tank_length(float(body.get("propellant_mass_kg", 0.0)),
				float(body.get("propellant_density_kg_m3", DEFAULT_PROPELLANT_DENSITY)),
				float(body.get("ullage_factor", DEFAULT_ULLAGE)), float(body["diameter_m"]))
	stages.append({"body": body, "engine": resolve_engine(upper.get("engine", {}), engines)})
	result["stages"] = stages
	return result

static func without_upper_stages(design: Dictionary) -> Dictionary:
	var result := design.duplicate(true)
	var stages: Array = result.get("stages", [])
	if stages.size() > 1:
		result["stages"] = [stages[0]]
	return result

static func from_easy(selections: Dictionary, presets: Dictionary, engines: Dictionary,
		payload: Dictionary, mission: Dictionary) -> Dictionary:
	var nose: Dictionary = _preset(presets, "nose", selections)
	var body: Dictionary = _preset(presets, "body", selections)
	var fins: Dictionary = _preset(presets, "fins", selections)
	var engine_preset: Dictionary = _preset(presets, "engine", selections)
	var material: Dictionary = _preset(presets, "material", selections)
	var diameter := float(body.get("diameter_m", 0.0))

	var fin_set := {}
	for key in ["count", "root_chord_m", "tip_chord_m", "span_m", "sweep_m", "position_from_tail_m", "mass_kg"]:
		if fins.has(key):
			fin_set[key] = fins[key]

	var design := {
		"name": "Easy: %s" % ", ".join(PackedStringArray(selections.values().map(func(v): return str(v)))),
		"nose": {
			"shape": str(nose.get("shape", "cone")),
			"length_m": float(nose.get("length_to_diameter", 1.0)) * diameter,
		},
		"payload": payload.duplicate(),
		"stages": [{
			"body": {
				"length_m": float(body.get("length_m", 0.0)),
				"diameter_m": diameter,
				"material": str(material.get("material", "")),
				"propellant_mass_kg": float(body.get("propellant_mass_kg", 0.0)),
			},
			"engine": resolve_engine({
				"engine_id": engine_preset.get("engine_id", null),
				"count": engine_preset.get("count", 1),
				"section_length_m": engine_preset.get("section_length_m", 0.0),
			}, engines),
		}],
		"fins": fin_set,
		"options": {"gimballed": false},
		"mission": mission.duplicate(),
	}

	var upper: Dictionary = _preset(presets, "upper_stage", selections)
	if not upper.is_empty() and upper.get("engine_id", null) != null:
		design = add_upper_stage(design, {
			"body": {
				"propellant_mass_kg": upper.get("propellant_mass_kg", 0.0),
				"dry_mass_kg": upper.get("dry_mass_kg", 0.0),
				"propellant_density_kg_m3": upper.get("propellant_density_kg_m3", DEFAULT_PROPELLANT_DENSITY),
				"ullage_factor": upper.get("ullage_factor", DEFAULT_ULLAGE),
			},
			"engine": {
				"engine_id": upper["engine_id"],
				"count": upper.get("count", 1),
				"section_length_m": upper.get("section_length_m", 0.0),
			},
		}, engines)
	return design

static func slider_to_value(slider: float, reference_value: float, min_factor: float, max_factor: float) -> float:
	var s := clampf(slider, 0.0, 1.0)
	if s <= 0.5:
		return lerpf(reference_value * min_factor, reference_value, s / 0.5)
	return lerpf(reference_value, reference_value * max_factor, (s - 0.5) / 0.5)

static func value_to_slider(value: float, reference_value: float, min_factor: float, max_factor: float) -> float:
	if reference_value == 0.0:
		return 0.5
	var ratio := value / reference_value
	if ratio <= 1.0:
		return clampf(0.5 * (ratio - min_factor) / (1.0 - min_factor), 0.0, 0.5)
	return clampf(0.5 + 0.5 * (ratio - 1.0) / (max_factor - 1.0), 0.5, 1.0)

static func from_sliders(reference: Dictionary, sliders: Dictionary, engines: Dictionary,
		with_upper_stage: bool) -> Dictionary:
	var design: Dictionary = (reference.get("design", {}) as Dictionary).duplicate(true)
	var uppers := upper_stage_specs(reference)
	if with_upper_stage:
		for upper: Dictionary in uppers:
			design = add_upper_stage(design, upper, engines)
	var reference_design := design.duplicate(true)
	var slider_range: Dictionary = reference.get("slider_range", {})
	var min_factor := float(slider_range.get("min_factor", 0.5))
	var max_factor := float(slider_range.get("max_factor", 2.0))
	for path in sliders:
		var ref_value: Variant = _get_path(reference_design, str(path))
		if ref_value == null:
			push_warning("DesignBuilder: unknown slider path %s" % path)
			continue
		_set_path(design, str(path), slider_to_value(float(sliders[path]), float(ref_value), min_factor, max_factor))
	if with_upper_stage:
		var stages: Array = design["stages"]
		for i in uppers.size():
			if not (uppers[i].get("body", {}) as Dictionary).has("length_m") and not sliders.has("stages/%d/body/length_m" % (i + 1)):
				recompute_tank_length((stages[i + 1] as Dictionary)["body"])
	return design

static func upper_stage_specs(reference: Dictionary) -> Array:
	var result: Array = []
	for spec in reference.get("optional_upper_stages", []):
		result.append(spec)
	var single: Dictionary = reference.get("optional_upper_stage", {})
	if result.is_empty() and not single.is_empty():
		result.append(single)
	return result

static func upper_stages_default_on(reference: Dictionary) -> bool:
	var specs := upper_stage_specs(reference)
	return not specs.is_empty() and bool((specs[0] as Dictionary).get("enabled_by_default", false))

static func recompute_tank_length(body: Dictionary) -> void:
	body["length_m"] = tank_length(float(body.get("propellant_mass_kg", 0.0)),
			float(body.get("propellant_density_kg_m3", DEFAULT_PROPELLANT_DENSITY)),
			float(body.get("ullage_factor", DEFAULT_ULLAGE)), float(body.get("diameter_m", 0.0)))

static func _preset(presets: Dictionary, part: String, selections: Dictionary) -> Dictionary:
	if not selections.has(part):
		return {}
	var table: Dictionary = presets.get(part, {})
	var id := str(selections[part])
	if not table.has(id):
		push_warning("DesignBuilder: unknown %s preset '%s'" % [part, id])
		return {}
	return table[id]

static func _get_path(root: Variant, path: String) -> Variant:
	var node: Variant = root
	for key in path.split("/"):
		if node is Dictionary and (node as Dictionary).has(key):
			node = node[key]
		elif node is Array and key.is_valid_int() and int(key) < (node as Array).size():
			node = node[int(key)]
		else:
			return null
	return node

static func _set_path(root: Variant, path: String, value: Variant) -> void:
	var keys := path.split("/")
	var node: Variant = root
	for i in keys.size() - 1:
		var key := keys[i]
		node = node[int(key)] if node is Array else node[key]
	var last := keys[keys.size() - 1]
	if node is Array:
		node[int(last)] = value
	else:
		node[last] = value
