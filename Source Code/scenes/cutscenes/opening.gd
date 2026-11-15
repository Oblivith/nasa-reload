# SI assistance metadata: This code used the help of SI.
extends Control

const BG := Color("0a0e16")
const TEXT := Color("f2e8cf")

var _cfg: Dictionary = {}
var _stars: StarField
var _memory: MemoryStage
var _label: Label
var _title: Label
var _rule: ColorRect
var _hint: Label
var _fade: ColorRect
var _sfx: AudioStreamPlayer
var _box: StoryDialogueBox = null
var _advance: bool = false
var _skipped: bool = false
var _selftest: bool = false
var _shot_beat: int = -1
var _shot_path: String = ""
var _log: PackedStringArray = []

func _ready() -> void:
	_cfg = Story.flow.get("opening", {})
	for arg in OS.get_cmdline_user_args():
		if arg == "--selftest":
			_selftest = true
		elif arg.begins_with("--beat="):
			_shot_beat = int(arg.trim_prefix("--beat="))
		elif arg.begins_with("--screenshot="):
			_shot_path = arg.trim_prefix("--screenshot=")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_stars = StarField.new()
	_stars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stars)
	_memory = MemoryStage.new()
	_memory.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_memory.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_memory.visible = false
	add_child(_memory)

	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.anchor_left = 0.5
	_label.anchor_right = 0.5
	_label.anchor_top = 0.5
	_label.anchor_bottom = 0.5
	_label.offset_left = -700
	_label.offset_right = 700
	_label.offset_top = -160
	_label.offset_bottom = 160
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_override("font", ConsoleTheme.typewriter())
	_label.add_theme_font_size_override("font_size", 44)
	_label.add_theme_color_override("font_color", TEXT)
	_label.add_theme_constant_override("line_spacing", 14)
	add_child(_label)

	_title = Label.new()
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", ConsoleTheme.typewriter())
	_title.add_theme_font_size_override("font_size", 120)
	_title.add_theme_color_override("font_color", TEXT)
	_title.modulate.a = 0.0
	add_child(_title)
	_rule = ColorRect.new()
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rule.color = ConsoleTheme.MUSTARD
	_rule.anchor_left = 0.5
	_rule.anchor_right = 0.5
	_rule.anchor_top = 0.5
	_rule.anchor_bottom = 0.5
	_rule.offset_left = -330
	_rule.offset_right = 330
	_rule.offset_top = 88
	_rule.offset_bottom = 94
	_rule.modulate.a = 0.0
	add_child(_rule)

	_hint = Label.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.text = Story.text("ui.hint_skip_opening")
	_hint.anchor_left = 1.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = -640
	_hint.offset_right = -36
	_hint.offset_top = -58
	_hint.offset_bottom = -24
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", Color(TEXT, 0.45))
	add_child(_hint)

	_fade = ColorRect.new()
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)
	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)
	if _selftest:
		Engine.time_scale = 12.0
	_run()

func _run() -> void:
	await _fade_to(0.0, 1.0)
	var beats: Array = _cfg.get("beats", [])
	for i in beats.size():
		if _skipped:
			break
		var beat: Dictionary = beats[i]
		_log.append("%d %s %s" % [i, str(beat.get("type", "")), str(beat.get("line", beat.get("lines", beat.get("file", ""))))])
		match str(beat.get("type", "")):
			"narrate":
				await _narrate(Story.text(str(beat["line"])), float(beat.get("hold", _cfg.get("hold_seconds", 1.9))), i)
			"stars":
				await _fade_stars(float(beat.get("alpha", 1.0)), float(beat.get("seconds", 1.0)))
			"dialogue":
				await _dialogue(beat, i)
			"sfx":
				_play(str(beat.get("file", "")))
				await _wait(float(beat.get("wait", 1.0)), false)
			"title":
				await _title_card(Story.text(str(beat["line"])), float(beat.get("hold", 3.5)), i)
	await _fade_to(1.0, 0.4 if _skipped else 1.2)
	_finish()

func _finish() -> void:
	Engine.time_scale = 1.0
	GameState.set_flag("opening_seen")
	if _selftest:
		for entry in _log:
			print("  beat " + entry)
		var ok := _skipped or _log.size() == (_cfg.get("beats", []) as Array).size()
		print("OPENING SELFTEST %s (%d beats)" % ["PASS" if ok and not _log.is_empty() else "FAIL", _log.size()])
		get_tree().quit(0 if ok and not _log.is_empty() else 1)
		return
	SceneManager.change_scene(str(_cfg.get("next_scene", "res://scenes/world/facility/facility.tscn")))

