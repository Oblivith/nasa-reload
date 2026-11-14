# Code generated with AI assistance (Claude). Reviewed by team.
extends Node
## Sim test scene. Run from the editor (open scenes/tests/sim_tests.tscn, press F6) or
## headless:  godot --headless --path . res://scenes/tests/sim_tests.tscn
## Prints every check and exits with code 1 if any assertion is outside tolerance.
##
## Where the expected numbers come from:
## - Tsiolkovsky, TWR, burn time, orbit speed/period: hand-calculated, working shown below.
## - Hohmann 200 -> 400 km: old Sim Spec section 7 worked example (58 + 57 m/s).
## - Barrowman: the equations are from James Barrowman, "Calculating the Center of
##   Pressure of a Model Rocket" (Centuri TIR-33), as given in Sim Spec v2 section 2.1.
##   Two checks: (a) the rectangular-fin result from Apogee "Peak of Flight" Newsletter 18
##   (a fin with root chord = tip chord = 3 in has its CP 0.75 in behind the leading edge,
##   on the quarter-chord line), and (b) a typical 25 mm model rocket worked BY HAND from
##   the TIR-33 equations. (b) is not a number copied out of a textbook: the research team
##   should cross-check it in OpenRocket or the rocketmime.com Barrowman spreadsheet.

const TOLERANCE := 0.02  # 2%

var _passed := 0
var _failed := 0


func _ready() -> void:
	print("\n================ SIM TESTS ================")
	_test_tsiolkovsky()
	_test_twr_and_burn_time()
	_test_orbit_math()
	_test_hohmann()
	_test_barrowman()
	_test_stability_rules()
	_test_mission_budget()
	_test_aero()
	_test_redstone_reference()
	_test_easy_presets()
	print("\n================ RESULT: %d passed, %d failed ================" % [_passed, _failed])
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1 if _failed > 0 else 0)


# --- Tests ----------------------------------------------------------------------------

func _test_tsiolkovsky() -> void:
	_section("Tsiolkovsky (hand-calculated)")
	# Isp 300 s, 10,000 kg -> 2,500 kg: 300 * 9.80665 * ln(4) = 2941.995 * 1.386294 = 4078.5 m/s
	_expect_close("single stage dv", RocketMath.stage_delta_v(300.0, 10000.0, 2500.0), 4078.5, "m/s")
	# Two stages + 1,000 kg payload:
	#   stage 1: Isp 280, dry 4,000, prop 40,000 -> m0 54,000, mf 14,000
	#            280 * 9.80665 * ln(3.857143) = 2745.862 * 1.349927 = 3706.7 m/s
	#   stage 2: Isp 310, dry 1,000, prop 8,000 -> m0 10,000, mf 2,000
	#            310 * 9.80665 * ln(5) = 3040.062 * 1.609438 = 4892.8 m/s
	var stack := RocketMath.total_delta_v([
		{"isp_s": 280.0, "dry_mass_kg": 4000.0, "propellant_mass_kg": 40000.0},
		{"isp_s": 310.0, "dry_mass_kg": 1000.0, "propellant_mass_kg": 8000.0},
	], 1000.0)
	var stack_stages: Array = stack["stages"]
	_expect_close("two-stage: stage 1 dv", float((stack_stages[0] as Dictionary)["delta_v_ms"]), 3706.7, "m/s")
	_expect_close("two-stage: stage 2 dv", float((stack_stages[1] as Dictionary)["delta_v_ms"]), 4892.8, "m/s")
	_expect_close("two-stage: total dv", float(stack["total_ms"]), 8599.5, "m/s")
	_expect_true("no propellant gives zero dv", RocketMath.stage_delta_v(300.0, 1000.0, 1000.0) == 0.0)


func _test_twr_and_burn_time() -> void:
	_section("TWR and burn time (hand-calculated)")
	# 350,000 N / (30,000 kg * 9.80665) = 1.1897
	_expect_close("TWR", RocketMath.twr(350000.0, 30000.0), 1.1897, "")
	# 23,600 kg * 215 s * 9.80665 / 350,000 N = 142.17 s
	_expect_close("burn time", RocketMath.burn_time(23600.0, 215.0, 350000.0), 142.17, "s")
	# 350,000 / (215 * 9.80665) = 166.0 kg/s
	_expect_close("mass flow", RocketMath.mass_flow(350000.0, 215.0), 166.0, "kg/s")


