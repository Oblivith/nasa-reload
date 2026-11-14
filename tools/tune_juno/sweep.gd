# Code generated with AI assistance (Claude). Reviewed by team.
extends SceneTree
## One-shot sweep for the Juno-class Medium reference (Level 1). Run:
##   Godot --headless --path . -s tools/tune_juno/sweep.gd
## Prints: the reference at 0.5, every slider alone at 0 and 1, all sliders at 0 / 1,
## and a random search around 0.5 for the share of 3-star / success / fail designs.

var data: Dictionary
var level: Dictionary
var reference: Dictionary
var sliders: Array
var engines: Dictionary


func _init() -> void:
	var loader: Node = load("res://scripts/systems/data_loader.gd").new()
	loader.load_all()
	data = loader.sim_data()
	level = loader.levels["L1"]
	reference = loader.reference_rockets["juno_class"]
	sliders = loader.builder_ui["medium_sliders"]
	engines = loader.engines
	var base := evaluate({})
	print("REFERENCE: ", summary(base))
	for check: Dictionary in base["checks"]:
		print("   %-26s %-4s %8.3f %s" % [check["name"], check["status"], check["value"], check["threshold"]])
	var n: Dictionary = base["numbers"]
	print("   liftoff %.0f kg, dv %.0f / %.0f m/s, q %.1f/%.1f kPa, margin %.2f/%.2f" % [n["liftoff_mass_kg"],
			n["delta_v_available_ms"], n["delta_v_required_ms"], n["q_max_pa"] / 1000.0, n["q_limit_pa"] / 1000.0,
			n["static_margin_liftoff_cal"], n["static_margin_burnout_cal"]])
	var asc: Dictionary = n["ascent_estimate"]
	var bud: Dictionary = n["delta_v_budget"]
	for st: Dictionary in n["delta_v_stages"]:
		print("   stage dv: Isp %.0f s, m0 %.1f kg, mf %.1f kg -> %.0f m/s" % [st["isp_s"], st["m0_kg"], st["mf_kg"], st["delta_v_ms"]])
	print("   required: legs %.0f - spin %.0f + raise %.0f = %.0f, x(1+%.2f) = %.0f" % [bud["outbound_ms"], bud["rotation_bonus_ms"], bud["orbit_raise_ms"], bud["subtotal_ms"], bud["margin_fraction"], bud["required_ms"]])
	print("   booster (vertical estimate): gravity loss %.0f, drag loss %.0f, burnout %.0f m/s at %.1f km" % [asc["gravity_loss_ms"], asc["drag_loss_ms"], asc.get("burnout_velocity_ms", 0.0), asc.get("burnout_altitude_m", 0.0) / 1000.0])
	var loaded: Node = loader
	print("   cost ref $%.2fM" % cost_of({}, loaded))
	var all_one := {}
	for s: Dictionary in sliders:
		all_one[s["id"]] = 1.0
	print("   cost 2x (all sliders 1) $%.2fM: %s" % [cost_of(all_one, loaded), summary(evaluate(all_one))])
	print("   cost tweak (+30%% upper fuel, lighter upper stages) $%.2fM" % cost_of({"upper_propellant": 0.65, "upper2_propellant": 0.65, "upper3_propellant": 0.65, "upper_mass": 0.25, "upper2_mass": 0.25}, loaded))
	var costs: Array = []
	var mission_nb := DesignModes.level_mission(level)
	mission_nb.erase("budget_musd")
	for a in loaded.presets["nose"]:
		for b in loaded.presets["body"]:
			for c in loaded.presets["fins"]:
				for d in loaded.presets["engine"]:
					for e in loaded.presets["material"]:
						for f in loaded.presets["upper_stage"]:
							var dz := DesignBuilder.from_easy({"nose": a, "body": b, "fins": c, "engine": d, "material": e, "upper_stage": f}, loaded.presets, engines, DesignModes.level_payload(level), mission_nb)
							var rz := RocketEvaluator.evaluate(dz, data)
							if rz["outcome"] == "success":
								costs.append([CostModel.design_cost(dz, engines, loaded.materials, loaded.cost_model)["total"], d, rz["stars"]])
	costs.sort()
	print("   Easy successes (no budget): %d, cost min $%.2fM max $%.2fM" % [costs.size(), costs[0][0], costs[costs.size() - 1][0]])
	for eng in ["small_cheap", "medium", "big_powerful"]:
		var cheapest3 := 999.0
		for row in costs:
			if row[1] == eng and row[2] == 3:
				cheapest3 = minf(cheapest3, row[0])
		print("     cheapest 3-star with engine %s: $%.2fM" % [eng, cheapest3])
	print("\nONE SLIDER AT A TIME (0 / 0.25 / 0.75 / 1):")
	for s: Dictionary in sliders:
		var parts: PackedStringArray = []
		for v in [0.0, 0.25, 0.75, 1.0]:
			parts.append(summary(evaluate({s["id"]: v})))
		print("  %-18s %s" % [s["id"], " | ".join(parts)])
	var all0 := {}
	var all1 := {}
	for s: Dictionary in sliders:
		all0[s["id"]] = 0.0
		all1[s["id"]] = 1.0
	print("\nALL AT 0: ", summary(evaluate(all0)))
	print("ALL AT 1: ", summary(evaluate(all1)))
	var grid_hits: Array = []
	for um in [0.25, 0.4, 0.5, 0.6]:
		for um2 in [0.25, 0.4, 0.5, 0.6]:
			for up in [0.4, 0.5, 0.6, 0.7]:
				for up2 in [0.4, 0.5, 0.6, 0.7]:
					for th in [0.5, 0.6]:
						var picks := {"upper_mass": um, "upper_mass2": um2, "upper2_mass": um2, "upper_propellant": up, "upper2_propellant": up2, "thrust": th}
						var r := evaluate(picks)
						if r["outcome"] == "success" and r["stars"] == 3:
							grid_hits.append(picks)
	print("
GRID (stage masses, upper fuel, thrust): %d three-star hits" % grid_hits.size())
	for i in mini(6, grid_hits.size()):
		print("   ", grid_hits[i])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for spread in [0.1, 0.2, 0.3, 0.5]:
		var counts := {"3": 0, "2": 0, "1": 0, "fail": 0}
		var best := {}
		var trials := 3000
		for t in trials:
			var picks := {}
			for s: Dictionary in sliders:
				picks[s["id"]] = clampf(0.5 + rng.randf_range(-spread, spread), 0.0, 1.0)
			var report := evaluate(picks)
			var key := "fail" if report["outcome"] == "failure" else str(report["stars"])
			counts[key] += 1
			if key == "3" and best.is_empty():
				best = picks
		print("\nRANDOM +-%.1f around 0.5: %s" % [spread, counts])
		if not best.is_empty():
			print("   example 3-star: ", best)
	quit()


func evaluate(picks: Dictionary) -> Dictionary:
	var paths := {}
	for s: Dictionary in sliders:
		if picks.has(s["id"]):
			for path in s["paths"]:
				paths[path] = picks[s["id"]]
	var design := DesignBuilder.from_sliders(reference, paths, engines, true)
	design["payload"] = DesignModes.level_payload(level)
	design["mission"] = DesignModes.level_mission(level)
	design["mission"].erase("budget_musd")
	return RocketEvaluator.evaluate(design, data)


func summary(report: Dictionary) -> String:
	if report["outcome"] == "failure":
		var ids: PackedStringArray = []
		for c: Dictionary in report["checks"]:
			if c["status"] == "fail":
				ids.append(c["id"].replace("stability_", "stab_").replace("upper_twr_stage_", "uTWR"))
		return "FAIL(%s)" % ",".join(ids)
	var warn: PackedStringArray = []
	for c: Dictionary in report["checks"]:
		if c["status"] == "warn":
			warn.append(c["id"].replace("stability_", "stab_"))
	return "%d*%s" % [report["stars"], "(" + ",".join(warn) + ")" if not warn.is_empty() else ""]


func cost_of(picks: Dictionary, loaded: Node) -> float:
	var paths := {}
	for s: Dictionary in sliders:
		if picks.has(s["id"]):
			for path in s["paths"]:
				paths[path] = picks[s["id"]]
	var design := DesignBuilder.from_sliders(reference, paths, engines, true)
	return float(CostModel.design_cost(design, engines, loaded.materials, loaded.cost_model)["total"])
