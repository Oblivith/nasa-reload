# Code generated with AI assistance (Claude). Reviewed by team.
extends Node3D
## The Center Campus facility: explorable rooms built from placeholder boxes (swap in
## .glb models later). Every room works on the same rocket through DesignSession, which
## stores it in GameState and judges it with RocketEvaluator.
##
##   Design Bay      Easy input: click a part on a shelf, click the rocket to fit it.
##                   Dot stands here: E turns the evaluator report into her lines.
##   Wind Tunnel     A model of the rocket holds steady, wobbles or tumbles by static margin.
##   Computer Room   Hard input: the keypunch deck and fan-fold printout.
##   Launch Office   Requests the launch and hands over to Mission Control.
##   F1              The Rocket Builder sheet (debug / fallback view of the same design).
##
## Rooms report entry through StoryTriggers.enter_area(room id).
## Debug: `-- [--room=<id>] [--open=dot|keypunch|printout|tunnel|sheet]
##   [--screenshot=<png>] [--selftest]`.

const SHEET_SCENE := "res://scenes/ui/RocketBuilder.tscn"
const PICK_LAYER_BIT := 2         # collision layer 2: clickable things
const INTERACT_RANGE := 2.8
const CLICK_RANGE := 11.0
const WALK_SPEED := 5.5
const CAMERA_OFFSET := Vector3(0, 9.5, 9.0)
const SHELF_PIECE_SIZE := 0.9

var session: DesignSession
var _cfg: Dictionary = {}
var _rooms: Array = []
var _player: CharacterBody3D
var _player_mesh: Node3D
var _camera: Camera3D
var _ui_layer: CanvasLayer
var _hud: FacilityHud
var _overlay: Control = null
var _overlay_kind: String = ""
var _room_id: String = ""

var _bench_rocket: RocketModel
var _bench_pick: StaticBody3D
var _office_rocket: RocketModel
var _shelf_items: Array = []      # [{part, id, preset, node, label}]
var _held: Dictionary = {}        # {part, id, node}
var _hovered: Dictionary = {}
var _interactables: Array = []    # [{id, position, prompt}]

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

var _blinkers: Array[StandardMaterial3D] = []
var _reels: Array[Node3D] = []
## Static scenery (floors, walls, furniture) as one brick kit, committed after building.
var _bricks := BrickKit.new(0.4)
var _blink_t: float = 0.0


func _ready() -> void:
	_cfg = DataLoader.raw.get("facility", {})
	_rooms = _cfg.get("rooms", [])
	session = DesignSession.new()
	_build_environment()
	_build_rooms()
	_build_player()
	_build_design_bay(_room("design_bay"))
	_build_wind_tunnel(_room("wind_tunnel"))
	_build_computer_room(_room("computer_room"))
	_build_launch_office(_room("launch_office"))
	_bricks.commit(self, "Scenery")
	_ui_layer = CanvasLayer.new()
	add_child(_ui_layer)
	_hud = FacilityHud.new()
	_ui_layer.add_child(_hud)
	GameState.design_changed.connect(_on_design_changed)
	GameState.budget_changed.connect(func(_b: float) -> void: _on_design_changed())
	_on_design_changed()
	_snap_camera()
	_apply_cmdline.call_deferred()


# --- Input ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var dir := Vector3.ZERO
	if _overlay == null:
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
			dir.z -= 1.0
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
			dir.z += 1.0
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
			dir.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
			dir.x += 1.0
	dir = dir.normalized()
	_player.velocity = dir * WALK_SPEED
	_player.move_and_slide()
	_player.position.y = 0.0
	if dir != Vector3.ZERO:
		_player_mesh.rotation.y = lerp_angle(_player_mesh.rotation.y, atan2(dir.x, dir.z), minf(1.0, delta * 12.0))
	var target := _player.position + CAMERA_OFFSET
	_camera.position = _camera.position.lerp(target, minf(1.0, delta * 5.0))
	_camera.look_at(_camera.position - CAMERA_OFFSET + Vector3(0, 1.0, -1.0), Vector3.UP)
	if _held.has("node"):
		(_held["node"] as Node3D).position = _player.position + Vector3(0, 2.3 + sin(Time.get_ticks_msec() / 300.0) * 0.06, 0)
	_update_hover()
	_update_prompt()


