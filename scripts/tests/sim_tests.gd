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
	_test_twr_thresholds()
	_test_design_builder()
	_test_mission_outcome()
	_test_redstone_reference()
	_test_easy_presets()
	_test_design_modes()
	_test_juno_reference()
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
	_expect_text("TWR 1.19 now passes the liftoff gate", _status_of(report, "liftoff"), "pass")
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


func _test_twr_thresholds() -> void:
	_section("Liftoff thresholds (decision: pass >= 1.1, warn 1.0 to 1.1, fail < 1.0)")
	_expect_text("TWR 0.95", str(RocketEvaluator._liftoff_check(0.95, 1.0, 1.0)["status"]), "fail")
	_expect_text("TWR 1.00", str(RocketEvaluator._liftoff_check(1.0, 1.0, 1.0)["status"]), "warn")
	_expect_text("TWR 1.05", str(RocketEvaluator._liftoff_check(1.05, 1.0, 1.0)["status"]), "warn")
	_expect_text("TWR 1.10", str(RocketEvaluator._liftoff_check(1.1, 1.0, 1.0)["status"]), "pass")
	_expect_text("TWR 1.19 (Redstone-class)", str(RocketEvaluator._liftoff_check(1.19, 1.0, 1.0)["status"]), "pass")


func _test_design_builder() -> void:
	_section("DesignBuilder: sliders and upper-stage stacking")
	# Slider: 0.5 = reference, 0 = 0.5x, 1 = 2x, linear on each half.
	_expect_close("slider 0.5 = reference", DesignBuilder.slider_to_value(0.5, 100.0, 0.5, 2.0), 100.0, "")
	_expect_close("slider 0 = min", DesignBuilder.slider_to_value(0.0, 100.0, 0.5, 2.0), 50.0, "")
	_expect_close("slider 1 = max", DesignBuilder.slider_to_value(1.0, 100.0, 0.5, 2.0), 200.0, "")
	_expect_close("slider 0.75", DesignBuilder.slider_to_value(0.75, 100.0, 0.5, 2.0), 150.0, "")
	_expect_close("value -> slider round trip", DesignBuilder.value_to_slider(150.0, 100.0, 0.5, 2.0), 0.75, "")
	# Tank length: 12,000 kg * 1.1 / (1200 * pi * 3.05^2 / 4) = 13.2 / 8.7675 = 1.5056 m
	_expect_close("tank length from volume", DesignBuilder.tank_length(12000.0, 1200.0, 1.1, 3.05), 1.5056, "m")

	var reference: Dictionary = DataLoader.reference_rockets["redstone_class"]
	var single := DesignBuilder.from_sliders(reference, {}, DataLoader.engines, false)
	_expect_true("Medium, all sliders at 0.5, no upper stage = the reference design", single["stages"].size() == 1
			and is_equal_approx(float(single["stages"][0]["body"]["propellant_mass_kg"]), 23600.0))
	var stacked := DesignBuilder.from_sliders(reference, {"stages/1/body/propellant_mass_kg": 1.0}, DataLoader.engines, true)
	var upper_body: Dictionary = stacked["stages"][1]["body"]
	var upper_engine: Dictionary = stacked["stages"][1]["engine"]
	_expect_close("Medium upper stage, propellant slider at 1 (2x)", float(upper_body["propellant_mass_kg"]), 24000.0, "kg")
	_expect_close("upper stage takes the first stage's diameter", float(upper_body["diameter_m"]), 1.78, "m")
	# 24,000 * 1.1 / (1200 * pi * 1.78^2 / 4) = 26.4 / 2.98615 = 8.8408 m
	_expect_close("upper tank length follows the scaled propellant", float(upper_body["length_m"]), 8.8408, "m")
	_expect_close("upper engine resolved from engines.json", float(upper_engine["thrust_vac_N"]), 450000.0, "N")
	var unstacked := DesignBuilder.without_upper_stages(stacked)
	_expect_true("upper stage can be removed again", unstacked["stages"].size() == 1)

	# Hard mode: raw numbers, same stacking call.
	var hard := DesignBuilder.add_upper_stage(single, {
		"body": {"length_m": 3.0, "diameter_m": 1.78, "material": "steel", "propellant_mass_kg": 5000.0},
		"engine": {"engine_id": "hypergolic_upper", "section_length_m": 1.2, "isp_vac": 300.0},
	}, DataLoader.engines)
	_expect_close("Hard upper stage keeps the player's length", float(hard["stages"][1]["body"]["length_m"]), 3.0, "m")
	_expect_close("Hard upper stage keeps the player's Isp override", float(hard["stages"][1]["engine"]["isp_vac"]), 300.0, "s")
	var hard_report := RocketEvaluator.evaluate(hard, DataLoader.sim_data())
	var hard_stages: Array = (hard_report["numbers"] as Dictionary)["delta_v_stages"]
	_expect_true("evaluator sees both stages", hard_stages.size() == 2)
	_expect_true("upper-stage thrust check is reported", _status_of(hard_report, "upper_twr_stage_2") != "missing")


