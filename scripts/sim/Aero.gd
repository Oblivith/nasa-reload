# Code generated with AI assistance (Claude). Reviewed by team.
class_name Aero
extends RefCounted
## Atmosphere, drag and structural (Max-Q) maths (Sim Spec v2, 2.4 and 2.5).
## Pure maths: SI units, no UI. Model coefficients come from /data (nose_shapes.json
## "drag_model", materials.json "q_limit_model") and are passed in as dictionaries.

const RHO0 := 1.225            ## Sea-level air density, kg/m^3
const SCALE_HEIGHT_M := 8500.0 ## Exponential atmosphere scale height, m


## Air density: rho = 1.225 * e^(-h / 8500).
static func air_density(altitude_m: float) -> float:
	return RHO0 * exp(-maxf(altitude_m, 0.0) / SCALE_HEIGHT_M)


## Dynamic pressure: q = 1/2 * rho * v^2. Pascals.
static func dynamic_pressure(density: float, velocity: float) -> float:
	return 0.5 * density * velocity * velocity


## Body cross-section: pi * R^2.
static func reference_area(diameter: float) -> float:
	return PI * diameter * diameter / 4.0


## Total planform area of N trapezoidal fins: N * (C_r + C_t)/2 * S.
static func fin_planform_area(count: int, root_chord: float, tip_chord: float, span: float) -> float:
	return float(count) * (root_chord + tip_chord) / 2.0 * span


## Cd = base (by nose shape) + fin term (proportional to fin area / body cross-section)
##      + wobble penalty if the static margin is marginal.
static func drag_coefficient(base_cd: float, fin_area: float, ref_area: float, marginal: bool, drag_model: Dictionary) -> float:
	var cd := base_cd
	if ref_area > 0.0:
		cd += float(drag_model.get("fin_cd_per_area_ratio", 0.0)) * fin_area / ref_area
	if marginal:
		cd += float(drag_model.get("marginal_wobble_cd", 0.0))
	return cd


## Drag = 1/2 * rho * v^2 * Cd * A. Newtons.
static func drag_force(density: float, velocity: float, cd: float, ref_area: float) -> float:
	return dynamic_pressure(density, velocity) * cd * ref_area


## Max dynamic pressure a rocket tolerates: the material limit scaled by fineness
## (length / diameter), so long, thin rockets are weaker.
static func q_limit(material: Dictionary, length: float, diameter: float, q_model: Dictionary) -> float:
	var base := float(material.get("max_q_pa", 0.0))
	if length <= 0.0 or diameter <= 0.0:
		return base
	var fineness := length / diameter
	var factor := float(q_model.get("reference_fineness", fineness)) / fineness
	factor = clampf(factor, float(q_model.get("min_factor", 1.0)), float(q_model.get("max_factor", 1.0)))
	return base * factor


## Thrust (or Isp) blended from sea level to vacuum with ambient pressure:
## value = vac - (vac - sl) * e^(-h / 8500).
static func blend_to_vacuum(sea_level: float, vacuum: float, altitude_m: float) -> float:
	return vacuum - (vacuum - sea_level) * exp(-maxf(altitude_m, 0.0) / SCALE_HEIGHT_M)


## Pre-flight estimate of the first-stage burn, flown STRAIGHT UP (no gravity turn).
## Fixed time steps; thrust and Isp blend from sea level to vacuum; gravity mu/r^2;
## exponential atmosphere; drag. Gives the Max-Q the structure check needs before the
## real launch sim exists. A pitched trajectory stays in thick air longer, so the
## launch sim's own Max-Q replaces this number.
## Returns {lifted_off, q_max_pa, q_max_time_s, q_max_altitude_m, q_max_velocity_ms,
##          burnout_time_s, burnout_altitude_m, burnout_velocity_ms,
##          vertical_apogee_m, gravity_loss_ms, drag_loss_ms}.
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

	# Powered flight.
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
			accel = 0.0  # Still sitting on the pad, burning propellant.
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

	# Unpowered coast to the top.
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
