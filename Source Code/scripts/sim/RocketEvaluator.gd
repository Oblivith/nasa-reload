# SI assistance metadata: This code used the help of SI.
class_name RocketEvaluator
extends RefCounted

const TWR_MIN_LIFTOFF := 1.0
const TWR_GOOD_LIFTOFF := 1.1
const TWR_MIN_UPPER := 0.5

const _STATUS_RANK := {"pass": 0, "warn": 1, "fail": 2}

static func evaluate(design: Dictionary, data: Dictionary) -> Dictionary:
	var materials: Dictionary = data.get("materials", {})
	var nose_shapes: Dictionary = data.get("nose_shapes", {})
	var drag_model: Dictionary = data.get("drag_model", {})
	var q_model: Dictionary = data.get("q_limit_model", {})
	var dv_data: Dictionary = data.get("delta_v", {})

	var stages: Array = design.get("stages", [])
	var options: Dictionary = design.get("options", {})
	var mission: Dictionary = design.get("mission", {})
	var nose: Dictionary = design.get("nose", {})
	var fins: Dictionary = design.get("fins", {})
	var gimballed := bool(options.get("gimballed", false))

	var checks: Array = []
	var numbers := {}
	var nose_model: Dictionary = data.get("nose_mass_model", {})
	var geometry := RocketGeometry.build(design, materials, nose_shapes, float(nose_model.get("areal_factor", 1.0)))
	var report := {
		"design_name": str(design.get("name", "Unnamed rocket")),
		"overall": "fail",
		"outcome": "failure",
		"stars": 0,
		"tips": [],
		"failures": [],
		"checks": checks,
		"numbers": numbers,
		"geometry": geometry,
	}
	if stages.is_empty():
		checks.append(_check("design", "Design", 0.0, "", "at least 1 stage", "fail",
				"There is no rocket here yet. Add a body and an engine.",
				"Design has no stages."))
		return _finish(report)

	var segments: Array = geometry["segments"]
	var diameter := float(geometry["diameter_m"])
	var length := float(geometry["length_m"])
	var liftoff_mass := float(geometry["liftoff_mass_kg"])
	numbers["length_m"] = length
	numbers["diameter_m"] = diameter
	numbers["liftoff_mass_kg"] = liftoff_mass
	numbers["dry_mass_kg"] = float(geometry["dry_mass_kg"])
	numbers["propellant_mass_kg"] = float(geometry["propellant_mass_kg"])

	var first_stage: Dictionary = stages[0]
	var first_engine: Dictionary = first_stage.get("engine", {})
	var first_body: Dictionary = first_stage.get("body", {})
	var engine_count := float(first_engine.get("count", 1))
	var thrust_sl := _number(first_engine, "thrust_sl_N") * engine_count
	var thrust_vac := _number(first_engine, "thrust_vac_N") * engine_count
	var isp_sl := _number(first_engine, "isp_sl")
	var isp_vac := _number(first_engine, "isp_vac")

	var twr := RocketMath.twr(thrust_sl, liftoff_mass)
	numbers["thrust_sl_N"] = thrust_sl
	numbers["twr_liftoff"] = twr
	checks.append(_liftoff_check(twr, thrust_sl, liftoff_mass))

	var nose_factor := Stability.nose_x_factor(str(nose.get("shape", "")), nose_shapes)
	var barrowman := Stability.barrowman(float(nose.get("length_m", 0.0)), nose_factor, diameter,
			fins, float(geometry["fin_root_le_x_m"]))
	var x_cp := float(barrowman["x_cp_m"])
	var at_liftoff := RocketGeometry.mass_and_cg(segments, [])
	var at_burnout := RocketGeometry.mass_and_cg(segments, [0])
	var x_cg_liftoff := float(at_liftoff["x_cg_m"])
	var x_cg_burnout := float(at_burnout["x_cg_m"])
	var margin_liftoff := Stability.static_margin(x_cp, x_cg_liftoff, diameter)
	var margin_burnout := Stability.static_margin(x_cp, x_cg_burnout, diameter)
	var class_liftoff := Stability.classify(margin_liftoff, gimballed)
	var class_burnout := Stability.classify(margin_burnout, gimballed)
	numbers["barrowman"] = barrowman
	numbers["x_cp_m"] = x_cp
	numbers["x_cg_liftoff_m"] = x_cg_liftoff
	numbers["x_cg_burnout_m"] = x_cg_burnout
	numbers["burnout_mass_kg"] = float(at_burnout["mass_kg"])
	numbers["static_margin_liftoff_cal"] = margin_liftoff
	numbers["static_margin_burnout_cal"] = margin_burnout
	numbers["stability_class_liftoff"] = str(class_liftoff["class"])
	numbers["stability_class_burnout"] = str(class_burnout["class"])
	numbers["gimballed"] = gimballed
	checks.append(_stability_check("stability_liftoff", "Stability at liftoff", margin_liftoff,
			class_liftoff, x_cp, x_cg_liftoff, diameter, gimballed))
	checks.append(_stability_check("stability_burnout", "Stability at burnout", margin_burnout,
			class_burnout, x_cp, x_cg_burnout, diameter, gimballed))

	var nose_entry: Dictionary = nose_shapes.get(str(nose.get("shape", "")), {})
	var ref_area := Aero.reference_area(float(geometry["max_diameter_m"]))
	var fin_area := Aero.fin_planform_area(int(fins.get("count", 0)), float(fins.get("root_chord_m", 0.0)),
			float(fins.get("tip_chord_m", 0.0)), float(fins.get("span_m", 0.0)))
	var marginal := str(class_liftoff["class"]) == "marginal" or str(class_burnout["class"]) == "marginal"
	var cd := Aero.drag_coefficient(float(nose_entry.get("base_cd", 0.5)), fin_area, ref_area, marginal, drag_model)
	var stage_masses := RocketGeometry.stage_masses(segments, stages.size())
	var ascent := Aero.vertical_ascent_estimate(liftoff_mass, float((stage_masses[0] as Dictionary)["propellant_mass_kg"]),
			thrust_sl, thrust_vac, isp_sl, isp_vac, cd, ref_area)

	var burn_times: Array = []
	for i in stages.size():
		var engine: Dictionary = (stages[i] as Dictionary).get("engine", {})
		var masses: Dictionary = stage_masses[i]
		var count := float(engine.get("count", 1))
		var stage_isp_sl := _number(engine, "isp_sl")
		var stage_isp_vac := _number(engine, "isp_vac")
		masses["isp_s"] = RocketMath.budget_isp(stage_isp_sl, stage_isp_vac, i == 0)
		var burn_thrust := _number(engine, "thrust_vac_N") * count
		if i == 0:
			burn_thrust = (thrust_sl + thrust_vac) / 2.0
		burn_times.append(RocketMath.burn_time(float(masses["propellant_mass_kg"]), float(masses["isp_s"]), burn_thrust))
	var payload_mass := RocketGeometry.payload_mass(segments)
	var delta_v := RocketMath.total_delta_v(stage_masses, payload_mass)
	var dv_stages: Array = delta_v["stages"]
	var dv_available := float(delta_v["total_ms"])
	var upper_twrs: Array = []
	for i in range(1, stages.size()):
		var upper_engine: Dictionary = (stages[i] as Dictionary).get("engine", {})
		upper_twrs.append(RocketMath.twr(_number(upper_engine, "thrust_vac_N") * float(upper_engine.get("count", 1)),
				float((dv_stages[i] as Dictionary)["m0_kg"])))
	var budget := MissionBudget.required_delta_v(mission, dv_data, {
		"first_burn_s": float(burn_times[0]),
		"upper_burns_s": burn_times.slice(1),
		"drag_loss_ms": float(ascent["drag_loss_ms"]),
		"liftoff_mass_kg": liftoff_mass,
		"upper_twrs": upper_twrs,
	})
	var dv_required := float(budget["required_ms"])
	var margins: Dictionary = dv_data.get("margins", {})
	var safe_ratio := float(margins.get("safe_range_ratio", MissionBudget.DEFAULT_SAFE_RATIO))
	var ratio := MissionBudget.range_ratio(dv_available, dv_required)
	numbers["payload_mass_kg"] = payload_mass
	numbers["delta_v_stages"] = dv_stages
	numbers["delta_v_available_ms"] = dv_available
	numbers["delta_v_budget"] = budget
	numbers["delta_v_required_ms"] = dv_required
	numbers["range_ratio"] = ratio
	numbers["burn_times_s"] = burn_times
	checks.append(_range_check(ratio, dv_available, budget, safe_ratio, dv_stages))

	var material_id := str(first_body.get("material", ""))
	var material: Dictionary = materials.get(material_id, {})
	var q_limit := Aero.q_limit(material, length, diameter, q_model)
	var q_max := float(ascent["q_max_pa"])
	numbers["cd"] = cd
	numbers["reference_area_m2"] = ref_area
	numbers["fin_area_m2"] = fin_area
	numbers["ascent_estimate"] = ascent
	numbers["q_max_pa"] = q_max
	numbers["q_limit_pa"] = q_limit
	numbers["fineness"] = length / diameter if diameter > 0.0 else 0.0
	checks.append(_structure_check(q_max, q_limit, material, float(numbers["fineness"]),
			float(q_model.get("warn_fraction", 0.85)), ascent))

	for i in range(1, stages.size()):
		var engine: Dictionary = (stages[i] as Dictionary).get("engine", {})
		var stage_info: Dictionary = dv_stages[i]
		var upper_thrust := _number(engine, "thrust_vac_N") * float(engine.get("count", 1))
		var upper_twr := RocketMath.twr(upper_thrust, float(stage_info["m0_kg"]))
		checks.append(_upper_twr_check(i, upper_twr, upper_thrust, float(stage_info["m0_kg"])))

	if bool(mission.get("crewed", false)):
		var tower: Dictionary = options.get("escape_tower", {})
		var has_tower := float(tower.get("mass_kg", 0.0)) > 0.0
		checks.append(_check("escape_tower", "Escape tower", 1.0 if has_tower else 0.0, "",
				"required for crew", "pass" if has_tower else "warn",
				"The crew has an escape tower to pull them clear if the launch goes wrong." if has_tower
				else "There are people on board and no escape tower. If the launch goes wrong they have no quick way out.",
				"Escape tower fitted." if has_tower else "Crewed mission without a launch escape system."))

	var budget_limit := float(mission.get("budget_musd", 0.0))
	if budget_limit > 0.0:
		var cost := CostModel.design_cost(design, data.get("engines", {}), materials, data.get("cost_model", {}))
		report["budget"] = CostModel.budget_status(float(cost["total"]), budget_limit, data.get("cost_model", {}))
		report["budget"]["items"] = cost["items"]

	return _finish(report)

