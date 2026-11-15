# SI assistance metadata: This code used the help of SI.
class_name Aero
extends RefCounted

const RHO0 := 1.225
const SCALE_HEIGHT_M := 8500.0

static func air_density(altitude_m: float) -> float:
	return RHO0 * exp(-maxf(altitude_m, 0.0) / SCALE_HEIGHT_M)

static func dynamic_pressure(density: float, velocity: float) -> float:
	return 0.5 * density * velocity * velocity

static func reference_area(diameter: float) -> float:
	return PI * diameter * diameter / 4.0

static func fin_planform_area(count: int, root_chord: float, tip_chord: float, span: float) -> float:
	return float(count) * (root_chord + tip_chord) / 2.0 * span

static func drag_coefficient(base_cd: float, fin_area: float, ref_area: float, marginal: bool, drag_model: Dictionary) -> float:
	var cd := base_cd
	if ref_area > 0.0:
		cd += float(drag_model.get("fin_cd_per_area_ratio", 0.0)) * fin_area / ref_area
	if marginal:
		cd += float(drag_model.get("marginal_wobble_cd", 0.0))
	return cd

static func drag_force(density: float, velocity: float, cd: float, ref_area: float) -> float:
	return dynamic_pressure(density, velocity) * cd * ref_area

static func q_limit(material: Dictionary, length: float, diameter: float, q_model: Dictionary) -> float:
	var base := float(material.get("max_q_pa", 0.0))
	if length <= 0.0 or diameter <= 0.0:
		return base
	var fineness := length / diameter
	var factor := float(q_model.get("reference_fineness", fineness)) / fineness
	factor = clampf(factor, float(q_model.get("min_factor", 1.0)), float(q_model.get("max_factor", 1.0)))
	return base * factor

static func blend_to_vacuum(sea_level: float, vacuum: float, altitude_m: float) -> float:
	return vacuum - (vacuum - sea_level) * exp(-maxf(altitude_m, 0.0) / SCALE_HEIGHT_M)

static func vertical_ascent_estimate(liftoff_mass: float, propellant_mass: float, thrust_sl: float,
		thrust_vac: float, isp_sl: float, isp_vac: float, cd: float, ref_area: float, dt: float = 0.05) -> Dictionary:
	var result := {
		"lifted_off": false,
		"q_max_pa": 0.0, "q_max_time_s": 0.0, "q_max_altitude_m": 0.0, "q_max_velocity_ms": 0.0,
		"burnout_time_s": 0.0, "burnout_altitude_m": 0.0, "burnout_velocity_ms": 0.0,
		"vertical_apogee_m": 0.0, "gravity_loss_ms": 0.0, "drag_loss_ms": 0.0,
	}
	if liftoff_mass <= 0.0 or thrust_sl <= 0.0 or isp_sl <= 0.0 or isp_vac <= 0.0:
		return result

	var mass := liftoff_mass
	var propellant := propellant_mass
	var h := 0.0
	var v := 0.0
	var t := 0.0
	var max_steps := int(3600.0 / dt)

	for _step in max_steps:
		if propellant <= 0.0:
			break
		var thrust := blend_to_vacuum(thrust_sl, thrust_vac, h)
		var isp := blend_to_vacuum(isp_sl, isp_vac, h)
		var burned := minf(thrust / (isp * RocketMath.G0) * dt, propellant)
		var g := OrbitMath.MU_EARTH / pow(OrbitMath.EARTH_RADIUS_M + h, 2.0)
		var rho := air_density(h)
		var drag := drag_force(rho, v, cd, ref_area) * signf(v)
		var accel := (thrust - drag) / mass - g
		if h <= 0.0 and accel < 0.0:
			accel = 0.0
		else:
			result["lifted_off"] = true
			result["gravity_loss_ms"] = float(result["gravity_loss_ms"]) + g * dt
			result["drag_loss_ms"] = float(result["drag_loss_ms"]) + absf(drag) / mass * dt
		v += accel * dt
		h = maxf(h + v * dt, 0.0)
		mass -= burned
		propellant -= burned
		t += dt
		var q := dynamic_pressure(air_density(h), v)
		if q > float(result["q_max_pa"]):
			result["q_max_pa"] = q
			result["q_max_time_s"] = t
			result["q_max_altitude_m"] = h
			result["q_max_velocity_ms"] = v

	result["burnout_time_s"] = t
	result["burnout_altitude_m"] = h
	result["burnout_velocity_ms"] = v

	var apogee := h
	for _step in max_steps:
		if v <= 0.0:
			break
		var g := OrbitMath.MU_EARTH / pow(OrbitMath.EARTH_RADIUS_M + h, 2.0)
		var drag := drag_force(air_density(h), v, cd, ref_area)
		v -= (g + drag / mass) * dt
		h += v * dt
		apogee = maxf(apogee, h)
	result["vertical_apogee_m"] = apogee
	return result