func _test_mission_outcome() -> void:
	_section("Gameplay rule: WARN still succeeds (fewer stars), only FAIL fails")
	var check := func(status: String) -> Dictionary:
		return {"status": status, "plain": "reason " + status}
	var all_pass := RocketEvaluator._finish({"checks": [check.call("pass"), check.call("pass")]})
	_expect_text("all pass: success", str(all_pass["outcome"]), "success")
	_expect_true("all pass: 3 stars, no tips", int(all_pass["stars"]) == 3 and (all_pass["tips"] as Array).is_empty())
	var one_warn := RocketEvaluator._finish({"checks": [check.call("pass"), check.call("warn")]})
	_expect_text("one warning: still a success", str(one_warn["outcome"]), "success")
	_expect_true("one warning: 2 stars and 1 tip", int(one_warn["stars"]) == 2 and (one_warn["tips"] as Array).size() == 1)
	var two_warn := RocketEvaluator._finish({"checks": [check.call("warn"), check.call("warn")]})
	_expect_true("two warnings: success with 1 star", str(two_warn["outcome"]) == "success" and int(two_warn["stars"]) == 1)
	var failed := RocketEvaluator._finish({"checks": [check.call("warn"), check.call("fail")]})
	_expect_text("any fail: mission failure", str(failed["outcome"]), "failure")
	_expect_true("failure: 0 stars, the fail reason is reported", int(failed["stars"]) == 0 and (failed["failures"] as Array).size() == 1)