static func _finish(report: Dictionary) -> Dictionary:
	var checks: Array = report["checks"]
	var tips: Array = []
	var failures: Array = []
	for check: Dictionary in checks:
		match str(check["status"]):
			"warn":
				tips.append(str(check["plain"]))
			"fail":
				failures.append(str(check["plain"]))
	report["overall"] = _worst(checks)
	report["tips"] = tips
	report["failures"] = failures
	if not failures.is_empty():
		report["outcome"] = "failure"
		report["stars"] = 0
	else:
		report["outcome"] = "success"
		report["stars"] = 3 if tips.is_empty() else (2 if tips.size() == 1 else 1)
	return report

static func format_report(report: Dictionary) -> String:
	var lines: PackedStringArray = []
	var numbers: Dictionary = report.get("numbers", {})
	lines.append("=== %s: %s ===" % [str(report.get("design_name", "")), str(report.get("overall", "")).to_upper()])
	lines.append("  Mission: %s, %d / 3 stars" % [str(report.get("outcome", "")).to_upper(), int(report.get("stars", 0))])
	if numbers.has("liftoff_mass_kg"):
		lines.append("  Length %.2f m | diameter %.2f m | liftoff mass %.0f kg (dry %.0f + propellant %.0f)" % [
			float(numbers["length_m"]), float(numbers["diameter_m"]), float(numbers["liftoff_mass_kg"]),
			float(numbers["dry_mass_kg"]), float(numbers["propellant_mass_kg"])])
	var geometry: Dictionary = report.get("geometry", {})
	var segments: Array = geometry.get("segments", [])
	for segment: Dictionary in segments:
		lines.append("    %-24s x_top %7.2f m  len %5.2f m  dry %8.0f kg  prop %8.0f kg  cg %6.2f m" % [
			str(segment["name"]), float(segment["x_top_m"]), float(segment["length_m"]),
			float(segment["dry_mass_kg"]), float(segment["propellant_mass_kg"]), float(segment["cg_x_m"])])
	var checks: Array = report.get("checks", [])
	for check: Dictionary in checks:
		lines.append("  [%s] %s: %s %s (threshold: %s)" % [
			str(check["status"]).to_upper(), str(check["name"]), _format_value(float(check["value"])),
			str(check["unit"]), str(check["threshold"])])
		lines.append("         Plain:     %s" % str(check["plain"]))
		lines.append("         Technical: %s" % str(check["technical"]))
	var tips: Array = report.get("tips", [])
	for tip in tips:
		lines.append("  Tip: %s" % str(tip))
	return "\n".join(lines)

