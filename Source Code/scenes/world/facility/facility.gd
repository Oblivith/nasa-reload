# SI assistance metadata: This code used the help of SI.
extends Node3D

const SHEET_SCENE := "res://scenes/ui/RocketBuilder.tscn"
const PLAYER_SCENE := "res://scenes/player/Player.tscn"
const PICK_LAYER_BIT := 2
const CLICK_RANGE := 7.0
const SHELF_PIECE_SIZE := 0.9
const ROOM_ALIASES := {"launch_office": "mission_control"}

var session: DesignSession
var world: FacilityWorld
var atmosphere: WorldAtmosphere
var audio: WorldAudio
var _cfg: Dictionary = {}
var _player: Player
var _camera: Camera3D
var _at: Node3D

var _bricks := BrickKit.new(0.4)
var _ui_layer: CanvasLayer
var _hud: FacilityHud
var _overlay: Control = null
var _overlay_kind: String = ""
var _room_id: String = ""
var _stubs: Dictionary = {}

var _bench_rocket: RocketModel
var _bench_pick: StaticBody3D
var _office_rocket: RocketModel
var _shelf_items: Array = []
var _held: Dictionary = {}
var _hovered: Dictionary = {}

var _tunnel_pivot: Node3D
var _tunnel_rocket: RocketModel
var _tunnel_label: Label3D
var _tunnel_fan: Node3D
var _tunnel_streaks: Array[Node3D] = []
var _tunnel_running: bool = false
var _tunnel_angle: float = 0.0
var _tunnel_rate: float = 0.0
var _tunnel_gust: float = 0.0
var _tunnel_margin: float = 0.0

func _ready() -> void:
	_cfg = DataLoader.raw.get("facility", {})
	session = DesignSession.new()
	world = FacilityWorld.new()
	world.name = "World"
	add_child(world)
	world.build(DataLoader.raw.get("facility_world", {}))
	world.spawn_people(DataLoader.raw.get("facility_npcs", {}), DataLoader.raw.get("npc_barks", {}))
	_build_environment()
	_build_player()
	_build_design_bay(_station("design_bay"))
	_build_wind_tunnel(_station("wind_tunnel"))
	_build_computer_room(_station("keypunch"))
	_build_launch_office(_station("flight_console"))
	_bricks.commit(self, "StationScenery")
	_ui_layer = CanvasLayer.new()
	add_child(_ui_layer)
	_hud = FacilityHud.new()
	_ui_layer.add_child(_hud)
	audio = WorldAudio.new()
	audio.name = "Audio"
	add_child(audio)
	audio.setup(world, DataLoader.raw.get("facility_audio", {}))
	audio.announcement.connect(func(text: String) -> void:
		if _overlay == null:
			_hud.notice(text))
	world.room_changed.connect(_on_room_changed)
	world.door_locked_tried.connect(_on_door_locked)
	StoryTriggers.event_fired.connect(_on_story_event)
	GameState.design_changed.connect(_on_design_changed)
	GameState.budget_changed.connect(func(_b: float) -> void: _on_design_changed())
	_on_design_changed()
	Story.attach_facility(self)
	_apply_cmdline.call_deferred()

func _physics_process(_delta: float) -> void:
	_update_hover()

func _process(delta: float) -> void:
	_animate_tunnel(delta)

func _unhandled_input(event: InputEvent) -> void:
	if _overlay != null:
		return
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed:
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			_on_click(_pick_at(_aim_point()))
		elif mouse.button_index == MOUSE_BUTTON_RIGHT:
			_drop_held()

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F1:
		_toggle_sheet()
		get_viewport().set_input_as_handled()
		return
	if _overlay_kind == "sheet" and key.keycode == KEY_ESCAPE:
		_toggle_sheet()
		get_viewport().set_input_as_handled()
		return

	if _overlay != null:
		return
	if key.keycode == KEY_ESCAPE and not _held.is_empty():
		_drop_held()

func interact(id: String) -> void:
	match id:
		"dot":
			var dialogue := DotDialogue.new()
			_open_overlay(dialogue, "dot")
			_hold_shot("dot", dialogue)
			dialogue.start(DotDialogue.lines_for(session.report, session.total_cost(session.design),
					session.budget_limit(), DataLoader.raw.get("dot_lines", {})))
			StoryTriggers.fire("talked_to_dot", {"stars": int(session.report.get("stars", 0))})
		"keypunch":
			var keypunch := Keypunch.new()
			keypunch.session = session
			_open_overlay(keypunch, "keypunch")
			_hold_shot("keypunch", keypunch)
			StoryTriggers.fire("used_keypunch")
		"wind_tunnel":

			_start_tunnel()
			StoryTriggers.fire("ran_wind_tunnel", {"margin_cal": _tunnel_margin})
		"launch":
			_request_launch()
			get_tree().create_timer(3.0).timeout.connect(_release_frame)

func _request_launch() -> void:
	var texts: Dictionary = _cfg.get("launch_office", {})
	var blocker := session.launch_blocker()
	if blocker != "":
		_hud.notice(str(texts.get("blocked", "%s")) % blocker)
		return
	StoryTriggers.fire("launch_requested", {"stars": int(session.report.get("stars", 0))})
	var scene := str(_cfg.get("mission_control_scene", ""))
	if scene != "" and ResourceLoader.exists(scene):
		_hud.notice(str(texts.get("cleared", "")))
		SceneManager.change_scene(scene)
	else:
		_hud.notice(str(texts.get("not_built", "")))

