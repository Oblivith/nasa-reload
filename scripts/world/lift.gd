# Code generated with AI assistance (Claude). Reviewed by team.
class_name WorldLift
extends Node3D
## The lift (kit scene: /scenes/world/kit/lift.tscn), built from "lift" in
## data/facility_world.json. One cab that really travels between the floors:
##   landing:  call button (InteractStub "lift_call_<n>"), sliding doors, floor indicator
##   cab:      floor buttons (InteractStub "lift_floor_<n>"), light, handrail
## Doors close, the cab rides (riders are carried, the camera gets a gentle shake through
## the player's optional add_camera_shake()), a ding, doors open. NPCs use the same
## request() / is_open_at() calls the player's buttons do.
##
## The doorway is on the cab's -z side (facing the corridor).

signal ride_started(from_floor: int, to_floor: int)
signal ride_ended(floor_index: int)
signal doors_changed(floor_index: int, open: bool)

enum State { IDLE, CLOSING, MOVING, OPENING }

const DOOR_SPEED := 1.1
const IDLE_OPEN_SECONDS := 5.0

var data: Dictionary = {}
var floors: Array = []            # [{y, room, label}]
var floor_index: int = 0
var state: int = State.IDLE
var door_open: float = 0.0
var cab: AnimatableBody3D
var rect: Rect2
var actors: Callable
var riders: Callable              # returns Node3D bodies to carry (player + NPCs)
var play_sound: Callable

var _queue: Array[int] = []
var _target: int = -1
var _idle: float = 0.0
var _speed: float = 1.3
var _door_x: float = 0.0
var _door_z: float = 0.0
var _door_w: float = 1.4
var _door_h: float = 2.3
var _landings: Array = []         # [{left, right, blocker, lamp, indicator}]
var _cab_indicator: Label3D
var _cab_height: float = 2.5
var _ride_sound: Node = null


func setup(entry: Dictionary, layers: int, texts: Dictionary) -> void:
	data = entry
	floors = entry.get("floors", [])
	_speed = float(entry.get("speed", 1.3))
	var r: Array = entry["rect"]
	rect = Rect2(float(r[0]), float(r[1]), float(r[2]) - float(r[0]), float(r[3]) - float(r[1]))
	var door: Dictionary = entry.get("door", {})
	_door_x = float((door.get("at", [rect.get_center().x, rect.position.y]) as Array)[0])
	_door_z = rect.position.y
	_door_w = float(door.get("w", 1.4))
	_door_h = float(door.get("h", 2.3))
	_build_cab(layers, texts)
	for i in floors.size():
		_build_landing(i, layers, texts)
	floor_index = int(entry.get("start_floor", 0))
	cab.position.y = _floor_y(floor_index)
	_apply_doors()


func request(index: int) -> void:
	if index < 0 or index >= floors.size():
		return
	if index == floor_index and state != State.MOVING:
		if state == State.CLOSING or door_open < 1.0:
			state = State.OPENING
		_idle = 0.0
		return
	if index not in _queue:
		_queue.append(index)


func is_open_at(index: int) -> bool:
	return floor_index == index and state == State.IDLE and door_open > 0.95


func is_moving() -> bool:
	return state == State.MOVING


## True while the doorway on `index` can be seen through (for room culling).
func portal_open(index: int) -> bool:
	return floor_index == index and state != State.MOVING and door_open > 0.02


func contains(point: Vector3) -> bool:
	return rect.has_point(Vector2(point.x, point.z)) and point.y > cab.position.y - 0.4 and point.y < cab.position.y + _cab_height + 0.3


func cab_floor_y() -> float:
	return cab.position.y


## Where to stand to wait for / ride the lift on a floor.
func wait_point(index: int) -> Vector3:
	return Vector3(_door_x, _floor_y(index), _door_z - 1.3)


func ride_point(y: float = INF) -> Vector3:
	return Vector3(rect.get_center().x, cab.position.y if y == INF else y, rect.get_center().y + 0.2)


