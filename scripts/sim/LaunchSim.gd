# Code generated with AI assistance (Claude). Reviewed by team.
class_name LaunchSim
extends RefCounted
## The live launch: a 2D ascent of the player's exact rocket in fixed time steps
## (Sim Spec v2 2.6 / old spec 6.5). Pure maths, no UI: the Mission Control view calls
## step() and listens to the signals; tests call run_to_end().
##
## Per tick:
##   thrust, Isp  blend sea level -> vacuum with ambient pressure (Aero.blend_to_vacuum)
##   mdot         = thrust_vac / (Isp_vac * g0)   (constant per engine)
##   gravity      = mu / r^2 towards Earth's centre
##   density      = 1.225 * e^(-h / 8500)         (Aero.air_density)
##   drag         = 1/2 rho v_air^2 Cd A, against the air-relative velocity
##   steering     vertical -> pitch kick -> gravity turn (nose on the air-relative
##                velocity); upper stages fly horizontal (lofted kick stages) or a
##                linear guidance law towards level flight at the insertion altitude
##   integration  semi-implicit Euler in an Earth-centred inertial plane
## Earth's spin: the pad (and the air) move east at 465 * cos(latitude) m/s, so the
## rocket starts with that speed for free. Staging drops each stage's dry mass. Liquid
## engines cut off once the orbit meets the target; solids burn out. Apogee and perigee
## come from the state vector (vis-viva, OrbitMath.apsides_from_state).
## Failures come only from the physics and seeded reliability rolls: no liftoff (TWR < 1),
## tumbling (static margin not flyable while q is high), break-up (q over the material
## limit, or a roll near it), engine-out and staging failure (rolls).
##
## Coordinates: x east, y up, origin at Earth's centre, the pad at (0, R). Everything in
## SI; signals that carry orbits use km.
##
## Use: var sim := LaunchSim.new(design, data, cfg, {seed = 7})
##      sim.plan_with(kick_deg) (or let LaunchPlanner choose), then step() until done.
##   design: RocketEvaluator format (with "mission"); data: DataLoader.sim_data();
##   cfg: data/launch_sim.json.
##   options: seed (int), reliability (bool, default true), record (telemetry, default
##            true), dt (override), stop_at_loft_apogee (planner), pitch_kick_deg.

signal liftoff
signal tower_cleared
signal max_q(q_pa: float)
signal staging(n: int)
signal seco
signal orbit_achieved(apogee_km: float, perigee_km: float)
signal failure(type: String)
## Every callout-worthy moment (the signals above plus roll_program, pitch_over,
## stage_burnout, ignition, coast, engine_out, apogee, splashdown), with numbers.
signal event(id: String, info: Dictionary)
signal finished(result: Dictionary)

enum Phase { PAD, VERTICAL, PITCH_OVER, GRAVITY_TURN, COAST, BURN, DONE }
enum Steer { ASCENT, HORIZONTAL, POWERED }

const MU := OrbitMath.MU_EARTH
const RE := OrbitMath.EARTH_RADIUS_M
const G0 := RocketMath.G0

var cfg: Dictionary
var report: Dictionary          ## RocketEvaluator report of this design
var mission: Dictionary
var orbital: bool = true
var guidance_mode: String = "powered"   ## "lofted", "powered" or "suborbital"
var kick_deg: float = 5.0
var insertion_alt_m: float = 220000.0
var target_perigee_m: float = 200000.0
var target_apogee_m: float = 200000.0
var dt: float = 0.05
var record: bool = true
var reliability_on: bool = true
var stop_at_loft_apogee: bool = false
var seed_value: int = 0

## Firing order. Each: {name, dry_kg, prop_kg, prop0_kg, thrust_sl, thrust_vac, isp_sl,
## isp_vac, mdot, solid, engines, engines_out, burn_s, fail_at_s, sep_fails, area_m2, cd}
var stages: Array = []
var carried_kg: float = 0.0     ## nose + payload (always on board)
var tower_kg: float = 0.0       ## escape tower, jettisoned at the first staging
var dead_kg: float = 0.0        ## unburned propellant stranded by an engine-out
var stage_index: int = 0
var burning: bool = false
var stage_t: float = 0.0        ## time since the current stage lit

# State (64-bit floats: Vector2 is 32-bit and too coarse at Earth radius).
var t: float = 0.0
var x: float = 0.0
var y: float = RE
var vx: float = 0.0
var vy: float = 0.0
var omega: float = 0.0          ## Earth's spin in this plane, rad/s
var phase: int = Phase.PAD
var steer: int = Steer.ASCENT
var done: bool = false

# Live readouts (updated every step).
var altitude_m: float = 0.0
var speed_ms: float = 0.0       ## inertial
var air_speed_ms: float = 0.0   ## relative to the ground / air
var fpa_deg: float = 90.0       ## inertial flight-path angle above the horizon
var downrange_m: float = 0.0    ## over the ground
var q_pa: float = 0.0
var thrust_n: float = 0.0
var accel_g: float = 0.0
var pitch_deg: float = 90.0     ## heading above the local horizon
var apogee_m: float = 0.0       ## predicted from the current state
var perigee_m: float = -RE

