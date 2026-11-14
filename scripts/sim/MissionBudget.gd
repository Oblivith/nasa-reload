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
##                  margin_fraction?}

const DEFAULT_SAFE_RATIO := 1.1


## Free eastward speed from Earth's spin: v = equator_speed * cos(latitude). m/s.
static func rotation_bonus(latitude_deg: float, equator_speed_ms: float) -> float:
	return equator_speed_ms * cos(deg_to_rad(latitude_deg))


## Builds the full budget. Returns:
##   {valid, profile, legs: [{id, name, delta_v_ms, part: "outbound"/"raise"/"return"}],
##    outbound_ms, rotation_bonus_ms, orbit_raise_ms, return_ms, subtotal_ms,
##    margin_fraction, margin_ms, required_ms}
static func required_delta_v(mission: Dictionary, dv_data: Dictionary) -> Dictionary:
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