func _test_orbit_math() -> void:
	_section("Orbit maths (hand-calculated)")
	var r200 := OrbitMath.radius_from_altitude_km(200.0)
	var r400 := OrbitMath.radius_from_altitude_km(400.0)
	# sqrt(3.986e14 / 6.571e6) = 7788.5 m/s
	_expect_close("circular velocity at 200 km", OrbitMath.circular_velocity(r200), 7788.5, "m/s")
	# 2*pi*sqrt(6.771e6^3 / 3.986e14) = 5544.9 s = 92.4 min (spec table: ~92 min)
	_expect_close("period at 400 km", OrbitMath.period(r400) / 60.0, 92.4, "min")
	_expect_close("vis-viva on a circle = circular velocity", OrbitMath.vis_viva(r200, r200), 7788.5, "m/s")
	# Perigee speed of the 200 x 400 km transfer ellipse = 7788.5 + 58.2
	_expect_close("vis-viva at transfer perigee", OrbitMath.vis_viva(r200, (r200 + r400) / 2.0), 7846.7, "m/s")


func _test_hohmann() -> void:
	_section("Hohmann 200 -> 400 km (old Sim Spec section 7: 58 + 57 m/s)")
	var transfer := OrbitMath.hohmann(OrbitMath.radius_from_altitude_km(200.0), OrbitMath.radius_from_altitude_km(400.0))
	_expect_close("burn 1", float(transfer["dv1_ms"]), 58.0, "m/s")
	_expect_close("burn 2", float(transfer["dv2_ms"]), 57.0, "m/s")
	_expect_close("total", float(transfer["total_ms"]), 115.0, "m/s")


func _test_barrowman() -> void:
	_section("Barrowman (a): rectangular fin, Apogee Peak of Flight Newsletter 18")
	# Root = tip = 3 in, no sweep: CP is 0.75 in behind the leading edge (quarter chord).
	_expect_close("fin CP behind leading edge", Stability.fin_cp_x(0.0, 0.0, 3.0, 3.0), 0.75, "in")

	_section("Barrowman (b): 25 mm model rocket, hand-worked from Centuri TIR-33 equations")
	# Ogive nose L_n = 0.125 m; d = 0.025 m (R = 0.0125); 3 fins: C_r = 0.06, C_t = 0.03,
	# S = 0.04, X_r = 0.03; fin root leading edge X_b = 0.44 m from the nose tip.
	#   X_nose  = 0.466 * 0.125 = 0.05825 m,  CN_nose = 2
	#   L_f     = sqrt(0.04^2 + (0.03 + 0.015 - 0.03)^2) = 0.04272 m
	#   CN_fins = [1 + 0.0125/0.0525] * [4*3*(0.04/0.025)^2] / [1 + sqrt(1 + (2*0.04272/0.09)^2)]
	#           = 1.238095 * 30.72 / 2.378853 = 15.9885
	#   X_fins  = 0.44 + (0.03/3)*(0.06 + 0.06)/0.09 + (1/6)*(0.09 - 0.0018/0.09)
	#           = 0.44 + 0.013333 + 0.011667 = 0.465 m
	#   X_cp    = (2*0.05825 + 15.9885*0.465) / 17.9885 = 0.4198 m
	var fins := {"count": 3, "root_chord_m": 0.06, "tip_chord_m": 0.03, "span_m": 0.04, "sweep_m": 0.03}
	var result := Stability.barrowman(0.125, Stability.nose_x_factor("ogive"), 0.025, fins, 0.44)
	_expect_close("X_nose", float(result["x_nose_m"]), 0.05825, "m")
	_expect_close("L_f", float(result["fin_mid_chord_m"]), 0.04272, "m")
	_expect_close("CN_alpha fins", float(result["cn_alpha_fins"]), 15.9885, "")
	_expect_close("X_fins", float(result["x_fins_m"]), 0.465, "m")
	_expect_close("X_cp", float(result["x_cp_m"]), 0.4198, "m")
	# CG at 0.37 m -> margin = (0.4198 - 0.37) / 0.025 = 1.99 calibres.
	_expect_close("static margin", Stability.static_margin(float(result["x_cp_m"]), 0.37, 0.025), 1.99, "cal")
	_expect_close("cone X factor", Stability.nose_x_factor("cone"), 0.666, "")
	_expect_close("parabolic X factor", Stability.nose_x_factor("parabolic"), 0.5, "")
	# CG: 2 kg at 1 m + 6 kg at 3 m -> (2 + 18) / 8 = 2.5 m
	_expect_close("centre of mass", Stability.center_of_mass([
		{"mass_kg": 2.0, "x_m": 1.0}, {"mass_kg": 6.0, "x_m": 3.0}]), 2.5, "m")


