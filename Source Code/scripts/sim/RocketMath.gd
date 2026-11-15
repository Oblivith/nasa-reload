# SI assistance metadata: This code used the help of SI.
class_name RocketMath
extends RefCounted

const G0 := 9.80665

static func stage_delta_v(isp_s: float, m0_kg: float, mf_kg: float) -> float:
	if isp_s <= 0.0 or mf_kg <= 0.0 or m0_kg <= mf_kg:
		return 0.0
	return isp_s * G0 * log(m0_kg / mf_kg)

static func total_delta_v(stages: Array, payload_mass_kg: float) -> Dictionary:
	var per_stage: Array = []
	var total := 0.0
	for i in stages.size():
		var stage: Dictionary = stages[i]
		var above := payload_mass_kg
		for j in range(i + 1, stages.size()):
			var upper: Dictionary = stages[j]
			above += float(upper.get("dry_mass_kg", 0.0)) + float(upper.get("propellant_mass_kg", 0.0))
		var dry := float(stage.get("dry_mass_kg", 0.0))
		var propellant := float(stage.get("propellant_mass_kg", 0.0))
		var isp := float(stage.get("isp_s", 0.0))
		var m0 := above + dry + propellant
		var mf := above + dry
		var dv := stage_delta_v(isp, m0, mf)
		total += dv
		per_stage.append({
			"m0_kg": m0,
			"mf_kg": mf,
			"mass_ratio": m0 / mf if mf > 0.0 else 0.0,
			"isp_s": isp,
			"delta_v_ms": dv,
		})
	return {"total_ms": total, "stages": per_stage}

static func twr(thrust_N: float, mass_kg: float, g: float = G0) -> float:
	if mass_kg <= 0.0:
		return 0.0
	return thrust_N / (mass_kg * g)

static func mass_flow(thrust_N: float, isp_s: float) -> float:
	if isp_s <= 0.0:
		return 0.0
	return thrust_N / (isp_s * G0)

static func burn_time(propellant_mass_kg: float, isp_s: float, thrust_N: float) -> float:
	if thrust_N <= 0.0:
		return 0.0
	return propellant_mass_kg * isp_s * G0 / thrust_N

static func budget_isp(isp_sl: float, isp_vac: float, is_first_stage: bool) -> float:
	if is_first_stage and isp_sl > 0.0:
		return (isp_sl + isp_vac) / 2.0
	return isp_vac