func _narrate(line_text: String, hold: float, index: int) -> void:
	_label.text = line_text
	_label.visible_ratio = 0.0
	_label.modulate.a = 1.0
	var total := maxf(1.0, float(line_text.length()))
	var cps := float(_cfg.get("chars_per_second", 30.0))
	var shown := 0.0
	_advance = false
	while shown < total and not _skipped:
		await get_tree().process_frame
		shown += get_process_delta_time() * cps
		if _advance or _selftest:
			shown = total
		_label.visible_ratio = minf(1.0, shown / total)
	_label.visible_ratio = 1.0
	await _maybe_screenshot(index)
	await _wait(hold + line_text.length() * 0.012)
	await _fade_node(_label, 0.0, 0.45)
	_label.text = ""

func _dialogue(beat: Dictionary, index: int) -> void:
	_memory.visible = true
	_box = Story.make_box(Story.lines(beat.get("lines", []), {"auto": float(beat.get("auto", 2.2))}))
	_box.line_shown.connect(_memory.set_dialogue_beat)
	_box.esc_skips_all = false
	_box.set_process_unhandled_key_input(false)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	move_child(_fade, get_child_count() - 1)
	_hint.visible = false
	var box := _box
	if index == _shot_beat:
		await get_tree().create_timer(1.2).timeout
		await _maybe_screenshot(index)
	while is_instance_valid(box) and not box.is_queued_for_deletion():
		await get_tree().process_frame
		if _skipped and is_instance_valid(box):
			box.queue_free()
	_box = null
	_memory.visible = false
	_hint.visible = true

func _title_card(title_text: String, hold: float, index: int) -> void:
	_title.text = title_text
	_hint.visible = false
	await _fade_node(_title, 1.0, 1.4)
	await _fade_node(_rule, 1.0, 0.5)
	await _maybe_screenshot(index)
	await _wait(hold)

func _fade_stars(alpha: float, seconds: float) -> void:
	await _fade_node(_stars, alpha, seconds)

func _fade_to(alpha: float, seconds: float) -> void:
	await _fade_node(_fade, alpha, seconds)

func _fade_node(node: CanvasItem, alpha: float, seconds: float) -> void:
	var from := node.modulate.a
	var t := 0.0
	while t < seconds and not (_skipped and node != _fade):
		await get_tree().process_frame
		t += get_process_delta_time()
		node.modulate.a = lerpf(from, alpha, clampf(t / maxf(seconds, 0.001), 0.0, 1.0))
	node.modulate.a = alpha

func _wait(seconds: float, can_advance: bool = true) -> void:
	var t := 0.0
	_advance = false
	while t < seconds and not _skipped:
		await get_tree().process_frame
		t += get_process_delta_time()
		if can_advance and _advance:
			break
	_advance = false

func _play(file: String) -> void:
	var path := "res://assets/audio/%s.wav" % file
	if file == "" or not ResourceLoader.exists(path):
		return
	_sfx.stream = load(path)
	_sfx.volume_db = -3.0
	_sfx.play()

func _maybe_screenshot(index: int) -> void:
	if index != _shot_beat or _shot_path == "":
		return
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(_shot_path)
	print("Opening: beat %d screenshot -> %s (%s)" % [index, _shot_path, error_string(err)])
	get_tree().quit()

func _next() -> void:
	if _box != null and is_instance_valid(_box):
		_box.advance()
	else:
		_advance = true

func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		_next()
		accept_event()

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var code := key.keycode if key.keycode != KEY_NONE else key.physical_keycode
	if code == KEY_ESCAPE:
		_skipped = true
	elif code == KEY_E or code == KEY_SPACE or code == KEY_ENTER or code == KEY_KP_ENTER or key.physical_keycode == KEY_E:
		_next()
	get_viewport().set_input_as_handled()

class StarField:
	extends Control

	const COUNT := 220
	var _points: Array = []
	var _t: float = 0.0

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1958
		for i in COUNT:
			_points.append([rng.randf(), rng.randf(), rng.randf_range(0.8, 2.4), rng.randf() * TAU, rng.randf_range(0.3, 1.4)])

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		for p: Array in _points:
			var glow := 0.35 + 0.65 * (0.5 + 0.5 * sin(_t * float(p[4]) + float(p[3])))
			draw_circle(Vector2(float(p[0]) * size.x, float(p[1]) * size.y), float(p[2]), Color(0.95, 0.93, 0.85, glow * 0.85))