func _test_stability_rules() -> void:
	_section("Stability classification (Sim Spec v2 section 2.1)")
	_expect_text("margin -0.5", str(Stability.classify(-0.5, false)["class"]), "unstable")
	_expect_text("margin -0.5 gimballed still fails", str(Stability.classify(-0.5, true)["status"]), "fail")
	_expect_text("margin 0.5", str(Stability.classify(0.5, false)["class"]), "marginal")
	_expect_text("margin 0.5 without gimbal", str(Stability.classify(0.5, false)["status"]), "fail")
	_expect_text("margin 0.5 with gimbal is flyable", str(Stability.classify(0.5, true)["status"]), "warn")
	_expect_text("margin 0.2 with gimbal", str(Stability.classify(0.2, true)["status"]), "fail")
	_expect_text("margin 1.5", str(Stability.classify(1.5, false)["class"]), "stable")
	_expect_text("margin 1.5 status", str(Stability.classify(1.5, false)["status"]), "pass")
	_expect_text("margin 3.5", str(Stability.classify(3.5, false)["class"]), "over_stable")
	_expect_text("margin 3.5 status", str(Stability.classify(3.5, false)["status"]), "warn")


func _test_mission_budget() -> void:
	_section("Mission budget (old Sim Spec section 7 worked example)")
	var dv_data: Dictionary = DataLoader.sim_data()["delta_v"]
	# 465 * cos(28.5 deg) = 408.7 m/s (spec: ~408)
	_expect_close("Cape rotation bonus", MissionBudget.rotation_bonus(28.5, 465.0), 408.0, "m/s")
	# LEO 400 km from the Cape, one way, no margin: 9400 - 408.7 + 115.9 = 9107 m/s
	var one_way := MissionBudget.required_delta_v({
		"profile": "leo", "target_altitude_km": 400.0, "latitude_deg": 28.5,
		"needs_return": false, "margin_fraction": 0.0}, dv_data)
	_expect_close("L1 required dv (spec: 9.1-9.2 km/s)", float(one_way["required_ms"]), 9107.0, "m/s")
	# Lunar landing and back, from the equator, no margin:
	# 9400 + 3150 + 850 + 2000 - 465 + (1850 + 950 + 0) = 17,735 m/s
	var lunar := MissionBudget.required_delta_v({
		"profile": "lunar_landing", "latitude_deg": 0.0, "needs_return": true, "margin_fraction": 0.0}, dv_data)
	_expect_close("lunar landing + return", float(lunar["required_ms"]), 17735.0, "m/s")
	# 10% margin on 9107 = 10,018 m/s
	var with_margin := MissionBudget.required_delta_v({
		"profile": "leo", "target_altitude_km": 400.0, "latitude_deg": 28.5, "margin_fraction": 0.1}, dv_data)
	_expect_close("margin applied", float(with_margin["required_ms"]), 10018.0, "m/s")
	_expect_close("range ratio", MissionBudget.range_ratio(9500.0, 9107.0), 1.0432, "")
	_expect_text("ratio 1.15", MissionBudget.classify_range(1.15), "pass")
	_expect_text("ratio 1.04", MissionBudget.classify_range(1.04), "warn")
	_expect_text("ratio 0.9", MissionBudget.classify_range(0.9), "fail")


func _test_aero() -> void:
	_section("Aero (hand-calculated)")
	# 1.225 * e^(-1) = 0.4506 kg/m3 at one scale height
	_expect_close("density at 8.5 km", Aero.air_density(8500.0), 0.4506, "kg/m3")
	# 0.5 * 1.225 * 300^2 = 55,125 Pa
	_expect_close("dynamic pressure", Aero.dynamic_pressure(1.225, 300.0), 55125.0, "Pa")
	# 55,125 * 0.4 * (pi * 1^2 / 4 = 0.7854) = 17,318 N
	_expect_close("drag force", Aero.drag_force(1.225, 300.0, 0.4, Aero.reference_area(1.0)), 17318.0, "N")
	# Cd = 0.30 + 0.02 * (4 / 2) + 0.10 = 0.44
	var model := {"fin_cd_per_area_ratio": 0.02, "marginal_wobble_cd": 0.10}
	_expect_close("drag coefficient", Aero.drag_coefficient(0.30, 4.0, 2.0, true, model), 0.44, "")
	# q limit: 45 kPa * (12 / 24) = 22.5 kPa for a rocket twice as slender as the reference
	var q_model := {"reference_fineness": 12.0, "min_factor": 0.5, "max_factor": 1.5}
	_expect_close("q limit, slender rocket", Aero.q_limit({"max_q_pa": 45000.0}, 24.0, 1.0, q_model), 22500.0, "Pa")


