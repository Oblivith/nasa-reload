# Code generated with AI assistance (Claude). Reviewed by team.
class_name KitLibrary
extends RefCounted
## Placeholder geometry for every kit prop, in toy-brick blocks and the 60s palette.
## Convention: origin on the floor, the side a person uses faces +Z (they stand or sit
## at +Z looking toward -Z). Wall props have their back on the z = 0 plane.
## To replace a prop with real art, edit its scene in /scenes/world/kit/ instead.

const CREAM := Color("f2e8cf")
const PAPER := Color("fbf5e6")
const TEAL := Color("2a7b7b")
const TEAL_L := Color("8fc1b5")
const MUSTARD := Color("e9c46a")
const ORANGE := Color("c8551f")
const WOOD := Color("8c6a4a")
const WOOD_D := Color("6b4f36")
const INK := Color("2b2622")
const STEEL := Color("8c8577")
const STEEL_L := Color("b7b2a8")
const GREY := Color("4d5b63")
const GREY_L := Color("c9c2b0")
const IBM_BLUE := Color("54728c")
const IBM_GREY := Color("8fa3ad")
const RED := Color("c0392b")
const GREEN := Color("5f8f5a")
const CORK := Color("c9a66b")
const AMBER := Color("ffcf5a")
const CRT := Color("7dffb0")

const KINDS: Array[String] = [
	"desk", "chair", "table", "cafe_table", "workbench", "drafting_table", "filing_cabinet", "shelf_unit",
	"crate", "crate_stack", "barrel", "locker_row", "plant", "security_desk", "display_case", "bench_seat",
	"noticeboard", "water_fountain", "wall_clock", "dir_sign", "fire_extinguisher", "vending_machine",
	"coffee_station", "counter", "fridge", "gantry_crane", "work_light", "tool_cart", "rocket_stage",
	"instrument_rack", "tape_drive", "cpu_cabinet", "operator_console", "card_reader", "line_printer",
	"teletype", "pike_desk", "chart_board", "bookshelf", "moon_poster", "model_rocket", "tape_player",
	"dust_boxes", "coat_rack", "mc_console", "wall_screen", "status_board", "ceiling_fan", "sofa", "rug",
	"safe", "pa_speaker", "exit_sign", "trash_can", "floor_open", "tree", "flagpole", "car", "pad_plinth",
	"rail", "desk_lamp", "photo_frame", "window_blind",
]


static func build(kind: String, o: Dictionary, prop: KitProp) -> BrickMesh:
	var bm := BrickMesh.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind) + int(o.get("seed", 0)) * 7919
	prop.lod_range = 60.0
	match kind:
		"desk": _desk(bm, o, prop, rng)
		"chair": _chair(bm, Vector3.ZERO, Color(str(o.get("color", "2a7b7b"))))
		"table": _table(bm, o)
		"cafe_table": _cafe_table(bm, o, prop)
		"workbench": _workbench(bm, o, prop, rng)
		"drafting_table": _drafting_table(bm, prop)
		"filing_cabinet": _filing_cabinet(bm, o)
		"shelf_unit": _shelf_unit(bm, o, rng, false)
		"bookshelf": _shelf_unit(bm, o, rng, true)
		"crate": _crate(bm, Vector3.ZERO, float(o.get("s", 0.9)), true)
		"crate_stack": _crate_stack(bm, rng)
		"barrel": _barrel(bm, o)
		"locker_row": _locker_row(bm, o)
		"plant": _plant(bm, prop)
		"security_desk": _security_desk(bm, prop)
		"display_case": _display_case(bm, prop)
		"bench_seat": _bench_seat(bm)
		"noticeboard": _noticeboard(bm, o, prop, rng)
		"water_fountain": _water_fountain(bm, prop)
		"wall_clock": _wall_clock(bm, prop)
		"dir_sign": _dir_sign(bm, o, prop)
		"fire_extinguisher": _fire_extinguisher(bm, prop)
		"vending_machine": _vending_machine(bm, prop)
		"coffee_station": _coffee_station(bm, o, prop)
		"counter": _counter(bm, o)
		"fridge": _fridge(bm)
		"gantry_crane": _gantry_crane(bm, o, prop)
		"work_light": _work_light(bm, o, prop)
		"tool_cart": _tool_cart(bm)
		"rocket_stage": _rocket_stage(bm, o)
		"instrument_rack": _instrument_rack(bm, prop, rng)
		"tape_drive": _tape_drive(bm, prop, rng)
		"cpu_cabinet": _cpu_cabinet(bm, o, prop, rng)
		"operator_console": _operator_console(bm, prop, rng)
		"card_reader": _card_reader(bm, prop)
		"line_printer": _line_printer(bm, prop)
		"teletype": _teletype(bm, prop)
		"pike_desk": _pike_desk(bm, o, prop)
		"chart_board": _chart_board(bm, o, prop, rng)
		"moon_poster": _moon_poster(bm, o, prop)
		"model_rocket": _model_rocket(bm, o, prop)
		"tape_player": _tape_player(bm, o, prop)
		"dust_boxes": _dust_boxes(bm, rng)
		"coat_rack": _coat_rack(bm, prop)
		"mc_console": _mc_console(bm, o, prop, rng)
		"wall_screen": _wall_screen(bm, o, prop, rng)
		"status_board": _status_board(bm, o, prop, rng)
		"ceiling_fan": _ceiling_fan(bm, prop)
		"sofa": _sofa(bm, o)
		"rug": _rug(bm, o, prop)
		"safe": _safe(bm, prop)
		"pa_speaker": _pa_speaker(bm, prop)
		"exit_sign": _exit_sign(bm, o, prop)
		"trash_can": _trash_can(bm, prop)
		"floor_open": _floor_open(bm, prop)
		"tree": _tree(bm, rng)
		"flagpole": _flagpole(bm, prop)
		"car": _car(bm, o)
		"pad_plinth": _pad_plinth(bm, o, prop)
		"rail": _rail(bm, o)
		"desk_lamp": _desk_lamp(bm, Vector3.ZERO, prop)
		"photo_frame": _photo_frame(bm, prop)
		"window_blind": _window_blind(bm, o)
		_:
			push_warning("KitLibrary: unknown prop kind '%s'" % kind)
			b(bm, 0, 0.5, 0, 1, 1, 1, Color("ff00ff"))
	return bm


static func b(bm: BrickMesh, x: float, y: float, z: float, w: float, h: float, d: float, col: Color, surf: String = "matte") -> void:
	bm.box(Vector3(x, y, z), Vector3(w, h, d), col, surf)


## A grid of small panel lamps on a +Z-facing surface, each blinking on its own.
static func blink_grid(bm: BrickMesh, origin: Vector3, cols: int, rows: int, dx: float, dy: float, size: float,
		rng: RandomNumberGenerator, colors: Array = [AMBER], fill: float = 0.85, basis: Basis = Basis.IDENTITY) -> void:
	for r in rows:
		for c in cols:
			if rng.randf() > fill:
				continue
			var col: Color = colors[rng.randi() % colors.size()]
			var uv := Vector2(rng.randf() * 97.0, rng.randf_range(0.4, 3.0))
			bm.box(origin + basis * Vector3(c * dx, r * dy, 0), Vector3(size, size, 0.02), col, "blink", basis, 1.0, 1.0, uv)


# --- Furniture -----------------------------------------------------------------------

static func _desk(bm: BrickMesh, o: Dictionary, prop: KitProp, rng: RandomNumberGenerator) -> void:
	var top := Color(str(o.get("color", "8c6a4a")))
	b(bm, 0, 0.74, 0, 1.5, 0.05, 0.78, top, "gloss")
	b(bm, -0.5, 0.36, 0, 0.42, 0.72, 0.7, GREY_L)
	b(bm, 0.5, 0.36, 0, 0.42, 0.72, 0.7, GREY_L)
	b(bm, 0, 0.5, -0.36, 0.6, 0.4, 0.03, GREY_L)
	for i in 3:
		b(bm, 0.5, 0.16 + i * 0.22, 0.355, 0.2, 0.03, 0.02, INK)
	bm.collide(Vector3(0, 0.38, 0), Vector3(1.5, 0.76, 0.78))
	_chair(bm, Vector3(0, 0, 0.72), TEAL if not o.has("chair") else Color(str(o["chair"])))
	prop.spot(Vector3(0, 0, 0.72), PI, "sit")
	if bool(o.get("typewriter", false)):
		_typewriter(bm, Vector3(0, 0.765, 0.05))
		prop.sound("typewriter", Vector3(0, 0.9, 0))
	if bool(o.get("phone", false)):
		_phone(bm, Vector3(0.52, 0.765, -0.12))
		prop.sound("phone", Vector3(0.52, 0.9, -0.12))
	if bool(o.get("lamp", false)):
		_desk_lamp(bm, Vector3(-0.55, 0.765, -0.2), prop)
	if bool(o.get("papers", true)):
		for i in 1 + rng.randi() % 3:
			bm.box(Vector3(rng.randf_range(-0.6, 0.6), 0.772 + i * 0.004, rng.randf_range(-0.25, 0.25)), Vector3(0.21, 0.006, 0.3),
					PAPER, "matte", Basis(Vector3.UP, rng.randf_range(-0.5, 0.5)))
	if bool(o.get("mug", false)):
		bm.cyl(Vector3(0.3, 0.82, 0.2), 0.045, 0.1, ORANGE)


static func _chair(bm: BrickMesh, at: Vector3, col: Color) -> void:
	bm.box(at + Vector3(0, 0.44, 0), Vector3(0.44, 0.06, 0.44), col)
	bm.box(at + Vector3(0, 0.75, 0.2), Vector3(0.42, 0.42, 0.05), col)
	bm.cyl(at + Vector3(0, 0.22, 0), 0.035, 0.42, STEEL, "metal", 1, 6)
	bm.box(at + Vector3(0, 0.03, 0), Vector3(0.46, 0.04, 0.06), STEEL, "metal")
	bm.box(at + Vector3(0, 0.03, 0), Vector3(0.06, 0.04, 0.46), STEEL, "metal")