# Records.
var telemetry: Array = []       ## [{t, alt_km, downrange_km, v, v_air, fpa_deg, pitch_deg, mass_kg, q_kpa, thrust_kn, accel_g, stage, fuel: [], apogee_km, perigee_km}]
var events: Array = []          ## [{t, id, info}]
var max_q_pa: float = 0.0
var max_q_t: float = 0.0
var max_q_alt_m: float = 0.0
var max_alt_m: float = 0.0
var max_speed_ms: float = 0.0
var failure_type: String = ""
var cause: String = ""          ## the last anomaly (engine_out) that may explain a short flight
var result: Dictionary = {}

var _rng := RandomNumberGenerator.new()
var _t_liftoff: float = -1.0
var _t_kick: float = 0.0
var _t_coast: float = 0.0
var _pad_t: float = 0.0
var _tower_cleared: bool = false
var _max_q_called: bool = false
var _apogee_called: bool = false
var _next_sample: float = 0.0
var _next_stab_check: float = 0.0
var _q_limit: float = 0.0
var _q_warn: float = 0.85
var _structural_roll: float = 1.0
var _x_cp: float = 0.0
var _diameter: float = 1.0
var _gimballed: bool = false
var _segments: Array = []
var _tumble_q: float = 1500.0
var _seco_called: bool = false
var _loft_apogee_m: float = 0.0
var _loft_horizontal_ms: float = 0.0
var _all_burned: bool = false
var _burn_target_m: float = 0.0
var _max_retarget: float = 500000.0
var _tgo_burnout: bool = true
var _law: String = "vgo"
var _vgo_tau: float = 60.0
var _vgo_tau_g: float = 10.0
var _vgo_max_climb: float = 300.0
var _vgo_min_forward: float = 50.0
# Config cached out of the dictionaries (read every tick).
var _coast_fast_alt: float = 100000.0
var _coast_factor: float = 1.0
var _tel_dt: float = 1.0
var _max_t: float = 4000.0
var _kick_ramp: float = 6.0
var _kick_speed: float = 60.0
var _min_tgo: float = 8.0
var _max_down: float = 0.6
var _max_up: float = 0.9
var _tower_h: float = 40.0
var _ign_delay: float = 2.0
var _max_loft: float = 900.0
var _cutoff_margin: float = 5000.0


func _init(design: Dictionary, data: Dictionary, launch_cfg: Dictionary, options: Dictionary = {}) -> void:
	cfg = launch_cfg
	seed_value = int(options.get("seed", 0))
	_rng.seed = seed_value
	reliability_on = bool(options.get("reliability", true))
	record = bool(options.get("record", true))
	stop_at_loft_apogee = bool(options.get("stop_at_loft_apogee", false))
	dt = float(options.get("dt", cfg.get("dt_s", 0.05)))
	_tumble_q = float(cfg.get("tumble_min_q_pa", 1500.0))
	var gc: Dictionary = cfg.get("guidance", {})
	_coast_fast_alt = float(cfg.get("coast_fast_altitude_m", 100000.0))
	_coast_factor = float(cfg.get("coast_dt_factor", 1.0))
	_tel_dt = float(cfg.get("telemetry_interval_s", 1.0))
	_max_t = float(cfg.get("max_flight_time_s", 4000.0))
	_kick_ramp = maxf(float(gc.get("kick_ramp_s", 6.0)), 0.01)
	_kick_speed = float(gc.get("kick_start_speed_ms", 60.0))
	_min_tgo = float(gc.get("min_time_to_go_s", 8.0))
	_max_down = float(gc.get("max_down_fraction", 0.6))
	_max_up = float(gc.get("max_up_fraction", 0.9))
	_tower_h = float(cfg.get("tower_height_m", 40.0))
	_ign_delay = float(gc.get("upper_ignition_delay_s", 2.0))
	_max_loft = float(gc.get("max_loft_coast_s", 900.0))
	_cutoff_margin = float(gc.get("cutoff_margin_km", 5.0)) * 1000.0
	_max_retarget = float(gc.get("max_retarget_km", 500.0)) * 1000.0
	_tgo_burnout = bool(gc.get("time_to_go_includes_burnout", true))
	_law = str(gc.get("upper_law", "vgo"))
	_vgo_tau = maxf(float(gc.get("vgo_altitude_tau_s", 60.0)), 1.0)
	_vgo_tau_g = float(gc.get("vgo_gravity_tau_s", 10.0))
	_vgo_max_climb = float(gc.get("vgo_max_climb_ms", 300.0))
	_vgo_min_forward = float(gc.get("vgo_min_forward_ms", 50.0))
	report = RocketEvaluator.evaluate(design, data)
	mission = design.get("mission", {})
	_setup_vehicle(design, data)
	_setup_mission(data)
	var guidance: Dictionary = design.get("guidance", {})
	kick_deg = float(options.get("pitch_kick_deg", guidance.get("pitch_kick_deg", default_kick())))
	var rotation: Dictionary = (data.get("delta_v", {}) as Dictionary).get("earth_rotation", {})
	var surface_speed := MissionBudget.rotation_bonus(float(mission.get("latitude_deg", 0.0)),
			float(rotation.get("equator_speed_ms", 465.0)))
	omega = surface_speed / RE
	vx = surface_speed
	vy = 0.0
	_update_readouts()


