# Code generated with AI assistance (Claude). Reviewed by team.
class_name RocketGeometry
extends RefCounted
## Turns a design (real units) into a stacked list of segments with mass, length and
## position measured from the nose tip (Sim Spec v2, section 1). Pure data, no UI.
##
## Design format (metres, kg, newtons, seconds):
##   nose:    {shape, length_m, mass_kg?}
##   payload: {length_m, mass_kg}
##   stages:  [ {body: {length_m, diameter_m, material, propellant_mass_kg, dry_mass_kg?},
##               engine: {section_length_m, mass_kg, count?, thrust_sl_N, thrust_vac_N,
##                        isp_sl, isp_vac}} ]      firing order: index 0 = first stage
##   fins:    {count, root_chord_m, tip_chord_m, span_m, sweep_m, position_from_tail_m, mass_kg}
##   options: {gimballed, escape_tower: {length_m, mass_kg}}
##
## Stack order from the nose tip down: nose, payload, stages (last stage on top), with
## the fins on the first stage. An escape tower sits above the nose tip (negative x):
## its mass counts, its aerodynamics do not.
## Masses left out (nose mass, body dry mass) are derived from the material's areal density.

const DEFAULT_NOSE_CG_FRACTION := 0.6


## Wall area of a cylindrical body: pi * d * L.
static func body_wall_area(diameter: float, length: float) -> float:
	return PI * diameter * length


## Dry structure mass = wall area * material areal density (spec section 1).
static func body_dry_mass(diameter: float, length: float, material: Dictionary) -> float:
	return body_wall_area(diameter, length) * float(material.get("areal_density_kg_m2", 0.0))


## Nose shell mass from the lateral area of a cone of the same size: pi * R * slant,
## times the material's areal density, times areal_factor. A nose fairing carries no
## tank pressure, bulkheads or plumbing, so it is much lighter per square metre than a
## tank wall (factor from nose_shapes.json "nose_mass_model").
static func nose_shell_mass(diameter: float, length: float, material: Dictionary, areal_factor: float = 1.0) -> float:
	var radius := diameter / 2.0
	var slant := sqrt(radius * radius + length * length)
	return PI * radius * slant * float(material.get("areal_density_kg_m2", 0.0)) * areal_factor


## Builds the segment list. `materials` and `nose_shapes` are { id -> entry } tables.
## Returns:
##   segments: [{kind, name, stage, x_top_m, length_m, diameter_m, dry_mass_kg,
##               propellant_mass_kg, cg_x_m}]
##   length_m (nose tip to tail), diameter_m (first-stage body: the reference calibre),
##   max_diameter_m, fin_root_le_x_m, dry_mass_kg, propellant_mass_kg, liftoff_mass_kg
## nose_areal_factor scales the derived nose mass (see nose_shell_mass).
static func build(design: Dictionary, materials: Dictionary = {}, nose_shapes: Dictionary = {}, nose_areal_factor: float = 1.0) -> Dictionary:
	var segments: Array = []
	var stages: Array = design.get("stages", [])
	var options: Dictionary = design.get("options", {})

	var ref_diameter := 0.0
	var top_diameter := 0.0
	var max_diameter := 0.0
	var top_material: Dictionary = {}
	if not stages.is_empty():
		var first_body: Dictionary = (stages[0] as Dictionary).get("body", {})
		var top_body: Dictionary = (stages[stages.size() - 1] as Dictionary).get("body", {})
		ref_diameter = float(first_body.get("diameter_m", 0.0))
		top_diameter = float(top_body.get("diameter_m", ref_diameter))
		top_material = materials.get(str(top_body.get("material", "")), {})
		for stage: Dictionary in stages:
			var stage_body: Dictionary = stage.get("body", {})
			max_diameter = maxf(max_diameter, float(stage_body.get("diameter_m", 0.0)))

	# Escape tower: above the nose tip, so it sits at negative x.
	var tower: Dictionary = options.get("escape_tower", {})
	if float(tower.get("mass_kg", 0.0)) > 0.0:
		var tower_length := float(tower.get("length_m", 0.0))
		segments.append(_segment("escape_tower", "Escape tower", -1, -tower_length, tower_length,
				0.0, float(tower["mass_kg"]), 0.0, -tower_length / 2.0))

	var x := 0.0

	var nose: Dictionary = design.get("nose", {})
	var nose_length := float(nose.get("length_m", 0.0))
	var nose_shape: Dictionary = nose_shapes.get(str(nose.get("shape", "")), {})
	var nose_mass := float(nose.get("mass_kg", -1.0))
	if nose_mass < 0.0:
		nose_mass = nose_shell_mass(top_diameter, nose_length, top_material, nose_areal_factor)
	var nose_cg := float(nose_shape.get("cg_fraction", DEFAULT_NOSE_CG_FRACTION))
	segments.append(_segment("nose", "Nose cone", -1, x, nose_length, top_diameter,
			nose_mass, 0.0, x + nose_cg * nose_length))
	x += nose_length

	var payload: Dictionary = design.get("payload", {})
	var payload_length := float(payload.get("length_m", 0.0))
	var payload_mass := float(payload.get("mass_kg", 0.0))
	if payload_length > 0.0 or payload_mass > 0.0:
		segments.append(_segment("payload", "Payload section", -1, x, payload_length, top_diameter,
				payload_mass, 0.0, x + payload_length / 2.0))
		x += payload_length

	# Stages from the top of the stack down: the last stage to fire sits highest.
	for i in range(stages.size() - 1, -1, -1):
		var stage: Dictionary = stages[i]
		var body: Dictionary = stage.get("body", {})
		var engine: Dictionary = stage.get("engine", {})
		var diameter := float(body.get("diameter_m", ref_diameter))
		var body_length := float(body.get("length_m", 0.0))
		var material: Dictionary = materials.get(str(body.get("material", "")), {})
		var dry := float(body.get("dry_mass_kg", -1.0))
		if dry < 0.0:
			dry = body_dry_mass(diameter, body_length, material)
		segments.append(_segment("body", "Stage %d tanks" % (i + 1), i, x, body_length, diameter,
				dry, float(body.get("propellant_mass_kg", 0.0)), x + body_length / 2.0))
		x += body_length

		var engine_length := float(engine.get("section_length_m", 0.0))
		var engine_mass := float(engine.get("mass_kg", 0.0)) * float(engine.get("count", 1))
		segments.append(_segment("engine", "Stage %d engine section" % (i + 1), i, x, engine_length,
				diameter, engine_mass, 0.0, x + engine_length / 2.0))
		x += engine_length

	var total_length := x

	# Fins hang off the first stage. Their mass sits at the middle of the root chord.
	var fins: Dictionary = design.get("fins", {})
	var fin_root_le_x := total_length
	if int(fins.get("count", 0)) > 0 and float(fins.get("span_m", 0.0)) > 0.0:
		var root := float(fins.get("root_chord_m", 0.0))
		fin_root_le_x = total_length - float(fins.get("position_from_tail_m", 0.0)) - root
		segments.append(_segment("fins", "Fins", 0, fin_root_le_x, root, ref_diameter,
				float(fins.get("mass_kg", 0.0)), 0.0, fin_root_le_x + root / 2.0))

	var dry_total := 0.0
	var propellant_total := 0.0
	for segment: Dictionary in segments:
		dry_total += float(segment["dry_mass_kg"])
		propellant_total += float(segment["propellant_mass_kg"])

	return {
		"segments": segments,
		"length_m": total_length,
		"diameter_m": ref_diameter,
		"max_diameter_m": max_diameter,
		"fin_root_le_x_m": fin_root_le_x,
		"dry_mass_kg": dry_total,
		"propellant_mass_kg": propellant_total,
		"liftoff_mass_kg": dry_total + propellant_total,
	}


