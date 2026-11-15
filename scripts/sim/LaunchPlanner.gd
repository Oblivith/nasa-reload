# Code generated with AI assistance (Claude). Reviewed by team.
class_name LaunchPlanner
extends RefCounted
## Works out the pitch program (the pitch-kick angle) for a design before launch, the
## way a 1960s guidance team flew trajectories on the computer first. Pure sim, no UI.
## It flies the real LaunchSim many times (no reliability rolls, coarse time step) and
## keeps the best kick for the mission:
##   lofted     (kick-stage rockets like Juno): bisection for the kick whose coast apogee
##              is the insertion altitude. Apogee falls as the kick grows, so the answer
##              is the flattest climb that still gets that high.
##   powered    (normal upper stages): grid then golden-section search for the most
##              propellant left at cutoff (or, short of orbit, the highest perigee).
##   suborbital (single hop): the same bisection on the peak altitude: the flattest
##              climb that still reaches the mission's target altitude.
## A design that carries guidance.pitch_kick_deg (Flight Director) is flown as given.
##
## Use: var p := LaunchPlanner.new(design, data, cfg); while not p.step(): pass
##      (one trial flight per step() call, so a UI can spread it over frames), then p.kick_deg.

var design: Dictionary
var data: Dictionary
var cfg: Dictionary
var mode: String = "powered"
var kick_deg: float = 5.0
var done: bool = false
var trials: Array = []          ## [{kick_deg, score, result summary}]
var player_set: bool = false

var _lo: float = 0.2
var _hi: float = 45.0
var _target_m: float = 0.0
var _queue: Array = []          ## kicks still to try in the grid stage
var _stage: String = "start"
var _budget: int = 0
var _best_kick: float = 0.0
var _best_score: float = -INF
# Golden-section state.
var _a: float = 0.0
var _b: float = 0.0
var _c: float = 0.0
var _d: float = 0.0
var _fc: float = 0.0
var _fd: float = 0.0

const GOLDEN := 0.6180339887


func _init(p_design: Dictionary, p_data: Dictionary, p_cfg: Dictionary) -> void:
	design = p_design
	data = p_data
	cfg = p_cfg
	var g: Dictionary = cfg.get("guidance", {})
	_lo = float(g.get("kick_min_deg", 0.2))
	_hi = float(g.get("kick_max_deg", 45.0))
	var probe := LaunchSim.new(design, data, cfg, {"reliability": false, "record": false})
	mode = probe.guidance_mode
	_target_m = probe.insertion_alt_m if mode != "suborbital" else probe.target_perigee_m
	kick_deg = probe.default_kick()
	var guidance: Dictionary = design.get("guidance", {})
	if guidance.has("pitch_kick_deg"):
		kick_deg = float(guidance["pitch_kick_deg"])
		player_set = true
		done = true


## Runs one trial flight. Returns true when the plan is finished.
func step() -> bool:
	if done:
		return true
	match mode:
		"lofted", "suborbital":
			_step_lofted()
		_:
			_step_search()
	return done


## Runs the whole plan at once (tests, headless).
func run() -> float:
	while not step():
		pass
	return kick_deg


func _trial(kick: float, loft_only: bool) -> Dictionary:
	var sim := LaunchSim.new(design, data, cfg, {
		"reliability": false, "record": false, "pitch_kick_deg": kick,
		"dt": float(cfg.get("dt_s", 0.1)),
		"stop_at_loft_apogee": loft_only})
	var r := sim.run_to_end()
	trials.append({"kick_deg": kick, "apogee_km": r["apogee_km"], "perigee_km": r["perigee_km"],
			"loft_apogee_km": r["loft_apogee_km"], "failure": r["failure_type"],
			"downrange_km": r["downrange_km"], "dv_left_ms": r["delta_v_left_ms"]})
	return r


# --- Lofted: bisection on the coast apogee ------------------------------------------

func _loft_apogee(kick: float) -> float:
	var r := _trial(kick, true)
	if str(r["failure_type"]) != "":
		return -INF
	var loft := float(r["loft_apogee_km"]) * 1000.0
	return loft if loft > 0.0 else float(r["max_altitude_km"]) * 1000.0


func _step_lofted() -> void:
	var g: Dictionary = cfg.get("guidance", {})
	match _stage:
		"start":
			# The most vertical climb: if even that cannot reach the insertion
			# altitude, fly it anyway (the debrief will show why).
			if _loft_apogee(_lo) < _target_m:
				kick_deg = _lo
				done = true
				return
			_stage = "hi"
		"hi":
			if _loft_apogee(_hi) >= _target_m:
				kick_deg = _hi
				done = true
				return
			_budget = int(g.get("plan_grid", 10)) + int(g.get("plan_refine", 8))
			_stage = "bisect"
		"bisect":
			var mid := (_lo + _hi) * 0.5
			if _loft_apogee(mid) >= _target_m:
				_lo = mid
			else:
				_hi = mid
			_budget -= 1
			if _budget <= 0:
				kick_deg = _lo
				done = true


# --- Powered / suborbital: grid, then golden section ---------------------------------

func _score(kick: float) -> float:
	var r := _trial(kick, false)
	var s := 0.0
	var fail := str(r["failure_type"])
	# A plan that only just survives Max-Q is not a plan: keep a margin under the limit.
	var q_margin := float((cfg.get("guidance", {}) as Dictionary).get("q_margin_fraction", 0.9))
	var q_tight := float(r["q_limit_pa"]) > 0.0 and float(r["max_q_pa"]) > float(r["q_limit_pa"]) * q_margin
	if fail in ["structural", "unstable", "no_liftoff", "staging"]:
		s = -1.0e6 - kick
	elif q_tight:
		s = -5.0e5 - kick
	elif mode == "suborbital":
		s = float(r["downrange_km"])
	elif bool(r["in_orbit"]):
		s = 1.0e5 + float(r["delta_v_left_ms"])
	else:
		s = maxf(float(r["perigee_km"]), -10000.0)
	if s > _best_score:
		_best_score = s
		_best_kick = kick
	return s


func _step_search() -> void:
	var g: Dictionary = cfg.get("guidance", {})
	match _stage:
		"start":
			var n := maxi(int(g.get("plan_grid", 10)), 3)
			for i in n:
				_queue.append(lerpf(_lo, _hi, float(i) / float(n - 1)))
			_stage = "grid"
		"grid":
			_score(float(_queue.pop_front()))
			if _queue.is_empty():
				var step_size := (_hi - _lo) / float(maxi(int(g.get("plan_grid", 10)), 3) - 1)
				_a = maxf(_lo, _best_kick - step_size)
				_b = minf(_hi, _best_kick + step_size)
				_c = _b - GOLDEN * (_b - _a)
				_d = _a + GOLDEN * (_b - _a)
				_budget = int(g.get("plan_refine", 8))
				_stage = "golden_c"
		"golden_c":
			_fc = _score(_c)
			_stage = "golden_d"
		"golden_d":
			_fd = _score(_d)
			_stage = "golden"
		"golden":
			if _fc > _fd:
				_b = _d
				_d = _c
				_fd = _fc
				_c = _b - GOLDEN * (_b - _a)
				_fc = _score(_c)
			else:
				_a = _c
				_c = _d
				_fc = _fd
				_d = _a + GOLDEN * (_b - _a)
				_fd = _score(_d)
			_budget -= 1
			if _budget <= 0:
				kick_deg = _best_kick
				done = true
