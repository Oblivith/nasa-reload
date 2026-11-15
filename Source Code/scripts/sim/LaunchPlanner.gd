# SI assistance metadata: This code used the help of SI.
class_name LaunchPlanner
extends RefCounted

var design: Dictionary
var data: Dictionary
var cfg: Dictionary
var mode: String = "powered"
var kick_deg: float = 5.0
var done: bool = false
var trials: Array = []
var player_set: bool = false

var _lo: float = 0.2
var _hi: float = 45.0
var _target_m: float = 0.0
var _queue: Array = []
var _stage: String = "start"
var _budget: int = 0
var _best_kick: float = 0.0
var _best_score: float = -INF

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

func step() -> bool:
	if done:
		return true
	match mode:
		"lofted", "suborbital":
			_step_lofted()
		_:
			_step_search()
	return done

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

func _score(kick: float) -> float:
	var r := _trial(kick, false)
	var s := 0.0
	var fail := str(r["failure_type"])

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