func _test_redstone_reference() -> void:
	_section("Redstone-class reference rocket: full report")
	var data := DataLoader.sim_data()
	var entry: Dictionary = DataLoader.reference_rockets.get("redstone_class", {})
	_expect_true("reference rocket loaded from /data", not entry.is_empty())
	if entry.is_empty():
		return
	var design: Dictionary = entry["design"]
	var real: Dictionary = entry["real_flight"]
	var report := RocketEvaluator.evaluate(design, data)
	print(RocketEvaluator.format_report(report))
	var numbers: Dictionary = report["numbers"]
	var ascent: Dictionary = numbers["ascent_estimate"]

	# Hand-calculated from the JSON geometry (working in the commit description / chat):
	#   length = 2.9 + 2.5 + 12.0 + 3.5 = 20.9 m; liftoff mass = 29,900 kg
	#   CN_fins = 3.804, X_fins = 19.50 m, X_cp = 13.45 m
	#   X_cg = 10.90 m (liftoff), 9.04 m (burnout) -> margins 1.43 and 2.47 cal
	#   dv = 225 s * g0 * ln(29,900 / 6,300) = 3436 m/s; TWR = 350,000 / (29,900 * g0) = 1.194
	_expect_close("length", float(numbers["length_m"]), 20.9, "m")
	_expect_close("X_cp", float(numbers["x_cp_m"]), 13.45, "m")
	_expect_close("X_cg at liftoff", float(numbers["x_cg_liftoff_m"]), 10.90, "m")
	_expect_close("X_cg at burnout", float(numbers["x_cg_burnout_m"]), 9.04, "m")
	_expect_close("static margin at liftoff", float(numbers["static_margin_liftoff_cal"]), 1.43, "cal")
	_expect_close("static margin at burnout", float(numbers["static_margin_burnout_cal"]), 2.47, "cal")
	_expect_close("delta-v", float(numbers["delta_v_available_ms"]), 3436.0, "m/s")
	_expect_close("TWR at liftoff", float(numbers["twr_liftoff"]), 1.194, "")
	_expect_true("overall verdict is not a failure (got '%s')" % str(report["overall"]), str(report["overall"]) != "fail")

	print("\n  -- Against the real flight (%s) --" % str(real["mission"]))
	# Real Mercury-Redstone liftoff mass: about 66,000 lb = 29,937 kg.
	_expect_close("liftoff mass vs real 29,937 kg", float(numbers["liftoff_mass_kg"]), 29937.0, "kg")
	var burn_times: Array = numbers["burn_times_s"]
	_expect_close("burn time vs real flight", float(burn_times[0]), float(real["burn_time_s"]), "s")
	print("  [INFO] The numbers below are NOT asserted. The pre-flight estimate flies straight up;")
	print("         the real flight pitched over, so apogee and speed only match once the launch sim exists.")
	print("  [INFO] Max-Q:            sim %.1f kPa (vertical)  | real about %.1f kPa (low-confidence figure)" % [
		float(numbers["q_max_pa"]) / 1000.0, float(real["max_q_pa"]) / 1000.0])
	print("  [INFO] Burnout velocity: sim %.0f m/s (vertical)  | real max %.0f m/s" % [
		float(ascent["burnout_velocity_ms"]), float(real["max_velocity_ms"])])
	print("  [INFO] Apogee:           sim %.0f km (vertical)   | real %.1f km (pitched trajectory, %.0f km downrange)" % [
		float(ascent["vertical_apogee_m"]) / 1000.0, float(real["apogee_km"]), float(real["downrange_km"])])
	print("  [INFO] Losses to burnout: gravity %.0f m/s, drag %.0f m/s" % [
		float(ascent["gravity_loss_ms"]), float(ascent["drag_loss_ms"])])