static func _liftoff_check(twr: float, thrust_sl: float, mass: float) -> Dictionary:
	var threshold := ">= %.1f" % TWR_GOOD_LIFTOFF
	var technical := "TWR = thrust_SL / (m * g0) = %.0f N / (%.0f kg * %.5f) = %.3f. Needs >= %.1f to leave the pad, >= %.1f to climb well." % [
		thrust_sl, mass, RocketMath.G0, twr, TWR_MIN_LIFTOFF, TWR_GOOD_LIFTOFF]
	if thrust_sl <= 0.0:
		return _check("liftoff", "Liftoff (thrust-to-weight)", 0.0, "", threshold, "fail",
				"This engine only works in space. It cannot light on the launch pad, so the rocket goes nowhere.",
				"First-stage engine has no sea-level thrust (vacuum-only engine). " + technical)
	if twr < TWR_MIN_LIFTOFF:
		return _check("liftoff", "Liftoff (thrust-to-weight)", twr, "", threshold, "fail",
				"Your rocket is too heavy for its engine. It sits on the pad making a lot of noise. Try a bigger engine or less fuel.",
				technical)
	if twr < TWR_GOOD_LIFTOFF:
		return _check("liftoff", "Liftoff (thrust-to-weight)", twr, "", threshold, "warn",
				"Your rocket only just lifts off. It climbs so slowly that it wastes a lot of fuel fighting gravity.",
				technical)
	return _check("liftoff", "Liftoff (thrust-to-weight)", twr, "", threshold, "pass",
			"The engine is strong enough to lift the rocket briskly off the pad.", technical)

