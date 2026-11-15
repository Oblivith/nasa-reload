# SI assistance metadata: This code used the help of SI.
class_name OrbitMath
extends RefCounted

const MU_EARTH := 3.986e14
const EARTH_RADIUS_M := 6.371e6

static func radius_from_altitude_km(altitude_km: float) -> float:
	return EARTH_RADIUS_M + altitude_km * 1000.0

static func circular_velocity(r: float, mu: float = MU_EARTH) -> float:
	return sqrt(mu / r)

static func period(a: float, mu: float = MU_EARTH) -> float:
	return TAU * sqrt(a * a * a / mu)

static func vis_viva(r: float, a: float, mu: float = MU_EARTH) -> float:
	var v_squared := mu * (2.0 / r - 1.0 / a)
	return sqrt(v_squared) if v_squared > 0.0 else 0.0

static func hohmann(r1: float, r2: float, mu: float = MU_EARTH) -> Dictionary:
	var a_transfer := (r1 + r2) / 2.0
	var dv1 := sqrt(mu / r1) * (sqrt(2.0 * r2 / (r1 + r2)) - 1.0)
	var dv2 := sqrt(mu / r2) * (1.0 - sqrt(2.0 * r1 / (r1 + r2)))
	return {
		"dv1_ms": absf(dv1),
		"dv2_ms": absf(dv2),
		"total_ms": absf(dv1) + absf(dv2),
		"transfer_time_s": period(a_transfer, mu) / 2.0,
		"transfer_semi_major_axis_m": a_transfer,
	}

static func plane_change(v: float, delta_inclination_deg: float) -> float:
	return 2.0 * v * sin(deg_to_rad(delta_inclination_deg) / 2.0)

static func apsides_from_state(r: float, v: float, flight_path_angle_rad: float, mu: float = MU_EARTH) -> Dictionary:
	var energy := v * v / 2.0 - mu / r
	if energy >= 0.0:
		return {}
	var a := -mu / (2.0 * energy)
	var h := r * v * cos(flight_path_angle_rad)
	var e := sqrt(maxf(0.0, 1.0 - h * h / (mu * a)))
	return {
		"semi_major_axis_m": a,
		"eccentricity": e,
		"apogee_radius_m": a * (1.0 + e),
		"perigee_radius_m": a * (1.0 - e),
	}