func _test_easy_presets() -> void:
	_section("Easy-mode presets: sanity runs")
	var data := DataLoader.sim_data()
	var mission := {"profile": "suborbital", "target_altitude_km": 187.0, "latitude_deg": 28.5}
	var sensible := _design_from_presets("rounded", "medium", "medium", "small_cheap", "light", mission)
	var report := RocketEvaluator.evaluate(sensible, data)
	print(RocketEvaluator.format_report(report))
	_expect_text("Rounded / Medium / Medium fins / Small engine / Light passes every check", str(report["overall"]), "pass")

	var tiny_fins := _design_from_presets("rounded", "medium", "small", "small_cheap", "light", mission)
	_expect_text("same rocket with Small fins is unstable", _status_of(RocketEvaluator.evaluate(tiny_fins, data), "stability_liftoff"), "fail")
	var too_heavy := _design_from_presets("rounded", "tall_fat", "large", "small_cheap", "light", mission)
	_expect_text("Tall & fat body on the Small engine cannot lift off", _status_of(RocketEvaluator.evaluate(too_heavy, data), "liftoff"), "fail")
	var too_hot := _design_from_presets("rounded", "medium", "medium", "medium", "light", mission)
	_expect_text("Medium body on the Medium engine breaks up at Max-Q", _status_of(RocketEvaluator.evaluate(too_hot, data), "structure"), "fail")

	var orbit_mission := {"profile": "leo", "target_altitude_km": 200.0, "latitude_deg": 28.5}
	var best := _design_from_presets("rounded", "tall_fat", "large", "medium", "light", orbit_mission)
	var orbit_report := RocketEvaluator.evaluate(best, data)
	print(RocketEvaluator.format_report(orbit_report))
	print("  [INFO] Best single-stage Easy preset vs low Earth orbit: range ratio %.2f. No single-stage preset reaches orbit." % float((orbit_report["numbers"] as Dictionary)["range_ratio"]))


# --- Helpers --------------------------------------------------------------------------

## Assembles a single-stage design from Easy-mode preset ids (the rocket builder will do
## this for real; here it only proves the preset numbers make sensible rockets).
func _design_from_presets(nose_id: String, body_id: String, fins_id: String, engine_id: String,
		material_id: String, mission: Dictionary) -> Dictionary:
	var nose: Dictionary = DataLoader.presets["nose"][nose_id]
	var body: Dictionary = DataLoader.presets["body"][body_id]
	var fins: Dictionary = DataLoader.presets["fins"][fins_id]
	var engine_preset: Dictionary = DataLoader.presets["engine"][engine_id]
	var material: Dictionary = DataLoader.presets["material"][material_id]
	var engine: Dictionary = DataLoader.engines[str(engine_preset["engine_id"])].duplicate()
	engine["count"] = engine_preset["count"]
	engine["section_length_m"] = engine_preset["section_length_m"]
	return {
		"name": "Easy: %s nose, %s body, %s fins, %s engine, %s" % [nose_id, body_id, fins_id, engine_id, material_id],
		"nose": {"shape": nose["shape"], "length_m": float(nose["length_to_diameter"]) * float(body["diameter_m"])},
		"payload": {"length_m": 1.0, "mass_kg": 20.0},
		"stages": [{
			"body": {
				"length_m": body["length_m"],
				"diameter_m": body["diameter_m"],
				"material": material["material"],
				"propellant_mass_kg": body["propellant_mass_kg"],
			},
			"engine": engine,
		}],
		"fins": fins,
		"options": {"gimballed": false},
		"mission": mission,
	}


func _status_of(report: Dictionary, check_id: String) -> String:
	var checks: Array = report["checks"]
	for check: Dictionary in checks:
		if str(check["id"]) == check_id:
			return str(check["status"])
	return "missing"


func _section(title: String) -> void:
	print("\n--- %s ---" % title)


func _expect_close(label: String, actual: float, expected: float, unit: String) -> void:
	var error := absf(actual - expected) / absf(expected) if expected != 0.0 else absf(actual)
	var ok := error <= TOLERANCE
	_record(ok, "%s: got %.4f %s, expected %.4f %s (error %.2f%%)" % [label, actual, unit, expected, unit, error * 100.0])


func _expect_text(label: String, actual: String, expected: String) -> void:
	_record(actual == expected, "%s: got '%s', expected '%s'" % [label, actual, expected])


func _expect_true(label: String, condition: bool) -> void:
	_record(condition, label)


func _record(ok: bool, message: String) -> void:
	if ok:
		_passed += 1
		print("  [PASS] " + message)
	else:
		_failed += 1
		print("  [FAIL] " + message)
		push_error("Sim test failed: " + message)
