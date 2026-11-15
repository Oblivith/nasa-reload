# SI assistance metadata: This code used the help of SI.
extends SceneTree

var _failed := 0
var _loader: Node

func _init() -> void:
	_loader = load("res://scripts/systems/data_loader.gd").new()
	_loader.load_all()
	var data: Dictionary = _loader.sim_data()
	var cfg: Dictionary = _loader.raw["launch_sim"]
	print("\n================ LAUNCH SIM VALIDATION ================")
	var started := Time.get_ticks_msec()
	var rows: Array = []
	rows.append_array(_validate_juno(data, cfg))
	rows.append_array(_validate_redstone(data, cfg))
	print("\n  | Flight | Quantity | Real | Sim | Error |")
	print("  |---|---|---|---|---|")
	for row: Array in rows:
		print("  | %s | %s | %s | %s | %+.1f%% |" % [row[0], row[1], row[2], row[3], row[4]])
	_juno_sensitivity(data, cfg)
	var orbiter := _easy_sweep(data, cfg)
	_rules(data, cfg, orbiter)
	print("\n  time %d ms" % (Time.get_ticks_msec() - started))
	print("LAUNCH VALIDATION %s" % ("PASS" if _failed == 0 else "FAIL (%d)" % _failed))
	quit(0 if _failed == 0 else 1)

func _juno_design() -> Dictionary:
	var reference: Dictionary = _loader.reference_rockets["juno_class"]
	var design := DesignBuilder.from_sliders(reference, {}, _loader.engines, true)
	var real: Dictionary = reference["real_flight"]
	design["payload"] = {"length_m": 1.0, "mass_kg": float(real["payload_kg"])}

	design["mission"] = {"profile": "orbit_insertion", "target_perigee_km": float(real["perigee_km"]),
			"target_apogee_km": float(real["perigee_km"]), "insertion_altitude_km": float(real["perigee_km"]),
			"latitude_deg": 28.5}
	return design

func _validate_juno(data: Dictionary, cfg: Dictionary) -> Array:
	var design := _juno_design()
	var real: Dictionary = _loader.reference_rockets["juno_class"]["real_flight"]
	var planner := LaunchPlanner.new(design, data, cfg)
	var t0 := Time.get_ticks_msec()
	var kick := planner.run()
	var plan_ms := Time.get_ticks_msec() - t0
	var sim := LaunchSim.new(design, data, cfg, {"reliability": false, "pitch_kick_deg": kick})
	var r := sim.run_to_end()
	print("\nJuno-class + %.0f kg (Explorer 1, 31 Jan 1958)" % float(real["payload_kg"]))
	print("  guidance %s, kick %.2f deg (%d trial flights, %d ms)" % [r["guidance"], kick, planner.trials.size(), plan_ms])
	var burnout: Dictionary = {}
	for e: Dictionary in r["events"]:
		if str(e["id"]) == "stage_burnout" and burnout.is_empty():
			burnout = e["info"]
	print("  booster burnout T+%.0f s at %.1f km, %.0f m/s inertial" % [float(burnout.get("t", 0.0)), float(burnout.get("alt_km", 0.0)), float(burnout.get("v", 0.0))])
	print("  booster coast apogee %.0f km, horizontal speed there %.0f m/s (inertial, incl. Earth spin)" % [r["loft_apogee_km"], r["loft_horizontal_ms"]])
	var dv_stages: Array = sim.report["numbers"]["delta_v_stages"]
	var kick_dv := 0.0
	for i in range(1, dv_stages.size()):
		kick_dv += float((dv_stages[i] as Dictionary)["delta_v_ms"])
	var r_p := OrbitMath.radius_from_altitude_km(float(real["perigee_km"]))
	var need := OrbitMath.vis_viva(r_p, (r_p + OrbitMath.radius_from_altitude_km(float(real["apogee_km"]))) / 2.0)
	print("  kick stages' Tsiolkovsky dv %.0f m/s; Explorer 1's orbit needs %.0f m/s at perigee -> the booster must leave %.0f m/s horizontal at %.0f km" % [
			kick_dv, need, need - kick_dv, float(real["perigee_km"])])
	print("  max-Q %.1f kPa at T+%.0f s, %.1f km (limit %.1f kPa)" % [float(r["max_q_pa"]) / 1000.0, r["max_q_time_s"], r["max_q_altitude_km"], float(r["q_limit_pa"]) / 1000.0])
	print("  result: in orbit %s, failure '%s', orbit %.0f x %.0f km, final speed %.0f m/s" % [r["in_orbit"], r["failure_type"], r["perigee_km"], r["apogee_km"], r["final_speed_ms"]])
	_print_events(r)
	_report(bool(r["in_orbit"]), "Juno-class reaches orbit")
	return [
		["Explorer 1 / Juno I", "perigee km (guidance target)", "%.0f" % float(real["perigee_km"]), "%.0f" % float(r["perigee_km"]), _err(float(r["perigee_km"]), float(real["perigee_km"]))],
		["Explorer 1 / Juno I", "apogee km", "%.0f" % float(real["apogee_km"]), "%.0f" % float(r["apogee_km"]), _err(float(r["apogee_km"]), float(real["apogee_km"]))],
	]