func _floor_y(index: int) -> float:
	return float((floors[index] as Dictionary).get("y", 0.0))


# --- Build ---------------------------------------------------------------------------

func _build_cab(layers: int, texts: Dictionary) -> void:
	cab = AnimatableBody3D.new()
	cab.name = "Cab"
	cab.sync_to_physics = false
	cab.collision_layer = 1
	cab.collision_mask = 0
	add_child(cab)
	var x0 := rect.position.x + 0.2
	var x1 := rect.end.x - 0.2
	var z0 := rect.position.y + 0.3
	var z1 := rect.end.y - 0.2
	var cx := (x0 + x1) / 2.0
	var cz := (z0 + z1) / 2.0
	var h := _cab_height
	var panel := Color("8c6a4a")
	var upper := Color("f2e8cf")
	var bm := BrickMesh.new()
	bm.slab(Vector3(x0, -0.12, rect.position.y + 0.02), Vector3(x1, 0.0, z1), Color("6b4f36"), "tile")
	bm.slab(Vector3(x0, h, z0), Vector3(x1, h + 0.1, z1), upper)
	bm.box(Vector3(cx, h - 0.01, cz), Vector3(1.2, 0.02, 1.2), Color("fff3d6"), "glow")
	# Walls: back, left, right, and the two returns beside the doorway.
	var walls := [
		[Vector3(x0, 0, z1 - 0.08), Vector3(x1, h, z1)],
		[Vector3(x0, 0, z0), Vector3(x0 + 0.08, h, z1)],
		[Vector3(x1 - 0.08, 0, z0), Vector3(x1, h, z1)],
		[Vector3(x0, 0, z0), Vector3(_door_x - _door_w / 2, h, z0 + 0.08)],
		[Vector3(_door_x + _door_w / 2, 0, z0), Vector3(x1, h, z0 + 0.08)],
		[Vector3(_door_x - _door_w / 2, _door_h, z0), Vector3(_door_x + _door_w / 2, h, z0 + 0.08)],
	]
	for w: Array in walls:
		var a: Vector3 = w[0]
		var c: Vector3 = w[1]
		if a.y < 1.0:
			bm.slab(a, Vector3(c.x, 1.0, c.z), panel, "wood", 0.85, 1.0)
			bm.slab(Vector3(a.x, 1.0, a.z), c, upper, "matte", 1.0, 0.92)
		else:
			bm.slab(a, c, upper)
		bm.collide((a + c) / 2.0, (c - a).abs())
	bm.collide(Vector3(cx, -0.25, cz - 0.1), Vector3(x1 - x0, 0.5, z1 - rect.position.y))
	bm.collide(Vector3(cx, h + 0.1, cz), Vector3(x1 - x0, 0.2, z1 - z0))
	# Handrail and the button panel on the right-hand return.
	bm.box(Vector3(cx, 0.95, z1 - 0.14), Vector3(x1 - x0 - 0.4, 0.05, 0.05), Color("e9c46a"), "metal")
	var px := _door_x + _door_w / 2 + 0.3
	bm.box(Vector3(px, 1.25, z0 + 0.1), Vector3(0.3, 0.6, 0.03), Color("b7b2a8"), "metal")
	bm.commit(cab, layers, "CabMesh")
	bm.build_body_shapes(cab)
	var light := OmniLight3D.new()
	light.position = Vector3(cx, h - 0.4, cz)
	light.light_color = Color("fff0d0")
	light.light_energy = 1.2
	light.omni_range = 4.0
	light.light_cull_mask = layers | 1
	cab.add_child(light)
	for i in floors.size():
		var by := 1.1 + i * 0.22
		var button := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.045
		cm.bottom_radius = 0.045
		cm.height = 0.03
		button.mesh = cm
		button.rotation.x = PI / 2.0
		button.position = Vector3(px, by, z0 + 0.125)
		button.material_override = BrickMesh.lamp_material(Color("ffd27a"), 1.2)
		button.layers = layers
		cab.add_child(button)
		var tag := _text(str((floors[i] as Dictionary).get("label", str(i))), Vector3(px - 0.1, by, z0 + 0.12), 30, Color("2b2622"), layers)
		cab.add_child(tag)
		var prompt := str(texts.get("lift_floor", "E  %s")) % str((floors[i] as Dictionary).get("name", "Floor %d" % i))
		var stub := InteractStub.make(cab, "lift_floor_%d" % i, prompt, Vector3(px, by, z0 + 0.3), Vector3(cx, 1.6, cz + 0.5))
		stub.reach = 2.0
		stub.used.connect(func(_by: Node) -> void: request(i))
	_cab_indicator = _text("", Vector3(_door_x, _door_h + 0.1, z0 + 0.1), 44, Color("ffcf5a"), layers)
	cab.add_child(_cab_indicator)