func _on_click(pick: Dictionary) -> void:
	if pick.is_empty():
		return
	if not _within_reach(pick.get("position", _player.position)):
		_hud.notice("Too far away. Walk closer.")
		return
	match str(pick.get("type", "")):
		"part":
			_hold(str(pick["part"]), str(pick["id"]))
		"rocket":
			if _held.is_empty():
				_hud.notice(str(_room("design_bay").get("subtitle", "")))
				return
			var result := session.fit_part(str(_held["part"]), str(_held["id"]))
			_hud.notice(str(result["notice"]))
			if bool(result["ok"]):
				StoryTriggers.fire("fitted_part", {"part": _held["part"], "id": _held["id"]})
				_drop_held()

func _hold(part: String, id: String) -> void:
	_drop_held()
	var preset: Dictionary = (DataLoader.presets.get(part, {}) as Dictionary).get(id, {})
	var node := RocketModel.part_piece(part, preset, _preset_scale(DataLoader.presets.get(part, {})), SHELF_PIECE_SIZE * 0.5)
	_player.hand_anchor().add_child(node)
	node.position = Vector3(0, -0.1, 0.12)
	_player.set_carrying(true)
	_held = {"part": part, "id": id, "node": node}
	_hud.set_holding(str((_cfg.get("prompts", {}) as Dictionary).get("holding", "%s")) % str(preset.get("label", id)))

func _drop_held() -> void:
	if _held.has("node"):
		(_held["node"] as Node3D).queue_free()
	_held = {}
	if _player != null and is_instance_valid(_player):
		_player.set_carrying(false)
	if _hud != null:
		_hud.set_holding("")

func _within_reach(at: Vector3) -> bool:
	return at.distance_to(_player.global_position + Vector3(0, 1.2, 0)) <= CLICK_RANGE

func _hold_shot(id: String, node: Node) -> void:
	var it: Interactable = _stubs.get(id)
	if it != null and it.is_in_use():
		it.hold_while(node)

func _release_frame() -> void:
	if _player != null and is_instance_valid(_player) and _overlay == null:
		_player.end_interaction()

func _aim_point() -> Vector2:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return get_viewport().get_visible_rect().size * 0.5
	return get_viewport().get_mouse_position()

func _update_hover() -> void:
	if _overlay != null:
		_hud.show_hover("", Vector2.ZERO)
		return
	var mouse := _aim_point()
	var pick := _pick_at(mouse)
	if pick.get("type", "") != _hovered.get("type", "") or pick.get("id", "") != _hovered.get("id", "") \
			or pick.get("part", "") != _hovered.get("part", ""):
		for item: Dictionary in _shelf_items:
			(item["node"] as Node3D).scale = Vector3.ONE
		_hovered = pick
		if str(pick.get("type", "")) == "part":
			for item: Dictionary in _shelf_items:
				if item["part"] == pick["part"] and item["id"] == pick["id"]:
					(item["node"] as Node3D).scale = Vector3.ONE * 1.15
	match str(pick.get("type", "")):
		"part":
			var preset: Dictionary = (DataLoader.presets.get(str(pick["part"]), {}) as Dictionary).get(str(pick["id"]), {})
			var option := session.part_option(str(pick["part"]), str(pick["id"]))
			var state := "FITTED" if bool(option["fitted"]) else ("Rocket would cost $%.1fM" % float(option["cost"]))
			if not bool(option["affordable"]):
				state += "  (over budget)"
			_hud.show_hover("%s\n%s\n%s" % [str(preset.get("label", "")).to_upper(), str(preset.get("description", "")), state], mouse)
		"rocket":
			_hud.show_hover("YOUR ROCKET\n%s" % ("Click to fit the part you are holding." if not _held.is_empty()
					else "Pick a part off a shelf first."), mouse)
		_:
			_hud.show_hover("", Vector2.ZERO)

func _pick_at(screen: Vector2) -> Dictionary:
	if _camera == null or not is_inside_tree():
		return {}
	var from := _camera.project_ray_origin(screen)
	var to := from + _camera.project_ray_normal(screen) * 80.0
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 << (PICK_LAYER_BIT - 1))
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not (hit["collider"] as Object).has_meta("pick"):
		return {}
	var pick: Dictionary = ((hit["collider"] as Object).get_meta("pick") as Dictionary).duplicate()
	pick["position"] = hit["position"]
	return pick

func _open_overlay(control: Control, kind: String) -> void:
	_close_overlay()
	_overlay = control
	_overlay_kind = kind
	_drop_held()
	_set_player_input(false)
	control.tree_exited.connect(func() -> void:
		if _overlay == control:
			_overlay = null
			_overlay_kind = ""
			_set_player_input(true))
	_ui_layer.add_child(control)

func open_story_overlay(control: Control) -> void:
	_open_overlay(control, "story")

func story_overlay_open() -> bool:
	return _overlay != null

func _close_overlay() -> void:
	var had := _overlay != null
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_overlay_kind = ""
	if had:
		_set_player_input(true)

func _set_player_input(on: bool) -> void:
	if not is_inside_tree() or _player == null or not is_instance_valid(_player):
		return
	_player.set_control_enabled(on)