func _validate_redstone(data: Dictionary, cfg: Dictionary) -> Array:
	var reference: Dictionary = _loader.reference_rockets["redstone_class"]
	var design: Dictionary = (reference["design"] as Dictionary).duplicate(true)
	var real: Dictionary = reference["real_flight"]
	var planner := LaunchPlanner.new(design, data, cfg)
	var kick := planner.run()
	var sim := LaunchSim.new(design, data, cfg, {"reliability": false, "pitch_kick_deg": kick})
	var r := sim.run_to_end()
	var burnout: Dictionary = {}
	for e: Dictionary in r["events"]:
		if str(e["id"]) == "stage_burnout":
			burnout = e["info"]
	print("\nRedstone-class (Mercury-Redstone 3, 5 May 1961)")
	print("  guidance %s (flattest climb to the target apogee), kick %.2f deg (%d trial flights)" % [r["guidance"], kick, planner.trials.size()])
	print("  burnout T+%.0f s at %.1f km, %.0f m/s inertial" % [float(burnout.get("t", 0.0)), float(burnout.get("alt_km", 0.0)), float(burnout.get("v", 0.0))])
	print("  max-Q %.1f kPa at T+%.0f s (limit %.1f kPa)" % [float(r["max_q_pa"]) / 1000.0, r["max_q_time_s"], float(r["q_limit_pa"]) / 1000.0])
	print("  apogee %.1f km, downrange %.0f km, flight %.0f s, failure '%s'" % [r["max_altitude_km"], r["downrange_km"], r["flight_time_s"], r["failure_type"]])
	_expect(str(r["failure_type"]) == "", "Redstone-class flies")
	return [
		["Mercury-Redstone 3", "apogee km", "%.1f" % float(real["apogee_km"]), "%.1f" % float(r["max_altitude_km"]), _err(float(r["max_altitude_km"]), float(real["apogee_km"]))],
		["Mercury-Redstone 3", "downrange km", "%.0f" % float(real["downrange_km"]), "%.0f" % float(r["downrange_km"]), _err(float(r["downrange_km"]), float(real["downrange_km"]))],
		["Mercury-Redstone 3", "max speed m/s", "%.0f" % float(real["max_velocity_ms"]), "%.0f" % float(r["max_speed_ms"]), _err(float(r["max_speed_ms"]), float(real["max_velocity_ms"]))],
		["Mercury-Redstone 3", "burn time s", "%.0f" % float(real["burn_time_s"]), "%.0f" % float(burnout.get("t", 0.0)), _err(float(burnout.get("t", 0.0)), float(real["burn_time_s"]))],
		["Mercury-Redstone 3", "flight time s", "%.0f" % float(real["flight_duration_s"]), "%.0f" % float(r["flight_time_s"]), _err(float(r["flight_time_s"]), float(real["flight_duration_s"]))],
	]