static func _stability_check(id: String, check_name: String, margin: float, classification: Dictionary,
		x_cp: float, x_cg: float, diameter: float, gimballed: bool) -> Dictionary:
	var technical := "Static margin = (X_cp - X_cg) / d = (%.2f - %.2f) / %.2f = %.2f cal. Class: %s. Gimballed: %s." % [
		x_cp, x_cg, diameter, margin, str(classification["class"]), "yes" if gimballed else "no"]
	var plain := ""
	match str(classification["class"]):
		"unstable":
			plain = "Your rocket tips over: the fins are too small to keep the back behind the front. Try bigger fins, or put heavy parts higher up."
		"marginal":
			if bool(classification["flyable"]):
				plain = "Your rocket is wobbly on its own, but the steerable engine keeps it pointed the right way. Bigger fins would make it calmer."
			elif gimballed:
				plain = "Your rocket is so close to tipping over that even the steerable engine cannot hold it. Try bigger fins, or put heavy parts higher up."
			else:
				plain = "Your rocket wobbles badly: the fins are barely big enough. Try bigger fins, heavy parts higher up, or an engine that can steer."
		"stable":
			plain = "Your rocket flies straight. The fins keep the back behind the front, like the feathers on an arrow."
		"over_stable":
			plain = "Your rocket is too steady: like a weather vane, it turns into every gust of wind and wastes fuel. Try smaller fins."
	var threshold := "1 to 3 cal"
	if gimballed:
		threshold = "0.3 to 3 cal (gimballed)"
	return _check(id, check_name, margin, "cal", threshold, str(classification["status"]), plain, technical)