static func _typewriter(bm: BrickMesh, at: Vector3) -> void:
	bm.box(at + Vector3(0, 0.05, 0.05), Vector3(0.36, 0.1, 0.3), TEAL_L, "gloss")
	bm.box(at + Vector3(0, 0.13, -0.08), Vector3(0.42, 0.06, 0.08), INK)
	bm.box(at + Vector3(0, 0.19, -0.09), Vector3(0.24, 0.16, 0.01), PAPER)
	bm.box(at + Vector3(0, 0.105, 0.12), Vector3(0.28, 0.01, 0.12), INK)


static func _phone(bm: BrickMesh, at: Vector3) -> void:
	bm.box(at + Vector3(0, 0.035, 0), Vector3(0.2, 0.07, 0.22), INK, "gloss")
	bm.box(at + Vector3(0, 0.09, -0.04), Vector3(0.24, 0.04, 0.06), INK, "gloss")
	bm.cyl(at + Vector3(0, 0.075, 0.04), 0.05, 0.012, PAPER, "matte", 1, 8)


static func _desk_lamp(bm: BrickMesh, at: Vector3, prop: KitProp) -> void:
	bm.cyl(at + Vector3(0, 0.015, 0), 0.08, 0.03, INK, "gloss", 1, 8)
	bm.box(at + Vector3(0, 0.17, 0), Vector3(0.025, 0.3, 0.025), STEEL, "metal")
	bm.cyl(at + Vector3(0.06, 0.33, 0.05), 0.11, 0.1, TEAL, "gloss", 1, 8, 0.05)
	bm.cyl(at + Vector3(0.06, 0.285, 0.05), 0.09, 0.01, Color("ffe2a8"), "glow", 1, 8)
	prop.lamp(at + Vector3(0.1, 0.3, 0.15), Color("ffd9a0"), 1.1, 3.2)


static func _table(bm: BrickMesh, o: Dictionary) -> void:
	var w := float(o.get("w", 1.6))
	var d := float(o.get("d", 0.8))
	var h := float(o.get("h", 0.74))
	b(bm, 0, h, 0, w, 0.05, d, Color(str(o.get("color", "8c6a4a"))), "gloss")
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			b(bm, sx * (w / 2 - 0.06), h / 2, sz * (d / 2 - 0.06), 0.06, h, 0.06, STEEL, "metal")
	bm.collide(Vector3(0, h / 2, 0), Vector3(w, h, d))


static func _cafe_table(bm: BrickMesh, o: Dictionary, prop: KitProp) -> void:
	bm.cyl(Vector3(0, 0.73, 0), 0.55, 0.04, Color(str(o.get("color", "e9c46a"))), "gloss", 1, 14)
	bm.cyl(Vector3(0, 0.36, 0), 0.05, 0.72, STEEL, "metal", 1, 6)
	bm.cyl(Vector3(0, 0.02, 0), 0.3, 0.04, STEEL, "metal", 1, 10)
	bm.collide(Vector3(0, 0.37, 0), Vector3(0.8, 0.74, 0.8))
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		var p := Vector3(sin(a), 0, cos(a)) * 0.95
		bm.cyl(p + Vector3(0, 0.45, 0), 0.2, 0.06, ORANGE if i % 2 == 0 else TEAL, "gloss", 1, 10)
		bm.cyl(p + Vector3(0, 0.21, 0), 0.03, 0.42, STEEL, "metal", 1, 6)
		prop.spot(p, a + PI, "sit")
	if bool(o.get("mugs", true)):
		bm.cyl(Vector3(0.2, 0.8, 0.1), 0.045, 0.1, PAPER)
		bm.cyl(Vector3(-0.15, 0.8, -0.2), 0.045, 0.1, TEAL)
		b(bm, -0.1, 0.76, 0.25, 0.22, 0.01, 0.3, PAPER)


static func _workbench(bm: BrickMesh, o: Dictionary, prop: KitProp, rng: RandomNumberGenerator) -> void:
	var w := float(o.get("w", 2.6))
	b(bm, 0, 0.88, 0, w, 0.08, 0.9, WOOD, "wood")
	b(bm, 0, 0.3, 0, w - 0.2, 0.04, 0.8, STEEL)
	for sx: float in [-1.0, 1.0]:
		b(bm, sx * (w / 2 - 0.08), 0.42, 0, 0.1, 0.84, 0.86, GREY)
	b(bm, 0, 1.5, -0.42, w, 1.1, 0.05, CORK)
	for i in 7:
		var col: Color = [RED, MUSTARD, TEAL, STEEL_L, ORANGE][rng.randi() % 5]
		b(bm, -w / 2 + 0.25 + i * (w - 0.5) / 6.0, 1.45 + rng.randf_range(-0.25, 0.3), -0.38, 0.07, rng.randf_range(0.2, 0.45), 0.04, col)
	b(bm, w / 2 - 0.35, 0.99, 0.15, 0.22, 0.14, 0.3, GREY, "metal")
	bm.cyl(Vector3(-w / 2 + 0.5, 1.07, 0.05), 0.16, 0.3, PAPER, "gloss", 2, 10)
	bm.cyl(Vector3(-w / 2 + 0.5, 1.07, 0.26), 0.16, 0.12, ORANGE, "gloss", 2, 10, 0.02)
	b(bm, 0.1, 0.94, 0.1, 0.5, 0.03, 0.36, TEAL_L)
	bm.collide(Vector3(0, 0.46, 0), Vector3(w, 0.92, 0.9))
	prop.spot(Vector3(-0.3, 0, 0.75), PI, "tinker")
	prop.lamp(Vector3(0, 1.9, 0.3), Color("fff0d0"), 0.9, 4.0)


static func _drafting_table(bm: BrickMesh, prop: KitProp) -> void:
	var tilt := Basis(Vector3.RIGHT, 0.42)
	bm.box(Vector3(0, 1.0, 0), Vector3(1.5, 0.05, 1.0), GREY_L, "gloss", tilt)
	bm.box(Vector3(0, 1.03, 0.01), Vector3(1.2, 0.01, 0.8), Color("cfe0ea"), "matte", tilt)
	bm.box(Vector3(0, 1.045, 0.1), Vector3(1.3, 0.012, 0.05), WOOD, "matte", tilt)
	for sx: float in [-1.0, 1.0]:
		b(bm, sx * 0.6, 0.48, 0, 0.06, 0.96, 0.6, TEAL, "metal")
		b(bm, sx * 0.6, 0.03, 0, 0.08, 0.06, 0.8, TEAL, "metal")
	b(bm, 0, 0.3, 0, 1.2, 0.05, 0.05, TEAL, "metal")
	b(bm, -0.7, 1.45, -0.4, 0.03, 0.5, 0.03, STEEL, "metal")
	bm.cyl(Vector3(-0.5, 1.7, -0.25), 0.12, 0.1, MUSTARD, "gloss", 1, 8, 0.05)
	bm.cyl(Vector3(-0.5, 1.65, -0.25), 0.1, 0.01, Color("ffe2a8"), "glow", 1, 8)
	prop.lamp(Vector3(-0.4, 1.55, 0.0), Color("ffe0b0"), 1.0, 3.0)
	bm.collide(Vector3(0, 0.55, 0), Vector3(1.4, 1.1, 0.8))
	prop.spot(Vector3(0, 0, 0.8), PI, "write")


static func _filing_cabinet(bm: BrickMesh, o: Dictionary) -> void:
	var n := int(o.get("n", 1))
	var col := Color(str(o.get("color", "8c8577")))
	for i in n:
		var x := (i - (n - 1) / 2.0) * 0.5
		b(bm, x, 0.66, 0, 0.47, 1.32, 0.62, col, "metal")
		for d in 4:
			b(bm, x, 0.2 + d * 0.31, 0.315, 0.4, 0.26, 0.012, col.lightened(0.12), "metal")
			b(bm, x, 0.26 + d * 0.31, 0.325, 0.14, 0.025, 0.02, INK)
	bm.collide(Vector3(0, 0.66, 0), Vector3(0.5 * n, 1.32, 0.62))


static func _shelf_unit(bm: BrickMesh, o: Dictionary, rng: RandomNumberGenerator, books: bool) -> void:
	var w := float(o.get("w", 2.0))
	var h := float(o.get("h", 2.2))
	var d := float(o.get("d", 0.5))
	var frame := WOOD_D if books else GREY
	for sx: float in [-1.0, 1.0]:
		b(bm, sx * (w / 2 - 0.03), h / 2, 0, 0.06, h, d, frame, "metal" if not books else "wood")
	var levels := int(h / 0.5)
	for l in levels + 1:
		var y := 0.06 + l * (h - 0.1) / levels
		b(bm, 0, y, 0, w - 0.06, 0.04, d, frame, "metal" if not books else "wood")
		if l == levels:
			continue
		var x := -w / 2 + 0.12
		while x < w / 2 - 0.2:
			if books:
				var bw := rng.randf_range(0.04, 0.09)
				var bh := rng.randf_range(0.26, 0.4)
				var bc: Color = [TEAL, ORANGE, MUSTARD, WOOD_D, CREAM, RED, GREY][rng.randi() % 7]
				if rng.randf() < 0.9:
					b(bm, x + bw / 2, y + 0.02 + bh / 2, 0, bw, bh, d * 0.7, bc)
				x += bw + 0.008
			else:
				var cw := rng.randf_range(0.25, 0.5)
				var ch := rng.randf_range(0.18, 0.36)
				if rng.randf() < 0.8:
					var cc: Color = [CORK, GREY_L, TEAL_L, MUSTARD, STEEL_L, ORANGE][rng.randi() % 6]
					b(bm, x + cw / 2, y + 0.02 + ch / 2, 0, cw, ch, d * 0.75, cc)
				x += cw + 0.06
	bm.collide(Vector3(0, h / 2, 0), Vector3(w, h, d))