func _process(delta: float) -> void:
	_animate_tunnel(delta)
	_blink_t += delta
	if _blink_t > 0.25:
		_blink_t = 0.0
		for m in _blinkers:
			if randf() < 0.3:
				m.emission_enabled = not m.emission_enabled
	for reel in _reels:
		reel.rotation.z += delta * (2.0 if randf() < 0.9 else -4.0)


func _unhandled_input(event: InputEvent) -> void:
	if _overlay != null:
		return
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed:
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			_on_click(_pick_at(mouse.position))
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
	if key.keycode == KEY_E:
		var target := _nearest_interactable()
		if not target.is_empty():
			interact(str(target["id"]))
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_ESCAPE and not _held.is_empty():
		_drop_held()


# --- Interactions --------------------------------------------------------------------

func interact(id: String) -> void:
	match id:
		"dot":
			var dialogue := DotDialogue.new()
			_open_overlay(dialogue, "dot")
			dialogue.start(DotDialogue.lines_for(session.report, session.total_cost(session.design),
					session.budget_limit(), DataLoader.raw.get("dot_lines", {})))
			StoryTriggers.fire("talked_to_dot", {"stars": int(session.report.get("stars", 0))})
		"keypunch":
			var keypunch := Keypunch.new()
			keypunch.session = session
			_open_overlay(keypunch, "keypunch")
			StoryTriggers.fire("used_keypunch")
		"wind_tunnel":
			_start_tunnel()
			StoryTriggers.fire("ran_wind_tunnel", {"margin_cal": _tunnel_margin})
		"launch":
			_request_launch()


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
	var node := RocketModel.part_piece(part, preset, _preset_scale(DataLoader.presets.get(part, {})), SHELF_PIECE_SIZE * 0.8)
	add_child(node)
	_held = {"part": part, "id": id, "node": node}
	_hud.set_holding(str((_cfg.get("prompts", {}) as Dictionary).get("holding", "%s")) % str(preset.get("label", id)))


func _drop_held() -> void:
	if _held.has("node"):
		(_held["node"] as Node3D).queue_free()
	_held = {}
	if _hud != null:
		_hud.set_holding("")


func _within_reach(at: Vector3) -> bool:
	return Vector2(at.x - _player.position.x, at.z - _player.position.z).length() <= CLICK_RANGE


func _nearest_interactable() -> Dictionary:
	var best: Dictionary = {}
	var best_d := INTERACT_RANGE
	for item: Dictionary in _interactables:
		var p: Vector3 = item["position"]
		var d := Vector2(p.x - _player.position.x, p.z - _player.position.z).length()
		if d <= best_d:
			best_d = d
			best = item
	return best


func _update_prompt() -> void:
	if _overlay != null:
		_hud.set_prompt("")
		return
	var target := _nearest_interactable()
	_hud.set_prompt(str(target.get("prompt", "")))


func _update_hover() -> void:
	if _overlay != null:
		_hud.show_hover("", Vector2.ZERO)
		return
	var mouse := get_viewport().get_mouse_position()
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


# --- Overlays ------------------------------------------------------------------------

func _open_overlay(control: Control, kind: String) -> void:
	_close_overlay()
	_overlay = control
	_overlay_kind = kind
	_drop_held()
	control.tree_exited.connect(func() -> void:
		if _overlay == control:
			_overlay = null
			_overlay_kind = "")
	_ui_layer.add_child(control)


func _close_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_overlay_kind = ""


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


# --- World building ------------------------------------------------------------------

func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("142a29")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("f2e8cf")
	e.ambient_light_energy = 0.3
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, 28, 0)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = 50.0
	add_child(_camera)
	_camera.make_current()