func _test_easy_presets() -> void:
	_section("Easy-mode presets: Level 1 (20 kg to a 400 km orbit from the Cape), all 486 combinations")
	var data := DataLoader.sim_data()
	var payload := {"length_m": 1.0, "mass_kg": 20.0}
	var level1 := {"profile": "leo", "target_altitude_km": 400.0, "latitude_deg": 28.5, "needs_return": false}
	var bodies := ["short_thin", "medium", "tall_fat"]
	var engines := ["small_cheap", "medium", "big_powerful"]

	var lists := {"pass": [], "warn": [], "fail": []}
	var fail_reasons := {}
	var successes_by_option := {}
	var bad_successes: Array = []
	var large_big := {"pass": 0, "over_stable": 0}
	var first_pass: Dictionary = {}
	for nose_id in ["pointy", "rounded", "fat"]:
		for body_id in bodies:
			for engine_id in engines:
				for fins_id in ["small", "medium", "large"]:
					for material_id in ["light", "strong"]:
						for upper_id in ["none", "small", "big"]:
							var design := _easy(nose_id, body_id, fins_id, engine_id, material_id, upper_id, payload, level1)
							var r := RocketEvaluator.evaluate(design, data)
							var n: Dictionary = r["numbers"]
							var overall := str(r["overall"])
							var flagged: PackedStringArray = []
							for c: Dictionary in r["checks"]:
								if str(c["status"]) == overall and overall != "pass":
									flagged.append(str(c["id"]))
							var label := "%-8s %-10s %-13s %-7s %-7s %-6s" % [nose_id, body_id, engine_id, fins_id, material_id, upper_id]
							if str(r["outcome"]) == "success":
								for option in ["body:" + body_id, "engine:" + engine_id]:
									successes_by_option[option] = int(successes_by_option.get(option, 0)) + 1
								if upper_id == "none" or (fins_id == "small" and nose_id == "fat") \
										or (body_id == "tall_fat" and engine_id == "small_cheap"):
									bad_successes.append(label)
								if fins_id == "large" and upper_id == "big":
									if overall == "pass":
										large_big["pass"] = int(large_big["pass"]) + 1
									if _status_of(r, "stability_burnout") == "warn":
										large_big["over_stable"] = int(large_big["over_stable"]) + 1
								if overall == "pass":
									successes_by_option["clean:" + engine_id] = int(successes_by_option.get("clean:" + engine_id, 0)) + 1
								if overall == "pass" and first_pass.is_empty():
									first_pass = r
							else:
								for id in flagged:
									fail_reasons[id] = int(fail_reasons.get(id, 0)) + 1
							(lists[overall] as Array).append("%s  %d*  TWR %5.2f  SM %5.2f/%5.2f  ratio %5.3f  %s" % [
									label, int(r["stars"]), float(n["twr_liftoff"]), float(n["static_margin_liftoff_cal"]),
									float(n["static_margin_burnout_cal"]), float(n["range_ratio"]), ", ".join(flagged)])

	var passes: Array = lists["pass"]
	var warns: Array = lists["warn"]
	var fails: Array = lists["fail"]
	var success_count := passes.size() + warns.size()
	print("\n  Spread: %d pass (3 stars) + %d warn (1-2 stars) = %d successes (%.1f%%), %d fail" % [
			passes.size(), warns.size(), success_count, 100.0 * success_count / 486.0, fails.size()])
	for option in ["body:short_thin", "body:medium", "body:tall_fat", "engine:small_cheap", "engine:medium", "engine:big_powerful"]:
		print("    successes with %-20s %d" % [option, int(successes_by_option.get(option, 0))])
	for status in ["pass", "warn"]:
		var rows: Array = lists[status]
		print("\n  SUCCESS, %s (%d):" % [status.to_upper(), rows.size()])
		for row in rows:
			print("    " + str(row))
	print("\n  FAIL (%d). Failing checks (a rocket can fail several):" % fails.size())
	for id in fail_reasons:
		print("    %-20s %d" % [id, int(fail_reasons[id])])
	if not first_pass.is_empty():
		print(RocketEvaluator.format_report(first_pass))

	_expect_true("at least one Easy combination passes every Level 1 check with no warnings (%d found)" % passes.size(),
			not passes.is_empty())
	for body_id in bodies:
		_expect_true("body option '%s' has at least one successful combination (%d)" % [body_id, int(successes_by_option.get("body:" + body_id, 0))],
				int(successes_by_option.get("body:" + body_id, 0)) > 0)
	for engine_id in engines:
		_expect_true("engine option '%s' has at least one successful combination (%d)" % [engine_id, int(successes_by_option.get("engine:" + engine_id, 0))],
				int(successes_by_option.get("engine:" + engine_id, 0)) > 0)
	for engine_id in engines:
		_expect_true("engine option '%s' has at least one clean pass (%d)" % [engine_id, int(successes_by_option.get("clean:" + engine_id, 0))],
				int(successes_by_option.get("clean:" + engine_id, 0)) > 0)
	var small_up := float(DataLoader.presets["upper_stage"]["small"]["propellant_mass_kg"])
	var big_up := float(DataLoader.presets["upper_stage"]["big"]["propellant_mass_kg"])
	_expect_true("Big upper stage carries at least 1.8x the Small one (%.0f vs %.0f kg = %.2fx)" % [big_up, small_up, big_up / small_up], big_up >= 1.8 * small_up)
	_expect_true("15-25%% of combinations succeed (%.1f%%)" % (100.0 * success_count / 486.0),
			success_count >= 73 and success_count <= 121)
	_expect_true("at least 10 clean passes (%d)" % passes.size(), passes.size() >= 10)
	_expect_true("obvious mistakes fail: no upper stage, Small fins + Fat nose, Tall & fat + Small engine (%d slipped through: %s)" % [
			bad_successes.size(), ", ".join(PackedStringArray(bad_successes.slice(0, 3)))], bad_successes.is_empty())
	_expect_true("Large fins + Big upper stage stays an over-stable lesson (%d clean passes, %d over-stable warnings)" % [
			int(large_big["pass"]), int(large_big["over_stable"])], int(large_big["pass"]) == 0 and int(large_big["over_stable"]) > 0)


func _easy(nose_id: String, body_id: String, fins_id: String, engine_id: String, material_id: String,
		upper_id: String, payload: Dictionary, mission: Dictionary) -> Dictionary:
	return DesignBuilder.from_easy({
		"nose": nose_id, "body": body_id, "fins": fins_id, "engine": engine_id,
		"material": material_id, "upper_stage": upper_id,
	}, DataLoader.presets, DataLoader.engines, payload, mission)


# --- Helpers --------------------------------------------------------------------------

func _status_of(report: Dictionary, check_id: String) -> String:
	var checks: Array = report["checks"]
	for check: Dictionary in checks:
		if str(check["id"]) == check_id:
			return str(check["status"])
	return "missing"


