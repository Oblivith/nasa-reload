# SI assistance metadata: This code used the help of SI.
class_name FacilityWorld
extends Node3D

signal room_changed(room_id: String, room: Dictionary)
signal door_locked_tried(door: WorldDoor)

const EXTERIOR := "exterior"
const LIFT := "lift"
const LIFT_BIT := 1 << 18
const EXTERIOR_BIT := 1 << 19

const SIGHT_BUDGET := 3

var cfg: Dictionary = {}
var rooms: Dictionary = {}
var room_list: Array[WorldRoom] = []
var doors: Array[WorldDoor] = []
var doors_by_id: Dictionary = {}
var lift: WorldLift
var exterior: Node3D
var current_room: String = ""
var visible_rooms: Dictionary = {}

var walkers: Array[Node3D] = []
var npcs: Array[WorldNpc] = []

var sound_player: Callable

var _portals: Array = []
var _player: Node3D
var _build_ms: int = 0
var _box_total: int = 0
var _force_all: bool = false

func build(config: Dictionary) -> void:
	var started := Time.get_ticks_msec()
	cfg = config
	var texts: Dictionary = cfg.get("texts", {})
	var openings := _openings()
	var index := 0
	for entry: Dictionary in cfg.get("rooms", []):
		var room := WorldRoom.new()
		room.setup(entry, 1 << (1 + index % 17))
		index += 1
		add_child(room)
		rooms[room.room_id] = room
		room_list.append(room)
		if entry.has("scene") and ResourceLoader.exists(str(entry["scene"])):
			room.add_child((load(str(entry["scene"])) as PackedScene).instantiate())
		else:
			room.build_shell(openings)
		for op: Dictionary in openings:
			if bool(op.get("glass", false)) and str(op["owner"]) == room.room_id:
				room.build_window(op)
		for structure: Dictionary in entry.get("structures", []):
			room.build_structure(structure)
		for p: Array in entry.get("props", []):
			var options: Dictionary = (p[4] as Dictionary).duplicate() if p.size() > 4 else {}
			if str(p[0]) == "wall_screen" and str(options.get("mode", "")) == "map":
				options["map"] = cfg.get("world_map", [])
			var prop := room.add_prop(str(p[0]), Vector3(float(p[1]), float(options.get("y", 0.0)), float(p[2])), float(p[3]) if p.size() > 3 else 0.0, options, false)
			_prop_interact(room, prop, options)
		for s: Dictionary in entry.get("signs", []):
			room.add_sign(s)
		room.build_lights()
	for room in room_list:
		_box_total += room.chunk_count()
		room.finish()
	_build_doors(texts)
	_build_lift(texts)
	_build_exterior()
	for room in room_list:
		room.active = true
		room.set_active(false)
	_build_ms = Time.get_ticks_msec() - started

func _openings() -> Array:
	var result: Array = []
	for d: Dictionary in cfg.get("doors", []):
		var at: Array = d["at"]
		var y := float(d.get("y", 0.0))
		result.append({"axis": str(d.get("axis", "x")), "x": float(at[0]), "z": float(at[1]), "w": float(d.get("w", 1.0)) + (0.16 if str(d.get("type", "swing")) != "arch" else 0.0),
				"y0": y, "y1": y + float(d.get("h", 2.2)) + (0.08 if str(d.get("type", "swing")) != "arch" else 0.0), "rooms": d.get("rooms", [])})
	for w: Dictionary in cfg.get("windows", []):
		var at: Array = w["at"]
		var y0 := float(w.get("y", 0.0)) + float(w.get("sill", 0.9))
		var win_rooms: Array = w.get("rooms", [])
		var entry := {"axis": str(w.get("axis", "x")), "x": float(at[0]), "z": float(at[1]), "w": float(w.get("w", 2.0)), "y0": y0,
				"y1": y0 + float(w.get("h", 1.6)), "rooms": win_rooms, "glass": true, "owner": str(win_rooms[0])}
		for key in ["frame", "alpha", "bay"]:
			if w.has(key):
				entry[key] = w[key]
		result.append(entry)
	var lift_cfg: Dictionary = cfg.get("lift", {})
	if not lift_cfg.is_empty():
		var door: Dictionary = lift_cfg.get("door", {})
		var at: Array = door.get("at", [0, 0])
		for f: Dictionary in lift_cfg.get("floors", []):
			var y := float(f.get("y", 0.0))
			result.append({"axis": "x", "x": float(at[0]), "z": float(at[1]), "w": float(door.get("w", 1.4)) + 0.2, "y0": y,
					"y1": y + float(door.get("h", 2.3)) + 0.12, "rooms": [str(f.get("room", ""))]})
	return result