func _juno_sensitivity(data: Dictionary, cfg: Dictionary) -> void:
	print("\nJuno-class sensitivity (diagnostic only; the data is NOT changed)")
	var variants := {
		"as in the data (14 kg payload + 5.7 kg stage-4 case)": {},
		"payload 8.3 kg (the 14 kg already includes the stage-4 case)": {"payload": 8.3},
		"booster Isp +5% (hydyne uprate, not modelled)": {"isp": 1.05},
	}
	for label: String in variants:
		var v: Dictionary = variants[label]
		var d := _juno_design()
		if v.has("payload"):
			d["payload"]["mass_kg"] = float(v["payload"])
		if v.has("isp"):
			var e: Dictionary = d["stages"][0]["engine"]
			for k in ["isp_sl", "isp_vac", "thrust_sl_N", "thrust_vac_N"]:
				e[k] = float(e[k]) * float(v["isp"])
		var kick := LaunchPlanner.new(d, data, cfg).run()
		var r := LaunchSim.new(d, data, cfg, {"reliability": false, "record": false, "pitch_kick_deg": kick}).run_to_end()
		print("  %-62s orbit %6.0f x %5.0f km, final %4.0f m/s" % [label, r["perigee_km"], r["apogee_km"], r["final_speed_ms"]])

func _easy_sweep(data: Dictionary, cfg: Dictionary) -> Dictionary:
	print("\nLevel 1 Easy rockets (evaluator vs launch sim)")
	var level: Dictionary = _loader.levels["L1"]
	var base: Dictionary = (_loader.builder_ui["easy_defaults"] as Dictionary).duplicate()
	var orbiter := {}
	for engine in ["small_cheap", "medium", "big_powerful"]:
		for upper in ["none", "small", "big"]:
			for body in ["medium", "tall_fat"]:
				var picks := base.duplicate()
				picks["engine"] = engine
				picks["upper_stage"] = upper
				picks["body"] = body
				var d := DesignBuilder.from_easy(picks, _loader.presets, _loader.engines,
						DesignModes.level_payload(level), DesignModes.level_mission(level))
				var report := RocketEvaluator.evaluate(d, data)
				var planner := LaunchPlanner.new(d, data, cfg)
				var kick := planner.run()
				var r := LaunchSim.new(d, data, cfg, {"reliability": false, "record": false, "pitch_kick_deg": kick}).run_to_end()
				print("  %-12s %-6s %-9s eval %-7s %d* range %.2f | %-7s kick %5.2f: %-11s orbit %5.0f x %6.0f km, spare %4.0f m/s, max-Q %4.1f/%4.1f kPa" % [
					engine, upper, body, report["outcome"], int(report["stars"]), float(report["numbers"]["range_ratio"]),
					r["guidance"], kick, "ORBIT" if r["in_orbit"] else str(r["failure_type"]), r["perigee_km"], minf(float(r["apogee_km"]), 99999.0),
					r["delta_v_left_ms"], float(r["max_q_pa"]) / 1000.0, float(r["q_limit_pa"]) / 1000.0])
				if bool(r["in_orbit"]) and orbiter.is_empty():
					orbiter = d
	_expect(not orbiter.is_empty(), "at least one Level 1 Easy rocket reaches orbit in the launch sim")
	return orbiter

