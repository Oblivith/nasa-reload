# Code generated with AI assistance (Claude). Reviewed by team.
class_name RocketMath
extends RefCounted
## Rocket performance maths: Tsiolkovsky delta-v, thrust-to-weight, burn time.
## Pure maths: SI units (kg, N, s, m/s), no UI.

const G0 := 9.80665  ## Standard gravity, m/s^2


## Tsiolkovsky rocket equation: dv = Isp * g0 * ln(m0 / mf).
## m0 = mass when the burn starts, mf = mass when it ends.
static func stage_delta_v(isp_s: float, m0_kg: float, mf_kg: float) -> float:
	if isp_s <= 0.0 or mf_kg <= 0.0 or m0_kg <= mf_kg:
		return 0.0
	return isp_s * G0 * log(m0_kg / mf_kg)


## Delta-v of a whole stack. `stages` is in firing order (index 0 burns first); each
## entry needs "isp_s", "dry_mass_kg" and "propellant_mass_kg". Every stage pushes its
## own mass plus everything above it (later stages + payload), then drops its dry mass.
## Returns {"total_ms", "stages": [{"m0_kg", "mf_kg", "mass_ratio", "isp_s", "delta_v_ms"}]}.
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


## Thrust-to-weight ratio: TWR = thrust / (mass * g).
static func twr(thrust_N: float, mass_kg: float, g: float = G0) -> float:
	if mass_kg <= 0.0:
		return 0.0
	return thrust_N / (mass_kg * g)


## Propellant mass flow: mdot = thrust / (Isp * g0). kg/s.
static func mass_flow(thrust_N: float, isp_s: float) -> float:
	if isp_s <= 0.0:
		return 0.0
	return thrust_N / (isp_s * G0)


## Burn time: t = m_propellant * Isp * g0 / thrust. Seconds.
static func burn_time(propellant_mass_kg: float, isp_s: float, thrust_N: float) -> float:
	if thrust_N <= 0.0:
		return 0.0
	return propellant_mass_kg * isp_s * G0 / thrust_N


## Isp used for a paper delta-v budget. A first stage climbs from sea level to near
## vacuum, so it gets the mean of its sea-level and vacuum Isp; upper stages get vacuum.
static func budget_isp(isp_sl: float, isp_vac: float, is_first_stage: bool) -> float:
	if is_first_stage and isp_sl > 0.0:
		return (isp_sl + isp_vac) / 2.0
	return isp_vac