static func _range_check(ratio: float, available: float, budget: Dictionary, safe_ratio: float, dv_stages: Array) -> Dictionary:
	var threshold := ">= 1.0 (safe >= %.1f)" % safe_ratio
	if not bool(budget["valid"]):
		return _check("range", "Range (delta-v)", 0.0, "", threshold, "fail",
				"This rocket has not been given a mission, so there is nowhere to measure the trip to.",
				"Unknown mission profile '%s'. Delta-v available: %.0f m/s." % [str(budget["profile"]), available])
	var stage_parts: PackedStringArray = []
	for i in dv_stages.size():
		var stage: Dictionary = dv_stages[i]
		stage_parts.append("stage %d: %.0f s * g0 * ln(%.0f / %.0f) = %.0f m/s" % [
			i + 1, float(stage["isp_s"]), float(stage["m0_kg"]), float(stage["mf_kg"]), float(stage["delta_v_ms"])])
	var technical := "Available dv = %.0f m/s (%s). Required = %.0f legs - %.0f spin + %.0f raise + %.0f return, + %.0f%% margin = %.0f m/s. Range ratio = %.3f." % [
		available, "; ".join(stage_parts), float(budget["outbound_ms"]), float(budget["rotation_bonus_ms"]),
		float(budget["orbit_raise_ms"]), float(budget["return_ms"]), float(budget["margin_fraction"]) * 100.0,
		float(budget["required_ms"]), ratio]
	if bool(budget.get("loss_model", false)):
		technical = "Available dv = %.0f m/s (%s). Required = v_insert %.0f - spin %.0f + gravity loss %.0f + drag loss %.0f (%s profile) + return %.0f, + %.0f%% margin = %.0f m/s. Range ratio = %.3f. Loss model calibrated against Juno I / Explorer 1; the launch sim will replace it." % [
			available, "; ".join(stage_parts), float(budget["insertion_ms"]), float(budget["rotation_bonus_ms"]),
			float(budget["gravity_loss_ms"]), float(budget["drag_loss_ms"]), "lofted" if bool(budget["lofted"]) else "standard",
			float(budget["return_ms"]), float(budget["margin_fraction"]) * 100.0, float(budget["required_ms"]), ratio]
	var status := MissionBudget.classify_range(ratio, safe_ratio)
	var plain := ""
	match status:
		"pass":
			plain = "Your rocket has enough fuel for the whole trip, with some to spare."
		"warn":
			plain = "Your rocket can just about make the trip, but there is almost nothing spare if anything goes wrong."
		_:
			plain = "Your rocket runs out of fuel before it gets there: it has about %d%% of the speed it needs. Try more fuel, a more efficient engine, or less weight." % int(round(ratio * 100.0))
	return _check("range", "Range (delta-v)", ratio, "", threshold, status, plain, technical)