func _test_design_modes() -> void:
	_section("DesignModes: switching between Easy, Medium and Hard")
	var level: Dictionary = DataLoader.levels["L1"]
	var payload := DesignModes.level_payload(level)
	var mission := DesignModes.level_mission(level)
	_expect_text("L1 mission profile", str(mission["profile"]), "leo")
	_expect_close("L1 mission latitude from the launch site", float(mission["latitude_deg"]), 28.5, "deg")

	# Every Easy rocket snaps back to exactly its own presets, with nothing changed.
	var mismatches := 0
	var combos := 0
	for nose_id in DataLoader.presets["nose"]:
		for body_id in DataLoader.presets["body"]:
			for fins_id in DataLoader.presets["fins"]:
				for engine_id in DataLoader.presets["engine"]:
					for material_id in DataLoader.presets["material"]:
						for upper_id in DataLoader.presets["upper_stage"]:
							var picks := {"nose": nose_id, "body": body_id, "fins": fins_id, "engine": engine_id,
									"material": material_id, "upper_stage": upper_id}
							var design := DesignBuilder.from_easy(picks, DataLoader.presets, DataLoader.engines, payload, mission)
							var snap := DesignModes.snap_to_easy(design, DataLoader.presets, DataLoader.engines, DataLoader.materials)
							combos += 1
							if snap["selections"] != picks or not (snap["changed"] as Array).is_empty() or not (snap["dropped"] as Array).is_empty():
								mismatches += 1
	_expect_true("all %d Easy rockets snap back to their own presets (%d mismatches)" % [combos, mismatches], mismatches == 0)

	# Medium: the reference sits at 0.5 on every slider; a 2x value sits at 1.
	var reference: Dictionary = DataLoader.reference_rockets[str(level["reference_rocket"])]
	var sliders: Array = DataLoader.builder_ui["medium_sliders"]
	var ref_values := DesignModes.reference_values(reference, DataLoader.engines, sliders)
	var ref_design := DesignModes.reference_design(reference, DataLoader.engines, level, true)
	var positions := DesignModes.slider_positions(ref_design, sliders, ref_values, 0.5, 2.0)
	var all_half := positions.size() == sliders.size()
	for id in positions:
		all_half = all_half and is_equal_approx(float(positions[id]["slider"]), 0.5) and bool(positions[id]["in_range"])
	_expect_true("reference rocket: every Medium slider at 0.5 and in range (%d sliders)" % positions.size(), all_half)
	_expect_true("reference for an uncrewed level drops the escape tower", not (ref_design["options"] as Dictionary).has("escape_tower"))
	DesignModes.path_set(ref_design, "stages/0/body/length_m", 24.0)
	DesignModes.path_set(ref_design, "stages/0/body/propellant_mass_kg", 23600.0 * 8.0)
	positions = DesignModes.slider_positions(ref_design, sliders, ref_values, 0.5, 2.0)
	_expect_text("Level 1 Medium reference is the Juno-class", str(level["reference_rocket"]), "juno_class")
	_expect_close("2x body length sits at slider 1", float(positions["body_length"]["slider"]), 1.0, "")
	_expect_true("8x fuel is out of range but keeps its real value", not bool(positions["propellant"]["in_range"])
			and is_equal_approx(float(positions["propellant"]["value"]), 188800.0))

	# Hard -> Easy: a gimballed Redstone with a tower snaps and reports what it dropped.
	var redstone := DesignModes.reference_design(DataLoader.reference_rockets["redstone_class"], DataLoader.engines,
			DataLoader.levels["L1"], false)
	redstone["options"]["escape_tower"] = {"length_m": 4.5, "mass_kg": 500.0}
	var snap := DesignModes.snap_to_easy(redstone, DataLoader.presets, DataLoader.engines, DataLoader.materials)
	_expect_text("Redstone snaps to the Short & thin body", str(snap["selections"]["body"]), "short_thin")
	_expect_text("Redstone has no upper stage", str(snap["selections"]["upper_stage"]), "none")
	_expect_true("snap reports the dropped gimbal and tower", (snap["dropped"] as Array).size() == 2)

	# Cost: engines + walls + fins, in $M.
	var easy := DesignBuilder.from_easy({"nose": "pointy", "body": "medium", "fins": "medium", "engine": "medium",
			"material": "light", "upper_stage": "small"}, DataLoader.presets, DataLoader.engines, payload, mission)
	var cost := DesignModes.design_cost(easy, DataLoader.engines, DataLoader.materials, DataLoader.builder_ui["cost_model"])
	# 2 x 3.0 + 1 x 3.0 engines + aluminium walls 0.010 x pi x 3 x (18 + upper tank) + fins 4 x 2.94 m2 x 0.02
	var upper_len := float(easy["stages"][1]["body"]["length_m"])
	var expected := 9.0 + 0.010 * PI * 3.0 * (18.0 + upper_len) + 4.0 * 0.5 * (2.8 + 1.4) * 2.1 * 0.02
	_expect_close("design cost", float(cost["total"]), expected, "$M")