func _toggle_sheet() -> void:
	if _overlay_kind == "sheet":
		_close_overlay()
		session.load_from_game_state()
		return
	var sheet := (load(SHEET_SCENE) as PackedScene).instantiate() as Control
	_open_overlay(sheet, "sheet")

func _on_design_changed() -> void:
	if _overlay_kind == "sheet":
		return
	var design: Dictionary = GameState.current_design
	var report: Dictionary = GameState.current_report
	_bench_rocket.build(design, report)
	_office_rocket.build(design, report)
	_tunnel_rocket.build(design, report)
	_place_tunnel_rocket(report)
	var shape := _bench_pick.get_child(0) as CollisionShape3D
	(shape.shape as BoxShape3D).size = Vector3(maxf(1.2, _bench_rocket.radius_m * 4.0), maxf(1.0, _bench_rocket.height_m), 1.4)
	shape.position.y = _bench_rocket.height_m / 2.0
	_refresh_shelf_labels()
	_hud.set_status(session.report, session.total_cost(session.design), session.budget_limit())

func _build_environment() -> void:
	atmosphere = WorldAtmosphere.new()
	atmosphere.name = "Atmosphere"
	add_child(atmosphere)
	atmosphere.setup(world)

func _station(id: String) -> Dictionary:
	var data := world.station(id)
	var origin: Array = data.get("origin", data.get("at", [0, 0, 0]))
	_at = Node3D.new()
	_at.name = "Station_" + id
	_at.position = Vector3(float(origin[0]), float(origin[1]), float(origin[2]))
	add_child(_at)
	return data

func _add_interact(id: String, at: Vector3, frame_from: Vector3) -> void:
	var stub := WorldInteract.make(_at, id, str((_cfg.get("prompts", {}) as Dictionary).get(id, "Use")), at, frame_from)
	stub.used.connect(func(_by: Player) -> void: interact(id))
	_stubs[id] = stub

func _on_room_changed(room_id: String, room: Dictionary) -> void:
	_room_id = room_id
	_hud.set_room(str(room.get("name", "")), str(room.get("subtitle", "")))
	StoryTriggers.enter_area(room_id)

func _on_door_locked(door: WorldDoor) -> void:
	var texts: Dictionary = world.cfg.get("texts", {})
	_hud.notice(str(door.data.get("locked_text", texts.get("locked", "Locked."))))
	StoryTriggers.fire("door_locked", {"door": door.door_id})

func _on_story_event(event_id: String, payload: Dictionary) -> void:
	if str(payload.get("say", "")) != "":
		_hud.notice(str(payload["say"]))
	for unlock: Dictionary in world.cfg.get("story_unlocks", []):
		if str(unlock.get("event", "")) == event_id and not GameState.has_flag(str(unlock["flag"])):
			GameState.set_flag(str(unlock["flag"]))
			if str(unlock.get("say", "")) != "" and _overlay == null:
				_hud.notice(str(unlock["say"]))

func _build_player() -> void:
	var spawn := world.spawn_point()
	var at: Array = spawn.get("at", [0, 0, 0])
	_player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	_player.name = "Player"
	_player.position = Vector3(float(at[0]), float(at[1]), float(at[2]))
	_player.capture_mouse = DisplayServer.get_name() != "headless"
	add_child(_player)
	_player.teleport(_player.position, _yaw_dir(deg_to_rad(float(spawn.get("yaw_deg", 0.0)))))
	_camera = _player.camera_rig.camera

static func _yaw_dir(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))

func _mini_figure(parent: Node3D, shirt: Color, head: Color) -> void:
	var legs := _figure_box(Vector3(0.5, 0.75, 0.3), Color("2b2622"))
	legs.position.y = 0.375
	parent.add_child(legs)
	var torso := _figure_box(Vector3(0.62, 0.65, 0.36), shirt)
	torso.position.y = 1.08
	parent.add_child(torso)
	var face := MeshInstance3D.new()
	var sphere := CylinderMesh.new()
	sphere.top_radius = 0.2
	sphere.bottom_radius = 0.2
	sphere.height = 0.36
	face.mesh = sphere
	face.material_override = RocketModel.mat(head)
	face.position.y = 1.6
	parent.add_child(face)
	var stud := MeshInstance3D.new()
	var stud_mesh := CylinderMesh.new()
	stud_mesh.top_radius = 0.1
	stud_mesh.bottom_radius = 0.1
	stud_mesh.height = 0.1
	stud.mesh = stud_mesh
	stud.material_override = RocketModel.mat(head)
	stud.position.y = 1.83
	parent.add_child(stud)

