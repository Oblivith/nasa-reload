# Code generated with AI assistance (Claude). Reviewed by team.
class_name OrbitMath
extends RefCounted
## Two-body orbital mechanics around Earth. Pure maths: SI units (m, s, m/s), no UI.
## Radii are measured from Earth's centre; use radius_from_altitude_km() to convert.

const MU_EARTH := 3.986e14        ## Earth's gravitational parameter, m^3/s^2
const EARTH_RADIUS_M := 6.371e6   ## Mean Earth radius, m


## Altitude above the surface (km) -> radius from Earth's centre (m).
static func radius_from_altitude_km(altitude_km: float) -> float:
	return EARTH_RADIUS_M + altitude_km * 1000.0


## Circular orbit speed: v = sqrt(mu / r).
static func circular_velocity(r: float, mu: float = MU_EARTH) -> float:
	return sqrt(mu / r)


## Orbital period for semi-major axis a: T = 2*pi*sqrt(a^3 / mu). Seconds.
static func period(a: float, mu: float = MU_EARTH) -> float:
	return TAU * sqrt(a * a * a / mu)


## Vis-viva: speed at radius r on an orbit with semi-major axis a.
## v = sqrt(mu * (2/r - 1/a)). Returns 0 if the radius is not on the orbit.
static func vis_viva(r: float, a: float, mu: float = MU_EARTH) -> float:
	var v_squared := mu * (2.0 / r - 1.0 / a)
	return sqrt(v_squared) if v_squared > 0.0 else 0.0


## Hohmann transfer between two circular orbits r1 -> r2 (either direction).
## Returns both burns (always positive), their sum, and the coast time.
##   dv1 = sqrt(mu/r1) * (sqrt(2*r2/(r1+r2)) - 1)
##   dv2 = sqrt(mu/r2) * (1 - sqrt(2*r1/(r1+r2)))
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


## Plane change at speed v by angle delta_i: dv = 2*v*sin(delta_i / 2).
static func plane_change(v: float, delta_inclination_deg: float) -> float:
	return 2.0 * v * sin(deg_to_rad(delta_inclination_deg) / 2.0)


## Apogee and perigee radii from a state (radius, speed, flight-path angle above the
## local horizontal). Used by the launch sim to read out the achieved orbit.
## Returns {} for an escape trajectory.
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
