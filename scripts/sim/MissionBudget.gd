# Code generated with AI assistance (Claude). Reviewed by team.
class_name MissionBudget
extends RefCounted
## Required delta-v for a mission (Sim Spec v2, 2.3): legs from the delta-v map, minus
## the Earth rotation bonus, plus an orbit raise, plus return legs, plus a margin.
## Pure maths, no UI. `dv_data` is the parsed /data/delta_v_map.json content with
## "legs" and "mission_profiles" given as { id -> entry } tables:
##   {legs, mission_profiles, earth_rotation: {equator_speed_ms},
##    margins: {default_margin_fraction, safe_range_ratio}}
##
## Mission format: {profile, target_altitude_km?, latitude_deg?, needs_return?,
##                  margin_fraction?, target_perigee_km?, target_apogee_km?}
##
## Profiles with "loss_model": true (Level 1 onwards) skip the flat ground-to-orbit leg:
##   required = v_insert(target perigee, vis-viva) - Earth spin bonus
##              + gravity loss + drag loss (+ return legs), x (1 + margin)
##   gravity loss = g0 x (k_first x first-stage burn time + k_upper x upper burn times)
##   drag loss    = k_drag x the first-stage drag loss of the vertical-ascent estimate
## A small rocket with kick stages (dv_data.loss_model.lofted) may fly a lofted profile:
## the booster lofts the stack and the kick stages fire horizontally at the top, so
## k_upper = 0. Coefficients are calibrated against Juno I / Explorer 1 (see data); the
## launch sim will replace this estimate. `rocket` = {first_burn_s, upper_burns_s,
## drag_loss_ms, liftoff_mass_kg, upper_twrs} from RocketEvaluator.

const DEFAULT_SAFE_RATIO := 1.1


## Free eastward speed from Earth's spin: v = equator_speed * cos(latitude). m/s.
static func rotation_bonus(latitude_deg: float, equator_speed_ms: float) -> float:
	return equator_speed_ms * cos(deg_to_rad(latitude_deg))


## Builds the full budget. Returns:
##   {valid, profile, legs: [{id, name, delta_v_ms, part: "outbound"/"raise"/"return"}],
##    outbound_ms, rotation_bonus_ms, orbit_raise_ms, return_ms, subtotal_ms,
##    margin_fraction, margin_ms, required_ms}
static func required_delta_v(mission: Dictionary, dv_data: Dictionary, rocket: Dictionary = {}) -> Dictionary:
	var legs_table: Dictionary = dv_data.get("legs", {})
	var profiles: Dictionary = dv_data.get("mission_profiles", {})
	var margins: Dictionary = dv_data.get("margins", {})
	var rotation: Dictionary = dv_data.get("earth_rotation", {})
	var profile_id := str(mission.get("profile", ""))
	var profile: Dictionary = profiles.get(profile_id, {})

	var budget := {
		"valid": not profile.is_empty(),
		"profile": profile_id,
		"legs": [],
		"outbound_ms": 0.0,
		"rotation_bonus_ms": 0.0,
		"orbit_raise_ms": 0.0,
		"return_ms": 0.0,
		"subtotal_ms": 0.0,
		"margin_fraction": 0.0,
		"margin_ms": 0.0,
		"required_ms": 0.0,
	}
	if profile.is_empty():
		return budget
	if bool(profile.get("loss_model", false)):
		return _loss_model_budget(mission, dv_data, profile, rocket, budget)
	var legs: Array = budget["legs"]

	var outbound := 0.0
	var outbound_ids: Array = profile.get("outbound_legs", [])
	for leg_key in outbound_ids:
		var leg_id := str(leg_key)
		var leg: Dictionary = legs_table.get(leg_id, {})
		var dv := float(leg.get("delta_v_ms", 0.0))
		outbound += dv
		legs.append({"id": leg_id, "name": str(leg.get("name", leg_id)), "delta_v_ms": dv, "part": "outbound"})

	var bonus := 0.0
	if bool(profile.get("spin_bonus", false)) and bool(mission.get("spin_bonus", true)):
		bonus = rotation_bonus(float(mission.get("latitude_deg", 0.0)), float(rotation.get("equator_speed_ms", 0.0)))

	var orbit_raise := 0.0
	if bool(profile.get("orbit_raise", false)):
		var parking_km := float(profile.get("parking_altitude_km", 200.0))
		var target_km := float(mission.get("target_altitude_km", parking_km))
		if target_km > parking_km:
			var transfer := OrbitMath.hohmann(
					OrbitMath.radius_from_altitude_km(parking_km),
					OrbitMath.radius_from_altitude_km(target_km))
			orbit_raise = float(transfer["total_ms"])
			legs.append({
				"id": "orbit_raise",
				"name": "Hohmann raise %d -> %d km" % [int(parking_km), int(target_km)],
				"delta_v_ms": orbit_raise,
				"part": "raise",
			})

	var return_dv := 0.0
	if bool(mission.get("needs_return", false)):
		var return_ids: Array = profile.get("return_legs", [])
		for leg_key in return_ids:
			var leg_id := str(leg_key)
			var leg: Dictionary = legs_table.get(leg_id, {})
			var dv := float(leg.get("delta_v_ms", 0.0))
			return_dv += dv
			legs.append({"id": leg_id, "name": str(leg.get("name", leg_id)), "delta_v_ms": dv, "part": "return"})

	var subtotal := outbound - bonus + orbit_raise + return_dv
	var margin_fraction := float(mission.get("margin_fraction", margins.get("default_margin_fraction", 0.0)))
	budget["outbound_ms"] = outbound
	budget["rotation_bonus_ms"] = bonus
	budget["orbit_raise_ms"] = orbit_raise
	budget["return_ms"] = return_dv
	budget["subtotal_ms"] = subtotal
	budget["margin_fraction"] = margin_fraction
	budget["margin_ms"] = subtotal * margin_fraction
	budget["required_ms"] = subtotal * (1.0 + margin_fraction)
	return budget