func _build_landing(index: int, layers: int, texts: Dictionary) -> void:
	var y := _floor_y(index)
	var node := Node3D.new()
	node.name = "Landing%d" % index
	node.position = Vector3(_door_x, y, _door_z)
	add_child(node)
	var bm := BrickMesh.new()
	var steel := Color("b7b2a8")
	for sx: float in [-1.0, 1.0]:
		bm.box(Vector3(sx * (_door_w / 2 + 0.05), _door_h / 2, -0.05), Vector3(0.1, _door_h, 0.34), steel, "metal")
	bm.box(Vector3(0, _door_h + 0.06, -0.05), Vector3(_door_w + 0.2, 0.12, 0.34), steel, "metal")
	bm.box(Vector3(0, _door_h + 0.4, -0.17), Vector3(0.7, 0.3, 0.04), Color("2b2622"))
	bm.box(Vector3(_door_w / 2 + 0.45, 1.2, -0.17), Vector3(0.16, 0.26, 0.04), steel, "metal")
	bm.commit(node, layers, "Frame")
	var panels: Array = []
	for sx: float in [-1.0, 1.0]:
		var pm := BrickMesh.new()
		pm.box(Vector3(0, _door_h / 2, 0), Vector3(_door_w / 2, _door_h, 0.05), Color("8c8577"), "metal")
		pm.box(Vector3(0, _door_h / 2, -0.03), Vector3(_door_w / 2 - 0.16, _door_h - 0.3, 0.01), Color("a39c8d"), "metal")
		var pivot := Node3D.new()
		pivot.position = Vector3(sx * _door_w / 4, 0, 0.06)
		node.add_child(pivot)
		pm.commit(pivot, layers, "Panel")
		panels.append(pivot)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var blocker := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(_door_w, _door_h, 0.3)
	blocker.shape = bs
	blocker.position = Vector3(0, _door_h / 2, 0.0)
	body.add_child(blocker)
	node.add_child(body)
	var lamp := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.04
	cm.bottom_radius = 0.04
	cm.height = 0.03
	lamp.mesh = cm
	lamp.rotation.x = PI / 2.0
	lamp.position = Vector3(_door_w / 2 + 0.45, 1.2, -0.2)
	lamp.material_override = BrickMesh.lamp_material(Color("5a4a2a"), 1.0)
	lamp.layers = layers
	node.add_child(lamp)
	var indicator := _text("", Vector3(0, _door_h + 0.4, -0.195), 54, Color("ffcf5a"), layers)
	indicator.rotation.y = PI
	node.add_child(indicator)
	var stub := InteractStub.make(node, "lift_call_%d" % index, str(texts.get("lift_call", "E  Call the lift")),
			Vector3(_door_w / 2 + 0.45, 1.2, -0.4), Vector3(0.2, 1.6, -2.2))
	stub.reach = 2.4
	stub.used.connect(func(_by: Node) -> void: request(index))
	_landings.append({"left": panels[0], "right": panels[1], "blocker": blocker, "lamp": lamp, "indicator": indicator, "node": node})