func _build_rooms() -> void:
	var depth := float(_cfg.get("room_depth_m", 14.0))
	var door := float(_cfg.get("door_width_m", 4.0))
	var height := float(_cfg.get("wall_height_m", 3.2))
	var half := depth / 2.0
	for i in _rooms.size():
		var room: Dictionary = _rooms[i]
		var x0 := float(room["x_min"])
		var x1 := float(room["x_max"])
		var w := x1 - x0
		var cx := (x0 + x1) / 2.0
		var wall_color := Color(str(room.get("wall", "8fc1b5")))
		# Studded baseplate floor in ~2 m checker tiles of plates (top of the plates at y = 0).
		var floor_color := Color(str(room.get("floor", "d8c9a8")))
		var tiles_x := maxi(1, roundi(w / 2.0))
		var tiles_z := maxi(1, roundi(depth / 2.0))
		for tx in tiles_x:
			for tz in tiles_z:
				var tile := Vector3(w / tiles_x, 0.16, depth / tiles_z)
				var at := Vector3(x0 + tile.x * (tx + 0.5), -0.08, -half + tile.z * (tz + 0.5))
				_bricks.add_box(at, tile, floor_color.darkened(0.08) if (tx + tz) % 2 == 1 else floor_color)
		_box(Vector3(cx, height / 2.0, -half), Vector3(w, height, 0.3), wall_color, true)    # back wall
		_box(Vector3(cx, 0.25, half), Vector3(w, 0.5, 0.3), wall_color.darkened(0.2), true)  # front kerb
		if i == 0:
			_box(Vector3(x0, height / 2.0, 0), Vector3(0.3, height, depth), wall_color, true)
		var right_color := wall_color
		if i == _rooms.size() - 1:
			_box(Vector3(x1, height / 2.0, 0), Vector3(0.3, height, depth), right_color, true)
		else:
			var seg := (depth - door) / 2.0
			_box(Vector3(x1, height / 2.0, -half + seg / 2.0), Vector3(0.3, height, seg), right_color, true)
			_box(Vector3(x1, height / 2.0, half - seg / 2.0), Vector3(0.3, height, seg), right_color, true)
		# Room sign above the back wall.
		var sign := _label(str(room.get("name", "")), Vector3(cx, height + 0.5, -half + 0.2), 160)
		sign.modulate = Color("fbf5e6")
		# Entry trigger.
		var area := Area3D.new()
		area.collision_layer = 0
		area.collision_mask = 1
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(w - 0.4, 3.0, depth)
		shape.shape = box
		area.add_child(shape)
		area.position = Vector3(cx, 1.5, 0)
		area.body_entered.connect(_on_room_body_entered.bind(str(room["id"])))
		add_child(area)


func _on_room_body_entered(body: Node3D, room_id: String) -> void:
	if body != _player or room_id == _room_id:
		return
	_room_id = room_id
	var room := _room(room_id)
	_hud.set_room(str(room.get("name", "")), str(room.get("subtitle", "")))
	StoryTriggers.enter_area(room_id)


func _build_player() -> void:
	_player = CharacterBody3D.new()
	_player.collision_layer = 1
	_player.collision_mask = 1
	_player.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.7
	shape.shape = capsule
	shape.position.y = 0.85
	_player.add_child(shape)
	_player_mesh = Node3D.new()
	_player.add_child(_player_mesh)
	_mini_figure(_player_mesh, Color("2a7b7b"), Color("e9c46a"))
	var spawn: Dictionary = _cfg.get("spawn", {})
	_player.position = Vector3(float(spawn.get("x", 4.0)), 0, float(spawn.get("z", 3.0)))
	add_child(_player)


## A toy-brick person: block legs, torso, round head.
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


func _snap_camera() -> void:
	_camera.position = _player.position + CAMERA_OFFSET
	_camera.look_at(_player.position + Vector3(0, 1.0, -1.0), Vector3.UP)


# --- Design Bay ----------------------------------------------------------------------