## Total mass and centre of mass with the propellant of the listed stages burned off.
## `empty_stages` holds stage indices whose tanks are empty ([] = liftoff, [0] = first
## stage burnout). Returns {"mass_kg", "x_cg_m"}.
static func mass_and_cg(segments: Array, empty_stages: Array = []) -> Dictionary:
	var mass := 0.0
	var moment := 0.0
	for segment: Dictionary in segments:
		var m := float(segment["dry_mass_kg"])
		if not empty_stages.has(int(segment["stage"])):
			m += float(segment["propellant_mass_kg"])
		mass += m
		moment += m * float(segment["cg_x_m"])
	return {"mass_kg": mass, "x_cg_m": moment / mass if mass > 0.0 else 0.0}


## Per-stage masses for the rocket equation, in firing order:
## [{"dry_mass_kg", "propellant_mass_kg"}]. Fins count as first-stage dry mass.
static func stage_masses(segments: Array, stage_count: int) -> Array:
	var result: Array = []
	for i in stage_count:
		result.append({"dry_mass_kg": 0.0, "propellant_mass_kg": 0.0})
	for segment: Dictionary in segments:
		var index := int(segment["stage"])
		if index < 0 or index >= stage_count:
			continue
		var entry: Dictionary = result[index]
		entry["dry_mass_kg"] = float(entry["dry_mass_kg"]) + float(segment["dry_mass_kg"])
		entry["propellant_mass_kg"] = float(entry["propellant_mass_kg"]) + float(segment["propellant_mass_kg"])
	return result


## Mass that every stage carries all the way: nose, payload and escape tower.
## (The tower is treated as carried throughout; jettison is left to the launch sim.)
static func payload_mass(segments: Array) -> float:
	var mass := 0.0
	for segment: Dictionary in segments:
		if int(segment["stage"]) < 0:
			mass += float(segment["dry_mass_kg"])
	return mass


static func _segment(kind: String, segment_name: String, stage: int, x_top: float, length: float,
		diameter: float, dry_mass: float, propellant_mass: float, cg_x: float) -> Dictionary:
	return {
		"kind": kind,
		"name": segment_name,
		"stage": stage,
		"x_top_m": x_top,
		"length_m": length,
		"diameter_m": diameter,
		"dry_mass_kg": dry_mass,
		"propellant_mass_kg": propellant_mass,
		"cg_x_m": cg_x,
	}