func _rules(data: Dictionary, cfg: Dictionary, orbiter: Dictionary) -> void:
	print("\nRules")

	var heavy := _juno_design()
	heavy["stages"][0]["body"]["propellant_mass_kg"] = 60000.0
	var r := LaunchSim.new(heavy, data, cfg, {"reliability": false}).run_to_end()
	_expect(str(r["failure_type"]) == "no_liftoff", "TWR < 1 -> no_liftoff (%s)" % r["failure_type"])
	if orbiter.is_empty():
		return
	var orbit_kick := LaunchPlanner.new(orbiter, data, cfg).run()

	var sim := LaunchSim.new(orbiter, data, cfg, {"reliability": false, "pitch_kick_deg": orbit_kick})
	var seen: Array = []
	sim.liftoff.connect(func() -> void: seen.append("liftoff"))
	sim.tower_cleared.connect(func() -> void: seen.append("tower_cleared"))
	sim.max_q.connect(func(_q: float) -> void: seen.append("max_q"))
	sim.staging.connect(func(n: int) -> void: seen.append("staging%d" % n))
	sim.seco.connect(func() -> void: seen.append("seco"))
	sim.orbit_achieved.connect(func(_a: float, _p: float) -> void: seen.append("orbit"))
	sim.run_to_end()
	var want := ["liftoff", "tower_cleared", "max_q"]
	for n in range(1, (orbiter["stages"] as Array).size()):
		want.append("staging%d" % n)
	want.append_array(["seco", "orbit"])
	_expect(seen == want, "signal order %s" % str(seen))
	_expect(sim.telemetry.size() > 100, "telemetry recorded (%d samples)" % sim.telemetry.size())

	var weak_data := data.duplicate(true)
	weak_data["materials"][str(orbiter["stages"][0]["body"]["material"])]["max_q_pa"] = 5000.0
	r = LaunchSim.new(orbiter, weak_data, cfg, {"reliability": false, "pitch_kick_deg": orbit_kick}).run_to_end()
	_expect(str(r["failure_type"]) == "structural", "weak structure breaks up (%s, max-q %.1f kPa)" % [r["failure_type"], float(r["max_q_pa"]) / 1000.0])

	var finless := _juno_design()
	finless["fins"] = {}
	finless["options"] = {"gimballed": false}
	r = LaunchSim.new(finless, data, cfg, {"reliability": false, "pitch_kick_deg": 5.0}).run_to_end()
	_expect(str(r["failure_type"]) == "unstable", "finless, ungimballed rocket tumbles (%s)" % r["failure_type"])

	var single := orbiter.duplicate(true)
	single["stages"] = [single["stages"][0]]
	r = LaunchSim.new(single, data, cfg, {"reliability": false, "pitch_kick_deg": orbit_kick}).run_to_end()
	_expect(str(r["failure_type"]) != "", "booster alone does not make orbit (%s, perigee %.0f km)" % [r["failure_type"], r["perigee_km"]])

	var a := LaunchSim.new(orbiter, data, cfg, {"seed": 42, "pitch_kick_deg": orbit_kick}).run_to_end()
	var b := LaunchSim.new(orbiter, data, cfg, {"seed": 42, "pitch_kick_deg": orbit_kick}).run_to_end()
	_expect(a["failure_type"] == b["failure_type"] and is_equal_approx(float(a["apogee_km"]), float(b["apogee_km"])), "same seed, same flight")
	var kinds := {}
	for s in 60:
		var f := str(LaunchSim.new(orbiter, data, cfg, {"seed": s, "pitch_kick_deg": orbit_kick, "record": false, "dt": 0.25}).run_to_end()["failure_type"])
		kinds[f] = int(kinds.get(f, 0)) + 1
	print("  60 seeded flights: %s" % str(kinds))
	_expect(kinds.size() > 1, "reliability rolls produce some failures")

func _print_events(r: Dictionary) -> void:
	var parts: PackedStringArray = []
	for e: Dictionary in r["events"]:
		parts.append("%s@%.0f" % [e["id"], float(e["t"])])
	print("  events: " + ", ".join(parts))

func _err(sim_value: float, real_value: float) -> float:
	return (sim_value - real_value) / real_value * 100.0 if real_value != 0.0 else 0.0

func _expect(ok: bool, what: String) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", what])
	if not ok:
		_failed += 1

func _report(ok: bool, what: String) -> void:
	print("  [%s] %s" % ["ok" if ok else "GAP", what])