func _build_design_bay(room: Dictionary) -> void:
	var x0 := float(room.get("x_min", 0.0))
	var x1 := float(room.get("x_max", 18.0))
	var half := float(_cfg.get("room_depth_m", 14.0)) / 2.0
	var bench_pos := Vector3((x0 + x1) / 2.0 - 1.0, 0, -1.0)
	_box(bench_pos + Vector3(0, 0.45, 0), Vector3(3.4, 0.9, 1.8), Color("8c6a4a"), true)
	_box(bench_pos + Vector3(0, 0.93, 0), Vector3(3.6, 0.06, 2.0), Color("6b4f36"), false)
	_bench_rocket = RocketModel.new()
	_bench_rocket.model_height = 3.6
	_bench_rocket.position = bench_pos + Vector3(0, 0.96, 0)
	add_child(_bench_rocket)
	_bench_pick = StaticBody3D.new()
	_bench_pick.collision_layer = 1 << (PICK_LAYER_BIT - 1)
	_bench_pick.collision_mask = 0
	_bench_pick.set_meta("pick", {"type": "rocket"})
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	_bench_pick.add_child(shape)
	_bench_pick.position = _bench_rocket.position
	add_child(_bench_pick)
	_label("WORKBENCH", bench_pos + Vector3(0, 0.5, 0.95), 70)

	# Shelves along the back wall, one rack per part type.
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
			add_child(piece)
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
			add_child(body)
			var label := _label("", Vector3(px, 0.72, z + 0.6), 34)
			_shelf_items.append({"part": part, "id": id, "preset": table[id], "node": piece, "label": label})

	# Dot: chief engineer, at her desk with eight mugs.
	var dot_pos := Vector3(x1 - 2.2, 0, 1.0)
	_box(dot_pos + Vector3(0.9, 0.4, -0.2), Vector3(1.4, 0.8, 1.0), Color("6b4f36"), true)
	for m in 8:
		var mug_color: Color = [Color("c8551f"), Color("fbf5e6"), Color("e9c46a"), Color("2a7b7b")][m % 4]
		_bricks.add_cylinder(dot_pos + Vector3(0.4 + (m % 4) * 0.3, 0.87, -0.5 + (m / 4) * 0.45), 0.07, 0.14, mug_color, 0.14)
	var dot := Node3D.new()
	dot.position = dot_pos
	dot.rotation.y = -0.4
	add_child(dot)
	_mini_figure(dot, Color("c8551f"), Color("8c5a3c"))
	var dot_name := _label("DOT", dot_pos + Vector3(0, 2.25, 0), 70)
	dot_name.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_interactables.append({"id": "dot", "position": dot_pos, "prompt": str((_cfg.get("prompts", {}) as Dictionary).get("dot", "[E]"))})


func _refresh_shelf_labels() -> void:
	for item: Dictionary in _shelf_items:
		var option := session.part_option(str(item["part"]), str(item["id"]))
		var label: Label3D = item["label"]
		# Short tag only (racks are narrow); the name and story are in the hover card.
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


# --- Wind Tunnel ---------------------------------------------------------------------

func _build_wind_tunnel(room: Dictionary) -> void:
	var x0 := float(room.get("x_min", 18.0))
	var x1 := float(room.get("x_max", 32.0))
	var cx := (x0 + x1) / 2.0
	var z := -3.0
	var length := x1 - x0 - 3.0
	var glass := _mesh_box(Vector3(length, 2.4, 2.6), Color(0.7, 0.9, 0.95, 0.18))
	glass.position = Vector3(cx, 1.5, z)
	add_child(glass)
	_box(Vector3(cx, 0.15, z), Vector3(length, 0.3, 2.8), Color("4d5b63"), true)
	_box(Vector3(cx, 2.75, z), Vector3(length, 0.1, 2.8), Color("4d5b63"), false)
	_box(Vector3(cx, 1.5, z - 1.35), Vector3(length, 2.6, 0.1), Color("4d5b63"), true)
	# Fan housing at the tail end.
	_tunnel_fan = Node3D.new()
	_tunnel_fan.position = Vector3(x1 - 1.4, 1.5, z)
	add_child(_tunnel_fan)
	for b in 4:
		var blade := _mesh_box(Vector3(0.08, 2.0, 0.35), Color("2b2622"))
		blade.rotation.x = TAU * b / 4.0
		_tunnel_fan.add_child(blade)
	for i in 6:
		var streak := _mesh_box(Vector3(0.9, 0.03, 0.03), Color(1, 1, 1, 0.6))
		streak.position = Vector3(x0 + 2.0 + i * 1.6, 0.8 + (i % 3) * 0.6, z + (float(i % 2) - 0.5) * 1.4)
		streak.visible = false
		add_child(streak)
		_tunnel_streaks.append(streak)
	_tunnel_pivot = Node3D.new()
	_tunnel_pivot.position = Vector3(cx - 0.5, 1.5, z)
	add_child(_tunnel_pivot)
	var stand := _mesh_box(Vector3(0.08, 1.2, 0.08), Color("8c8577"))
	stand.position = Vector3(cx - 0.5, 0.9, z)
	add_child(stand)
	var holder := Node3D.new()
	holder.rotation.z = PI / 2.0     # model's +y (nose) points along -x, into the wind
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
	_interactables.append({"id": "wind_tunnel", "position": desk, "prompt": str((_cfg.get("prompts", {}) as Dictionary).get("wind_tunnel", "[E]"))})


