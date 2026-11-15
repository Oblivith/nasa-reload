# SI assistance metadata: This code used the help of SI.
class_name KitProp
extends Node3D

@export var kind: String = ""
@export var options: Dictionary = {}

var render_layers: int = 1

var lamps: Array = []

var sounds: Array = []

var spots: Array = []
var lod_range: float = 0.0
var mesh_instance: MeshInstance3D

var _anims: Array = []
var _built: bool = false
var _time: float = 0.0
var _tick: float = 0.0

func setup(prop_kind: String, prop_options: Dictionary, layers: int) -> void:
	kind = prop_kind
	options = prop_options
	render_layers = layers
	build()

func _ready() -> void:
	build()
	set_process(not _anims.is_empty())

func build() -> void:
	if _built or kind == "":
		return
	_built = true
	var bm := KitLibrary.build(kind, options, self)
	mesh_instance = bm.commit(self, render_layers)
	if mesh_instance != null and lod_range > 0.0:
		mesh_instance.visibility_range_end = lod_range
		mesh_instance.visibility_range_end_margin = 2.0
	bm.build_body(self)

func set_active(on: bool) -> void:
	set_process(on and not _anims.is_empty())

func part(bm: BrickMesh, at: Vector3, part_name: String = "Part") -> Node3D:
	var pivot := Node3D.new()
	pivot.name = part_name
	pivot.position = at
	add_child(pivot)
	var mi := bm.commit(pivot, render_layers)
	if mi != null and lod_range > 0.0:
		mi.visibility_range_end = lod_range
	return pivot

func label(text: String, at: Vector3, font_size: int = 48, color: Color = Color("fbf5e6"), yaw: float = 0.0,
		pitch: float = 0.0, range_m: float = 26.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = ConsoleTheme.typewriter()
	l.font_size = font_size
	l.pixel_size = 0.004
	l.modulate = color
	l.outline_size = 0
	l.position = at
	l.rotation = Vector3(pitch, yaw, 0)
	l.layers = render_layers
	l.visibility_range_end = range_m
	add_child(l)
	return l

func lamp(at: Vector3, color: Color, energy: float, range_m: float, spot: bool = false) -> void:
	lamps.append({"pos": at, "color": color, "energy": energy, "range": range_m, "spot": spot})

func sound(id: String, at: Vector3 = Vector3.ZERO) -> void:
	sounds.append({"id": id, "pos": at})

func spot(at: Vector3, yaw: float, pose: String) -> void:
	spots.append({"pos": at, "yaw": yaw, "pose": pose})

func anim(entry: Dictionary) -> void:
	_anims.append(entry)

func _process(delta: float) -> void:
	_time += delta
	_tick += delta
	var second := _tick >= 1.0
	if second:
		_tick = 0.0
	for a: Dictionary in _anims:
		var node := a.get("node") as Node3D
		match str(a["type"]):
			"spin":
				var speed := float(a["speed"])
				if a.has("jitter") and randf() < delta * 0.4:
					a["dir"] = -float(a.get("dir", 1.0)) if randf() < 0.5 else float(a.get("dir", 1.0))
				node.rotate_object_local(a["axis"], speed * float(a.get("dir", 1.0)) * delta)
			"clock":
				if second or not a.has("set"):
					a["set"] = true
					var now := Time.get_time_dict_from_system()
					var s := float(now["second"])
					var m := float(now["minute"]) + s / 60.0
					var h := float(int(now["hour"]) % 12) + m / 60.0
					(a["second"] as Node3D).rotation.z = -TAU * s / 60.0
					(a["minute"] as Node3D).rotation.z = -TAU * m / 60.0
					(a["hour"] as Node3D).rotation.z = -TAU * h / 12.0
			"crane":
				var span := float(a["span"])
				var travel := float(a["travel"])
				node.position.z = sin(_time * 0.11) * travel
				(a["trolley"] as Node3D).position.x = sin(_time * 0.23 + 1.0) * span
				(a["hook"] as Node3D).position.y = -1.6 + sin(_time * 0.31) * 0.9
			"paper":

				var k := fmod(_time * float(a.get("speed", 0.12)), 1.0)
				node.scale.y = 0.15 + k
				node.position.y = float(a["base"]) + (0.15 + k) * float(a["len"]) * 0.5
			"track":

				var u := fmod(_time * 0.03, 1.0)
				node.position.x = (u - 0.5) * float(a["w"])
				node.position.y = float(a["y"]) + sin(u * TAU * 1.5 + 0.6) * float(a["h"]) * 0.3
			"bob":
				node.position.y = float(a["base"]) + sin(_time * float(a["speed"])) * float(a["amp"])
			"sway":
				node.rotation.z = sin(_time * float(a["speed"])) * float(a["amp"])