static func _crate(bm: BrickMesh, at: Vector3, s: float, solid: bool, yaw: float = 0.0) -> void:
	var basis := Basis(Vector3.UP, yaw)
	bm.box(at + Vector3(0, s / 2, 0), Vector3(s, s, s), CORK, "wood", basis)
	for sy: float in [-1.0, 1.0]:
		bm.box(at + Vector3(0, s / 2 + sy * (s / 2 - 0.05), 0), Vector3(s + 0.04, 0.1, s + 0.04), WOOD, "wood", basis)
	bm.box(at + Vector3(0, s / 2, 0), Vector3(0.1, s, s + 0.04), WOOD, "wood", basis)
	if solid:
		bm.collide(at + Vector3(0, s / 2, 0), Vector3(s, s, s), basis)


static func _crate_stack(bm: BrickMesh, rng: RandomNumberGenerator) -> void:
	_crate(bm, Vector3(-0.5, 0, 0), 0.95, false, rng.randf_range(-0.1, 0.1))
	_crate(bm, Vector3(0.55, 0, 0.05), 0.9, false, rng.randf_range(-0.15, 0.15))
	_crate(bm, Vector3(0.0, 0.95, 0), 0.8, false, rng.randf_range(-0.3, 0.3))
	if rng.randf() < 0.6:
		_crate(bm, Vector3(0.1, 0, 1.0), 0.7, false, rng.randf_range(-0.4, 0.4))
	bm.collide(Vector3(0, 0.9, 0.1), Vector3(2.0, 1.8, 1.2))


static func _barrel(bm: BrickMesh, o: Dictionary) -> void:
	var col := Color(str(o.get("color", "c8551f")))
	bm.cyl(Vector3(0, 0.45, 0), 0.3, 0.9, col, "metal", 1, 12)
	for y: float in [0.25, 0.65]:
		bm.cyl(Vector3(0, y, 0), 0.315, 0.04, col.darkened(0.25), "metal", 1, 12)
	bm.collide(Vector3(0, 0.45, 0), Vector3(0.55, 0.9, 0.55))


static func _locker_row(bm: BrickMesh, o: Dictionary) -> void:
	var n := int(o.get("n", 4))
	for i in n:
		var x := (i - (n - 1) / 2.0) * 0.42
		b(bm, x, 0.95, 0, 0.4, 1.9, 0.45, TEAL if i % 2 == 0 else TEAL_L, "metal")
		b(bm, x + 0.12, 1.0, 0.23, 0.03, 0.12, 0.02, STEEL_L, "metal")
		for v in 3:
			b(bm, x, 1.6 + v * 0.06, 0.228, 0.24, 0.02, 0.01, INK)
	bm.collide(Vector3(0, 0.95, 0), Vector3(0.42 * n, 1.9, 0.45))


static func _plant(bm: BrickMesh, prop: KitProp) -> void:
	prop.lod_range = 35.0
	bm.cyl(Vector3(0, 0.2, 0), 0.22, 0.4, ORANGE, "matte", 1, 8, 0.28)
	bm.cyl(Vector3(0, 0.6, 0), 0.04, 0.5, WOOD_D, "matte", 1, 6)
	for i in 6:
		var a := TAU * i / 6.0
		bm.box(Vector3(sin(a) * 0.22, 0.95 + (i % 3) * 0.16, cos(a) * 0.22), Vector3(0.36, 0.06, 0.2), GREEN if i % 2 == 0 else GREEN.darkened(0.15),
				"matte", Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, 0.5))
	bm.box(Vector3(0, 1.35, 0), Vector3(0.3, 0.2, 0.3), GREEN)
	bm.collide(Vector3(0, 0.5, 0), Vector3(0.45, 1.0, 0.45))


static func _sofa(bm: BrickMesh, o: Dictionary) -> void:
	var w := float(o.get("w", 1.8))
	var col := Color(str(o.get("color", "c8551f")))
	b(bm, 0, 0.3, 0, w, 0.24, 0.75, col)
	b(bm, 0, 0.62, -0.3, w, 0.5, 0.18, col.darkened(0.08))
	for sx: float in [-1.0, 1.0]:
		b(bm, sx * (w / 2 - 0.08), 0.42, 0, 0.16, 0.48, 0.75, col.darkened(0.12))
	b(bm, 0, 0.09, 0, w - 0.2, 0.18, 0.6, WOOD_D)
	bm.collide(Vector3(0, 0.4, 0), Vector3(w, 0.8, 0.75))


static func _rug(bm: BrickMesh, o: Dictionary, prop: KitProp) -> void:
	prop.lod_range = 40.0
	var w := float(o.get("w", 3.0))
	var d := float(o.get("d", 2.0))
	var col := Color(str(o.get("color", "2a7b7b")))
	b(bm, 0, 0.008, 0, w, 0.016, d, col, "carpet")
	b(bm, 0, 0.012, 0, w - 0.4, 0.016, d - 0.4, col.lightened(0.2), "carpet")


static func _coat_rack(bm: BrickMesh, prop: KitProp) -> void:
	prop.lod_range = 35.0
	bm.cyl(Vector3(0, 0.9, 0), 0.03, 1.8, WOOD_D, "wood", 1, 6)
	bm.cyl(Vector3(0, 0.02, 0), 0.22, 0.04, WOOD_D, "wood", 1, 8)
	b(bm, 0, 1.7, 0, 0.5, 0.03, 0.03, WOOD_D)
	b(bm, 0, 1.7, 0, 0.03, 0.03, 0.5, WOOD_D)
	b(bm, 0.2, 1.3, 0, 0.12, 0.75, 0.3, GREY)
	bm.cyl(Vector3(-0.22, 1.76, 0), 0.14, 0.1, WOOD, "matte", 1, 8, 0.1)


static func _trash_can(bm: BrickMesh, prop: KitProp) -> void:
	prop.lod_range = 25.0
	bm.cyl(Vector3(0, 0.2, 0), 0.16, 0.4, GREY, "metal", 1, 8, 0.2)
	b(bm, 0.03, 0.4, 0, 0.14, 0.06, 0.1, PAPER)


static func _photo_frame(bm: BrickMesh, prop: KitProp) -> void:
	prop.lod_range = 15.0
	bm.box(Vector3(0, 0.1, 0), Vector3(0.18, 0.2, 0.02), WOOD_D, "wood", Basis(Vector3.RIGHT, -0.2))
	bm.box(Vector3(0, 0.1, 0.012), Vector3(0.14, 0.16, 0.01), Color("d8cdb4"), "matte", Basis(Vector3.RIGHT, -0.2))


static func _window_blind(bm: BrickMesh, o: Dictionary) -> void:
	var w := float(o.get("w", 2.0))
	var h := float(o.get("h", 1.6))
	var slats := int(h / 0.12)
	for i in slats:
		bm.box(Vector3(0, i * 0.12 + 0.06, 0.05), Vector3(w, 0.012, 0.09), CREAM, "matte", Basis(Vector3.RIGHT, 0.5))


# --- Lobby and corridors -------------------------------------------------------------

static func _security_desk(bm: BrickMesh, prop: KitProp) -> void:
	b(bm, 0, 0.55, 0, 3.2, 1.1, 0.5, TEAL, "gloss")
	b(bm, 0, 1.12, 0, 3.3, 0.05, 0.6, WOOD, "wood")
	b(bm, 1.35, 0.4, -0.75, 0.5, 0.8, 1.0, TEAL, "gloss")
	b(bm, 0, 0.76, -0.5, 2.6, 0.04, 0.6, WOOD, "wood")
	b(bm, -1.0, 1.16, 0.05, 0.5, 0.03, 0.36, PAPER)          # the sign-in book
	b(bm, -1.0, 1.165, 0.05, 0.01, 0.035, 0.36, INK)
	b(bm, -0.72, 1.17, 0.12, 0.02, 0.02, 0.16, ORANGE)       # pen
	_phone(bm, Vector3(0.6, 0.78, -0.5))
	b(bm, 0.0, 1.4, -0.1, 0.6, 0.5, 0.04, WOOD_D)            # key rack
	for i in 8:
		b(bm, -0.22 + (i % 4) * 0.15, 1.3 + (i / 4) * 0.2, -0.07, 0.03, 0.09, 0.01, MUSTARD, "metal")
	bm.collide(Vector3(0, 0.6, -0.1), Vector3(3.3, 1.2, 0.8))
	bm.collide(Vector3(1.35, 0.4, -0.75), Vector3(0.5, 0.8, 1.0))
	_chair(bm, Vector3(0, 0, -1.1), INK)
	prop.spot(Vector3(0, 0, -1.1), 0.0, "sit")
	prop.label("SECURITY", Vector3(0, 0.75, 0.26), 72, PAPER)
	prop.label("ALL VISITORS\nMUST SIGN IN", Vector3(-1.0, 0.45, 0.26), 30, MUSTARD)
	prop.sound("phone", Vector3(0.6, 0.9, -0.5))


static func _display_case(bm: BrickMesh, prop: KitProp) -> void:
	b(bm, 0, 0.45, 0, 2.4, 0.9, 0.9, WOOD_D, "wood")
	b(bm, 0, 0.92, 0, 2.5, 0.05, 1.0, WOOD, "wood")
	b(bm, 0, 1.5, 0, 2.4, 1.1, 0.9, Color(0.75, 0.92, 0.95, 0.16), "glass")
	b(bm, 0, 2.07, 0, 2.5, 0.05, 1.0, WOOD, "wood")
	var rockets := [[-0.8, 0.5, 0.06, CREAM, ORANGE], [-0.25, 0.75, 0.07, PAPER, TEAL], [0.35, 0.95, 0.09, CREAM, RED], [0.9, 0.6, 0.05, MUSTARD, INK]]
	for r: Array in rockets:
		var x: float = r[0]
		var h: float = r[1]
		var rad: float = r[2]
		bm.cyl(Vector3(x, 0.97, 0), rad * 2.2, 0.04, INK, "gloss", 1, 8)
		bm.cyl(Vector3(x, 0.99 + h / 2, 0), rad, h, r[3], "gloss", 1, 10)
		bm.cyl(Vector3(x, 0.99 + h * 0.6, 0), rad * 1.02, h * 0.08, r[4], "gloss", 1, 10)
		bm.cyl(Vector3(x, 0.99 + h + rad * 1.4, 0), rad, rad * 2.8, r[4], "gloss", 1, 10, 0.0)
		for f in 3:
			bm.box(Vector3(x, 1.06, 0) + Basis(Vector3.UP, TAU * f / 3.0) * Vector3(rad * 1.5, 0, 0), Vector3(rad * 1.4, 0.14, 0.012), r[4], "gloss",
					Basis(Vector3.UP, TAU * f / 3.0))
	prop.label("THE ROAD TO ORBIT", Vector3(0, 0.6, 0.46), 44, MUSTARD)
	prop.lamp(Vector3(0, 1.95, 0), Color("fff0cf"), 1.0, 3.0)
	bm.cyl(Vector3(0, 2.03, 0), 0.5, 0.02, Color("fff0cf"), "glow", 1, 10)
	bm.collide(Vector3(0, 1.05, 0), Vector3(2.5, 2.1, 1.0))
	prop.spot(Vector3(0.3, 0, 1.2), PI, "stand")