class MemoryStage:
	extends Control
	var _stage: Node3D
	var _kid: Node3D
	var _dad: Node3D
	var _kid_parts: Dictionary = {}
	var _dad_parts: Dictionary = {}
	var _kid_rest: Dictionary = {}
	var _dad_rest: Dictionary = {}
	var _beat: int = 0
	var _time: float = 0.0

	func _ready() -> void:
		var view := SubViewport.new()
		view.name = "FlashbackCharacterView"
		view.size = Vector2i(1920, 660)
		view.transparent_bg = false
		view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
		var port := SubViewportContainer.new()
		port.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		port.anchor_bottom = 0.61
		port.stretch = true
		port.add_child(view)
		add_child(port)
		_stage = Node3D.new()
		_stage.name = "1958KitchenDiorama"
		view.add_child(_stage)
		var environment := WorldEnvironment.new()
		var world := Environment.new()
		world.background_mode = Environment.BG_COLOR
		world.background_color = Color("665447")
		world.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		world.ambient_light_color = Color("d5c7af")
		world.ambient_light_energy = 0.62
		world.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		world.tonemap_exposure = 1.0
		environment.environment = world
		_stage.add_child(environment)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 3.45
		camera.position = Vector3(0.0, 1.55, 6.7)

		_stage.add_child(camera)
		camera.make_current()
		camera.look_at(Vector3(0.0, 1.05, 0), Vector3.UP)
		var key := DirectionalLight3D.new()
		key.rotation_degrees = Vector3(-39, -22, 0)
		key.light_energy = 1.45
		key.shadow_enabled = true
		_stage.add_child(key)
		var fill := OmniLight3D.new()
		fill.position = Vector3(-2.0, 3.0, 2.5)
		fill.light_color = Color("ffe0ad")
		fill.light_energy = 2.0
		fill.omni_range = 8.0
		_stage.add_child(fill)
		_build_kitchen()
		_kid = _spawn_character("child", Vector3(-1.03, 0.0, 0.0), 0.08)
		_dad = _spawn_character("antagonist", Vector3(1.08, 0.0, -0.12), -0.1)
		_cache_actor(_kid, _kid_parts, _kid_rest)
		_cache_actor(_dad, _dad_parts, _dad_rest)

	func _build_kitchen() -> void:
		_box(_stage, "DioramaFloor", Vector3(5.9, 0.16, 3.4), Vector3(0, -0.1, 0), Color("7f5940"), 0.36)
		_box(_stage, "KitchenWall", Vector3(5.9, 2.9, 0.16), Vector3(0, 1.33, -1.4), Color("52626a"), 0.5)
		_box(_stage, "WallWainscot", Vector3(5.9, 0.54, 0.12), Vector3(0, 0.42, -1.28), Color("35474e"), 0.42)
		_box(_stage, "WindowFrame", Vector3(1.85, 1.12, 0.1), Vector3(-1.28, 1.78, -1.27), Color("bb9862"), 0.28)
		_box(_stage, "WindowGlass", Vector3(1.62, 0.92, 0.05), Vector3(-1.28, 1.78, -1.19), Color("839eaa"), 0.22)
		_box(_stage, "WindowMullionV", Vector3(0.055, 0.92, 0.04), Vector3(-1.28, 1.78, -1.14), Color("e5d4b4"), 0.31)
		_box(_stage, "WindowMullionH", Vector3(1.62, 0.055, 0.04), Vector3(-1.28, 1.78, -1.14), Color("e5d4b4"), 0.31)
		_box(_stage, "DoorFrame", Vector3(0.92, 2.4, 0.1), Vector3(2.06, 1.12, -1.25), Color("c4a16b"), 0.31)
		_box(_stage, "Door", Vector3(0.78, 2.24, 0.07), Vector3(2.06, 1.1, -1.17), Color("42545b"), 0.38)
		_box(_stage, "DoorHandle", Vector3(0.05, 0.05, 0.06), Vector3(1.77, 1.08, -1.1), Color("e9c46a"), 0.22)
		_box(_stage, "TableTop", Vector3(3.45, 0.14, 0.72), Vector3(0.05, 0.64, 0.53), Color("9b7651"), 0.34)
		for x in [-1.45, 1.55]:
			for z in [0.28, 0.78]:
				_box(_stage, "TableLeg", Vector3(0.12, 0.62, 0.12), Vector3(x, 0.31, z), Color("71553d"), 0.4)
		for x in range(15):
			var stud := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.037
			cylinder.bottom_radius = 0.037
			cylinder.height = 0.025
			cylinder.radial_segments = 20
			stud.mesh = cylinder
			stud.position = Vector3(-1.55 + x * 0.22, 0.725, 0.53)
			stud.material_override = _plastic(Color("a7825d"), 0.3)
			_stage.add_child(stud)
		_box(_stage, "ScienceFairBoard", Vector3(0.9, 0.72, 0.06), Vector3(-2.0, 1.2, 0.44), Color("e4dec9"), 0.66)
		_box(_stage, "ScienceFairPhoto", Vector3(0.43, 0.34, 0.025), Vector3(-1.97, 1.28, 0.39), Color("617b87"), 0.62)
		_box(_stage, "RocketBody", Vector3(0.16, 0.48, 0.16), Vector3(-0.02, 1.02, 0.42), Color("d1d5cd"), 0.24)
		_box(_stage, "RocketNose", Vector3(0.16, 0.12, 0.16), Vector3(-0.02, 1.32, 0.42), Color("c8551f"), 0.24)
		_box(_stage, "RocketFinL", Vector3(0.055, 0.16, 0.22), Vector3(-0.12, 0.88, 0.42), Color("2d5665"), 0.3)
		_box(_stage, "RocketFinR", Vector3(0.055, 0.16, 0.22), Vector3(0.08, 0.88, 0.42), Color("2d5665"), 0.3)

	func _spawn_character(role: String, at: Vector3, yaw: float) -> Node3D:
		var packed := load("res://assets/models/characters/%s.glb" % role) as PackedScene
		if packed == null:
			return null
		var figure := packed.instantiate() as Node3D
		figure.position = at
		figure.rotation.y = yaw
		_stage.add_child(figure)
		return figure

	func _cache_actor(actor: Node3D, parts: Dictionary, rest: Dictionary) -> void:
		if actor == null:
			return
		for key in [&"Torso", &"Head", &"ArmL", &"ArmR", &"LegL", &"LegR"]:
			var node := actor.find_child(String(key), true, false) as Node3D
			if node != null:
				parts[key] = node
				rest[key] = node.transform

	func _pose_actor(parts: Dictionary, rest: Dictionary, key: StringName, euler: Vector3) -> void:
		var node := parts.get(key) as Node3D
		if node != null:
			var base: Transform3D = rest.get(key, Transform3D.IDENTITY)
			node.transform = base * Transform3D(Basis.from_euler(euler), Vector3.ZERO)

	func set_dialogue_beat(index: int, _line: Dictionary) -> void:
		_beat = index

	func _process(delta: float) -> void:
		_time += delta
		var breath := sin(_time * 1.8)
		var hurt := 1.0 if _beat == 0 or _beat == 2 or _beat == 4 else 0.0
		var father := 1.0 if _beat == 1 or _beat == 3 else 0.0
		_kid.position.x = lerpf(_kid.position.x, -1.03 - hurt * 0.025, minf(1.0, delta * 2.0))
		_dad.rotation.y = lerp_angle(_dad.rotation.y, -0.1 - father * 0.16, minf(1.0, delta * 2.0))
		_pose_actor(_kid_parts, _kid_rest, &"Torso", Vector3(0.025 + hurt * 0.035 + breath * 0.008, 0.0, sin(_time * 0.8) * 0.012))
		_pose_actor(_kid_parts, _kid_rest, &"Head", Vector3(0.06 + hurt * 0.08, sin(_time * 0.55) * 0.06, 0.0))
		_pose_actor(_kid_parts, _kid_rest, &"ArmL", Vector3(-0.12 - hurt * 0.16, 0.0, 0.08))
		_pose_actor(_kid_parts, _kid_rest, &"ArmR", Vector3(-0.1 - hurt * 0.1, 0.0, -0.08))
		_pose_actor(_dad_parts, _dad_rest, &"Torso", Vector3(-father * 0.035 + breath * 0.006, 0.0, -father * 0.012))
		_pose_actor(_dad_parts, _dad_rest, &"Head", Vector3(-father * 0.1 + sin(_time * 0.7) * 0.02, 0.0, 0.0))
		_pose_actor(_dad_parts, _dad_rest, &"ArmR", Vector3(-father * 0.72, 0.0, -father * 0.1))
		_pose_actor(_dad_parts, _dad_rest, &"ArmL", Vector3(-father * 0.24, 0.0, father * 0.06))

	func _box(parent: Node3D, label: String, dimensions: Vector3, at: Vector3, color: Color, roughness: float) -> void:
		var mesh := BoxMesh.new()
		mesh.size = dimensions
		var item := MeshInstance3D.new()
		item.name = label
		item.mesh = mesh
		item.position = at
		item.material_override = _plastic(color, roughness)
		parent.add_child(item)

	func _plastic(color: Color, roughness: float) -> StandardMaterial3D:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = roughness
		material.metallic = 0.0
		material.metallic_specular = 0.28
		material.clearcoat_enabled = true
		material.clearcoat = 0.12
		return material