static func _structure_check(q_max: float, q_limit: float, material: Dictionary, fineness: float,
		warn_fraction: float, ascent: Dictionary) -> Dictionary:
	var threshold := "<= %.1f kPa" % (q_limit / 1000.0)
	var material_name := str(material.get("name", "unknown material"))
	if material.is_empty():
		return _check("structure", "Structure (Max-Q)", q_max / 1000.0, "kPa", threshold, "fail",
				"The rocket body has no material chosen, so nobody knows how strong it is.",
				"Unknown body material; cannot compute a q limit.")
	var technical := "Estimated q_max = 1/2 * rho * v^2 = %.1f kPa at T+%.0f s, %.1f km, %.0f m/s (vertical-ascent estimate). Limit for %s at fineness %.1f = %.1f kPa." % [
		q_max / 1000.0, float(ascent["q_max_time_s"]), float(ascent["q_max_altitude_m"]) / 1000.0,
		float(ascent["q_max_velocity_ms"]), material_name, fineness, q_limit / 1000.0]
	if not bool(ascent["lifted_off"]):
		return _check("structure", "Structure (Max-Q)", 0.0, "kPa", threshold, "pass",
				"The rocket never leaves the pad, so the air never gets a chance to push on it.",
				"No liftoff, so no aerodynamic load. " + technical)
	if q_max > q_limit:
		return _check("structure", "Structure (Max-Q)", q_max / 1000.0, "kPa", threshold, "fail",
				"Your rocket breaks apart: it goes so fast through thick air that the air crushes it. Try a stronger material, a smaller engine, or a shorter, fatter body.",
				technical)
	if q_max > q_limit * warn_fraction:
		return _check("structure", "Structure (Max-Q)", q_max / 1000.0, "kPa", threshold, "warn",
				"Your rocket holds together, but only just. The air pushes on it almost as hard as it can take.",
				technical)
	return _check("structure", "Structure (Max-Q)", q_max / 1000.0, "kPa", threshold, "pass",
			"Your rocket is strong enough to push through the thick air on the way up.", technical)

static func _upper_twr_check(stage_index: int, twr: float, thrust: float, mass: float) -> Dictionary:
	var id := "upper_twr_stage_%d" % (stage_index + 1)
	var check_name := "Stage %d thrust-to-weight" % (stage_index + 1)
	var technical := "TWR = thrust_vac / (m * g0) = %.0f N / (%.0f kg * %.5f) = %.3f. Upper stages need > %.1f." % [
		thrust, mass, RocketMath.G0, twr, TWR_MIN_UPPER]
	if twr > TWR_MIN_UPPER:
		return _check(id, check_name, twr, "", "> 0.5", "pass",
				"Stage %d has enough push to keep the rocket speeding up." % (stage_index + 1), technical)
	return _check(id, check_name, twr, "", "> 0.5", "warn",
			"Stage %d is weak for the weight it carries. It will fall back towards Earth while it slowly builds up speed." % (stage_index + 1),
			technical)

static func _check(id: String, check_name: String, value: float, unit: String, threshold: String,
		status: String, plain: String, technical: String) -> Dictionary:
	return {
		"id": id,
		"name": check_name,
		"value": value,
		"unit": unit,
		"threshold": threshold,
		"status": status,
		"plain": plain,
		"technical": technical,
	}

static func _number(source: Dictionary, key: String) -> float:
	var value: Variant = source.get(key, 0.0)
	if value == null:
		return 0.0
	return float(value)

static func _worst(checks: Array) -> String:
	var worst := "pass"
	for check: Dictionary in checks:
		var status := str(check["status"])
		if int(_STATUS_RANK.get(status, 2)) > int(_STATUS_RANK[worst]):
			worst = status
	return worst

static func _format_value(value: float) -> String:
	return "%.3f" % value
