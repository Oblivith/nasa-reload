# SI assistance metadata: This code used the help of SI.
class_name Stability
extends RefCounted

const NOSE_CN_ALPHA := 2.0

const NOSE_X_FACTORS := {
	"cone": 0.666,
	"ogive": 0.466,
	"parabolic": 0.5,
}

const MARGIN_STABLE_MIN := 1.0
const MARGIN_OVER_STABLE := 3.0
const MARGIN_GIMBAL_MIN := 0.3

static func nose_x_factor(shape: String, nose_shapes: Dictionary = {}) -> float:
	var entry: Dictionary = nose_shapes.get(shape, {})
	if entry.has("barrowman_x_factor"):
		return float(entry["barrowman_x_factor"])
	return float(NOSE_X_FACTORS.get(shape, 0.5))

static func nose_cp_x(nose_length: float, x_factor: float) -> float:
	return x_factor * nose_length

static func fin_mid_chord_length(span: float, sweep: float, root_chord: float, tip_chord: float) -> float:
	var offset := sweep + tip_chord / 2.0 - root_chord / 2.0
	return sqrt(span * span + offset * offset)

static func fin_cn_alpha(count: int, span: float, diameter: float, root_chord: float, tip_chord: float, sweep: float) -> float:
	if count <= 0 or span <= 0.0 or diameter <= 0.0 or root_chord + tip_chord <= 0.0:
		return 0.0
	var radius := diameter / 2.0
	var l_f := fin_mid_chord_length(span, sweep, root_chord, tip_chord)
	var interference := 1.0 + radius / (span + radius)
	var planform := 4.0 * float(count) * pow(span / diameter, 2.0)
	var slenderness := 1.0 + sqrt(1.0 + pow(2.0 * l_f / (root_chord + tip_chord), 2.0))
	return interference * planform / slenderness

static func fin_cp_x(x_b: float, sweep: float, root_chord: float, tip_chord: float) -> float:
	var chord_sum := root_chord + tip_chord
	if chord_sum <= 0.0:
		return x_b
	return x_b \
		+ (sweep / 3.0) * (root_chord + 2.0 * tip_chord) / chord_sum \
		+ (1.0 / 6.0) * (chord_sum - root_chord * tip_chord / chord_sum)

static func center_of_pressure(components: Array) -> float:
	var cn_total := 0.0
	var moment := 0.0
	for component: Dictionary in components:
		var cn := float(component.get("cn_alpha", 0.0))
		cn_total += cn
		moment += cn * float(component.get("x_m", 0.0))
	return moment / cn_total if cn_total > 0.0 else 0.0

static func center_of_mass(items: Array) -> float:
	var mass := 0.0
	var moment := 0.0
	for item: Dictionary in items:
		var m := float(item.get("mass_kg", 0.0))
		mass += m
		moment += m * float(item.get("x_m", 0.0))
	return moment / mass if mass > 0.0 else 0.0

static func static_margin(x_cp: float, x_cg: float, diameter: float) -> float:
	if diameter <= 0.0:
		return 0.0
	return (x_cp - x_cg) / diameter

static func barrowman(nose_length: float, nose_factor: float, diameter: float, fins: Dictionary, x_b: float) -> Dictionary:
	var root := float(fins.get("root_chord_m", 0.0))
	var tip := float(fins.get("tip_chord_m", 0.0))
	var span := float(fins.get("span_m", 0.0))
	var sweep := float(fins.get("sweep_m", 0.0))
	var count := int(fins.get("count", 0))
	var x_nose := nose_cp_x(nose_length, nose_factor)
	var cn_fins := fin_cn_alpha(count, span, diameter, root, tip, sweep)
	var x_fins := fin_cp_x(x_b, sweep, root, tip)
	var x_cp := center_of_pressure([
		{"cn_alpha": NOSE_CN_ALPHA, "x_m": x_nose},
		{"cn_alpha": cn_fins, "x_m": x_fins},
	])
	return {
		"cn_alpha_nose": NOSE_CN_ALPHA,
		"x_nose_m": x_nose,
		"cn_alpha_fins": cn_fins,
		"x_fins_m": x_fins,
		"fin_mid_chord_m": fin_mid_chord_length(span, sweep, root, tip),
		"cn_alpha_total": NOSE_CN_ALPHA + cn_fins,
		"x_cp_m": x_cp,
	}

static func classify(margin_cal: float, gimballed: bool) -> Dictionary:
	if margin_cal < 0.0:
		return {"class": "unstable", "status": "fail", "flyable": false}
	if margin_cal < MARGIN_STABLE_MIN:
		if gimballed and margin_cal >= MARGIN_GIMBAL_MIN:
			return {"class": "marginal", "status": "warn", "flyable": true}
		return {"class": "marginal", "status": "fail", "flyable": false}
	if margin_cal > MARGIN_OVER_STABLE:
		return {"class": "over_stable", "status": "warn", "flyable": true}
	return {"class": "stable", "status": "pass", "flyable": true}