## Puts the model's centre of mass on the pivot (the sting holds it at its CG).
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


## steady / wobbly / stiff / tumbles, from the static margin (Stability thresholds).
static func tunnel_verdict(margin: float) -> String:
	if margin < 0.0:
		return "tumbles"
	if margin < Stability.MARGIN_STABLE_MIN:
		return "wobbly"
	if margin > Stability.MARGIN_OVER_STABLE:
		return "stiff"
	return "steady"


## A damped pendulum whose restoring stiffness is the static margin: a positive margin
## pulls the nose back into the wind, a negative one pushes it away (it tumbles).
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


# --- Computer Room -------------------------------------------------------------------

func _build_computer_room(room: Dictionary) -> void:
	var x0 := float(room.get("x_min", 32.0))
	var x1 := float(room.get("x_max", 48.0))
	var half := float(_cfg.get("room_depth_m", 14.0)) / 2.0
	var cabinets := 6
	var step := (x1 - x0 - 2.0) / cabinets
	for c in cabinets:
		var cx := x0 + 1.0 + step * (c + 0.5)
		var pos := Vector3(cx, 1.1, -half + 0.8)
		_box(pos, Vector3(step - 0.25, 2.2, 0.9), Color("8fa3ad") if c % 2 == 0 else Color("6f8590"), true)
		if c % 3 == 1:
			for r in 2:
				var reel := Node3D.new()
				reel.position = Vector3(cx + (r - 0.5) * 0.6, 1.5, -half + 1.27)
				# Reel: a round 2x2-style plate standing on edge, studs facing the room.
				var disc := BrickKit.new(0.13)
				disc.xform = Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO)
				disc.add_cylinder(Vector3.ZERO, 0.26, 0.05, Color("2b2622"))
				disc.commit(reel, "Disc")
				var spoke := _mesh_box(Vector3(0.5, 0.05, 0.07), Color("d9a42b"))
				spoke.position.z = 0.04
				reel.add_child(spoke)
				add_child(reel)
				_reels.append(reel)
		else:
			for i in 12:
				var light := BrickKit.single("plate1", Vector3(0.12, 0.04, 0.12), Color("3a3326"))
				var m := RocketModel.mat(Color("3a3326"))
				m.emission = Color("ffcf5a")
				m.emission_energy_multiplier = 2.0
				m.emission_enabled = randf() < 0.4
				light.material_override = m
				light.rotation.x = PI / 2.0
				light.position = Vector3(cx - 0.3 + (i % 4) * 0.2, 1.4 + (i / 4) * 0.22, -half + 1.27)
				add_child(light)
				_blinkers.append(m)
	# Keypunch desk.
	var desk := Vector3((x0 + x1) / 2.0, 0, 0.5)
	_box(desk + Vector3(0, 0.42, 0), Vector3(2.4, 0.84, 1.1), Color("c9c2b0"), true)
	_box(desk + Vector3(0.2, 1.05, -0.2), Vector3(1.2, 0.42, 0.6), Color("4d5b63"), false)
	_box(desk + Vector3(-0.75, 0.95, 0.1), Vector3(0.45, 0.22, 0.3), Color("f3e9c6"), false)
	_label("KEYPUNCH", desk + Vector3(0, 1.0, 0.57), 50)
	_interactables.append({"id": "keypunch", "position": desk, "prompt": str((_cfg.get("prompts", {}) as Dictionary).get("keypunch", "[E]"))})


# --- Launch Office -------------------------------------------------------------------