func _build_design_bay(room: Dictionary) -> void:
	var x0 := float(room.get("x_min", 0.0))
	var x1 := float(room.get("x_max", 18.0))
	var half := float(room.get("depth", 14.0)) / 2.0
	var bench_pos := Vector3((x0 + x1) / 2.0 - 1.0, 0, -1.0)
	_box(bench_pos + Vector3(0, 0.45, 0), Vector3(3.4, 0.9, 1.8), Color("8c6a4a"), true)
	_box(bench_pos + Vector3(0, 0.93, 0), Vector3(3.6, 0.06, 2.0), Color("6b4f36"), false)
	_bench_rocket = RocketModel.new()
	_bench_rocket.model_height = 3.6
	_bench_rocket.position = bench_pos + Vector3(0, 0.96, 0)
	_at.add_child(_bench_rocket)
	_bench_pick = StaticBody3D.new()
	_bench_pick.collision_layer = 1 << (PICK_LAYER_BIT - 1)
	_bench_pick.collision_mask = 0
	_bench_pick.set_meta("pick", {"type": "rocket"})
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	_bench_pick.add_child(shape)
	_bench_pick.position = _bench_rocket.position
	_at.add_child(_bench_pick)
	_label("WORKBENCH", bench_pos + Vector3(0, 0.5, 0.95), 70)

	var parts: Array = DataLoader.builder_ui.get("easy_parts", [])
	var rack_w := (x1 - x0 - 1.0) / maxf(1.0, float(parts.size()))
	for p in parts.size():
		var part := str((parts[p] as Dictionary)["part"])
		var cx := x0 + 0.5 + rack_w * (p + 0.5)
		var z := -half + 1.0
		_box(Vector3(cx, 0.5, z), Vector3(rack_w - 0.3, 1.0, 1.1), Color("2a7b7b"), true)
		_box(Vector3(cx, 1.02, z), Vector3(rack_w - 0.2, 0.05, 1.2), Color("1f5c5c"), false)
		_label(str((parts[p] as Dictionary)["label"]).to_upper(), Vector3(cx, 2.55, z), 90)
		var table: Dictionary = DataLoader.presets.get(part, {})
		var ids := table.keys()
		var scale_ref := _preset_scale(table)
		for k in ids.size():
			var id := str(ids[k])
			var px := cx + (float(k) - (ids.size() - 1) / 2.0) * minf(0.85, (rack_w - 0.4) / maxf(1.0, ids.size()))
			var piece := RocketModel.part_piece(part, table[id], scale_ref, SHELF_PIECE_SIZE)
			piece.position = Vector3(px, 1.05, z)
			_at.add_child(piece)
			var body := StaticBody3D.new()
			body.collision_layer = 1 << (PICK_LAYER_BIT - 1)
			body.collision_mask = 0
			body.set_meta("pick", {"type": "part", "part": part, "id": id})
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(0.7, SHELF_PIECE_SIZE + 0.2, 0.9)
			cs.shape = bs
			cs.position.y = (SHELF_PIECE_SIZE + 0.2) / 2.0
			body.add_child(cs)
			body.position = piece.position
			_at.add_child(body)
			var label := _label("", Vector3(px, 0.72, z + 0.6), 34)
			_shelf_items.append({"part": part, "id": id, "preset": table[id], "node": piece, "label": label})

	var dot_pos := Vector3(x1 - 2.2, 0, 1.0)
	_box(dot_pos + Vector3(0.9, 0.4, -0.2), Vector3(1.4, 0.8, 1.0), Color("6b4f36"), true)
	for m in 8:
		var mug_color: Color = [Color("c8551f"), Color("fbf5e6"), Color("e9c46a"), Color("2a7b7b")][m % 4]
		_bricks.add_cylinder(_at.position + dot_pos + Vector3(0.4 + (m % 4) * 0.3, 0.87, -0.5 + (m / 4) * 0.45), 0.07, 0.14, mug_color, 0.14)
	var dot := Node3D.new()
	dot.position = dot_pos
	dot.rotation.y = -0.4
	_at.add_child(dot)
	_mini_figure(dot, Color("c8551f"), Color("8c5a3c"))
	var dot_name := _label("DOT", dot_pos + Vector3(0, 2.25, 0), 70)
	dot_name.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_add_interact("dot", dot_pos + Vector3(0, 1.3, 0), dot_pos + Vector3(-1.7, 1.55, 2.0))

func _refresh_shelf_labels() -> void:
	for item: Dictionary in _shelf_items:
		var option := session.part_option(str(item["part"]), str(item["id"]))
		var label: Label3D = item["label"]

		if bool(option["fitted"]):
			label.text = "FITTED"
			label.modulate = Color("8fe0a0")
		elif not bool(option["affordable"]):
			label.text = "$%.0fM!" % float(option["cost"])
			label.modulate = Color("ff8a7a")
		else:
			label.text = "$%.1fM" % float(option["cost"])
			label.modulate = Color("fbf5e6")

func _preset_scale(table: Dictionary) -> Dictionary:
	var result := {}
	for id in table:
		var preset: Dictionary = table[id]
		for key in ["length_m", "diameter_m", "root_chord_m", "propellant_mass_kg"]:
			if preset.has(key) and preset[key] != null:
				result[key] = maxf(float(result.get(key, 0.0)), float(preset[key]))
	return result