## Range ratio = delta-v available / delta-v required.
static func range_ratio(available_ms: float, required_ms: float) -> float:
	if required_ms <= 0.0:
		return 0.0
	return available_ms / required_ms


## >= safe ratio: pass. >= 1.0: can make it, thin margin (warn). Below 1.0: fail.
static func classify_range(ratio: float, safe_ratio: float = DEFAULT_SAFE_RATIO) -> String:
	if ratio >= safe_ratio:
		return "pass"
	if ratio >= 1.0:
		return "warn"
	return "fail"


## True if this rocket may fly the lofted kick-stage profile: small enough and every
## upper stage is a kick stage (high vacuum thrust-to-weight).
static func lofted_allowed(rocket: Dictionary, loss_model: Dictionary) -> bool:
	var lofted: Dictionary = loss_model.get("lofted", {})
	var twrs: Array = rocket.get("upper_twrs", [])
	if lofted.is_empty() or twrs.is_empty():
		return false
	if float(rocket.get("liftoff_mass_kg", INF)) > float(lofted.get("max_liftoff_mass_kg", 0.0)):
		return false
	for twr in twrs:
		if float(twr) < float(lofted.get("min_upper_stage_twr", INF)):
			return false
	return true


## Speed needed at the start of the target orbit: vis-viva at the target perigee.
static func insertion_velocity(mission: Dictionary) -> float:
	var perigee_km := float(mission.get("target_perigee_km", mission.get("target_altitude_km", 200.0)))
	var apogee_km := maxf(float(mission.get("target_apogee_km", perigee_km)), perigee_km)
	var r_p := OrbitMath.radius_from_altitude_km(perigee_km)
	var r_a := OrbitMath.radius_from_altitude_km(apogee_km)
	return OrbitMath.vis_viva(r_p, (r_p + r_a) / 2.0)


static func _loss_model_budget(mission: Dictionary, dv_data: Dictionary, profile: Dictionary,
		rocket: Dictionary, budget: Dictionary) -> Dictionary:
	var loss_model: Dictionary = dv_data.get("loss_model", {})
	var margins: Dictionary = dv_data.get("margins", {})
	var rotation: Dictionary = dv_data.get("earth_rotation", {})
	var legs_table: Dictionary = dv_data.get("legs", {})
	var legs: Array = budget["legs"]

	var v_insert := insertion_velocity(mission)
	var lofted := lofted_allowed(rocket, loss_model)
	var k_first := float(loss_model.get("gravity_loss_coeff_first_stage", 1.0))
	var k_upper := float(loss_model.get("gravity_loss_coeff_upper", 1.0))
	if lofted:
		k_upper = float((loss_model.get("lofted", {}) as Dictionary).get("gravity_loss_coeff_upper", k_upper))
	var upper_burn := 0.0
	for burn in rocket.get("upper_burns_s", []):
		upper_burn += float(burn)
	var gravity := RocketMath.G0 * (k_first * float(rocket.get("first_burn_s", 0.0)) + k_upper * upper_burn)
	var drag := float(loss_model.get("drag_loss_coeff", 1.0)) * float(rocket.get("drag_loss_ms", 0.0))

	var bonus := 0.0
	if bool(profile.get("spin_bonus", false)) and bool(mission.get("spin_bonus", true)):
		bonus = rotation_bonus(float(mission.get("latitude_deg", 0.0)), float(rotation.get("equator_speed_ms", 0.0)))
	legs.append({"id": "insertion", "name": "Orbit insertion speed (vis-viva at perigee)", "delta_v_ms": v_insert, "part": "outbound"})
	legs.append({"id": "gravity_loss", "name": "Gravity loss (%s profile)" % ("lofted" if lofted else "standard"),
			"delta_v_ms": gravity, "part": "outbound"})
	legs.append({"id": "drag_loss", "name": "Drag loss", "delta_v_ms": drag, "part": "outbound"})

	var return_dv := 0.0
	if bool(mission.get("needs_return", false)):
		for leg_key in profile.get("return_legs", []):
			var leg: Dictionary = legs_table.get(str(leg_key), {})
			var dv := float(leg.get("delta_v_ms", 0.0))
			return_dv += dv
			legs.append({"id": str(leg_key), "name": str(leg.get("name", leg_key)), "delta_v_ms": dv, "part": "return"})

	var outbound := v_insert + gravity + drag
	var subtotal := outbound - bonus + return_dv
	var margin_fraction := float(mission.get("margin_fraction", margins.get("default_margin_fraction", 0.0)))
	budget["loss_model"] = true
	budget["lofted"] = lofted
	budget["insertion_ms"] = v_insert
	budget["gravity_loss_ms"] = gravity
	budget["drag_loss_ms"] = drag
	budget["outbound_ms"] = outbound
	budget["rotation_bonus_ms"] = bonus
	budget["return_ms"] = return_dv
	budget["subtotal_ms"] = subtotal
	budget["margin_fraction"] = margin_fraction
	budget["margin_ms"] = subtotal * margin_fraction
	budget["required_ms"] = subtotal * (1.0 + margin_fraction)
	return budget
