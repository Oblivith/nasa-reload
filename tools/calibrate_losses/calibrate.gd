# Code generated with AI assistance (Claude). Reviewed by team.
extends SceneTree
## Calibrates delta_v_map.json loss_model.gravity_loss_coeff_first_stage against the real
## Juno I putting Explorer 1 into a ~358 x 2,550 km orbit. Run once after changing the
## Juno-class data or the loss model, then copy the printed coefficient into the data:
##   Godot --headless --path . -s tools/calibrate_losses/calibrate.gd
##
## Solves: available dv / required dv = design_range_ratio (a small margin), with the
## Juno-class flying the lofted profile to the calibration orbit. Everything else in
## the loss model (drag coefficient, lofted upper-stage coefficient) is held fixed.

func _init() -> void:
	var loader: Node = load("res://scripts/systems/data_loader.gd").new()
	loader.load_all()
	var data: Dictionary = loader.sim_data()
	var loss: Dictionary = data["delta_v"]["loss_model"]
	var cal: Dictionary = loss["calibration"]
	var reference: Dictionary = loader.reference_rockets[str(cal["rocket"])]
	var design := DesignBuilder.from_sliders(reference, {}, loader.engines, true)
	design["payload"] = {"length_m": float(loader.levels["L1"].get("payload_length_m", 1.0)), "mass_kg": float(cal["payload_kg"])}
	design["mission"] = {"profile": "orbit_insertion", "target_perigee_km": float(cal["target_perigee_km"]),
			"target_apogee_km": float(cal["target_apogee_km"]), "latitude_deg": float(cal["latitude_deg"])}

	# With the first-stage coefficient set to 0, the budget holds every other term.
	loss["gravity_loss_coeff_first_stage"] = 0.0
	var report := RocketEvaluator.evaluate(design, data)
	var n: Dictionary = report["numbers"]
	var b: Dictionary = n["delta_v_budget"]
	var available := float(n["delta_v_available_ms"])
	var first_burn := float((n["burn_times_s"] as Array)[0])
	var target_required := available / float(cal["design_range_ratio"])
	var target_subtotal := target_required / (1.0 + float(b["margin_fraction"]))
	var gravity := target_subtotal - (float(b["insertion_ms"]) - float(b["rotation_bonus_ms"]) + float(b["drag_loss_ms"])
			+ float(b["gravity_loss_ms"]) + float(b["return_ms"]))
	var k := gravity / (RocketMath.G0 * first_burn)
	print("Juno-class: available %.0f m/s, lofted profile: %s" % [available, b["lofted"]])
	print("  v_insert %.0f (%.0f x %.0f km), spin bonus %.0f, drag loss %.0f, first-stage burn %.1f s" % [
		b["insertion_ms"], cal["target_perigee_km"], cal["target_apogee_km"], b["rotation_bonus_ms"], b["drag_loss_ms"], first_burn])
	print("  target ratio %.3f -> required %.0f m/s -> first-stage gravity loss %.0f m/s" % [cal["design_range_ratio"], target_required, gravity])
	print("CALIBRATED gravity_loss_coeff_first_stage = %.4f" % k)
	quit()