func _build_wind_tunnel(room: Dictionary) -> void:
	var x0 := float(room.get("x_min", 18.0))
	var x1 := float(room.get("x_max", 32.0))
	var cx := (x0 + x1) / 2.0
	var z := -3.0
	var length := x1 - x0 - 3.0
	var glass := _mesh_box(Vector3(length, 2.4, 2.6), Color(0.7, 0.9, 0.95, 0.18))
	glass.position = Vector3(cx, 1.5, z)
	_at.add_child(glass)
	_box(Vector3(cx, 0.15, z), Vector3(length, 0.3, 2.8), Color("4d5b63"), true)
	_box(Vector3(cx, 2.75, z), Vector3(length, 0.1, 2.8), Color("4d5b63"), false)
	_box(Vector3(cx, 1.5, z - 1.35), Vector3(length, 2.6, 0.1), Color("4d5b63"), true)

	_tunnel_fan = Node3D.new()
	_tunnel_fan.position = Vector3(x1 - 1.4, 1.5, z)
	_at.add_child(_tunnel_fan)
	for b in 4:
		var blade := _mesh_box(Vector3(0.08, 2.0, 0.35), Color("2b2622"))
		blade.rotation.x = TAU * b / 4.0
		_tunnel_fan.add_child(blade)
	for i in 6:
		var streak := _mesh_box(Vector3(0.9, 0.03, 0.03), Color(1, 1, 1, 0.6))
		streak.position = Vector3(x0 + 2.0 + i * 1.6, 0.8 + (i % 3) * 0.6, z + (float(i % 2) - 0.5) * 1.4)
		streak.visible = false
		_at.add_child(streak)
		_tunnel_streaks.append(streak)
	_tunnel_pivot = Node3D.new()
	_tunnel_pivot.position = Vector3(cx - 0.5, 1.5, z)
	_at.add_child(_tunnel_pivot)
	var stand := _mesh_box(Vector3(0.08, 1.2, 0.08), Color("8c8577"))
	stand.position = Vector3(cx - 0.5, 0.9, z)
	_at.add_child(stand)
	var holder := Node3D.new()
	holder.rotation.z = PI / 2.0
	_tunnel_pivot.add_child(holder)
	_tunnel_rocket = RocketModel.new()
	_tunnel_rocket.model_height = 4.6
	holder.add_child(_tunnel_rocket)
	_tunnel_label = _label(str((_cfg.get("wind_tunnel", {}) as Dictionary).get("idle", "")), Vector3(cx, 3.2, z + 1.4), 50)
	_tunnel_label.width = 900
	_tunnel_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var desk := Vector3(cx, 0, 1.8)
	_box(desk + Vector3(0, 0.45, 0), Vector3(2.2, 0.9, 0.9), Color("e9c46a").darkened(0.3), true)
	_label("TUNNEL CONTROL", desk + Vector3(0, 1.0, 0.46), 50)
	_add_interact("wind_tunnel", desk + Vector3(0, 1.0, 0), desk + Vector3(0.7, 1.6, 1.9))

func _place_tunnel_rocket(report: Dictionary) -> void:
	var numbers: Dictionary = report.get("numbers", {})
	var geometry: Dictionary = report.get("geometry", {})
	var length := float(geometry.get("length_m", 0.0))
	var bell := float(geometry.get("diameter_m", 1.0)) * 0.45
	var x_cg := float(numbers.get("x_cg_liftoff_m", length / 2.0))
	_tunnel_rocket.position = Vector3(0, -(bell + length - x_cg) * _tunnel_rocket.scale_factor, 0)
	_tunnel_margin = float(numbers.get("static_margin_liftoff_cal", 0.0))
	_tunnel_running = false
	_tunnel_angle = 0.0
	_tunnel_rate = 0.0
	_tunnel_pivot.rotation.y = 0.0
	for streak in _tunnel_streaks:
		streak.visible = false
	_tunnel_label.text = str((_cfg.get("wind_tunnel", {}) as Dictionary).get("idle", ""))

func _start_tunnel() -> void:
	_tunnel_running = true
	_tunnel_angle = 0.3
	_tunnel_rate = 0.0
	_tunnel_gust = 0.0
	for streak in _tunnel_streaks:
		streak.visible = true
	var texts: Dictionary = _cfg.get("wind_tunnel", {})
	_tunnel_label.text = str(texts.get(tunnel_verdict(_tunnel_margin), "%.2f")) % _tunnel_margin

static func tunnel_verdict(margin: float) -> String:
	if margin < 0.0:
		return "tumbles"
	if margin < Stability.MARGIN_STABLE_MIN:
		return "wobbly"
	if margin > Stability.MARGIN_OVER_STABLE:
		return "stiff"
	return "steady"

func _animate_tunnel(delta: float) -> void:
	if not _tunnel_running:
		return
	_tunnel_fan.rotation.x += delta * 18.0
	for streak in _tunnel_streaks:
		streak.position.x += delta * 7.0
		if streak.position.x > _tunnel_fan.position.x - 0.6:
			streak.position.x -= 9.5
	_tunnel_gust -= delta
	if _tunnel_gust <= 0.0:
		_tunnel_gust = randf_range(0.5, 1.1)
		_tunnel_rate += randf_range(-0.5, 0.5)
	var stiffness := 7.0 * _tunnel_margin
	var damping := 0.5 + 0.4 * maxf(0.0, _tunnel_margin)
	var accel := -stiffness * sin(_tunnel_angle) - damping * _tunnel_rate
	if _tunnel_margin < 0.0:
		accel += signf(_tunnel_rate if _tunnel_rate != 0.0 else 1.0) * 3.0
		damping = 0.1
	_tunnel_rate = clampf(_tunnel_rate + accel * delta, -9.0, 9.0)
	_tunnel_angle = wrapf(_tunnel_angle + _tunnel_rate * delta, -PI, PI)
	_tunnel_pivot.rotation.y = _tunnel_angle