func _layers_for(ids: Array) -> int:
	var bits := 0
	for id in ids:
		if rooms.has(str(id)):
			bits |= (rooms[str(id)] as WorldRoom).layer_bit
	return bits if bits != 0 else 1

func _build_doors(texts: Dictionary) -> void:
	var packed: PackedScene = load("res://scenes/world/kit/door.tscn") if ResourceLoader.exists("res://scenes/world/kit/door.tscn") else null
	for d: Dictionary in cfg.get("doors", []):
		var door: WorldDoor = (packed.instantiate() as WorldDoor) if packed != null else WorldDoor.new()
		door.name = "Door_" + str(d.get("id", doors.size()))
		door.actors = actor_positions
		door.play_sound = play_sound
		door.setup(d, _layers_for(d.get("rooms", [])), texts)
		add_child(door)
		doors.append(door)
		doors_by_id[door.door_id] = door
		door.locked_tried.connect(func(which: WorldDoor) -> void: door_locked_tried.emit(which))
		var ids: Array = d.get("rooms", [])
		if ids.size() >= 2:
			_portals.append({"a": str(ids[0]), "b": str(ids[1]), "door": door})
		var flag := str(d.get("lock_flag", ""))
		if flag != "":
			door.set_locked(not GameState.has_flag(flag))
	GameState.flag_changed.connect(_on_flag_changed)
	for w: Dictionary in cfg.get("windows", []):
		var ids: Array = w.get("rooms", [])
		if ids.size() >= 2:
			_portals.append({"a": str(ids[0]), "b": str(ids[1]), "cost": int(w.get("sight_cost", 2))})
		elif bool(w.get("exterior", true)):
			_portals.append({"a": str(ids[0]), "b": EXTERIOR})
	for link: Array in cfg.get("sight_links", []):
		_portals.append({"a": str(link[0]), "b": str(link[1])})

func _on_flag_changed(flag: String, value: bool) -> void:
	for door in doors:
		if str(door.data.get("lock_flag", "")) == flag:
			door.set_locked(not value)

func _build_lift(texts: Dictionary) -> void:
	var entry: Dictionary = cfg.get("lift", {})
	if entry.is_empty():
		return
	var packed: PackedScene = load("res://scenes/world/kit/lift.tscn") if ResourceLoader.exists("res://scenes/world/kit/lift.tscn") else null
	lift = (packed.instantiate() as WorldLift) if packed != null else WorldLift.new()
	lift.name = "Lift"
	lift.actors = actor_positions
	lift.riders = rider_bodies
	lift.play_sound = play_sound
	var bits := LIFT_BIT
	for f: Dictionary in entry.get("floors", []):
		bits |= _layers_for([f.get("room", "")])
	add_child(lift)
	lift.setup(entry, bits, texts)
	var floors: Array = entry.get("floors", [])
	for i in floors.size():
		_portals.append({"a": LIFT, "b": str((floors[i] as Dictionary).get("room", "")), "lift_floor": i})

func _build_exterior() -> void:
	exterior = Node3D.new()
	exterior.name = "Exterior"
	add_child(exterior)
	var ext: Dictionary = cfg.get("exterior", {})
	var bm := BrickMesh.new()

	bm.stud_world_grid = true
	var clip: Array = ext.get("stud_area", [-6, 44, 70, 62])
	bm.stud_clip = Rect2(float(clip[0]), float(clip[1]), float(clip[2]) - float(clip[0]), float(clip[3]) - float(clip[1]))
	for g: Dictionary in ext.get("ground", []):
		bm.slab(WorldRoom.v3(g["a"]), WorldRoom.v3(g["b"]), Color(str(g.get("color", "7f9a6a"))), str(g.get("surface", "matte")))
	var ground := 	bm.commit(exterior, EXTERIOR_BIT, "Ground")
	if ground != null:
		for child in ground.get_children():
			if child is GeometryInstance3D:
				(child as GeometryInstance3D).visibility_range_end = 0.0
	for p: Array in ext.get("props", []):
		var prop := KitProp.new()
		prop.position = Vector3(float(p[1]), 0.0, float(p[2]))
		prop.rotation.y = deg_to_rad(float(p[3]) if p.size() > 3 else 0.0)
		var options: Dictionary = (p[4] as Dictionary).duplicate() if p.size() > 4 else {}
		options["seed"] = exterior.get_child_count()
		prop.setup(str(p[0]), options, EXTERIOR_BIT)
		prop.lod_range = 0.0
		if prop.mesh_instance != null:
			prop.mesh_instance.visibility_range_end = 0.0
		exterior.add_child(prop)