static func _bench_seat(bm: BrickMesh) -> void:
	b(bm, 0, 0.42, 0, 1.8, 0.08, 0.5, ORANGE)
	b(bm, 0, 0.75, -0.22, 1.8, 0.35, 0.06, ORANGE)
	for sx: float in [-1.0, 1.0]:
		b(bm, sx * 0.75, 0.2, 0, 0.05, 0.4, 0.45, STEEL, "metal")
	bm.collide(Vector3(0, 0.3, 0), Vector3(1.8, 0.6, 0.5))


static func _noticeboard(bm: BrickMesh, o: Dictionary, prop: KitProp, rng: RandomNumberGenerator) -> void:
	prop.lod_range = 40.0
	var w := float(o.get("w", 1.8))
	b(bm, 0, 1.55, 0.02, w, 1.1, 0.04, WOOD_D, "wood")
	b(bm, 0, 1.55, 0.045, w - 0.12, 0.98, 0.01, CORK)
	for i in 9:
		var col: Color = [PAPER, PAPER, MUSTARD, TEAL_L, Color("f0c9b0"), CREAM][rng.randi() % 6]
		var nw := rng.randf_range(0.16, 0.3)
		var nh := rng.randf_range(0.18, 0.34)
		bm.box(Vector3(rng.randf_range(-w / 2 + 0.25, w / 2 - 0.25), 1.55 + rng.randf_range(-0.3, 0.3), 0.055 + i * 0.001), Vector3(nw, nh, 0.004),
				col, "matte", Basis(Vector3.BACK, rng.randf_range(-0.12, 0.12)))
	prop.label(str(o.get("title", "NOTICES")), Vector3(0, 2.2, 0.03), 40, PAPER)
	prop.spot(Vector3(0, 0, 0.9), PI, "stand")


static func _water_fountain(bm: BrickMesh, prop: KitProp) -> void:
	prop.lod_range = 35.0
	b(bm, 0, 0.5, 0.18, 0.4, 1.0, 0.36, STEEL_L, "metal")
	b(bm, 0, 1.02, 0.2, 0.44, 0.06, 0.42, STEEL, "metal")
	b(bm, 0, 1.055, 0.2, 0.3, 0.01, 0.28, GREY)
	bm.cyl(Vector3(0.1, 1.1, 0.1), 0.015, 0.08, STEEL_L, "metal", 1, 6)
	bm.collide(Vector3(0, 0.52, 0.2), Vector3(0.44, 1.05, 0.42))
	prop.spot(Vector3(0, 0, 0.75), PI, "stand")


static func _wall_clock(bm: BrickMesh, prop: KitProp) -> void:
	prop.lod_range = 35.0
	var c := Vector3(0, 2.55, 0.04)
	bm.cyl(c, 0.2, 0.05, INK, "gloss", 2, 16)
	bm.cyl(c + Vector3(0, 0, 0.03), 0.175, 0.01, PAPER, "matte", 2, 16)
	for i in 12:
		var a := TAU * i / 12.0
		bm.box(c + Vector3(sin(a) * 0.145, cos(a) * 0.145, 0.037), Vector3(0.012, 0.035, 0.004), INK, "matte", Basis(Vector3.BACK, -a))
	var hands := {}
	for spec: Array in [["hour", 0.09, 0.02, INK], ["minute", 0.14, 0.014, INK], ["second", 0.15, 0.006, RED]]:
		var hand := BrickMesh.new()
		hand.box(Vector3(0, float(spec[1]) / 2.0, 0), Vector3(spec[2], spec[1], 0.004), spec[3])
		hands[spec[0]] = prop.part(hand, c + Vector3(0, 0, 0.042 + 0.003 * hands.size()), str(spec[0]).capitalize())
	prop.anim({"type": "clock", "hour": hands["hour"], "minute": hands["minute"], "second": hands["second"]})
	prop.sound("clock_tick", c)


static func _dir_sign(bm: BrickMesh, o: Dictionary, prop: KitProp) -> void:
	prop.lod_range = 45.0
	var lines: Array = o.get("lines", [str(o.get("text", ""))])
	var w := float(o.get("w", 2.6))
	var h := 0.2 + 0.26 * lines.size()
	var y := float(o.get("mount", 2.45))
	var col := Color(str(o.get("color", "2a7b7b")))
	if bool(o.get("hanging", false)):
		# Hangs from the ceiling across a corridor; text on both faces.
		b(bm, 0, y, 0, w, h, 0.05, col)
		for sx: float in [-1.0, 1.0]:
			b(bm, sx * (w / 2 - 0.15), y + h / 2 + 0.2, 0, 0.02, 0.4, 0.02, STEEL, "metal")
		var back: Array = o.get("lines_back", lines)
		for i in lines.size():
			var ly := y + h / 2 - 0.23 - i * 0.26
			prop.label(str(lines[i]), Vector3(0, ly, 0.03), 46, PAPER, 0.0, 0.0, 40.0)
			prop.label(str(back[mini(i, back.size() - 1)]), Vector3(0, ly, -0.03), 46, PAPER, PI, 0.0, 40.0)
	else:
		b(bm, 0, y, 0.02, w, h, 0.03, col)
		for i in lines.size():
			prop.label(str(lines[i]), Vector3(0, y + h / 2 - 0.23 - i * 0.26, 0.04), 46, PAPER, 0.0, 0.0, 40.0)


static func _fire_extinguisher(bm: BrickMesh, prop: KitProp) -> void:
	prop.lod_range = 25.0
	bm.cyl(Vector3(0, 1.1, 0.1), 0.08, 0.45, RED, "gloss", 1, 8)
	bm.cyl(Vector3(0, 1.37, 0.1), 0.03, 0.1, INK, "matte", 1, 6)
	b(bm, 0, 1.6, 0.01, 0.2, 0.2, 0.01, RED)


static func _exit_sign(bm: BrickMesh, o: Dictionary, prop: KitProp) -> void:
	prop.lod_range = 45.0
	var y := float(o.get("mount", 2.75))
	b(bm, 0, y, 0.04, 0.62, 0.24, 0.07, INK)
	b(bm, 0, y, 0.08, 0.56, 0.18, 0.01, Color("ff5a3a"), "glow")
	prop.label(str(o.get("text", "EXIT")), Vector3(0, y, 0.09), 38, INK)


static func _pa_speaker(bm: BrickMesh, prop: KitProp) -> void:
	prop.lod_range = 35.0
	b(bm, 0, 2.85, 0.05, 0.2, 0.2, 0.1, GREY, "metal")
	bm.cyl(Vector3(0, 2.85, 0.22), 0.07, 0.26, GREY_L, "metal", 2, 10, 0.2)
	prop.sound("pa", Vector3(0, 2.85, 0.3))


# --- Cafeteria -----------------------------------------------------------------------

static func _vending_machine(bm: BrickMesh, prop: KitProp) -> void:
	b(bm, 0, 0.95, 0, 0.95, 1.9, 0.8, ORANGE, "gloss")
	b(bm, -0.12, 1.25, 0.405, 0.6, 1.0, 0.01, Color("fff1c9"), "glow")
	b(bm, -0.12, 0.45, 0.405, 0.6, 0.2, 0.02, INK)
	b(bm, 0.32, 1.35, 0.405, 0.16, 0.5, 0.02, CREAM)
	for i in 5:
		b(bm, 0.32, 1.15 + i * 0.1, 0.42, 0.08, 0.05, 0.02, [RED, MUSTARD, TEAL, PAPER, GREEN][i], "gloss")
	for r in 4:
		for c in 4:
			bm.cyl(Vector3(-0.33 + c * 0.14, 0.86 + r * 0.24, 0.39), 0.045, 0.12, [RED, TEAL, MUSTARD, CREAM][(r + c) % 4], "gloss", 1, 6)
	prop.label("COLA\n5c", Vector3(0.32, 1.72, 0.41), 26, INK)
	bm.collide(Vector3(0, 0.95, 0), Vector3(0.95, 1.9, 0.8))
	prop.lamp(Vector3(0, 1.3, 0.9), Color("ffe6b0"), 0.8, 3.0)
	prop.spot(Vector3(0.05, 0, 0.95), PI, "press")
	prop.sound("vending", Vector3(0, 1.0, 0.4))