func _text(text: String, at: Vector3, size: int, color: Color, layers: int) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = ConsoleTheme.typewriter()
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = color
	l.outline_size = 0
	l.position = at
	l.layers = layers
	l.visibility_range_end = 30.0
	return l


# --- Running -------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	match state:
		State.IDLE:
			if not _queue.is_empty():
				if _queue[0] == floor_index:
					_queue.pop_front()
					state = State.OPENING
				else:
					state = State.CLOSING
			elif door_open > 0.0:
				_idle += delta
				if _idle > IDLE_OPEN_SECONDS and not _doorway_blocked():
					state = State.CLOSING
		State.CLOSING:
			if _doorway_blocked() and door_open > 0.3:
				state = State.OPENING
			else:
				var was := door_open
				door_open = maxf(0.0, door_open - delta * DOOR_SPEED)
				if was >= 1.0:
					_sound("lift_door")
				if door_open <= 0.0:
					doors_changed.emit(floor_index, false)
					if _queue.is_empty():
						state = State.IDLE
					else:
						_target = _queue[0]
						state = State.MOVING
						ride_started.emit(floor_index, _target)
		State.MOVING:
			var goal := _floor_y(_target)
			var before := cab.position.y
			cab.position.y = move_toward(before, goal, _speed * delta)
			var dy := cab.position.y - before
			if riders.is_valid():
				for body: Node3D in riders.call():
					if contains(body.global_position + Vector3(0, 0.5, 0) - Vector3(0, dy, 0)):
						body.global_position.y += dy
						if body.has_method("add_camera_shake"):
							body.call("add_camera_shake", 0.35)
			if is_equal_approx(cab.position.y, goal):
				floor_index = _target
				_queue.erase(_target)
				_target = -1
				state = State.OPENING
				_sound("lift_ding")
				ride_ended.emit(floor_index)
		State.OPENING:
			var was_closed := door_open <= 0.0
			door_open = minf(1.0, door_open + delta * DOOR_SPEED)
			if was_closed:
				_sound("lift_door")
				doors_changed.emit(floor_index, true)
			if door_open >= 1.0:
				state = State.IDLE
				_idle = 0.0
	_apply_doors()


func _doorway_blocked() -> bool:
	if not actors.is_valid():
		return false
	var y := _floor_y(floor_index)
	for p: Vector3 in actors.call():
		if absf(p.x - _door_x) < _door_w / 2 + 0.2 and absf(p.z - _door_z) < 0.7 and absf(p.y - y) < 1.5:
			return true
	return false


func _apply_doors() -> void:
	var label := str((floors[floor_index] as Dictionary).get("label", str(floor_index)))
	if state == State.MOVING:
		label = "^" if _floor_y(_target) > cab.position.y else "v"
	if _cab_indicator.text != label:
		_cab_indicator.text = label
	for i in _landings.size():
		var landing: Dictionary = _landings[i]
		var open := door_open if i == floor_index and state != State.MOVING else 0.0
		var k := smoothstep(0.0, 1.0, open)
		(landing["left"] as Node3D).position.x = -_door_w / 4 - k * _door_w / 2
		(landing["right"] as Node3D).position.x = _door_w / 4 + k * _door_w / 2
		(landing["blocker"] as CollisionShape3D).disabled = open > 0.6
		var indicator: Label3D = landing["indicator"]
		if indicator.text != label:
			indicator.text = label
		var called := i in _queue
		if bool(landing.get("called", false)) != called:
			landing["called"] = called
			var mat := (landing["lamp"] as MeshInstance3D).material_override as StandardMaterial3D
			mat.albedo_color = Color("ffd27a") * 1.6 if called else Color("5a4a2a")


func _sound(id: String) -> void:
	if play_sound.is_valid():
		play_sound.call(id, Vector3(_door_x, cab.position.y + 1.4, _door_z))