func _prop_interact(room: WorldRoom, prop: KitProp, options: Dictionary) -> void:
	if not options.has("interact"):
		return
	var spec: Dictionary = options["interact"]
	var at: Array = spec.get("at", [0, 1.0, 0.4])
	var from: Array = spec.get("from", [0, 1.5, 1.8])
	var stub := WorldInteract.make(prop, str(spec.get("id", prop.kind)), str(spec.get("prompt", "E  Use")),
			Vector3(float(at[0]), float(at[1]), float(at[2])), Vector3(float(from[0]), float(from[1]), float(from[2])))
	stub.set_meta("room", room.room_id)
	stub.set_meta("spec", spec)
	stub.used.connect(func(_by: Player) -> void: StoryTriggers.fire(str(stub.get_meta("interact_id")), {"say": str(spec.get("say", "")), "room": room.room_id}))

func spawn_people(people_cfg: Dictionary, barks_cfg: Dictionary) -> void:
	var roles: Dictionary = people_cfg.get("roles", {})
	var barks: Dictionary = barks_cfg.get("barks", {})
	var packed: PackedScene = load("res://scenes/world/kit/npc.tscn") if ResourceLoader.exists("res://scenes/world/kit/npc.tscn") else null
	var make := func(spec: Dictionary, pose: String, layers: int) -> WorldNpc:
		var npc: WorldNpc = (packed.instantiate() as WorldNpc) if packed != null else WorldNpc.new()
		npc.role = str(spec.get("role", "engineer"))
		npc.name = "Npc_%s_%d" % [npc.role, npcs.size()]
		npc.setup(self, roles.get(npc.role, {}), pose, layers, barks.get(str(spec.get("bark", "")), []))
		npcs.append(npc)
		if spec.has("talk"):
			_npc_talk(npc, spec["talk"])
		if str(spec.get("name", "")) != "":
			var tag := Label3D.new()
			tag.text = str(spec["name"])
			tag.font = ConsoleTheme.typewriter()
			tag.font_size = 48
			tag.pixel_size = 0.005
			tag.outline_size = 8
			tag.outline_modulate = Color("2b2622")
			tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			tag.position = Vector3(0, 2.2, 0)
			tag.visibility_range_end = 14.0
			npc.add_child(tag)
		return npc
	for room in room_list:
		for prop in room.props:
			var specs: Array = prop.options.get("npcs", [])
			if prop.options.has("npc"):
				specs = [prop.options["npc"]]
			for spec: Dictionary in specs:
				var spot: Dictionary = {"pos": Vector3(0, 0, 1), "yaw": PI, "pose": "stand"}
				if not prop.spots.is_empty():
					spot = prop.spots[mini(int(spec.get("seat", 0)), prop.spots.size() - 1)]
				var spot_pose := str(spot["pose"])
				var pose := str(spec.get("pose", spot_pose))
				if spot_pose == "sit" and not spec.has("at") and not (pose.begins_with("sit") or pose in ["type", "write", "talk_sit"]):
					pose = "sit"
				var npc: WorldNpc = make.call(spec, pose, room.layer_bit)
				prop.add_child(npc)
				npc.position = spot["pos"]
				npc.rotation.y = float(spot["yaw"])
				if spec.has("at"):
					npc.position = WorldRoom.v3(spec["at"])
				if spec.has("yaw"):
					npc.rotation.y = deg_to_rad(float(spec["yaw"]))
				npc.room_id = room.room_id
				room.people.append(npc)
				npc.set_active(room.active)
	for spec: Dictionary in people_cfg.get("people", []):
		if not rooms.has(str(spec.get("room", ""))):
			continue
		var room: WorldRoom = rooms[str(spec["room"])]
		var npc: WorldNpc = make.call(spec, str(spec.get("pose", "stand")), room.layer_bit)
		room.add_child(npc)
		var at: Array = spec["at"]
		npc.position = room.local_point(float(at[0]), float(at[1]), float(at[2]))
		npc.rotation.y = deg_to_rad(float(spec.get("yaw", 0.0)))
		npc.room_id = room.room_id
		room.people.append(npc)
		npc.set_active(room.active)
	for spec: Dictionary in people_cfg.get("walkers", []):
		var npc: WorldNpc = make.call(spec, "walk", 1)
		add_child(npc)
		npc.set_route(spec.get("route", []))
		walkers.append(npc)

func _npc_talk(npc: WorldNpc, spec: Dictionary) -> void:
	var at: Array = spec.get("at", [0, 1.25, 0])
	var it := WorldInteract.make(npc, str(spec.get("id", "talk_" + npc.role)), str(spec.get("prompt", "E  Talk")),
			Vector3(float(at[0]), float(at[1]), float(at[2])))
	it.framing = Interactable.Framing.TWO_SHOT
	it.radius = float(spec.get("radius", 3.0))
	it.used.connect(func(_by: Player) -> void: StoryTriggers.fire(str(it.get_meta("interact_id")), {"role": npc.role}))