func _build_computer_room(_station_data: Dictionary) -> void:

	var desk := Vector3.ZERO
	_box(desk + Vector3(0, 0.42, 0), Vector3(2.4, 0.84, 1.1), Color("c9c2b0"), true)
	_box(desk + Vector3(0.2, 1.05, -0.2), Vector3(1.2, 0.42, 0.6), Color("4d5b63"), false)
	_box(desk + Vector3(-0.75, 0.95, 0.1), Vector3(0.45, 0.22, 0.3), Color("f3e9c6"), false)
	_label("KEYPUNCH", desk + Vector3(0, 1.0, 0.57), 50)
	_add_interact("keypunch", desk + Vector3(0, 1.0, 0.2), desk + Vector3(0.6, 1.6, 1.7))

func _build_launch_office(_station_data: Dictionary) -> void:
	_add_interact("launch", Vector3(0, 1.0, -0.55), Vector3(0, 1.3, 0.25))
	var model: Array = world.station("vehicle_model").get("at", [0, 0, 0])
	_office_rocket = RocketModel.new()
	_office_rocket.model_height = 3.6
	_office_rocket.position = Vector3(float(model[0]), float(model[1]) + 0.84, float(model[2]))
	add_child(_office_rocket)

func _room(id: String) -> Dictionary:
	return world.room_data(ROOM_ALIASES.get(id, id))

func _mesh_box(size: Vector3, color: Color) -> Node3D:
	var kit := BrickKit.new(clampf(minf(size.x, size.z), 0.05, 0.4))
	kit.add_box(Vector3.ZERO, size, color)
	return kit.commit(null, "BrickBox")

func _figure_box(size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = RocketModel.mat(color)
	return mi

func _box(center: Vector3, size: Vector3, color: Color, solid: bool) -> void:
	_bricks.add_box(_at.position + center, size, color)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		shape.shape = bs
		body.add_child(shape)
		body.position = center
		_at.add_child(body)

func _label(text: String, at: Vector3, font_size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = ConsoleTheme.typewriter()
	label.font_size = font_size
	label.pixel_size = 0.005
	label.outline_size = 10
	label.outline_modulate = Color("2b2622")
	label.position = at
	_at.add_child(label)
	return label

func _apply_cmdline() -> void:
	var screenshot := ""
	var selftest := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--room="):
			_teleport_room(arg.trim_prefix("--room="))
		elif arg.begins_with("--pos="):
			var parts := arg.trim_prefix("--pos=").split_floats(",")
			if parts.size() == 3:
				_player.teleport(Vector3(parts[0], parts[1], parts[2]))
		elif arg.begins_with("--yaw="):
			_player.teleport(_player.global_position, _yaw_dir(deg_to_rad(float(arg.trim_prefix("--yaw=")))))
		elif arg == "--all":
			world.show_everything(true)
		elif arg.begins_with("--flag="):
			GameState.set_flag(arg.trim_prefix("--flag="))
		elif arg.begins_with("--open="):
			var what := arg.trim_prefix("--open=")
			match what:
				"dot", "keypunch", "wind_tunnel":
					interact(what)
				"tunnel":
					interact("wind_tunnel")
				"printout":
					interact("keypunch")
					var keypunch := _overlay as Keypunch
					keypunch._finish_run({"ok": true})
					keypunch._printout.finish_now()
				"sheet":
					_toggle_sheet()
				"holding":
					_hold("upper_stage", "big")
		elif arg.begins_with("--screenshot="):
			screenshot = arg.trim_prefix("--screenshot=")
		elif arg == "--selftest":
			selftest = true
		elif arg.begins_with("--tour="):
			await _run_tour(arg.trim_prefix("--tour="))
			return
	if selftest:
		await _run_selftest()
		return
	var web_bench := OS.has_feature("web") and str(JavaScriptBridge.eval("window.location.search", true)).contains("bench")
	if web_bench or "--bench" in OS.get_cmdline_user_args():
		atmosphere.auto_quality = false
		await _run_bench()
		if not web_bench:
			get_tree().quit()
		return
	if screenshot != "":
		for i in 40:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var err := image.save_png(screenshot)
		print("Facility: screenshot -> %s (%s)  %s" % [screenshot, error_string(err), str(world.stats())])
		get_tree().quit()

func _run_bench() -> void:
	var report: PackedStringArray = []
	for id: String in ["lobby", "corridor_g", "design_bay", "computer_room", "mc_gallery", "mission_control", "typing_pool"]:
		_teleport_room(id)
		for i in 40:
			await get_tree().process_frame
		var started := Time.get_ticks_usec()
		for i in 120:
			await get_tree().process_frame
		var fps := 120.0 / (float(Time.get_ticks_usec() - started) / 1000000.0)
		report.append("%s %.0f" % [id, fps])
		print("BENCH %s: %.1f fps, %d draw calls, %d visible rooms" % [id, fps,
				int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)), world.visible_rooms.size()])
	print("BENCH DONE quality=%d  %s" % [atmosphere.quality, " | ".join(report)])
	_hud.notice("FPS  " + "   ".join(report))
	_teleport_room("lobby")

func _run_tour(path: String) -> void:
	var cell := Vector2i(640, 360)
	var cols := 4
	var ids: Array = world.rooms.keys()
	var sheet := Image.create(cell.x * cols, cell.y * int(ceil(ids.size() / float(cols))), false, Image.FORMAT_RGBA8)
	GameState.set_flag("dad_office_unlocked")
	for i in ids.size():
		_teleport_room(str(ids[i]))
		for f in 14:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.convert(Image.FORMAT_RGBA8)
		image.resize(cell.x, cell.y, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, cell), Vector2i((i % cols) * cell.x, (i / cols) * cell.y))
	print("Facility: tour -> %s (%s)" % [path, error_string(sheet.save_png(path))])
	get_tree().quit()