static func _coffee_station(bm: BrickMesh, o: Dictionary, prop: KitProp) -> void:
	b(bm, 0, 0.45, 0, 1.8, 0.9, 0.6, TEAL_L, "gloss")
	b(bm, 0, 0.92, 0, 1.86, 0.04, 0.66, PAPER, "gloss")
	bm.cyl(Vector3(-0.5, 1.12, 0), 0.13, 0.36, STEEL_L, "metal", 1, 10)       # the percolator
	bm.cyl(Vector3(-0.5, 1.33, 0), 0.05, 0.06, INK, "matte", 1, 6)
	b(bm, -0.34, 1.15, 0, 0.08, 0.04, 0.03, INK)
	b(bm, -0.5, 0.95, 0, 0.34, 0.03, 0.34, INK)
	var mug_colors := [ORANGE, PAPER, MUSTARD, TEAL, ORANGE, CREAM, RED, TEAL_L]
	for m in int(o.get("mugs", 8)):
		bm.cyl(Vector3(-0.1 + (m % 4) * 0.2, 0.99, -0.12 + (m / 4) * 0.22), 0.05, 0.1, mug_colors[m % 8], "gloss", 1, 8)
	prop.label(str(o.get("sign", "")), Vector3(0.2, 1.5, -0.28), 28, INK)
	b(bm, 0.2, 1.5, -0.29, 0.9, 0.3, 0.01, PAPER)
	bm.collide(Vector3(0, 0.47, 0), Vector3(1.86, 0.94, 0.66))
	prop.sound("coffee", Vector3(-0.5, 1.1, 0))


static func _counter(bm: BrickMesh, o: Dictionary) -> void:
	var w := float(o.get("w", 3.0))
	b(bm, 0, 0.45, 0, w, 0.9, 0.62, Color(str(o.get("color", "8fc1b5"))), "gloss")
	b(bm, 0, 0.92, 0, w + 0.06, 0.04, 0.68, PAPER, "gloss")
	b(bm, w / 2 - 0.6, 0.93, 0, 0.6, 0.03, 0.42, STEEL, "metal")
	for i in int(w / 0.6):
		b(bm, -w / 2 + 0.3 + i * 0.6, 0.6, 0.315, 0.1, 0.02, 0.02, STEEL, "metal")
	bm.collide(Vector3(0, 0.47, 0), Vector3(w, 0.94, 0.66))


static func _fridge(bm: BrickMesh) -> void:
	b(bm, 0, 0.85, 0, 0.75, 1.7, 0.7, PAPER, "gloss")
	b(bm, 0, 1.25, 0.352, 0.7, 0.01, 0.01, GREY)
	b(bm, -0.28, 1.0, 0.37, 0.03, 0.3, 0.03, STEEL, "metal")
	bm.collide(Vector3(0, 0.85, 0), Vector3(0.75, 1.7, 0.7))


static func _ceiling_fan(bm: BrickMesh, prop: KitProp) -> void:
	prop.lod_range = 40.0
	var y := 3.0
	bm.cyl(Vector3(0, y + 0.15, 0), 0.03, 0.3, STEEL, "metal", 1, 6)
	bm.cyl(Vector3(0, y, 0), 0.12, 0.12, CREAM, "gloss", 1, 8)
	var blades := BrickMesh.new()
	for i in 4:
		blades.box(Basis(Vector3.UP, TAU * i / 4.0) * Vector3(0.5, 0, 0), Vector3(0.8, 0.02, 0.16), WOOD, "wood", Basis(Vector3.UP, TAU * i / 4.0))
	prop.anim({"type": "spin", "node": prop.part(blades, Vector3(0, y - 0.04, 0), "Blades"), "axis": Vector3.UP, "speed": 5.0})


# --- Design Bay and Wind Tunnel ------------------------------------------------------

static func _gantry_crane(bm: BrickMesh, o: Dictionary, prop: KitProp) -> void:
	# Origin: bay centre at rail height. The bridge spans x and travels along z.
	var span := float(o.get("span", 22.0))
	var length := float(o.get("length", 20.0))
	prop.lod_range = 0.0
	for sx: float in [-1.0, 1.0]:
		b(bm, sx * span / 2, 0, 0, 0.4, 0.5, length, MUSTARD, "metal")
		b(bm, sx * span / 2, -0.3, 0, 0.6, 0.1, length, STEEL, "metal")
	var bridge := BrickMesh.new()
	for sz: float in [-0.5, 0.5]:
		bridge.box(Vector3(0, 0.55, sz), Vector3(span, 0.6, 0.25), MUSTARD, "metal")
	for i in int(span / 2.0):
		bridge.box(Vector3(-span / 2 + 1.0 + i * 2.0, 0.55, 0), Vector3(0.12, 0.12, 1.0), INK, "metal")
	for sx: float in [-1.0, 1.0]:
		bridge.box(Vector3(sx * span / 2, 0.5, 0), Vector3(0.7, 0.5, 1.6), ORANGE, "metal")
	var bridge_node := prop.part(bridge, Vector3.ZERO, "Bridge")
	var trolley := BrickMesh.new()
	trolley.box(Vector3(0, 0.95, 0), Vector3(1.2, 0.4, 1.3), ORANGE, "metal")
	trolley.box(Vector3(0, 0.55, 0), Vector3(0.5, 0.5, 0.5), GREY, "metal")
	trolley.box(Vector3(0, 1.2, 0), Vector3(0.3, 0.1, 0.3), AMBER, "blink", Basis.IDENTITY, 1.0, 1.0, Vector2(3.0, 2.0))
	var trolley_node := Node3D.new()
	trolley_node.name = "Trolley"
	bridge_node.add_child(trolley_node)
	trolley.commit(trolley_node, prop.render_layers)
	var hook := BrickMesh.new()
	hook.box(Vector3(0, 2.2, 0), Vector3(0.04, 4.4, 0.04), INK, "metal")
	hook.box(Vector3(0, -0.1, 0), Vector3(0.4, 0.3, 0.3), MUSTARD, "metal")
	hook.box(Vector3(0, -0.4, 0), Vector3(0.1, 0.3, 0.1), STEEL, "metal")
	var hook_node := Node3D.new()
	hook_node.name = "Hook"
	hook_node.position.y = -1.6
	trolley_node.add_child(hook_node)
	hook.commit(hook_node, prop.render_layers)
	prop.anim({"type": "crane", "node": bridge_node, "trolley": trolley_node, "hook": hook_node,
			"span": span / 2.0 - 3.0, "travel": length / 2.0 - 2.0})
	prop.sound("crane", Vector3.ZERO)


static func _work_light(bm: BrickMesh, o: Dictionary, prop: KitProp) -> void:
	# Origin on the floor under the lamp; `h` is the lamp height, `drop` the cable length.
	var h := float(o.get("h", 7.0))
	var drop := float(o.get("drop", 1.2))
	prop.lod_range = 0.0
	b(bm, 0, h + drop / 2, 0, 0.03, drop, 0.03, INK)
	bm.cyl(Vector3(0, h - 0.12, 0), 0.42, 0.3, TEAL, "metal", 1, 12, 0.14)
	bm.cyl(Vector3(0, h - 0.275, 0), 0.38, 0.01, Color("fff6dc"), "glow", 1, 12)
	bm.cyl(Vector3(0, (h - 0.3) / 2.0, 0), (h - 0.3) * 0.62, h - 0.3, Color(1.0, 0.95, 0.82, 0.016), "beam", 1, 14, 0.36)
	prop.lamp(Vector3(0, h - 0.4, 0), Color(str(o.get("color", "fff1d6"))), float(o.get("energy", 2.4)), float(o.get("range", 13.0)), true)


static func _tool_cart(bm: BrickMesh) -> void:
	b(bm, 0, 0.55, 0, 0.9, 0.7, 0.5, RED, "metal")
	for i in 4:
		b(bm, 0, 0.3 + i * 0.16, 0.255, 0.8, 0.12, 0.01, RED.lightened(0.1), "metal")
		b(bm, 0, 0.33 + i * 0.16, 0.265, 0.3, 0.02, 0.02, STEEL_L, "metal")
	b(bm, 0, 0.93, 0, 0.94, 0.04, 0.54, INK)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			bm.cyl(Vector3(sx * 0.36, 0.08, sz * 0.18), 0.08, 0.05, INK, "matte", 0, 8)
	bm.collide(Vector3(0, 0.48, 0), Vector3(0.94, 0.96, 0.54))


static func _rocket_stage(bm: BrickMesh, o: Dictionary) -> void:
	# A spare stage lying on a cradle (set dressing; the player's rocket is on the bench).
	var l := float(o.get("l", 5.0))
	var r := float(o.get("r", 0.7))
	bm.cyl(Vector3(0, r + 0.5, 0), r, l, CREAM, "gloss", 0, 16)
	bm.cyl(Vector3(-l * 0.2, r + 0.5, 0), r * 1.01, l * 0.08, ORANGE, "gloss", 0, 16)
	bm.cyl(Vector3(l / 2 + 0.3, r + 0.5, 0), r * 0.75, 0.6, STEEL, "metal", 0, 12, r * 0.35)
	bm.cyl(Vector3(-l / 2 - 0.02, r + 0.5, 0), r * 0.95, 0.04, INK, "matte", 0, 16)
	for sx: float in [-1.0, 1.0]:
		b(bm, sx * l * 0.3, 0.3, 0, 0.3, 0.6, r * 2.2, MUSTARD, "metal")
		b(bm, sx * l * 0.3, 0.05, 0, 0.5, 0.1, r * 2.6, INK)
	bm.collide(Vector3(0, r + 0.2, 0), Vector3(l + 0.8, r * 2 + 0.6, r * 2.2))


static func _instrument_rack(bm: BrickMesh, prop: KitProp, rng: RandomNumberGenerator) -> void:
	b(bm, 0, 0.95, 0, 1.2, 1.9, 0.6, GREY, "metal")
	b(bm, 0, 1.45, 0.305, 1.05, 0.7, 0.01, INK)
	for i in 3:
		bm.cyl(Vector3(-0.35 + i * 0.35, 1.6, 0.31), 0.12, 0.02, PAPER, "matte", 2, 12)
		bm.box(Vector3(-0.35 + i * 0.35, 1.63, 0.325), Vector3(0.01, 0.1, 0.005), RED, "matte", Basis(Vector3.BACK, rng.randf_range(-0.9, 0.9)))
	blink_grid(bm, Vector3(-0.4, 1.2, 0.315), 9, 2, 0.1, 0.1, 0.045, rng, [AMBER, Color("ff6a4a"), CRT])
	b(bm, 0, 0.7, 0.32, 0.8, 0.4, 0.04, PAPER)
	b(bm, 0, 0.72, 0.345, 0.7, 0.02, 0.005, RED)
	bm.collide(Vector3(0, 0.95, 0), Vector3(1.2, 1.9, 0.6))
	prop.spot(Vector3(0, 0, 0.85), PI, "stand")