## The planner's starting guess (the middle of the allowed range).
func default_kick() -> float:
	var g: Dictionary = cfg.get("guidance", {})
	return (float(g.get("kick_min_deg", 0.2)) + float(g.get("kick_max_deg", 45.0))) * 0.25


func mass_kg() -> float:
	var m := carried_kg + tower_kg + dead_kg
	for i in range(stage_index, stages.size()):
		var s: Dictionary = stages[i]
		m += float(s["dry_kg"]) + float(s["prop_kg"])
	return m


## Fraction of propellant left per stage (0 for stages already dropped).
func fuel_fractions() -> Array:
	var out: Array = []
	for i in stages.size():
		var s: Dictionary = stages[i]
		out.append(0.0 if i < stage_index or float(s["prop0_kg"]) <= 0.0 else float(s["prop_kg"]) / float(s["prop0_kg"]))
	return out


## Runs the whole flight (tests, planner). Returns the result.
func run_to_end(max_steps: int = 2000000) -> Dictionary:
	var n := 0
	while not done and n < max_steps:
		step()
		n += 1
	if not done:
		_finish()
	return result


## Advances one tick (dt, or a longer one while coasting high above the air).
func step() -> void:
	if done:
		return
	var h := sqrt(x * x + y * y) - RE
	var h_dt := dt
	if phase == Phase.COAST and h > _coast_fast_alt:
		h_dt = dt * _coast_factor
	_integrate(h_dt)
	_update_readouts()
	_check_events()
	if record and t >= _next_sample:
		_sample()
		_next_sample = t + _tel_dt
	if t > _max_t and not done:
		_finish()


# --- Physics ----------------------------------------------------------------------------

func _integrate(h_dt: float) -> void:
	var r := sqrt(x * x + y * y)
	var h := r - RE
	var ux := x / r
	var uy := y / r
	var ex := uy
	var ey := -ux
	var air_x := omega * y
	var air_y := -omega * x
	var rvx := vx - air_x
	var rvy := vy - air_y
	var rv := sqrt(rvx * rvx + rvy * rvy)
	var m := mass_kg()

	# Engine.
	var thrust := 0.0
	var burned := 0.0
	if burning:
		var s: Dictionary = stages[stage_index]
		var share := float(int(s["engines"]) - int(s["engines_out"])) / float(int(s["engines"]))
		thrust = _stage_thrust(s, h) * share
		burned = minf(float(s["mdot"]) * share * h_dt, float(s["prop_kg"]))

	# Steering.
	var hx := ux
	var hy := uy
	match steer:
		Steer.ASCENT:
			if phase == Phase.PITCH_OVER:
				var tilt := deg_to_rad(kick_deg) * minf(1.0, (t - _t_kick) / _kick_ramp)
				hx = ux * cos(tilt) + ex * sin(tilt)
				hy = uy * cos(tilt) + ey * sin(tilt)
			elif phase == Phase.GRAVITY_TURN and rv > 1.0:
				hx = rvx / rv
				hy = rvy / rv
		Steer.HORIZONTAL:
			hx = ex
			hy = ey
		Steer.POWERED:
			var burn_left := INF
			if burning and burned > 0.0:
				burn_left = float((stages[stage_index] as Dictionary)["prop_kg"]) / burned * h_dt
			var d := _powered_heading(r, ux, uy, ex, ey, thrust / m, burn_left)
			hx = d.x
			hy = d.y
	pitch_deg = rad_to_deg(asin(clampf(hx * ux + hy * uy, -1.0, 1.0)))

	# Forces.
	var g := MU / (r * r)
	var rho := Aero.air_density(h)
	var area := 0.0
	var cd := 0.0
	if stage_index < stages.size():
		area = float((stages[stage_index] as Dictionary)["area_m2"])
		cd = float((stages[stage_index] as Dictionary)["cd"])
	var drag := 0.5 * rho * rv * rv * cd * area
	var ax := thrust * hx / m - g * ux
	var ay := thrust * hy / m - g * uy
	if rv > 0.0:
		ax -= drag / m * rvx / rv
		ay -= drag / m * rvy / rv
	thrust_n = thrust
	accel_g = sqrt(pow(ax + g * ux, 2.0) + pow(ay + g * uy, 2.0)) / G0

	if phase == Phase.PAD:
		# Held down until thrust beats weight; the pad turns with the Earth.
		if burning and thrust > m * g:
			phase = Phase.VERTICAL
			_t_liftoff = t
			_emit("liftoff", {})
			liftoff.emit()
		else:
			_pad_t += h_dt
			_burn(burned, h_dt)
			t += h_dt
			var turn := omega * h_dt
			var nx := x * cos(turn) + y * sin(turn)
			var ny := -x * sin(turn) + y * cos(turn)
			x = nx
			y = ny
			vx = omega * y
			vy = -omega * x
			if _pad_t >= float(cfg.get("pad_hold_s", 3.0)):
				_fail("no_liftoff")
			return

	# Heun's method (2nd order): forces again at the predicted end of the step, with
	# the steering held and the propellant burned. Euler drifted ~5% in apogee between
	# a 0.25 s and a 0.05 s step; this keeps the planner's coarse runs honest.
	var px := x + vx * h_dt
	var py := y + vy * h_dt
	var pvx := vx + ax * h_dt
	var pvy := vy + ay * h_dt
	var a2 := _accel_at(px, py, pvx, pvy, m - burned, thrust, hx, hy, cd, area)
	x += (vx + pvx) * 0.5 * h_dt
	y += (vy + pvy) * 0.5 * h_dt
	vx += (ax + a2.x) * 0.5 * h_dt
	vy += (ay + a2.y) * 0.5 * h_dt
	_burn(burned, h_dt)
	t += h_dt