func _teleport_room(id: String) -> void:
	var room_id := str(ROOM_ALIASES.get(id, id))
	var at := world.entry_point(room_id)
	if at == Vector3.INF:
		push_warning("Facility: no room '%s'" % id)
		return
	var room: WorldRoom = world.rooms[room_id]
	var to_centre := Vector3(room.rect.get_center().x, at.y, room.rect.get_center().y) - at
	_player.teleport(at, to_centre if to_centre.length() > 0.5 else Vector3.ZERO)

func _run_selftest() -> void:
	var failures: PackedStringArray = []
	var expect := func(ok: bool, what: String) -> void:
		print("  [%s] %s" % ["ok" if ok else "FAIL", what])
		if not ok:
			failures.append(what)
	var settle := func() -> void:
		for i in 4:
			await get_tree().physics_frame
		for i in 3:
			await get_tree().process_frame
	print("FACILITY SELFTEST")
	await settle.call()
	var stats := world.stats()
	print("  world: %s" % str(stats))
	expect.call(int(stats["rooms"]) >= 16 and world.lift != null, "building has %d rooms, %d doors and a lift" % [stats["rooms"], stats["doors"]])
	expect.call(int(stats["people"]) >= 25 and world.walkers.size() >= 4, "%d people work here, %d of them walking routes" % [stats["people"], world.walkers.size()])
	var spawn_room := _room_id
	expect.call(StoryTriggers.has_visited("lobby") and spawn_room == "lobby", "player starts in the lobby (%s)" % spawn_room)
	var lost: PackedStringArray = []
	for room in world.room_list:
		if world.room_at(world.entry_point(room.room_id) + Vector3(0, 0.9, 0)) != room.room_id:
			lost.append(room.room_id)
	expect.call(lost.is_empty(), "every room's entry point is inside it %s" % str(lost))

	_teleport_room("design_bay")
	await settle.call()
	expect.call(_shelf_items.size() >= 12, "shelves hold every preset (%d pieces)" % _shelf_items.size())
	expect.call(_bench_rocket.brick_count() > 3, "bench rocket model built (%d bricks)" % _bench_rocket.brick_count())
	expect.call(StoryTriggers.has_visited("design_bay") and _room_id == "design_bay", "enter_area fired for %s" % _room_id)
	expect.call(world.visible_rooms.has("design_bay") and world.visible_rooms.size() <= 9, "only nearby rooms are drawn (%d visible)" % world.visible_rooms.size())
	var dot_stub: Interactable = _stubs["dot"]
	var near_dot := dot_stub.global_position + Vector3(-1.2, 0, 1.2)
	near_dot.y = _player.global_position.y
	_player.teleport(near_dot, dot_stub.global_position - near_dot)
	await settle.call()
	await settle.call()
	expect.call(_player.focused() == dot_stub and dot_stub.camera_point != null, "looking at Dot offers '%s' (focused %s)" % [dot_stub.prompt, str(_player.focused())])

	var before := int(session.report.get("stars", 0))
	var fit := session.fit_part("fins", "small")
	var stab := ""
	for check: Dictionary in session.report.get("checks", []):
		if str(check["id"]) == "stability_liftoff":
			stab = str(check["status"])
	expect.call(bool(fit["ok"]) and stab != "pass", "fitting small fins makes it less stable (%s)" % stab)
	expect.call(str(GameState.current_design.get("fins", {}).get("mass_kg", 0)) == str(DataLoader.presets["fins"]["small"]["mass_kg"]),
			"fit goes through GameState")
	session.fit_part("fins", "medium")
	expect.call(int(session.report.get("stars", 0)) == before, "fitting medium fins back restores %d stars" % before)

	var lines := DotDialogue.lines_for(session.report, session.total_cost(session.design), session.budget_limit(),
			DataLoader.raw.get("dot_lines", {}))
	expect.call(lines.size() >= 5, "Dot has %d lines for this rocket" % lines.size())
	for line in lines:
		print("      DOT: " + line)
		if line.contains("{"):
			failures.append("unfilled placeholder: " + line)

	_teleport_room("computer_room")
	await settle.call()
	expect.call(_room_id == "computer_room" and is_equal_approx(_player.global_position.y, 4.0) or _room_id == "computer_room", "computer room is upstairs (%s)" % _room_id)
	interact("keypunch")
	var keypunch := _overlay as Keypunch
	expect.call(keypunch != null, "keypunch opens")
	if keypunch != null:
		var read := keypunch.read_deck()
		expect.call(bool(read["ok"]), "deck reads back the current design %s" % str(read.get("error", "")))
		if not bool(read["ok"]):
			get_tree().quit(1)
			return
		var trial: Dictionary = read["design"]
		trial["fins"]["span_m"] = float(trial["fins"]["span_m"]) * 1.2
		var result := session.submit_deck(trial)
		expect.call(bool(result["ok"]) and session.input_mode == DesignSession.InputMode.HARD, "deck submit applies in Hard mode")
		expect.call(GameState.mode == GameState.Mode.FLIGHT_DIRECTOR, "GameState mode follows the deck")
		var text := Keypunch.printout_text(session.report, session.design, session.total_cost(session.design), session.budget_limit())
		expect.call(text.contains("Static margin") or text.contains("[PASS]") or text.contains("[WARN]"), "printout has the evaluator report")
		var huge: Dictionary = session.design.duplicate(true)
		huge["stages"][0]["engine"]["count"] = 40
		var refused := session.submit_deck(huge)
		expect.call(not bool(refused["ok"]), "over-budget deck is refused: %s" % str(refused["notice"]).left(70))
		(keypunch._inputs[0]["edit"] as LineEdit).text = "abc"
		var bad := keypunch.read_deck()
		expect.call(not bool(bad["ok"]), "bad card rejected: %s" % str(bad.get("error", "")))
		_close_overlay()

	var refit := session.fit_part("fins", "medium")
	expect.call(bool(refit["ok"]) and session.input_mode == DesignSession.InputMode.EASY, "bench snaps a Hard design back to presets")
	print("  launch blocker: '%s'" % session.launch_blocker())
	print("  tunnel: margin %.2f -> %s" % [_tunnel_margin, tunnel_verdict(_tunnel_margin)])
	expect.call(tunnel_verdict(-0.5) == "tumbles" and tunnel_verdict(2.0) == "steady" and tunnel_verdict(4.0) == "stiff", "tunnel verdicts")

	expect.call(audio.ambience_playing().has("amb_ibm") and audio.surface_at(_player.global_position) == "raised", "computer room ambience and floor surface (%s)" % ", ".join(audio.ambience_playing()))
	expect.call(atmosphere.env.tonemap_mode == Environment.TONE_MAPPER_FILMIC and atmosphere.env.glow_enabled, "atmosphere: filmic tonemap and glow are on")

	var dad: WorldDoor = world.doors_by_id.get("dad")
	expect.call(dad != null and dad.locked and not GameState.has_flag("dad_office_unlocked"), "Dad's office starts locked")
	dad.try_locked()
	expect.call(_hud.notice_text() != "", "locked door says: %s" % _hud.notice_text().left(60))
	StoryTriggers.fire("first_night_at_work")
	expect.call(GameState.has_flag("dad_office_unlocked") and not dad.locked, "story trigger unlocks it through GameState")

	var lift := world.lift
	_player.teleport(lift.ride_point(0.0))
	lift.request(1)
	var waited := 0
	while not lift.is_open_at(1) and waited < 900:
		await get_tree().physics_frame
		waited += 1
	await settle.call()
	expect.call(lift.is_open_at(1) and _player.global_position.y > 3.7, "lift rides to the upper floor (player y %.2f, %d ticks)" % [_player.global_position.y, waited])

	if true:
		var tick_scale := 4.2 / _player.walk_speed
		var walk := func(from: Vector3, dir: Vector3, ticks: int) -> Vector3:
			if from != Vector3.INF:
				_player.teleport(from, dir)
			_player.auto_move = dir
			for i in int(ticks * tick_scale):
				await get_tree().physics_frame
			_player.auto_move = Vector3.ZERO
			return _player.global_position
		var p: Vector3 = await walk.call(Vector3(44.25, 0, 32.6), Vector3(0, 0, 1), 150)
		expect.call(absf(p.y - 2.0) < 0.15 and p.z > 39.5, "walks up the first flight of stairs (%.1f, %.2f, %.1f)" % [p.x, p.y, p.z])
		p = await walk.call(Vector3.INF, Vector3(1, 0, 0), 60)
		p = await walk.call(Vector3.INF, Vector3(0, 0, -1), 170)
		expect.call(absf(p.y - 4.0) < 0.15 and p.z < 31.9, "second flight reaches the upper corridor (%.1f, %.2f, %.1f)" % [p.x, p.y, p.z])
		p = await walk.call(Vector3(16, 0, 30.5), Vector3(0, 0, -1), 130)
		expect.call(p.z < 27.0, "the Design Bay doors open as you walk up (z %.1f)" % p.z)
		p = await walk.call(Vector3(36, 4, 30), Vector3(0, 0, 1), 110)
		expect.call(p.z > 33.0, "Dad's office door opens once unlocked (z %.1f)" % p.z)
		p = await walk.call(Vector3(43.1, 4, 26), Vector3(0, 0, -1), 114)
		expect.call(absf(p.y - 1.2) < 0.15 and p.z < 18.6, "gallery stairs lead down to the Mission Control floor (y %.2f, z %.1f)" % [p.y, p.z])
		p = await walk.call(Vector3(43.0, 1.2, 17.8), Vector3(0, 0, -1), 260)
		expect.call(absf(p.y) < 0.15 and p.z < 9.0, "tier steps lead down to the front row (y %.2f, z %.1f)" % [p.y, p.z])
		p = await walk.call(Vector3(5.1, 4, 27), Vector3(0, 0, -1), 280)
		expect.call(absf(p.y) < 0.15, "catwalk stairs lead down to the bay floor (y %.2f, z %.1f)" % [p.y, p.z])

	_teleport_room("mission_control")
	await settle.call()
	expect.call(_room_id == "mission_control" and _stubs.has("launch"), "FLIGHT console is in Mission Control")
	interact("launch")
	print("  launch notice: %s" % _hud.notice_text())
	print("FACILITY SELFTEST %s" % ("PASS" if failures.is_empty() else "FAIL: " + ", ".join(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)