func _test_juno_reference() -> void:
	_section("Medium reference (Juno-class) on Level 1: 20 kg to a 400 km orbit")
	var level: Dictionary = DataLoader.levels["L1"]
	var reference: Dictionary = DataLoader.reference_rockets[str(level["reference_rocket"])]
	var sliders: Array = DataLoader.builder_ui["medium_sliders"]
	var data := DataLoader.sim_data()

	# All sliders at 0.5 = the reference: reaches orbit, tight, exactly one warning (range).
	var report := _medium_report(reference, sliders, level, data, {})
	print(RocketEvaluator.format_report(report))
	_expect_text("reference settings succeed on Level 1", str(report["outcome"]), "success")
	_expect_true("reference settings are a 2-star warn (tight but works)", int(report["stars"]) == 2)
	_expect_text("the one warning is Range", str(_warned(report)), "range")
	var ratio := float((report["numbers"] as Dictionary)["range_ratio"])
	_expect_true("reference range ratio is tight: 1.0 to 1.05 (got %.3f)" % ratio, ratio >= 1.0 and ratio < 1.05)
	_expect_true("reference rocket is 3 stages (booster + 2 solid stages)", ((report["geometry"] as Dictionary)["segments"] as Array).size() > 6
			and (DesignBuilder.upper_stage_specs(reference) as Array).size() == 2)

	# Sensible tweaks reach a clean pass: lighter upper stages, more fuel in them.
	var tweak := {"upper_mass": 0.25, "upper2_mass": 0.25, "upper_propellant": 0.7, "upper2_propellant": 0.6, "thrust": 0.5}
	var clean := _medium_report(reference, sliders, level, data, tweak)
	_expect_true("lighter upper stages + more upper fuel = clean 3-star pass", int(clean["stars"]) == 3)
	_expect_text("a modest fuel tweak still flies (+25% upper fuel)", str(_medium_report(reference, sliders, level, data,
			{"upper_propellant": 0.62, "upper2_propellant": 0.62})["outcome"]), "success")

	# Extremes clearly fail.
	var all_low := {}
	for slider: Dictionary in sliders:
		all_low[slider["id"]] = 0.0
	_expect_text("every slider at 0 fails", str(_medium_report(reference, sliders, level, data, all_low)["outcome"]), "failure")
	for extreme in [["propellant", 0.0], ["propellant", 1.0], ["thrust", 0.0], ["thrust", 1.0], ["fin_span", 0.0],
			["body_diameter", 0.0], ["body_diameter", 1.0], ["upper_propellant", 0.0], ["upper2_propellant", 0.0],
			["upper_mass", 1.0], ["upper2_mass", 1.0]]:
		var picks := {extreme[0]: extreme[1]}
		var extreme_report := _medium_report(reference, sliders, level, data, picks)
		_expect_text("%s at %.0f fails" % [extreme[0], extreme[1]], str(extreme_report["outcome"]), "failure")

	# The suborbital Redstone-class stays available as the validation rocket.
	_expect_true("Redstone-class is still a reference rocket", DataLoader.reference_rockets.has("redstone_class"))


## Builds the Medium design for slider id -> 0..1 and evaluates it on Level 1.
func _medium_report(reference: Dictionary, sliders: Array, level: Dictionary, data: Dictionary, picks: Dictionary) -> Dictionary:
	var paths := {}
	for slider: Dictionary in sliders:
		if picks.has(slider["id"]):
			for path in slider["paths"]:
				paths[path] = picks[slider["id"]]
	var design := DesignBuilder.from_sliders(reference, paths, DataLoader.engines, DesignBuilder.upper_stages_default_on(reference))
	design["payload"] = DesignModes.level_payload(level)
	design["mission"] = DesignModes.level_mission(level)
	return RocketEvaluator.evaluate(design, data)


func _warned(report: Dictionary) -> String:
	var ids: PackedStringArray = []
	for check: Dictionary in report["checks"]:
		if str(check["status"]) != "pass":
			ids.append(str(check["id"]))
	return ",".join(ids)


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