## Acceleration at a state: thrust along the held heading, gravity, drag on the air speed.
func _accel_at(px: float, py: float, pvx: float, pvy: float, m: float, thrust: float,
		hx: float, hy: float, cd: float, area: float) -> Vector2:
	var r := sqrt(px * px + py * py)
	var g := MU / (r * r)
	var rvx := pvx - omega * py
	var rvy := pvy + omega * px
	var rv := sqrt(rvx * rvx + rvy * rvy)
	var ax := thrust * hx / m - g * px / r
	var ay := thrust * hy / m - g * py / r
	if rv > 0.0:
		var k := 0.5 * Aero.air_density(r - RE) * rv * cd * area / m
		ax -= k * rvx
		ay -= k * rvy
	return Vector2(ax, ay)


func _stage_thrust(s: Dictionary, h: float) -> float:
	var vac := float(s["thrust_vac"])
	var sl := float(s["thrust_sl"])
	if sl > 0.0:
		return Aero.blend_to_vacuum(sl, vac, h)
	# Vacuum-only nozzle: no thrust at sea level, full thrust in vacuum.
	return vac * (1.0 - exp(-maxf(h, 0.0) / Aero.SCALE_HEIGHT_M))


func _burn(burned: float, h_dt: float) -> void:
	if not burning:
		return
	var s: Dictionary = stages[stage_index]
	s["prop_kg"] = maxf(float(s["prop_kg"]) - burned, 0.0)
	stage_t += h_dt


## Linear guidance (vacuum upper stages): the vertical acceleration that brings the
## climb rate to zero at the insertion altitude by the time the stage reaches orbital
## speed (or runs dry, whichever comes first), a0 = 6 (r_t - r) / t_go^2 - 4 v_up / t_go,
## plus gravity minus centrifugal lift. It may not dive steeply (max_down_fraction): a
## stage that arrives high and climbing flies level instead, which wastes far less.
##
## "vgo" law (default): thrust along the velocity still to be gained, from the current
## velocity to a level circular orbit right here, v_go = (v_circ(r) - v_h, v_up_wanted -
## v_up + (g - v_h^2/r) * tau_g), where v_up_wanted = (r_t - r) / tau gently steers
## towards the insertion altitude and the last term holds up against gravity.
func _powered_heading(r: float, ux: float, uy: float, ex: float, ey: float, a_t: float, burn_left: float) -> Vector2:
	var v_up := vx * ux + vy * uy
	var v_h := vx * ex + vy * ey
	var r_t := RE + _burn_target_m
	if _law == "vgo":
		var v_c := sqrt(MU / r)
		var want_up := clampf((r_t - r) / _vgo_tau, -_vgo_max_climb, _vgo_max_climb)
		var gu := want_up - v_up + (MU / (r * r) - v_h * v_h / r) * _vgo_tau_g
		var gx := maxf(v_c - v_h, _vgo_min_forward)
		var n := sqrt(gx * gx + gu * gu)
		var su := clampf(gu / n, -_max_up, _max_up)
		var cu := sqrt(1.0 - su * su)
		return Vector2(ex * cu + ux * su, ey * cu + uy * su)
	var v_t := sqrt(MU / r_t)
	var t_go := (v_t - v_h) / maxf(a_t, 0.01)
	if _tgo_burnout:
		t_go = burn_left if v_h >= v_t else minf(t_go, burn_left)
	t_go = maxf(t_go, _min_tgo)
	var a0 := 6.0 * (r_t - r) / (t_go * t_go) - 4.0 * v_up / t_go
	var need := a0 + MU / (r * r) - v_h * v_h / r
	var s := clampf(need / maxf(a_t, 0.01), -_max_down, _max_up)
	var c := sqrt(1.0 - s * s)
	return Vector2(ex * c + ux * s, ey * c + uy * s)