# --- IBM 7090 Computer Room ----------------------------------------------------------

static func _tape_drive(bm: BrickMesh, prop: KitProp, rng: RandomNumberGenerator) -> void:
	b(bm, 0, 0.9, 0, 0.78, 1.8, 0.72, IBM_GREY, "gloss")
	b(bm, 0, 1.87, 0, 0.8, 0.14, 0.74, IBM_BLUE, "gloss")
	b(bm, 0, 1.3, 0.362, 0.66, 0.84, 0.01, INK)
	b(bm, 0, 1.3, 0.372, 0.66, 0.84, 0.006, Color(0.8, 0.9, 0.95, 0.12), "glass")
	b(bm, 0, 0.98, 0.367, 0.3, 0.14, 0.01, STEEL_L, "metal")
	for sx: float in [-1.0, 1.0]:
		b(bm, sx * 0.12, 0.72, 0.366, 0.05, 0.3, 0.004, WOOD_D)
	blink_grid(bm, Vector3(-0.26, 0.42, 0.365), 6, 1, 0.105, 0.1, 0.05, rng, [AMBER, Color("ff6a4a"), PAPER])
	for sx: float in [-1.0, 1.0]:
		var reel := BrickMesh.new()
		reel.cyl(Vector3.ZERO, 0.155, 0.03, INK, "gloss", 2, 14)
		reel.cyl(Vector3(0, 0, 0.004), 0.12, 0.03, WOOD_D, "matte", 2, 14)
		reel.cyl(Vector3(0, 0, 0.018), 0.05, 0.02, STEEL_L, "metal", 2, 8)
		for s in 3:
			reel.box(Vector3.ZERO + Vector3(0, 0, 0.019), Vector3(0.24, 0.03, 0.006), STEEL_L, "metal", Basis(Vector3.BACK, TAU * s / 3.0))
		var node := prop.part(reel, Vector3(sx * 0.17, 1.5, 0.372), "Reel")
		prop.anim({"type": "spin", "node": node, "axis": Vector3.BACK, "speed": rng.randf_range(2.5, 6.0), "dir": -sx, "jitter": true})
	bm.collide(Vector3(0, 0.95, 0), Vector3(0.8, 1.9, 0.74))
	prop.sound("tape", Vector3(0, 1.4, 0.3))
	prop.spot(Vector3(0, 0, 0.9), PI, "stand")


static func _cpu_cabinet(bm: BrickMesh, o: Dictionary, prop: KitProp, rng: RandomNumberGenerator) -> void:
	var w := float(o.get("w", 1.6))
	b(bm, 0, 0.9, 0, w, 1.8, 0.8, IBM_GREY, "gloss")
	b(bm, 0, 1.87, 0, w + 0.02, 0.14, 0.82, IBM_BLUE, "gloss")
	b(bm, 0, 1.35, 0.402, w - 0.2, 0.7, 0.01, INK)
	blink_grid(bm, Vector3(-w / 2 + 0.2, 1.08, 0.41), int((w - 0.3) / 0.075), 8, 0.075, 0.08, 0.035, rng, [AMBER, AMBER, Color("ff7a52")], 0.7)
	for i in int(w / 0.4):
		b(bm, -w / 2 + 0.2 + i * 0.4, 0.5, 0.402, 0.3, 0.5, 0.008, IBM_GREY.darkened(0.12))
	prop.label(str(o.get("label", "")), Vector3(0, 1.87, 0.42), 36, PAPER)
	bm.collide(Vector3(0, 0.95, 0), Vector3(w, 1.9, 0.82))


static func _operator_console(bm: BrickMesh, prop: KitProp, rng: RandomNumberGenerator) -> void:
	b(bm, 0, 0.36, 0, 2.2, 0.72, 0.9, IBM_GREY, "gloss")
	b(bm, 0, 0.74, 0.1, 2.3, 0.05, 1.1, GREY_L, "gloss")
	var tilt := Basis(Vector3.RIGHT, -0.35)
	bm.box(Vector3(0, 1.2, -0.25), Vector3(2.2, 0.9, 0.12), IBM_BLUE, "gloss", tilt)
	bm.box(Vector3(0, 1.2, -0.185), Vector3(2.0, 0.76, 0.01), INK, "matte", tilt)
	blink_grid(bm, Vector3(-0.92, 0.95, -0.085) , 24, 6, 0.08, 0.1, 0.04, rng, [AMBER, AMBER, Color("ff7a52"), PAPER], 0.75, tilt)
	for i in 18:
		b(bm, -0.85 + i * 0.1, 0.79, 0.3, 0.04, 0.06, 0.03, [PAPER, RED, INK][i % 3], "gloss")
	bm.collide(Vector3(0, 0.6, -0.05), Vector3(2.3, 1.2, 1.1))
	_chair(bm, Vector3(0, 0, 1.0), IBM_BLUE)
	prop.spot(Vector3(0, 0, 1.0), PI, "sit")
	prop.label("IBM 7090", Vector3(0, 1.72, -0.36), 44, PAPER, 0.0, -0.35)
	prop.lamp(Vector3(0, 1.3, 0.5), Color("ffcf8a"), 0.6, 3.0)


static func _card_reader(bm: BrickMesh, prop: KitProp) -> void:
	b(bm, 0, 0.55, 0, 1.3, 1.1, 0.7, IBM_GREY, "gloss")
	b(bm, 0, 1.12, 0, 1.32, 0.05, 0.72, IBM_BLUE, "gloss")
	b(bm, -0.3, 1.25, 0, 0.3, 0.22, 0.2, PAPER)
	b(bm, 0.3, 1.2, 0.1, 0.4, 0.12, 0.3, GREY)
	b(bm, 0.3, 1.27, 0.1, 0.34, 0.03, 0.2, PAPER)
	bm.collide(Vector3(0, 0.6, 0), Vector3(1.32, 1.2, 0.72))
	prop.sound("cards", Vector3(0, 1.2, 0))


static func _line_printer(bm: BrickMesh, prop: KitProp) -> void:
	b(bm, 0, 0.55, 0, 1.4, 1.1, 0.75, IBM_GREY, "gloss")
	b(bm, 0, 1.2, -0.1, 1.4, 0.24, 0.5, IBM_BLUE, "gloss")
	b(bm, 0, 1.1, 0.3, 1.0, 0.02, 0.2, INK)
	var paper := BrickMesh.new()
	paper.box(Vector3.ZERO, Vector3(0.9, 0.5, 0.004), PAPER)
	for i in 5:
		paper.box(Vector3(0, -0.2 + i * 0.1, 0.003), Vector3(0.8, 0.012, 0.002), Color("b5d6c0"))
	var node := prop.part(paper, Vector3(0, 1.3, 0.16), "Paper")
	prop.anim({"type": "paper", "node": node, "base": 1.32, "len": 0.5, "speed": 0.1})
	b(bm, 0, 0.3, 0.5, 0.9, 0.3, 0.3, PAPER)
	bm.collide(Vector3(0, 0.65, 0), Vector3(1.4, 1.3, 0.75))
	prop.sound("printer", Vector3(0, 1.2, 0))
	prop.spot(Vector3(0.9, 0, 0.6), PI * 0.75, "stand")


static func _teletype(bm: BrickMesh, prop: KitProp) -> void:
	b(bm, 0, 0.4, 0, 0.6, 0.8, 0.5, GREY, "metal")
	b(bm, 0, 0.95, 0, 0.66, 0.3, 0.56, TEAL_L, "gloss")
	b(bm, 0, 1.0, 0.24, 0.5, 0.06, 0.14, INK)
	bm.cyl(Vector3(0, 1.14, -0.1), 0.08, 0.5, PAPER, "matte", 0, 8)
	var paper := BrickMesh.new()
	paper.box(Vector3.ZERO, Vector3(0.44, 0.4, 0.003), PAPER)
	for i in 6:
		paper.box(Vector3(-0.02, -0.17 + i * 0.065, 0.002), Vector3(0.34, 0.01, 0.002), INK)
	var node := prop.part(paper, Vector3(0, 1.2, -0.02), "Paper")
	node.rotation.x = -0.25
	prop.anim({"type": "paper", "node": node, "base": 1.14, "len": 0.4, "speed": 0.16})
	bm.collide(Vector3(0, 0.55, 0), Vector3(0.66, 1.1, 0.56))
	prop.sound("teletype", Vector3(0, 1.0, 0))
	prop.label("WIRE", Vector3(0, 0.6, 0.26), 26, PAPER)


static func _floor_open(bm: BrickMesh, prop: KitProp) -> void:
	# A lifted raised-floor tile with the cable run showing underneath.
	prop.lod_range = 30.0
	b(bm, 0, 0.012, 0, 0.62, 0.02, 0.62, INK)
	for i in 4:
		b(bm, -0.2 + i * 0.13, 0.03, 0, 0.05, 0.03, 0.6, [RED, MUSTARD, INK, TEAL][i])
	bm.box(Vector3(0.5, 0.25, 0), Vector3(0.6, 0.03, 0.6), GREY_L, "grid", Basis(Vector3.BACK, 1.1))
	b(bm, 0, 0.2, -0.4, 0.5, 0.4, 0.02, MUSTARD)
	prop.label("CAUTION", Vector3(0, 0.25, -0.385), 26, INK)


# --- Offices -------------------------------------------------------------------------

