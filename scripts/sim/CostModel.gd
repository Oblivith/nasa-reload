# Code generated with AI assistance (Claude). Reviewed by team.
class_name CostModel
extends RefCounted
## What a rocket costs, in millions of USD (the unit of a level's budget). Pure data,
## no UI. Coefficients come from data/costs.json ("cost_model"):
##   engines:  unit cost x count x (thrust / catalogue thrust) ^ engine_thrust_exponent,
##             thrust = sea-level or vacuum, whichever is raised more against the catalogue
##             unit cost = the engine's own "cost", else engines.json, else custom_engine_cost.
##             catalogue thrust = the engine's "cost_thrust_N", else its engines.json thrust_vac.
##   tanks:    wall area (pi * d * L) x the material's cost_per_m2 (materials.json)
##   fins:     planform area x fin_cost_per_m2
##   gimbal:   first-stage engine count x gimbal_cost_per_engine
##   tower:    escape_tower_cost


## Returns {total, items: [{id, stage, label, cost}]}. ids: stage_N_engine, stage_N_tanks,
## fins, gimbal, escape_tower (stage -1 = not part of a stage).
static func design_cost(design: Dictionary, engines: Dictionary, materials: Dictionary,
		cost_model: Dictionary) -> Dictionary:
	var items: Array = []
	var stages: Array = design.get("stages", [])
	var exponent := float(cost_model.get("engine_thrust_exponent", 1.0))
	for i in stages.size():
		var stage: Dictionary = stages[i]
		var engine: Dictionary = stage.get("engine", {})
		var body: Dictionary = stage.get("body", {})
		var count := int(engine.get("count", 1))
		var entry: Dictionary = engines.get(str(engine.get("engine_id", "")), {})
		var unit_cost := float(engine.get("cost", entry.get("cost", cost_model.get("custom_engine_cost", 3.0))))
		var scale := thrust_scale(engine, entry, exponent)
		items.append({"id": "stage_%d_engine" % i, "stage": i, "label": "Stage %d engines (%d x $%.2fM x %.2f)" % [i + 1, count, unit_cost, scale],
				"cost": unit_cost * count * scale})
		var material: Dictionary = materials.get(str(body.get("material", "")), {})
		var wall := RocketGeometry.body_wall_area(float(body.get("diameter_m", 0.0)), float(body.get("length_m", 0.0)))
		items.append({"id": "stage_%d_tanks" % i, "stage": i, "label": "Stage %d tanks (%.0f m2 %s)" % [i + 1, wall, str(material.get("name", "?"))],
				"cost": wall * float(material.get("cost_per_m2", 0.0))})
	var fins: Dictionary = design.get("fins", {})
	var fin_area := Aero.fin_planform_area(int(fins.get("count", 0)), float(fins.get("root_chord_m", 0.0)),
			float(fins.get("tip_chord_m", 0.0)), float(fins.get("span_m", 0.0)))
	if fin_area > 0.0:
		items.append({"id": "fins", "stage": 0, "label": "Fins (%.1f m2)" % fin_area, "cost": fin_area * float(cost_model.get("fin_cost_per_m2", 0.0))})
	var options: Dictionary = design.get("options", {})
	if bool(options.get("gimballed", false)) and not stages.is_empty():
		var first_count := int(((stages[0] as Dictionary).get("engine", {}) as Dictionary).get("count", 1))
		items.append({"id": "gimbal", "stage": 0, "label": "Gimbal mounts (%d)" % first_count,
				"cost": first_count * float(cost_model.get("gimbal_cost_per_engine", 0.0))})
	if float((options.get("escape_tower", {}) as Dictionary).get("mass_kg", 0.0)) > 0.0:
		items.append({"id": "escape_tower", "stage": -1, "label": "Escape tower", "cost": float(cost_model.get("escape_tower_cost", 0.0))})
	var total := 0.0
	for item: Dictionary in items:
		total += float(item["cost"])
	return {"total": total, "items": items}


## Bigger engines cost more: (thrust / catalogue thrust) ^ exponent, using whichever of
## sea-level and vacuum thrust is raised more. 1.0 when the engine is used at its
## catalogue thrust or nothing is known to compare with.
static func thrust_scale(engine: Dictionary, entry: Dictionary, exponent: float) -> float:
	var ratio := 0.0
	var vac_catalogue := _number(engine, "cost_thrust_N")
	if vac_catalogue <= 0.0:
		vac_catalogue = _number(entry, "thrust_vac_N")
	if _number(engine, "thrust_vac_N") > 0.0 and vac_catalogue > 0.0:
		ratio = _number(engine, "thrust_vac_N") / vac_catalogue
	var sl_catalogue := _number(entry, "thrust_sl_N")
	if _number(engine, "thrust_sl_N") > 0.0 and sl_catalogue > 0.0:
		ratio = maxf(ratio, _number(engine, "thrust_sl_N") / sl_catalogue)
	if ratio <= 0.0:
		return 1.0
	return pow(ratio, exponent)


static func _number(source: Dictionary, key: String) -> float:
	var value: Variant = source.get(key, 0.0)
	return float(value) if value != null else 0.0


## Total cost of the items belonging to one stage (its engines and tanks; stage 0 also
## carries the fins and gimbal).
static func stage_cost(cost: Dictionary, stage_index: int) -> float:
	var total := 0.0
	for item: Dictionary in cost.get("items", []):
		if int(item.get("stage", -1)) == stage_index:
			total += float(item["cost"])
	return total


## Cost of the items whose id is listed.
static func items_cost(cost: Dictionary, ids: Array) -> float:
	var total := 0.0
	for item: Dictionary in cost.get("items", []):
		if ids.has(str(item.get("id", ""))):
			total += float(item["cost"])
	return total


## Budget left after paying for a design, for the "budget left" score.
## Returns {cost_musd, budget_musd, left_musd, left_fraction, over, budget_star}.
## budget_star: at least cost_model.budget_star_min_left_fraction of the budget unspent.
static func budget_status(cost_musd: float, budget_musd: float, cost_model: Dictionary) -> Dictionary:
	var left := budget_musd - cost_musd
	var fraction := left / budget_musd if budget_musd > 0.0 else 0.0
	return {
		"cost_musd": cost_musd,
		"budget_musd": budget_musd,
		"left_musd": left,
		"left_fraction": fraction,
		"over": left < 0.0,
		"budget_star": fraction >= float(cost_model.get("budget_star_min_left_fraction", 0.0)),
	}


## How far a change can go before it breaks the budget. `cost_at` maps t in [0, 1]
## (0 = the design before the change, 1 = the full change) to a total cost. Returns the
## largest t whose cost fits `limit`: 1.0 if the whole change fits, 0.0 if none of it
## does. Assumes cost grows steadily along the change (true for every builder input).
static func affordable_fraction(cost_at: Callable, limit: float, iterations: int = 30) -> float:
	if float(cost_at.call(1.0)) <= limit:
		return 1.0
	if float(cost_at.call(0.0)) > limit:
		return 0.0
	var lo := 0.0
	var hi := 1.0
	for i in iterations:
		var mid := (lo + hi) / 2.0
		if float(cost_at.call(mid)) <= limit:
			lo = mid
		else:
			hi = mid
	return lo