# --- Events -----------------------------------------------------------------------------

func _check_events() -> void:
	if done:
		return
	if phase == Phase.PAD:
		return

	if not _tower_cleared and altitude_m >= _tower_h:
		_tower_cleared = true
		_emit("tower_cleared", {})
		tower_cleared.emit()
		_emit("roll_program", {})

	if phase == Phase.VERTICAL and kick_deg > 0.0 and air_speed_ms >= _kick_speed:
		phase = Phase.PITCH_OVER
		_t_kick = t
		_emit("pitch_over", {"kick_deg": kick_deg})
	elif phase == Phase.PITCH_OVER:
		var ramp := _kick_ramp
		if (90.0 - _air_fpa_deg()) >= kick_deg * 0.98 or t - _t_kick > ramp * 4.0:
			phase = Phase.GRAVITY_TURN

	# Max-Q: called once q has clearly passed its peak.
	if q_pa > max_q_pa and (burning or _v_up() > 0.0):
		max_q_pa = q_pa
		max_q_t = t
		max_q_alt_m = altitude_m
	# Ascent loads only: a falling stage or capsule on the way back down is not the
	# rocket's structure being tested (re-entry is its own sequence).
	var ascending := burning or _v_up() > 0.0
	if ascending and q_pa > _q_limit and _q_limit > 0.0:
		_fail("structural")
		return
	if not _max_q_called and max_q_pa > 1000.0 and q_pa < max_q_pa * 0.95:
		_max_q_called = true
		_emit("max_q", {"q_kpa": max_q_pa / 1000.0})
		max_q.emit(max_q_pa)
		if reliability_on and max_q_pa > _q_limit * _q_warn and _q_limit > 0.0:
			var p := float((cfg.get("reliability", {}) as Dictionary).get("structural_roll_max", 0.5)) \
					* (max_q_pa / _q_limit - _q_warn) / maxf(1.0 - _q_warn, 0.01)
			if _structural_roll < p:
				_fail("structural")
				return

	# Stability: only the first stage carries fins, and only thick air can tumble it.
	if ascending and stage_index == 0 and q_pa > _tumble_q and t >= _next_stab_check:
		_next_stab_check = t + 0.5
		var margin := current_static_margin()
		if not bool(Stability.classify(margin, _gimballed)["flyable"]):
			_fail("unstable")
			return

	if altitude_m > max_alt_m:
		max_alt_m = altitude_m
	max_speed_ms = maxf(max_speed_ms, speed_ms)

	# Burning stage.
	if burning:
		var s: Dictionary = stages[stage_index]
		if float(s["fail_at_s"]) >= 0.0 and stage_t >= float(s["fail_at_s"]) and int(s["engines_out"]) == 0:
			_engine_out(s)
		if done:
			return
		if float(s["prop_kg"]) <= 0.0:
			_stage_burnout()
			return
		if orbital and not bool(s["solid"]) and _orbit_meets_target():
			# Liquid engines shut down once the orbit is good enough.
			burning = false
			_seco()
			return

	# Coasting.
	if phase == Phase.COAST:
		var v_up := _v_up()
		if _all_burned:
			# Everything burned: a ballistic arc over the top and down.
			if not _apogee_called and v_up <= 0.0:
				_apogee_called = true
				_emit("apogee", {"altitude": "%.0f" % (altitude_m / 1000.0)})
				if stop_at_loft_apogee:
					_finish()
					return
			if altitude_m <= 0.0 and _t_liftoff >= 0.0:
				_emit("splashdown", {"downrange": "%.0f" % (downrange_m / 1000.0)})
				_finish()
		elif guidance_mode == "lofted" and stage_index >= 2 and stage_index < stages.size():
			# The next kick stage fires straight after the one before it.
			if t - _t_coast >= _ign_delay:
				_ignite(Steer.HORIZONTAL)
		elif guidance_mode == "lofted" and stage_index == 1:
			if v_up <= 0.0 or t - _t_coast > _max_loft:
				if stage_index == 1 and _loft_apogee_m <= 0.0:
					_loft_apogee_m = altitude_m
					_loft_horizontal_ms = _v_h()
					if stop_at_loft_apogee:
						_finish()
						return
				_ignite(Steer.HORIZONTAL)
		elif stage_index < stages.size():
			if t - _t_coast >= _ign_delay:
				_ignite(Steer.POWERED)