static func _pike_desk(bm: BrickMesh, o: Dictionary, prop: KitProp) -> void:
	b(bm, 0, 0.74, 0, 2.5, 0.07, 1.15, WOOD_D, "wood")
	b(bm, 0, 0.36, -0.3, 2.3, 0.72, 0.5, WOOD_D, "wood")
	for sx: float in [-1.0, 1.0]:
		b(bm, sx * 0.9, 0.36, 0.15, 0.5, 0.72, 0.8, WOOD_D.darkened(0.1), "wood")
	b(bm, 0, 0.782, 0.15, 0.9, 0.006, 0.6, TEAL)                # blotter
	b(bm, 0.05, 0.79, 0.15, 0.22, 0.008, 0.3, PAPER)
	b(bm, 0.5, 0.82, 0.3, 0.08, 0.1, 0.08, WOOD)                # the stamp
	b(bm, 0.5, 0.775, 0.3, 0.14, 0.02, 0.1, RED)
	b(bm, -0.3, 0.83, -0.42, 0.5, 0.1, 0.06, MUSTARD, "metal")  # nameplate
	_phone(bm, Vector3(0.95, 0.775, -0.1))
	_desk_lamp(bm, Vector3(-1.0, 0.775, -0.2), prop)
	for i in 3:
		b(bm, -0.75, 0.79 + i * 0.03, 0.2, 0.25, 0.03, 0.33, [CREAM, PAPER, GREY_L][i])
	bm.collide(Vector3(0, 0.39, 0), Vector3(2.5, 0.78, 1.15))
	b(bm, 0, 0.5, 1.05, 0.6, 0.12, 0.56, WOOD_D.darkened(0.2))  # leather chair
	b(bm, 0, 0.95, 1.3, 0.6, 0.9, 0.1, WOOD_D.darkened(0.2))
	b(bm, 0, 0.22, 1.05, 0.08, 0.44, 0.08, STEEL, "metal")
	prop.spot(Vector3(0, 0.06, 1.05), PI, "sit")
	prop.label(str(o.get("nameplate", "")), Vector3(-0.3, 0.83, -0.455), 20, INK, PI)
	prop.sound("phone", Vector3(0.95, 0.9, -0.1))


static func _chart_board(bm: BrickMesh, o: Dictionary, prop: KitProp, rng: RandomNumberGenerator) -> void:
	prop.lod_range = 40.0
	var w := float(o.get("w", 2.2))
	b(bm, 0, 1.6, 0.02, w, 1.3, 0.04, WOOD_D, "wood")
	b(bm, 0, 1.6, 0.045, w - 0.1, 1.2, 0.01, PAPER)
	var bars := int((w - 0.5) / 0.2)
	var level := 0.9
	for i in bars:
		level = clampf(level + rng.randf_range(-0.22, 0.08), 0.15, 0.95)
		var col := TEAL if level > 0.4 else RED
		b(bm, -w / 2 + 0.35 + i * 0.2, 1.1 + level / 2, 0.055, 0.13, level, 0.008, col)
	b(bm, 0, 1.09, 0.055, w - 0.3, 0.012, 0.008, INK)
	b(bm, -w / 2 + 0.22, 1.6, 0.055, 0.012, 1.0, 0.008, INK)
	bm.box(Vector3(0.1, 1.75, 0.06), Vector3(w - 0.5, 0.015, 0.006), RED, "matte", Basis(Vector3.BACK, -0.28))
	prop.label(str(o.get("title", "BUDGET")), Vector3(0, 2.33, 0.03), 34, PAPER)


static func _moon_poster(bm: BrickMesh, o: Dictionary, prop: KitProp) -> void:
	prop.lod_range = 40.0
	b(bm, 0, 1.75, 0.012, 1.1, 1.5, 0.012, Color("1c2a3a"))
	bm.cyl(Vector3(0.05, 1.95, 0.02), 0.36, 0.006, Color("e8e2cc"), "matte", 2, 20)
	for c: Array in [[-0.08, 2.05, 0.07], [0.18, 1.85, 0.05], [0.0, 1.8, 0.04], [0.22, 2.08, 0.035]]:
		bm.cyl(Vector3(c[0], c[1], 0.025), c[2], 0.004, Color("cfc7ae"), "matte", 2, 10)
	for i in 14:
		var sx := fmod(i * 0.37, 1.0) - 0.5
		var sy := fmod(i * 0.61, 1.0)
		b(bm, sx * 0.95, 1.1 + sy * 1.3, 0.02, 0.012, 0.012, 0.002, PAPER)
	b(bm, -0.42, 2.3, 0.02, 0.1, 0.1, 0.004, CREAM)            # curling corner
	prop.label(str(o.get("text", "")), Vector3(0, 1.22, 0.022), 40, MUSTARD)


static func _model_rocket(bm: BrickMesh, o: Dictionary, prop: KitProp) -> void:
	prop.lod_range = 25.0
	var y := 0.0
	bm.cyl(Vector3(0, y + 0.02, 0), 0.1, 0.04, WOOD_D, "wood", 1, 8)
	if bool(o.get("broken", false)):
		bm.cyl(Vector3(0, y + 0.16, 0), 0.035, 0.24, CREAM, "gloss", 1, 8)
		bm.cyl(Vector3(0.17, y + 0.035, 0.08), 0.035, 0.2, CREAM, "gloss", 0, 8)
		bm.cyl(Vector3(0.31, y + 0.035, 0.08), 0.035, 0.1, ORANGE, "gloss", 0, 8, 0.0)
	else:
		bm.cyl(Vector3(0, y + 0.26, 0), 0.035, 0.44, CREAM, "gloss", 1, 8)
		bm.cyl(Vector3(0, y + 0.53, 0), 0.035, 0.1, ORANGE, "gloss", 1, 8, 0.0)
	for f in 3:
		bm.box(Vector3(0, y + 0.08, 0) + Basis(Vector3.UP, TAU * f / 3.0) * Vector3(0.06, 0, 0), Vector3(0.07, 0.09, 0.008), ORANGE, "gloss",
				Basis(Vector3.UP, TAU * f / 3.0))


static func _tape_player(bm: BrickMesh, o: Dictionary, prop: KitProp) -> void:
	# Reel-to-reel on a low cabinet. The reels only turn while a tape is playing.
	b(bm, 0, 0.35, 0, 0.9, 0.7, 0.5, WOOD_D, "wood")
	b(bm, 0, 0.82, 0, 0.6, 0.24, 0.42, GREY_L, "gloss")
	bm.box(Vector3(0, 0.96, -0.02), Vector3(0.56, 0.02, 0.36), INK, "matte")
	b(bm, 0, 0.9, 0.215, 0.5, 0.06, 0.01, INK)
	var reels: Array = []
	for sx: float in [-1.0, 1.0]:
		var reel := BrickMesh.new()
		reel.cyl(Vector3.ZERO, 0.11, 0.02, PAPER, "gloss", 1, 12)
		reel.cyl(Vector3(0, 0.004, 0), 0.07, 0.02, WOOD_D, "matte", 1, 12)
		for s in 3:
			reel.box(Vector3(0, 0.012, 0), Vector3(0.18, 0.004, 0.025), STEEL_L, "metal", Basis(Vector3.UP, TAU * s / 3.0))
		var node := prop.part(reel, Vector3(sx * 0.14, 0.985, -0.03), "Reel")
		reels.append(node)
		prop.anim({"type": "spin", "node": node, "axis": Vector3.UP, "speed": 1.6 if bool(o.get("playing", false)) else 0.0})
	b(bm, 0.3, 0.74, 0.1, 0.18, 0.05, 0.18, CREAM)             # the boxed tape
	prop.label(str(o.get("tape", "#1")), Vector3(0.3, 0.77, 0.1), 22, INK, 0.0, -PI / 2.0, 8.0)
	bm.collide(Vector3(0, 0.45, 0), Vector3(0.9, 0.9, 0.5))


static func _dust_boxes(bm: BrickMesh, rng: RandomNumberGenerator) -> void:
	for i in 4:
		var s := rng.randf_range(0.4, 0.6)
		bm.box(Vector3((i % 2) * 0.55 - 0.25, s / 2 + (i / 2) * 0.5, rng.randf_range(-0.05, 0.05)), Vector3(s + 0.1, s, s), CORK.darkened(0.1 * (i % 3)),
				"matte", Basis(Vector3.UP, rng.randf_range(-0.2, 0.2)))
	b(bm, 0.9, 0.5, 0, 0.7, 1.0, 0.6, Color("d9d2bf"))          # something under a dust sheet
	b(bm, 0.9, 1.02, 0, 0.78, 0.04, 0.68, Color("e4ddca"))
	bm.collide(Vector3(0.3, 0.55, 0), Vector3(1.9, 1.1, 0.7))


static func _safe(bm: BrickMesh, prop: KitProp) -> void:
	prop.lod_range = 30.0
	b(bm, 0, 0.4, 0.3, 0.6, 0.8, 0.6, GREY, "metal")
	b(bm, 0, 0.4, 0.605, 0.5, 0.68, 0.02, GREY.lightened(0.1), "metal")
	bm.cyl(Vector3(0.08, 0.45, 0.625), 0.07, 0.03, STEEL_L, "metal", 2, 10)
	b(bm, -0.12, 0.45, 0.63, 0.03, 0.14, 0.03, STEEL_L, "metal")
	bm.collide(Vector3(0, 0.4, 0.3), Vector3(0.6, 0.8, 0.6))


# --- Mission Control -----------------------------------------------------------------