func _build_launch_office(room: Dictionary) -> void:
	var x0 := float(room.get("x_min", 48.0))
	var x1 := float(room.get("x_max", 62.0))
	var half := float(_cfg.get("room_depth_m", 14.0)) / 2.0
	var cx := (x0 + x1) / 2.0
	# Pad diorama: a scale model of the rocket on its launch stand.
	var pad := Vector3(cx - 2.5, 0, -half + 2.4)
	_box(pad + Vector3(0, 0.4, 0), Vector3(2.6, 0.8, 2.6), Color("8c8577"), true)
	_box(pad + Vector3(0.9, 2.2, -0.6), Vector3(0.25, 2.8, 0.25), Color("c0392b"), false)
	_office_rocket = RocketModel.new()
	_office_rocket.model_height = 3.6
	_office_rocket.position = pad + Vector3(0, 0.8, 0)
	add_child(_office_rocket)
	_label("PAD 5 (SCALE MODEL)", pad + Vector3(0, 0.5, 1.32), 50)
	var console := Vector3(cx + 2.5, 0, -1.0)
	_box(console + Vector3(0, 0.5, 0), Vector3(2.6, 1.0, 1.2), Color("4d5b63"), true)
	_box(console + Vector3(0, 1.25, -0.45), Vector3(2.6, 0.6, 0.2), Color("2b2622"), false)
	_bricks.add_cylinder(console + Vector3(0, 1.05, 0.1), 0.17, 0.1, Color("c0392b"), 0.3)
	_label("LAUNCH REQUEST  >>  MISSION CONTROL", console + Vector3(0, 1.0, 0.62), 46)
	_interactables.append({"id": "launch", "position": console, "prompt": str((_cfg.get("prompts", {}) as Dictionary).get("launch", "[E]"))})


# --- Helpers -------------------------------------------------------------------------

func _room(id: String) -> Dictionary:
	for room: Dictionary in _rooms:
		if str(room["id"]) == id:
			return room
	return {}


## A free-standing brick-built box (its own node, for parts that move or hide).
## Translucent colours give clear "glass" bricks.
func _mesh_box(size: Vector3, color: Color) -> Node3D:
	var kit := BrickKit.new(clampf(minf(size.x, size.z), 0.05, 0.4))
	kit.add_box(Vector3.ZERO, size, color)
	return kit.commit(null, "BrickBox")


## Plain box for the placeholder mini-figures (characters stay un-bricked).
func _figure_box(size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = RocketModel.mat(color)
	return mi


## A coloured brick-built box in the static scenery; `solid` boxes also block the player.
func _box(center: Vector3, size: Vector3, color: Color, solid: bool) -> void:
	_bricks.add_box(center, size, color)
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
		add_child(body)


func _label(text: String, at: Vector3, font_size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = ConsoleTheme.typewriter()
	label.font_size = font_size
	label.pixel_size = 0.005
	label.outline_size = 10
	label.outline_modulate = Color("2b2622")
	label.position = at
	label.rotation.x = -0.35
	add_child(label)
	return label


# --- Debug / tests -------------------------------------------------------------------

func _apply_cmdline() -> void:
	var screenshot := ""
	var selftest := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--room="):
			var wanted := arg.trim_prefix("--room=")
			var targets := {"design_bay": "dot", "wind_tunnel": "wind_tunnel", "computer_room": "keypunch", "launch_office": "launch"}
			for item: Dictionary in _interactables:
				if item["id"] == targets.get(wanted, ""):
					_player.position = (item["position"] as Vector3) + Vector3(-1.2 if wanted == "design_bay" else 0.0, 0, 1.6)
					if wanted == "design_bay":
						_player.position = Vector3(float(_room(wanted).get("x_min", 0)) + 7.5, 0, 2.5)
			_snap_camera()
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
	if selftest:
		for i in 5:
			await get_tree().physics_frame
		_run_selftest()
	if screenshot != "":
		for i in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var err := image.save_png(screenshot)
		print("Facility: screenshot -> %s (%s)" % [screenshot, error_string(err)])
		get_tree().quit()


func _run_selftest() -> void:
	var failures: PackedStringArray = []
	var expect := func(ok: bool, what: String) -> void:
		print("  [%s] %s" % ["ok" if ok else "FAIL", what])
		if not ok:
			failures.append(what)
	print("FACILITY SELFTEST")
	expect.call(_shelf_items.size() >= 12, "shelves hold every preset (%d pieces)" % _shelf_items.size())
	expect.call(_bench_rocket.brick_count() > 3, "bench rocket model built (%d bricks)" % _bench_rocket.brick_count())
	expect.call(StoryTriggers.has_visited("design_bay") and _room_id == "design_bay", "enter_area fired for %s" % _room_id)

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
	interact("launch")
	print("  launch notice: %s" % _hud.notice_text())
	print("FACILITY SELFTEST %s" % ("PASS" if failures.is_empty() else "FAIL: " + ", ".join(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)