func _engine_out(s: Dictionary) -> void:
	var n := int(s["engines"])
	s["engines_out"] = 1
	cause = "engine_out"
	_emit("engine_out", {"stage": stage_index + 1, "engines_left": n - 1})
	if n <= 1:
		# The only engine: the stage is finished, its propellant is dead weight.
		dead_kg += float(s["prop_kg"])
		s["prop_kg"] = 0.0
	elif bool(s["solid"]):
		# A cluster of solids loses that motor's share of propellant.
		var lost := float(s["prop_kg"]) / float(n)
		s["prop_kg"] = float(s["prop_kg"]) - lost
		dead_kg += lost


func _stage_burnout() -> void:
	burning = false
	_emit("stage_burnout", {"stage": stage_index + 1})
	if stage_index >= stages.size() - 1:
		_seco()
		return
	var s: Dictionary = stages[stage_index]
	if bool(s["sep_fails"]):
		_fail("staging")
		return
	dead_kg = 0.0
	stage_index += 1
	tower_kg = 0.0
	_emit("staging", {"stage": stage_index})
	staging.emit(stage_index)
	phase = Phase.COAST
	_t_coast = t
	if guidance_mode == "lofted" and stage_index == 1:
		_emit("coast", {})


func _ignite(mode: int) -> void:
	steer = mode
	phase = Phase.BURN
	burning = true
	stage_t = 0.0
	# A stage that lights while still climbing aims at the top of its coast arc
	# (capped) instead of diving back down to the insertion altitude.
	_burn_target_m = insertion_alt_m
	if mode == Steer.POWERED and apogee_m < INF:
		_burn_target_m = clampf(apogee_m, insertion_alt_m, insertion_alt_m + _max_retarget)
	_emit("ignition", {"stage": stage_index + 1})


## Final cutoff (liquid shutdown or the last stage burning out): read the orbit.
func _seco() -> void:
	if _seco_called:
		return
	_seco_called = true
	burning = false
	_emit("seco", {})
	seco.emit()
	if stop_at_loft_apogee and orbital:
		_finish()
		return
	var min_perigee := float(cfg.get("orbit_min_perigee_km", 150.0)) * 1000.0
	if orbital:
		if perigee_m >= min_perigee:
			_emit("orbit_achieved", {"apogee": "%.0f" % (apogee_m / 1000.0), "perigee": "%.0f" % (perigee_m / 1000.0)})
			orbit_achieved.emit(apogee_m / 1000.0, perigee_m / 1000.0)
			_finish()
		else:
			_fail(cause if cause != "" else "no_orbit")
		return
	# Suborbital: coast over the top and down.
	phase = Phase.COAST
	_all_burned = true
	_t_coast = t


func _fail(type: String) -> void:
	if done:
		return
	failure_type = type
	burning = false
	_emit("failure_" + type, {})
	failure.emit(type)
	_finish()


func _finish() -> void:
	if done:
		return
	done = true
	phase = Phase.DONE
	if record:
		_sample()
	var left_kg := 0.0
	var left_dv := 0.0
	if stage_index < stages.size() and failure_type == "":
		var m := mass_kg()
		for i in range(stage_index, stages.size()):
			var s: Dictionary = stages[i]
			var prop := float(s["prop_kg"])
			left_kg += prop
			left_dv += RocketMath.stage_delta_v(float(s["isp_vac"]), m, m - prop)
			m -= float(s["dry_kg"]) + prop
	var in_orbit := orbital and failure_type == "" and perigee_m >= float(cfg.get("orbit_min_perigee_km", 150.0)) * 1000.0
	result = {
		"orbital_mission": orbital,
		"in_orbit": in_orbit,
		"failure_type": failure_type,
		"cause": cause,
		"apogee_km": apogee_m / 1000.0,
		"perigee_km": perigee_m / 1000.0,
		"max_altitude_km": max_alt_m / 1000.0,
		"downrange_km": downrange_m / 1000.0,
		"max_speed_ms": max_speed_ms,
		"final_speed_ms": speed_ms,
		"max_q_pa": max_q_pa,
		"max_q_time_s": max_q_t,
		"max_q_altitude_km": max_q_alt_m / 1000.0,
		"q_limit_pa": _q_limit,
		"q_warn_fraction": _q_warn,
		"flight_time_s": t - maxf(_t_liftoff, 0.0),
		"kick_deg": kick_deg,
		"guidance": guidance_mode,
		"insertion_altitude_km": insertion_alt_m / 1000.0,
		"loft_apogee_km": _loft_apogee_m / 1000.0,
		"loft_horizontal_ms": _loft_horizontal_ms,
		"propellant_left_kg": left_kg,
		"delta_v_left_ms": left_dv,
		"stages_used": mini(stage_index + 1, stages.size()),
		"seed": seed_value,
		"events": events,
		"telemetry": telemetry,
	}
	finished.emit(result)


# --- Readouts ---------------------------------------------------------------------------