static func _mc_console(bm: BrickMesh, o: Dictionary, prop: KitProp, rng: RandomNumberGenerator) -> void:
	var w := float(o.get("w", 1.9))
	var body := Color(str(o.get("color", "7f8f84")))
	b(bm, 0, 0.36, -0.1, w, 0.72, 0.6, body, "gloss")
	b(bm, 0, 0.74, 0.22, w, 0.05, 0.66, GREY_L, "gloss")
	var tilt := Basis(Vector3.RIGHT, -0.3)
	bm.box(Vector3(0, 1.08, -0.26), Vector3(w, 0.68, 0.3), body, "gloss", tilt)
	var screen_col: Color = [CRT, Color("9fd8ff"), AMBER][rng.randi() % 3]
	bm.box(Vector3(-w * 0.2, 1.12, -0.105), Vector3(w * 0.42, 0.4, 0.01), screen_col.darkened(0.55), "screen", tilt)
	for i in 5:
		bm.box(Vector3(-w * 0.2, 1.0 + i * 0.065, -0.068 - i * 0.02), Vector3(w * rng.randf_range(0.12, 0.34), 0.012, 0.004), screen_col, "glow", tilt)
	blink_grid(bm, Vector3(w * 0.1, 0.96, -0.045), 7, 5, 0.085, 0.085, 0.045, rng, [AMBER, Color("ff6a4a"), CRT, PAPER], 0.8, tilt)
	for i in 8:
		b(bm, -w / 2 + 0.2 + i * 0.2, 0.785, 0.2, 0.08, 0.03, 0.08, [PAPER, MUSTARD, RED, GREY][i % 4], "gloss")
	_phone(bm, Vector3(w / 2 - 0.2, 0.765, 0.3))
	bm.collide(Vector3(0, 0.62, 0), Vector3(w, 1.24, 1.0))
	_chair(bm, Vector3(0, 0, 0.95), TEAL)
	prop.spot(Vector3(0, 0, 0.95), PI, "sit")
	if bool(o.get("lamp", false)):
		prop.lamp(Vector3(0, 1.15, 0.45), screen_col.lerp(Color.WHITE, 0.35), 0.6, 3.0)
	if o.has("label"):
		b(bm, 0, 1.5, -0.42, 0.9, 0.2, 0.03, INK)
		prop.label(str(o["label"]), Vector3(0, 1.5, -0.4), 40, MUSTARD, 0.0, 0.0, 30.0)
		prop.label(str(o["label"]), Vector3(0, 1.5, -0.44), 40, MUSTARD, PI, 0.0, 30.0)


static func _wall_screen(bm: BrickMesh, o: Dictionary, prop: KitProp, rng: RandomNumberGenerator) -> void:
	# Big projection screen on a wall; back on z = 0, bottom edge at `y`.
	prop.lod_range = 0.0
	var w := float(o.get("w", 6.0))
	var h := float(o.get("h", 3.4))
	var y := float(o.get("mount", 1.6))
	b(bm, 0, y + h / 2, 0.05, w + 0.3, h + 0.3, 0.1, INK)
	var mode := str(o.get("mode", "data"))
	if mode == "map":
		b(bm, 0, y + h / 2, 0.105, w, h, 0.01, Color("0c2b3a"), "glow")
		var rows: Array = o.get("map", [])
		if not rows.is_empty():
			var cols := str(rows[0]).length()
			var cw := w / cols
			var ch := h / rows.size()
			for r in rows.size():
				var line := str(rows[r])
				var start := -1
				for c in cols + 1:
					var land := c < cols and line[c] != " " and line[c] != "."
					if land and start < 0:
						start = c
					elif not land and start >= 0:
						b(bm, -w / 2 + (start + c) * cw / 2.0, y + h - (r + 0.5) * ch, 0.112, (c - start) * cw, ch * 0.92, 0.004, Color("2f8f6a"), "glow")
						start = -1
		# Ground track: a sine across the map, with a blip that rides along it.
		for i in 48:
			var k := i / 47.0
			b(bm, -w / 2 + k * w, y + h / 2 + sin(k * TAU * 1.5 + 0.6) * h * 0.3, 0.118, 0.05, 0.05, 0.004, AMBER, "glow")
		var blip := BrickMesh.new()
		blip.box(Vector3.ZERO, Vector3(0.16, 0.16, 0.01), Color("ff5a3a"), "blink", Basis.IDENTITY, 1.0, 1.0, Vector2(1.0, 2.5))
		var node := prop.part(blip, Vector3(0, y + h / 2, 0.125), "Blip")
		prop.anim({"type": "track", "node": node, "w": w, "h": h, "y": y + h / 2})
	else:
		b(bm, 0, y + h / 2, 0.105, w, h, 0.01, Color("10202a"), "glow")
		var col: Color = [CRT, AMBER, Color("9fd8ff")][rng.randi() % 3]
		for r in int(h / 0.3):
			var x := -w / 2 + 0.3
			while x < w / 2 - 0.5:
				var seg := rng.randf_range(0.2, 0.9)
				if rng.randf() < 0.75:
					b(bm, x + seg / 2, y + 0.25 + r * 0.3, 0.112, minf(seg, w / 2 - 0.3 - x), 0.07, 0.004, col, "glow")
				x += seg + 0.15
		blink_grid(bm, Vector3(w / 2 - 0.25, y + 0.3, 0.115), 1, int(h / 0.3) - 1, 0.1, 0.3, 0.1, rng, [RED, CRT, AMBER], 0.9)
	prop.label(str(o.get("title", "")), Vector3(0, y + h + 0.32, 0.08), 56, MUSTARD, 0.0, 0.0, 60.0)
	prop.lamp(Vector3(0, y + h / 2, 2.5), Color(str(o.get("glow", "8fd8ff"))), float(o.get("energy", 1.1)), 11.0)


static func _status_board(bm: BrickMesh, o: Dictionary, prop: KitProp, rng: RandomNumberGenerator) -> void:
	prop.lod_range = 50.0
	var rows: Array = o.get("rows", ["BOOSTER", "RETRO", "FIDO", "GUIDO", "SURGEON", "CAPCOM", "EECOM", "NETWORK"])
	var y := float(o.get("mount", 1.4))
	var h := 0.3 + rows.size() * 0.3
	b(bm, 0, y + h / 2, 0.04, 2.4, h, 0.08, INK)
	for r in rows.size():
		var ry := y + h - 0.3 - r * 0.3
		prop.label(str(rows[r]), Vector3(-0.35, ry, 0.09), 34, PAPER, 0.0, 0.0, 30.0)
		bm.box(Vector3(0.75, ry, 0.085), Vector3(0.36, 0.18, 0.01), Color("7dff9a") if rng.randf() < 0.8 else Color("ff6a4a"), "blink",
				Basis.IDENTITY, 1.0, 1.0, Vector2(rng.randf() * 50.0, 0.15))
	prop.label(str(o.get("title", "GO / NO GO")), Vector3(0, y + h + 0.2, 0.06), 44, MUSTARD, 0.0, 0.0, 40.0)


# --- Structure bits and exterior -----------------------------------------------------

## A handrail of length `l` along x, posts every ~1.5 m. Origin at its middle, floor level.
static func _rail(bm: BrickMesh, o: Dictionary) -> void:
	var l := float(o.get("l", 4.0))
	var col := Color(str(o.get("color", "e9c46a")))
	b(bm, 0, 1.05, 0, l, 0.06, 0.06, col, "metal")
	b(bm, 0, 0.55, 0, l, 0.04, 0.04, col, "metal")
	var posts := maxi(2, int(l / 1.5) + 1)
	for i in posts:
		b(bm, -l / 2 + i * l / (posts - 1), 0.53, 0, 0.05, 1.06, 0.05, col, "metal")
	if bool(o.get("solid", true)):
		bm.collide(Vector3(0, 0.6, 0), Vector3(l, 1.2, 0.12))


static func _tree(bm: BrickMesh, rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(3.0, 4.6)
	bm.cyl(Vector3(0, h / 2, 0), 0.2, h, WOOD_D, "matte", 1, 6)
	for i in 3:
		var s := 2.4 - i * 0.6
		bm.box(Vector3(rng.randf_range(-0.2, 0.2), h + i * 0.9, rng.randf_range(-0.2, 0.2)), Vector3(s, 1.1, s), GREEN.darkened(0.08 * i), "matte",
				Basis(Vector3.UP, rng.randf() * 1.5))


static func _flagpole(bm: BrickMesh, prop: KitProp) -> void:
	bm.cyl(Vector3(0, 4.5, 0), 0.06, 9.0, STEEL_L, "metal", 1, 6)
	bm.cyl(Vector3(0, 0.15, 0), 0.5, 0.3, GREY_L, "concrete", 1, 8)
	var flag := BrickMesh.new()
	flag.box(Vector3(0.75, 0, 0), Vector3(1.5, 0.9, 0.02), TEAL)
	flag.box(Vector3(0.75, 0, 0), Vector3(1.5, 0.22, 0.03), CREAM)
	flag.cyl(Vector3(0.4, 0, 0), 0.16, 0.035, ORANGE, "matte", 2, 10)
	var node := prop.part(flag, Vector3(0.06, 8.3, 0), "Flag")
	prop.anim({"type": "sway", "node": node, "speed": 1.3, "amp": 0.06})


static func _car(bm: BrickMesh, o: Dictionary) -> void:
	var col := Color(str(o.get("color", "2a7b7b")))
	b(bm, 0, 0.55, 0, 1.8, 0.6, 4.4, col, "gloss")
	b(bm, 0, 1.1, -0.2, 1.6, 0.55, 2.2, CREAM, "gloss")
	b(bm, 0, 1.1, -0.2, 1.62, 0.36, 1.9, Color(0.5, 0.7, 0.8, 0.5), "glass")
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			bm.cyl(Vector3(sx * 0.9, 0.34, sz * 1.4), 0.34, 0.24, INK, "matte", 0, 10)
	b(bm, 0, 0.5, 2.22, 1.7, 0.14, 0.08, STEEL_L, "metal")
	b(bm, 0, 0.5, -2.22, 1.7, 0.14, 0.08, STEEL_L, "metal")


static func _pad_plinth(bm: BrickMesh, o: Dictionary, prop: KitProp) -> void:
	# A plinth with a launch-tower stub; the player's rocket model stands on top.
	b(bm, 0, 0.4, 0, 2.4, 0.8, 2.4, STEEL, "concrete")
	b(bm, 0, 0.82, 0, 2.0, 0.04, 2.0, GREY)
	b(bm, 0.9, 2.2, -0.6, 0.25, 2.8, 0.25, RED, "metal")
	for i in 5:
		b(bm, 0.9, 1.1 + i * 0.55, -0.6, 0.34, 0.04, 0.34, PAPER, "metal")
	b(bm, 0.55, 2.9, -0.45, 0.6, 0.06, 0.1, RED, "metal")
	prop.label(str(o.get("label", "")), Vector3(0, 0.5, 1.21), 40, PAPER)
	bm.collide(Vector3(0, 0.42, 0), Vector3(2.4, 0.84, 2.4))