func player() -> Node3D:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D if is_inside_tree() else null
	return _player

func actor_positions() -> Array:
	var result: Array = []
	var p := player()
	if p != null:
		result.append(p.global_position)
	for w in walkers:
		if is_instance_valid(w):
			result.append(w.global_position)
	return result

func rider_bodies() -> Array:
	var result: Array = []
	var p := player()
	if p != null:
		result.append(p)
	for w in walkers:
		if is_instance_valid(w):
			result.append(w)
	return result

func play_sound(id: String, at: Vector3) -> void:
	if sound_player.is_valid():
		sound_player.call(id, at)

func room_at(point: Vector3) -> String:
	if lift != null and lift.contains(point):
		return LIFT
	for room in room_list:
		if room.contains(point):
			return room.room_id
	return ""

func room_data(id: String) -> Dictionary:
	if id == LIFT:
		return cfg.get("lift", {})
	return (rooms[id] as WorldRoom).data if rooms.has(id) else {}

func station(id: String) -> Dictionary:
	return (cfg.get("stations", {}) as Dictionary).get(id, {})

func spawn_point() -> Dictionary:
	return cfg.get("spawn", {"at": [32, 0, 41], "yaw": 0})

func entry_point(id: String) -> Vector3:
	if not rooms.has(id):
		return Vector3.INF
	var room: WorldRoom = rooms[id]
	if room.data.has("entry"):
		var e: Array = room.data["entry"]
		return room.local_point(float(e[0]), float(e[1]) if e.size() > 2 else 0.0, float(e[e.size() - 1]))
	return Vector3(room.rect.get_center().x, room.base_y, room.rect.get_center().y)

func _adopt(body: Node, room_id: String) -> void:
	var bit := LIFT_BIT if room_id == LIFT else (rooms[room_id] as WorldRoom).layer_bit
	var stack: Array = [body]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is GeometryInstance3D:
			(node as GeometryInstance3D).layers = bit | 1
		stack.append_array(node.get_children())

func stats() -> Dictionary:
	var prop_count := 0
	var light_count := 0
	for room in room_list:
		prop_count += room.props.size()
		light_count += room.lights.size()
	return {"rooms": room_list.size(), "doors": doors.size(), "props": prop_count, "lights": light_count,
			"people": npcs.size(), "chunks": _box_total, "build_ms": _build_ms, "visible": visible_rooms.size()}

func show_everything(on: bool) -> void:
	_force_all = on
	visible_rooms = {"__dirty": true}

func _process(_delta: float) -> void:
	var body := player()
	if body == null:
		return
	var here := room_at(body.global_position + Vector3(0, 0.9, 0))
	if here != "" and here != current_room:
		current_room = here
		_adopt(body, here)
		room_changed.emit(here, room_data(here))
	var starts: Array = [current_room]
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var cam_room := room_at(camera.global_position)
		if cam_room != "" and cam_room != current_room:
			starts.append(cam_room)
	var seen := {}
	if _force_all:
		for room in room_list:
			seen[room.room_id] = true
		seen[EXTERIOR] = true
	else:
		var frontier: Array = []
		for s: String in starts:
			if s != "":
				seen[s] = SIGHT_BUDGET
				frontier.append(s)
		while not frontier.is_empty():
			var id: String = frontier.pop_back()
			var budget: int = seen[id]
			if budget <= 0 or id == EXTERIOR:
				continue
			for portal: Dictionary in _portals:
				var other := ""
				if portal["a"] == id:
					other = portal["b"]
				elif portal["b"] == id:
					other = portal["a"]
				if other == "":
					continue
				var left := budget - int(portal.get("cost", 1))
				if left < 0 or int(seen.get(other, -1)) >= left or not _portal_open(portal):
					continue
				seen[other] = left
				frontier.append(other)
	if seen.size() == visible_rooms.size() and seen.has_all(visible_rooms.keys()):
		return
	visible_rooms = seen
	for room in room_list:
		room.set_active(seen.has(room.room_id))
	exterior.visible = seen.has(EXTERIOR)
	for door in doors:
		var show := door.rooms.is_empty()
		for id in door.rooms:
			if seen.has(str(id)):
				show = true
		door.visible = show

func _portal_open(portal: Dictionary) -> bool:
	if portal.has("lift_floor"):
		return lift != null and lift.portal_open(int(portal["lift_floor"]))
	if portal.has("door"):
		return (portal["door"] as WorldDoor).see_through()
	return true