func _update_readouts() -> void:
	var r := sqrt(x * x + y * y)
	altitude_m = r - RE
	speed_ms = sqrt(vx * vx + vy * vy)
	var rvx := vx - omega * y
	var rvy := vy + omega * x
	air_speed_ms = sqrt(rvx * rvx + rvy * rvy)
	var v_up := _v_up()
	fpa_deg = rad_to_deg(asin(clampf(v_up / maxf(speed_ms, 0.001), -1.0, 1.0)))
	var theta := atan2(x, y)
	downrange_m = RE * (theta - omega * t)  # over the ground: the pad has turned omega * t
	q_pa = Aero.dynamic_pressure(Aero.air_density(altitude_m), air_speed_ms)
	# Vis-viva apsides (same maths as OrbitMath.apsides_from_state, inlined: every tick).
	var energy := speed_ms * speed_ms / 2.0 - MU / r
	if energy >= 0.0:
		apogee_m = INF
		perigee_m = INF
	else:
		var a := -MU / (2.0 * energy)
		var h_ang := x * vy - y * vx
		var e := sqrt(maxf(0.0, 1.0 - h_ang * h_ang / (MU * a)))
		apogee_m = a * (1.0 + e) - RE
		perigee_m = a * (1.0 - e) - RE


func _sample() -> void:
	telemetry.append({
		"t": t - maxf(_t_liftoff, 0.0),
		"alt_km": altitude_m / 1000.0,
		"downrange_km": downrange_m / 1000.0,
		"v": speed_ms,
		"v_air": air_speed_ms,
		"fpa_deg": fpa_deg,
		"pitch_deg": pitch_deg,
		"mass_kg": mass_kg(),
		"q_kpa": q_pa / 1000.0,
		"thrust_kn": thrust_n / 1000.0,
		"accel_g": accel_g,
		"stage": mini(stage_index + 1, stages.size()),
		"fuel": fuel_fractions(),
		"apogee_km": apogee_m / 1000.0,
		"perigee_km": perigee_m / 1000.0,
	})


func _emit(id: String, info: Dictionary) -> void:
	info["t"] = t - maxf(_t_liftoff, 0.0)
	info["alt_km"] = altitude_m / 1000.0
	info["v"] = speed_ms
	events.append({"t": info["t"], "id": id, "info": info})
	event.emit(id, info)


## Mission elapsed time (T+, from liftoff; negative before it).
func met() -> float:
	return t - _t_liftoff if _t_liftoff >= 0.0 else 0.0


## Static margin right now: the first stage's CG moves forward as it drains.
func current_static_margin() -> float:
	var frac := 1.0
	if not stages.is_empty():
		var s: Dictionary = stages[0]
		frac = float(s["prop_kg"]) / maxf(float(s["prop0_kg"]), 0.001)
	var mass := 0.0
	var moment := 0.0
	for seg: Dictionary in _segments:
		var m := float(seg["dry_mass_kg"])
		var prop := float(seg["propellant_mass_kg"])
		m += prop * frac if int(seg["stage"]) == 0 else prop
		mass += m
		moment += m * float(seg["cg_x_m"])
	var x_cg := moment / mass if mass > 0.0 else 0.0
	return Stability.static_margin(_x_cp, x_cg, _diameter)


func _v_up() -> float:
	var r := sqrt(x * x + y * y)
	return (vx * x + vy * y) / r


func _v_h() -> float:
	var r := sqrt(x * x + y * y)
	return (vx * y - vy * x) / r


func _air_fpa_deg() -> float:
	var r := sqrt(x * x + y * y)
	var rvx := vx - omega * y
	var rvy := vy + omega * x
	var rv := sqrt(rvx * rvx + rvy * rvy)
	return rad_to_deg(asin(clampf((rvx * x + rvy * y) / r / maxf(rv, 0.001), -1.0, 1.0)))


func _orbit_meets_target() -> bool:
	var margin := _cutoff_margin
	return perigee_m >= target_perigee_m + margin and apogee_m >= target_apogee_m


# --- Setup ------------------------------------------------------------------------------

func _setup_vehicle(design: Dictionary, data: Dictionary) -> void:
	var numbers: Dictionary = report.get("numbers", {})
	var geometry: Dictionary = report.get("geometry", {})
	_segments = geometry.get("segments", [])
	var design_stages: Array = design.get("stages", [])
	var masses := RocketGeometry.stage_masses(_segments, design_stages.size())
	for seg: Dictionary in _segments:
		if int(seg["stage"]) < 0:
			if str(seg["kind"]) == "escape_tower":
				tower_kg += float(seg["dry_mass_kg"])
			else:
				carried_kg += float(seg["dry_mass_kg"])
	_q_limit = float(numbers.get("q_limit_pa", 0.0))
	_q_warn = float((data.get("q_limit_model", {}) as Dictionary).get("warn_fraction", 0.85))
	_x_cp = float(numbers.get("x_cp_m", 0.0))
	_diameter = float(numbers.get("diameter_m", 1.0))
	_gimballed = bool(numbers.get("gimballed", false))
	var rel: Dictionary = cfg.get("reliability", {})
	var engines_table: Dictionary = data.get("engines", {})
	var nose_shapes: Dictionary = data.get("nose_shapes", {})
	var upper_cd := float((nose_shapes.get(str((design.get("nose", {}) as Dictionary).get("shape", "")), {}) as Dictionary).get("base_cd", 0.5))
	_structural_roll = _rng.randf()
	for i in design_stages.size():
		var st: Dictionary = design_stages[i]
		var engine: Dictionary = st.get("engine", {})
		var body: Dictionary = st.get("body", {})
		var entry: Dictionary = engines_table.get(str(engine.get("engine_id", "")), {})
		var count := maxi(int(engine.get("count", 1)), 1)
		var isp_vac := _num(engine, "isp_vac")
		var thrust_vac := _num(engine, "thrust_vac_N") * count
		var propellant := str(engine.get("propellant", entry.get("propellant", "")))
		var solid := propellant == "solid"
		var reliability := float(engine.get("reliability", entry.get("reliability",
				rel.get("default_solid_motor" if solid else "default_engine", 0.97))))
		var m: Dictionary = masses[i]
		var prop := float(m["propellant_mass_kg"])
		var mdot := thrust_vac / (isp_vac * G0) if isp_vac > 0.0 else 0.0
		var burn_s := prop / mdot if mdot > 0.0 else 0.0
		# Reliability: one roll per engine; the first failure decides when it quits.
		var fail_at := -1.0
		var sep_fails := false
		if reliability_on:
			for e in count:
				if _rng.randf() > reliability:
					fail_at = _rng.randf() * burn_s
					break
			sep_fails = i < design_stages.size() - 1 and _rng.randf() > float(rel.get("separation", 0.99))
		# The widest body from this stage up meets the air; fins only on the first stage.
		var widest := 0.0
		for j in range(i, design_stages.size()):
			widest = maxf(widest, float(((design_stages[j] as Dictionary).get("body", {}) as Dictionary).get("diameter_m", 0.0)))
		stages.append({
			"name": str(engine.get("name", entry.get("name", "Stage %d" % (i + 1)))),
			"dry_kg": float(m["dry_mass_kg"]),
			"prop_kg": prop,
			"prop0_kg": prop,
			"thrust_sl": _num(engine, "thrust_sl_N") * count,
			"thrust_vac": thrust_vac,
			"isp_sl": _num(engine, "isp_sl"),
			"isp_vac": isp_vac,
			"mdot": mdot,
			"solid": solid,
			"engines": count,
			"engines_out": 0,
			"burn_s": burn_s,
			"fail_at_s": fail_at,
			"sep_fails": sep_fails,
			"area_m2": float(numbers.get("reference_area_m2", Aero.reference_area(widest))) if i == 0 else Aero.reference_area(widest),
			"cd": float(numbers.get("cd", upper_cd)) if i == 0 else upper_cd,
			"diameter_m": float(body.get("diameter_m", 0.0)),
		})
	if not stages.is_empty():
		burning = true


func _setup_mission(data: Dictionary) -> void:
	var g_cfg: Dictionary = cfg.get("guidance", {})
	var profile := str(mission.get("profile", ""))
	orbital = profile != "suborbital"
	target_perigee_m = float(mission.get("target_perigee_km", mission.get("target_altitude_km", 200.0))) * 1000.0
	target_apogee_m = float(mission.get("target_apogee_km", target_perigee_m / 1000.0)) * 1000.0
	if mission.has("insertion_altitude_km"):
		insertion_alt_m = float(mission["insertion_altitude_km"]) * 1000.0
	else:
		insertion_alt_m = target_perigee_m + float(g_cfg.get("insertion_margin_km", 20.0)) * 1000.0
	if not orbital:
		guidance_mode = "suborbital"
		return
	# Same "lofted" rule as the paper loss model (delta_v_map.json loss_model.lofted).
	var lofted: Dictionary = ((data.get("delta_v", {}) as Dictionary).get("loss_model", {}) as Dictionary).get("lofted", {})
	var ok := stages.size() > 1 and not lofted.is_empty() \
			and float(report.get("numbers", {}).get("liftoff_mass_kg", 0.0)) <= float(lofted.get("max_liftoff_mass_kg", 0.0))
	var above := carried_kg
	for i in range(stages.size() - 1, 0, -1):
		var s: Dictionary = stages[i]
		above += float(s["dry_kg"]) + float(s["prop_kg"])
		if RocketMath.twr(float(s["thrust_vac"]), above) < float(lofted.get("min_upper_stage_twr", INF)):
			ok = false
	guidance_mode = "lofted" if ok else "powered"


static func _num(source: Dictionary, key: String) -> float:
	var value: Variant = source.get(key, 0.0)
	return 0.0 if value == null else float(value)
