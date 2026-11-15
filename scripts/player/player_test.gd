# Code generated with AI assistance (Claude). Reviewed by team.
extends Node3D
## Test room for the player package (scenes/player/player_test.tscn). Not part of the
## game: a high room, a narrow corridor, a closet, stairs to a mezzanine and a ramp,
## with dummy interactables that exercise every kind of Interactable:
##
##   Shelf        CAMERA_POINT shot, mouse freed, E / Esc to step back
##   Keypunch     OVER_SHOULDER shot, stand point, "type" pose, held by a UI overlay
##   Dot (NPC)    TWO_SHOT, "talk" pose, glances at the player
##   Door         locked ("Locked", jiggles) until the buzzer is pressed, then opens
##   Buzzer, notice board   instant use (no camera move)
##
## All text here is test filler; real prompts come from /data through the world scenes.
##
## Run:  godot --path . scenes/player/player_test.tscn
## Debug: `-- [--selftest] [--at=<spot>] [--use] [--walk] [--sprint] [--left]
##          [--yaw=<deg>] [--pitch=<deg>] [--readout] [--bench=<seconds>] [--screenshot=<png>]`
## F3 toggles the readout.

const PLAYER_SCENE := "res://scenes/player/Player.tscn"

const CREAM := Color("f2e8cf")
const TEAL := Color("2a7b7b")
const TEAL_LIGHT := Color("8fc1b5")
const MUSTARD := Color("d9a42b")
const ORANGE := Color("c8551f")
const WOOD := Color("8c6a4a")
const WOOD_DARK := Color("6b4f36")
const LINO := Color("c9c2a8")
const STEEL := Color("7d8a8f")
const INK := Color("2b2622")

## Named places to stand: [position, facing].
const SPOTS := {
	"start": [Vector3(0, 0, 1.0), Vector3(0, 0, -1)],
	"shelf": [Vector3(-2.2, 0, -2.9), Vector3(0, 0, -1)],
	"terminal": [Vector3(2.9, 0, -2.6), Vector3(-0.15, 0, -1)],
	"npc": [Vector3(2.6, 0, 2.3), Vector3(1, 0, 0)],
	"door": [Vector3(-2.0, 0, 3.4), Vector3(0, 0, 1)],
	"corridor": [Vector3(9.5, 0, 0), Vector3(-1, 0, 0)],
	"closet": [Vector3(13.6, 0, 0.2), Vector3(-1, 0, 0)],
	"stairs": [Vector3(-5.2, 0, 3.9), Vector3(0, 0, -1)],
	"ramp": [Vector3(0.4, 0, 4.25), Vector3(1, 0, 0)],
	"wall": [Vector3(0, 0, 4.5), Vector3(0, 0, -1)],
}

var _player: Player
var _materials: Dictionary = {}
var _ui: CanvasLayer
var _message: Label
var _readout: Label
var _message_left: float = 0.0

var _shelf: Interactable
var _terminal: Interactable
var _dot: Interactable
var _dot_figure: BrickFigure
var _door: Interactable
var _door_slab: Node3D
var _door_open: bool = false
var _buzzer: Interactable
var _notice: Interactable
var _overlay: Control = null

var _log: Dictionary = {"used": [], "denied": [], "ended": [], "surfaces": {}, "steps": 0}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_build_environment()
	_build_rooms()
	_build_stairs_and_ramp()
	_build_shelf()
	_build_terminal()
	_build_dot()
	_build_door()
	_build_notice()
	_build_ui()

	_player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	var spawn: Array = SPOTS["start"]
	_player.position = spawn[0]
	for arg in args:
		if arg == "--selftest" or arg.begins_with("--screenshot="):
			_player.capture_mouse = false
	add_child(_player)
	_player.footstep.connect(func(surface: StringName, _running: bool) -> void:
		_log["steps"] = int(_log["steps"]) + 1
		_log["surfaces"][surface] = true)
	_player.interaction_ended.connect(func(it: Interactable) -> void: (_log["ended"] as Array).append(it))
	_apply_cmdline.call_deferred(args)


func _process(delta: float) -> void:
	# Dot glances at the player when they come close.
	if _dot_figure != null and _player != null:
		if _dot_figure.global_position.distance_to(_player.global_position) < 5.0:
			_dot_figure.look_at_point(_player.head_position())
		else:
			_dot_figure.clear_look()
	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			_message.get_parent().visible = false
	if _readout.visible:
		var cam := _player.camera_rig
		var focus := _player.focused()
		_readout.text = "speed %.1f m/s%s\nboom %.2f m   room openness %.2f\nshoulder %s   fov %.0f\nfocus: %s\nfps %d" % [
				_player.figure.animator.speed, "  SPRINT" if _player.sprinting else "",
				cam.boom_length(), cam.openness(), "right" if cam.shoulder_side > 0.0 else "left", cam.camera.fov,
				focus.prompt if focus != null else "-", Engine.get_frames_per_second()]


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F3:
		_readout.visible = not _readout.visible


func say(text: String, seconds: float = 4.0) -> void:
	_message.text = text
	_message.get_parent().visible = true
	_message_left = seconds


# --- Interactables ---------------------------------------------------------------------

func _build_shelf() -> void:
	var at := Vector3(-2.2, 0, -4.72)
	var body := _solid(at + Vector3(0, 1.05, 0), Vector3(2.5, 2.1, 0.5), WOOD_DARK)
	body.get_child(0).visible = false       # collider only; the visible shelf is built below
	_deco(at + Vector3(0, 1.05, -0.22), Vector3(2.5, 2.1, 0.06), WOOD_DARK)
	for side: float in [-1.0, 1.0]:
		_deco(at + Vector3(1.22 * side, 1.05, 0), Vector3(0.06, 2.1, 0.5), WOOD)
	var colors := [CREAM, MUSTARD, TEAL_LIGHT, ORANGE, TEAL, STEEL]
	for row in 4:
		var y := 0.08 + row * 0.62
		_deco(at + Vector3(0, y, 0), Vector3(2.4, 0.06, 0.48), WOOD)
		if row == 3:
			continue
		for col in 5:
			var color: Color = colors[(row * 2 + col) % colors.size()]
			var x := -0.92 + col * 0.46
			if (row + col) % 2 == 0:
				_deco(at + Vector3(x, y + 0.2, 0.02), Vector3(0.3, 0.34, 0.3), color)
			else:
				var cyl := MeshInstance3D.new()
				var mesh := CylinderMesh.new()
				mesh.top_radius = 0.11
				mesh.bottom_radius = 0.14
				mesh.height = 0.4
				cyl.mesh = mesh
				cyl.material_override = _mat(color)
				cyl.position = at + Vector3(x, y + 0.23, 0.02)
				add_child(cyl)
	_sign("PARTS", at + Vector3(0, 2.3, 0.05), 64)

	var camera_point := Marker3D.new()
	camera_point.position = Vector3(0, 0.2, 2.85)
	body.add_child(camera_point)
	var look_point := Marker3D.new()
	look_point.position = Vector3(0, 0.0, 0)
	body.add_child(look_point)
	_shelf = Interactable.new()
	_shelf.name = "ShelfInteractable"
	_shelf.prompt = "Browse shelf"
	_shelf.position = Vector3(0, -1.05, 0.25)
	_shelf.focus_offset = Vector3(0, 1.1, 0)
	_shelf.prompt_offset = Vector3(0, 0.5, 0)
	_shelf.framing = Interactable.Framing.CAMERA_POINT
	_shelf.camera_point = camera_point
	_shelf.look_point = look_point
	_shelf.shot_fov = 50.0
	_shelf.hide_player = true
	body.add_child(_shelf)
	_shelf.used.connect(func(_p: Player) -> void:
		(_log["used"] as Array).append(_shelf)
		say("Shelf view: the mouse is free to click parts here.  E / Esc steps back."))


func _build_terminal() -> void:
	var at := Vector3(2.5, 0, -4.45)
	var body := _solid(at + Vector3(0, 0.39, 0), Vector3(1.8, 0.78, 0.85), Color("c9c2b0"))
	_deco(at + Vector3(0, 0.8, 0), Vector3(1.86, 0.05, 0.9), Color("b3ab97"))
	_deco(at + Vector3(0.15, 1.03, -0.12), Vector3(1.0, 0.42, 0.55), Color("4d5b63"))
	_deco(at + Vector3(0.15, 1.3, -0.2), Vector3(0.7, 0.12, 0.3), Color("3d484e"))
	var keys := _deco(at + Vector3(0.15, 0.86, 0.26), Vector3(0.62, 0.05, 0.24), INK)
	keys.rotation.x = 0.2
	_deco(at + Vector3(-0.6, 0.9, 0.05), Vector3(0.4, 0.16, 0.2), CREAM)       # card stack
	var lamp := _deco(at + Vector3(0.5, 1.12, 0.17), Vector3(0.08, 0.08, 0.03), MUSTARD)
	var lamp_mat := (lamp.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color("ffcf5a")
	lamp_mat.emission_energy_multiplier = 2.0
	lamp.material_override = lamp_mat
	_sign("KEYPUNCH", at + Vector3(0, 1.85, -0.35), 56)

	var stand := Marker3D.new()
	stand.position = Vector3(0.15, -0.39, 1.0)       # in front of the keys, facing the machine (-Z)
	body.add_child(stand)
	_terminal = Interactable.new()
	_terminal.name = "TerminalInteractable"
	_terminal.prompt = "Use keypunch"
	_terminal.position = Vector3(0.15, -0.39, 0)
	_terminal.focus_offset = Vector3(0, 1.0, 0)
	_terminal.framing = Interactable.Framing.OVER_SHOULDER
	_terminal.stand_point = stand
	_terminal.pose = &"type"
	_terminal.shot_fov = 48.0
	body.add_child(_terminal)
	_terminal.used.connect(func(_p: Player) -> void:
		(_log["used"] as Array).append(_terminal)
		_overlay = TestOverlay.new()
		_ui.add_child(_overlay)
		_terminal.hold_while(_overlay))


func _build_dot() -> void:
	var at := Vector3(4.4, 0, 2.2)
	var body := StaticBody3D.new()
	body.name = "Dot"
	body.position = at
	body.rotation.y = -PI / 2.0 - 0.25      # figure front (+Z) turned to face west, into the room
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.75
	shape.shape = capsule
	shape.position.y = 0.875
	body.add_child(shape)
	add_child(body)
	_dot_figure = BrickFigure.new()
	_dot_figure.shirt_color = CREAM
	_dot_figure.vest_color = ORANGE
	_dot_figure.pants_color = Color("3f4a52")
	_dot_figure.skin_color = Color("b9794f")
	_dot_figure.hair_color = Color("2b2622")
	_dot_figure.hair_style = "bun"
	_dot_figure.tie_color = Color(0, 0, 0, 0)
	_dot_figure.animator.idle_glance = true
	body.add_child(_dot_figure)
	# A mug, of course.
	var mug := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.06
	mesh.bottom_radius = 0.05
	mesh.height = 0.12
	mug.mesh = mesh
	mug.material_override = _mat(MUSTARD)
	mug.position = Vector3(0, -0.1, 0.06)
	_dot_figure.part(&"HandL").add_child(mug)

	_dot = Interactable.new()
	_dot.name = "DotInteractable"
	_dot.prompt = "Talk to Dot"
	_dot.focus_offset = Vector3(0, 1.45, 0)
	_dot.prompt_offset = Vector3(0, 0.6, 0)
	_dot.radius = 3.0
	_dot.framing = Interactable.Framing.TWO_SHOT
	_dot.shot_fov = 44.0
	body.add_child(_dot)
	_dot.used.connect(func(_p: Player) -> void:
		(_log["used"] as Array).append(_dot)
		_dot_figure.animator.pose = &"talk"
		say("(Dot's dialogue opens here.)  E / Esc to finish.", 60.0))
	_dot.interaction_ended.connect(func(_p: Player) -> void:
		_dot_figure.animator.pose = &""
		say("", 0.01))


func _build_door() -> void:
	var at := Vector3(-2.0, 0, 4.96)
	_deco(at + Vector3(0, 1.1, 0.02), Vector3(1.3, 2.3, 0.06), Color("1c1a17"))     # dark doorway
	_deco(at + Vector3(-0.62, 1.1, -0.01), Vector3(0.1, 2.3, 0.12), WOOD_DARK)
	_deco(at + Vector3(0.62, 1.1, -0.01), Vector3(0.1, 2.3, 0.12), WOOD_DARK)
	_deco(at + Vector3(0, 2.25, -0.01), Vector3(1.34, 0.1, 0.12), WOOD_DARK)
	_door_slab = Node3D.new()
	_door_slab.position = at + Vector3(0, 0, -0.05)
	add_child(_door_slab)
	var slab := _deco(Vector3(0, 1.08, 0), Vector3(1.12, 2.14, 0.06), ORANGE)
	slab.reparent(_door_slab, false)
	var knob := _deco(Vector3(0.42, 1.0, -0.06), Vector3(0.08, 0.08, 0.08), MUSTARD)
	knob.reparent(_door_slab, false)
	_sign("AUTHORISED\nPERSONNEL ONLY", at + Vector3(0, 1.55, -0.1), 30, PI)

	_door = Interactable.new()
	_door.name = "DoorInteractable"
	_door.prompt = "Open door"
	_door.locked = true
	_door.focus_offset = Vector3(0, 1.1, 0)
	_door.needs_line_of_sight = false
	_door_slab.add_child(_door)
	_door.use_denied.connect(func(_p: Player) -> void:
		(_log["denied"] as Array).append(_door)
		var tween := create_tween()
		for i in 3:
			tween.tween_property(_door_slab, "rotation:y", 0.035, 0.05)
			tween.tween_property(_door_slab, "rotation:y", -0.035, 0.05)
		tween.tween_property(_door_slab, "rotation:y", 0.0, 0.05)
		say("Locked. Try the buzzer."))
	_door.used.connect(func(_p: Player) -> void:
		(_log["used"] as Array).append(_door)
		_door_open = not _door_open
		_door.prompt = "Close door" if _door_open else "Open door"
		create_tween().tween_property(slab, "position:x", -1.05 if _door_open else 0.0, 0.45).set_trans(Tween.TRANS_SINE))

	var button := _deco(at + Vector3(1.15, 1.2, -0.06), Vector3(0.16, 0.16, 0.06), Color("c0392b"))
	_deco(at + Vector3(1.15, 1.2, -0.03), Vector3(0.26, 0.3, 0.04), STEEL)
	_buzzer = Interactable.new()
	_buzzer.name = "BuzzerInteractable"
	_buzzer.prompt = "Press buzzer"
	_buzzer.focus_offset = Vector3.ZERO
	_buzzer.prompt_offset = Vector3(0, 0.3, 0)
	_buzzer.radius = 2.0
	_buzzer.look_angle_deg = 16.0
	_buzzer.needs_line_of_sight = false
	button.add_child(_buzzer)
	_buzzer.used.connect(func(_p: Player) -> void:
		(_log["used"] as Array).append(_buzzer)
		_door.locked = not _door.locked
		say("Bzzt. Door %s." % ("locked" if _door.locked else "unlocked")))


func _build_notice() -> void:
	var at := Vector3(9.0, 1.45, -0.97)
	var board := _deco(at, Vector3(1.2, 0.8, 0.05), Color("a9773f"))
	for i in 4:
		_deco(at + Vector3(-0.38 + i * 0.26, 0.08 - (i % 2) * 0.2, 0.03), Vector3(0.2, 0.26, 0.01), CREAM if i % 2 == 0 else MUSTARD)
	_notice = Interactable.new()
	_notice.name = "NoticeInteractable"
	_notice.prompt = "Read notice"
	_notice.focus_offset = Vector3.ZERO
	_notice.radius = 1.9
	_notice.needs_line_of_sight = false
	board.add_child(_notice)
	_notice.used.connect(func(_p: Player) -> void:
		(_log["used"] as Array).append(_notice)
		say("\"TEST ROOM. Please do not feed the engineers.\""))


# --- Room ------------------------------------------------------------------------------

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("101615")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("f2e8cf")
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	var fill := DirectionalLight3D.new()       # shadowless, so it lights through the ceiling
	fill.rotation_degrees = Vector3(-55, 35, 0)
	fill.light_energy = 0.22
	fill.light_color = Color("fff3d6")
	add_child(fill)
	for spot: Array in [[Vector3(0, 4.2, 0), 9.0, 0.9, true], [Vector3(-3.5, 4.2, -2.5), 7.0, 0.45, false],
			[Vector3(3.5, 4.2, -2.5), 7.0, 0.45, false], [Vector3(9, 2.3, 0), 4.5, 0.4, false], [Vector3(13.5, 2.3, 0), 3.5, 0.35, false]]:
		var lamp := OmniLight3D.new()
		lamp.position = spot[0]
		lamp.omni_range = spot[1]
		lamp.light_energy = spot[2]
		lamp.shadow_enabled = spot[3]
		lamp.light_color = Color("fff1cf")
		add_child(lamp)


func _build_rooms() -> void:
	var wall := CREAM.darkened(0.06)
	# Main room: 12 x 10 m, 4.6 m high.
	_solid(Vector3(0, -0.1, 0), Vector3(12, 0.2, 10), LINO, &"lino")
	_solid(Vector3(0, 4.7, 0), Vector3(12.6, 0.2, 10.6), CREAM)
	_solid(Vector3(0, 2.3, -5.15), Vector3(12.6, 4.6, 0.3), wall)
	_solid(Vector3(0, 2.3, 5.15), Vector3(12.6, 4.6, 0.3), wall)
	_solid(Vector3(-6.15, 2.3, 0), Vector3(0.3, 4.6, 10), wall)
	_solid(Vector3(6.15, 2.3, -3), Vector3(0.3, 4.6, 4), wall)
	_solid(Vector3(6.15, 2.3, 3), Vector3(0.3, 4.6, 4), wall)
	_solid(Vector3(6.15, 3.5, 0), Vector3(0.3, 2.2, 2), wall)
	# Teal dado band and floor tile lines, so walls read at a glance.
	_deco(Vector3(0, 0.55, -4.99), Vector3(12, 1.1, 0.02), TEAL_LIGHT)
	_deco(Vector3(0, 0.55, 4.99), Vector3(12, 1.1, 0.02), TEAL_LIGHT)
	_deco(Vector3(-5.99, 0.55, 0), Vector3(0.02, 1.1, 10), TEAL_LIGHT)
	for i in range(-5, 6):
		_deco(Vector3(i, 0.003, 0), Vector3(0.03, 0.006, 10), LINO.darkened(0.14))
	for i in range(-4, 5):
		_deco(Vector3(0, 0.003, i), Vector3(12, 0.006, 0.03), LINO.darkened(0.14))
	# Corridor: 2 m wide, 2.5 m high.
	_solid(Vector3(9.15, -0.1, 0), Vector3(5.7, 0.2, 2), Color("7a8f6e"), &"carpet")
	_solid(Vector3(9.15, 2.6, 0), Vector3(5.7, 0.2, 2.6), CREAM)
	_solid(Vector3(9.15, 1.25, -1.15), Vector3(5.7, 2.5, 0.3), MUSTARD.lightened(0.35))
	_solid(Vector3(9.15, 1.25, 1.15), Vector3(5.7, 2.5, 0.3), MUSTARD.lightened(0.35))
	# Closet: 3 x 3 m.
	_solid(Vector3(13.5, -0.1, 0), Vector3(3, 0.2, 3), Color("b9b1a0"), &"concrete")
	_solid(Vector3(13.5, 2.6, 0), Vector3(3.6, 0.2, 3.6), CREAM)
	_solid(Vector3(13.5, 1.25, -1.65), Vector3(3.6, 2.5, 0.3), TEAL_LIGHT)
	_solid(Vector3(13.5, 1.25, 1.65), Vector3(3.6, 2.5, 0.3), TEAL_LIGHT)
	_solid(Vector3(15.15, 1.25, 0), Vector3(0.3, 2.5, 3), TEAL_LIGHT)
	_solid(Vector3(12.0, 1.25, -1.3), Vector3(0.3, 2.5, 0.6), TEAL_LIGHT)
	_solid(Vector3(12.0, 1.25, 1.3), Vector3(0.3, 2.5, 0.6), TEAL_LIGHT)
	_solid(Vector3(14.5, 0.35, -1.0), Vector3(0.7, 0.7, 0.7), WOOD)
	_solid(Vector3(14.45, 0.95, -1.0), Vector3(0.5, 0.5, 0.5), WOOD_DARK)
	_sign("CORRIDOR  →", Vector3(5.98, 2.55, 0), 44, -PI / 2.0)


func _build_stairs_and_ramp() -> void:
	# Eight real steps (0.18 m risers) up the west wall to a mezzanine.
	for i in 8:
		var top := (i + 1) * 0.18
		_solid(Vector3(-5.2, top / 2.0, 3.0 - (i + 0.5) * 0.3), Vector3(1.6, top, 0.3), WOOD if i % 2 == 0 else WOOD_DARK, &"wood")
	_solid(Vector3(-5.2, 1.34, -2.2), Vector3(1.6, 0.2, 5.6), STEEL, &"metal")
	_solid(Vector3(-4.42, 1.94, -2.2), Vector3(0.06, 1.0, 5.6), TEAL)
	for z: float in [-4.8, -2.2, 0.4]:
		_deco(Vector3(-4.5, 0.62, z), Vector3(0.12, 1.24, 0.12), STEEL.darkened(0.2))
	# A ramp up to a low platform.
	_solid(Vector3(4.5, 0.25, 4.25), Vector3(3, 0.5, 1.5), STEEL, &"metal")
	var angle := atan2(0.5, 2.0)
	var ramp := _solid(Vector3.ZERO, Vector3(sqrt(4.25), 0.2, 1.5), MUSTARD, &"metal")
	ramp.rotation.z = angle
	ramp.position = Vector3(2.0, 0.25, 4.25) - Vector3(-sin(angle), cos(angle), 0) * 0.1


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	var help := ConsoleTheme.body("WASD move   Shift sprint   Mouse look (click to capture)   Q swap shoulder   E interact   Esc leave / free mouse   F3 readout", 17, ConsoleTheme.CREAM)
	help.autowrap_mode = TextServer.AUTOWRAP_OFF
	help.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	help.add_theme_constant_override("shadow_offset_y", 2)
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.offset_left = 28
	help.offset_top = -46
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(help)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ConsoleTheme.panel(ConsoleTheme.DESK, ConsoleTheme.INK, 3, 8, 12))
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_top = -120
	panel.offset_bottom = -70
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	_ui.add_child(panel)
	_message = ConsoleTheme.heading("", 22, ConsoleTheme.CREAM)
	panel.add_child(_message)
	_readout = ConsoleTheme.body("", 17, ConsoleTheme.CREAM)
	_readout.add_theme_font_override("font", ConsoleTheme.mono())
	_readout.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_readout.add_theme_constant_override("shadow_offset_y", 2)
	_readout.autowrap_mode = TextServer.AUTOWRAP_OFF
	_readout.position = Vector2(28, 24)
	_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_readout.visible = false
	_ui.add_child(_readout)


## A coloured box with a collider. The StaticBody3D is returned; child 0 is the mesh.
func _solid(center: Vector3, size: Vector3, color: Color, surface: StringName = &"") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = center
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _mat(color)
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	if surface != &"":
		body.set_meta(&"surface", surface)
	add_child(body)
	return body


func _deco(center: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _mat(color)
	mesh.position = center
	add_child(mesh)
	return mesh


func _sign(text: String, at: Vector3, font_size: int, yaw: float = 0.0) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = ConsoleTheme.typewriter()
	label.font_size = font_size
	label.pixel_size = 0.005
	label.modulate = INK
	label.outline_size = 0
	label.position = at
	label.rotation.y = yaw
	add_child(label)
	return label


func _mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.8
		_materials[key] = m
	return _materials[key]


## Stand-in for a real UI (keypunch deck, dialogue): a panel that closes on Esc.
class TestOverlay extends PanelContainer:
	func _ready() -> void:
		add_theme_stylebox_override("panel", ConsoleTheme.panel(ConsoleTheme.PAPER, ConsoleTheme.INK, 4, 10, 22))
		anchor_left = 1.0
		anchor_right = 1.0
		anchor_top = 0.5
		anchor_bottom = 0.5
		offset_left = -620
		offset_right = -60
		offset_top = -170
		offset_bottom = 170
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 14)
		add_child(box)
		box.add_child(ConsoleTheme.heading("KEYPUNCH  //  TEST OVERLAY", 26))
		box.add_child(ConsoleTheme.body("The real keypunch deck opens here. The player is held in the over-the-shoulder shot for as long as this panel exists (Interactable.hold_while).", 19))
		var close := Button.new()
		close.text = "TEAR OFF  (Esc)"
		close.pressed.connect(queue_free)
		box.add_child(close)

	func _unhandled_key_input(event: InputEvent) -> void:
		var key := event as InputEventKey
		if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			queue_free()


# --- Debug / tests ---------------------------------------------------------------------

func _apply_cmdline(args: PackedStringArray) -> void:
	var screenshot := ""
	var selftest := false
	var use := false
	var hold: Array[StringName] = []
	var bench := 0.0
	for arg in args:
		if arg.begins_with("--at="):
			_go(arg.trim_prefix("--at="))
		elif arg.begins_with("--yaw="):
			_player.camera_rig.yaw = deg_to_rad(float(arg.trim_prefix("--yaw=")))
			_player.camera_rig.snap()
		elif arg.begins_with("--pitch="):
			_player.camera_rig.pitch = deg_to_rad(float(arg.trim_prefix("--pitch=")))
			_player.camera_rig.snap()
		elif arg == "--left":
			_player.camera_rig.swap_shoulder()
		elif arg == "--use":
			use = true
		elif arg == "--walk":
			hold.append(PlayerInput.MOVE_FORWARD)
		elif arg == "--sprint":
			hold.append(PlayerInput.MOVE_FORWARD)
			hold.append(PlayerInput.SPRINT)
		elif arg == "--readout":
			_readout.visible = true
		elif arg.begins_with("--screenshot="):
			screenshot = arg.trim_prefix("--screenshot=")
		elif arg.begins_with("--bench="):
			bench = float(arg.trim_prefix("--bench="))
		elif arg == "--selftest":
			selftest = true
	if selftest:
		_readout.visible = false
		await _run_selftest()
		return
	if use:
		await _seconds(0.5)
		_player.try_interact()
	for action in hold:
		Input.action_press(action)
	if bench > 0.0:
		# Orbit the camera for a while and report the average frame rate.
		await _seconds(1.0)
		var frames := 0
		var started := Time.get_ticks_usec()
		while (Time.get_ticks_usec() - started) / 1000000.0 < bench:
			await get_tree().process_frame
			_player.camera_rig.rotate_look(0.01, 0.0)
			frames += 1
		var took := (Time.get_ticks_usec() - started) / 1000000.0
		print("PlayerTest: %.0f fps average over %.1f s (%d draw calls, %d primitives)" % [frames / took, took,
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
		get_tree().quit()
		return
	if screenshot != "":
		await _seconds(1.6 if use else 0.75)
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var err := image.save_png(screenshot)
		print("PlayerTest: screenshot -> %s (%s)" % [screenshot, error_string(err)])
		get_tree().quit()


func _go(spot: String) -> void:
	if not SPOTS.has(spot):
		push_warning("PlayerTest: unknown spot '%s'" % spot)
		return
	var where: Array = SPOTS[spot]
	_player.teleport(where[0], where[1])


func _seconds(seconds: float) -> void:
	var ticks := int(ceil(seconds * Engine.physics_ticks_per_second))
	for i in ticks:
		await get_tree().physics_frame


func _tap(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
		await get_tree().process_frame


func _release_all() -> void:
	for action: StringName in PlayerInput.DEFAULTS:
		Input.action_release(action)


## Sideways offset of the camera from the player (+ = over the right shoulder).
func _camera_side() -> float:
	var cam := _player.camera_rig.camera
	var offset := cam.global_position - (_player.global_position + Vector3.UP * Player.EYE_HEIGHT)
	return offset.dot(cam.global_basis.x)


func _inside(point: Vector3, x0: float, x1: float, z0: float, z1: float, top: float) -> bool:
	return point.x > x0 and point.x < x1 and point.z > z0 and point.z < z1 and point.y > 0.0 and point.y < top


func _run_selftest() -> void:
	var failures: PackedStringArray = []
	var expect := func(ok: bool, what: String) -> void:
		print("  [%s] %s" % ["ok" if ok else "FAIL", what])
		if not ok:
			failures.append(what)
	var p := _player
	var rig := p.camera_rig
	var cam := rig.camera
	var anim := p.figure.animator
	print("PLAYER SELFTEST")
	await _seconds(0.4)

	# --- Rig -------------------------------------------------------------------
	var missing: PackedStringArray = []
	for part_name in BrickFigure.PART_NAMES:
		if p.figure.part(part_name) == null:
			missing.append(part_name)
	expect.call(missing.is_empty(), "rig has the 8 named parts %s" % ("" if missing.is_empty() else "(missing %s)" % ", ".join(missing)))
	expect.call(p.is_on_floor(), "player stands on the floor (y=%.3f)" % p.global_position.y)
	expect.call(_camera_side() > 0.3, "camera sits over the right shoulder (%.2f m)" % _camera_side())
	var open_boom := rig.boom_length()
	expect.call(open_boom > 2.6, "open room: full boom (%.2f m, openness %.2f)" % [open_boom, rig.openness()])

	# --- Walk / sprint ---------------------------------------------------------
	var z0 := p.global_position.z
	Input.action_press(PlayerInput.MOVE_FORWARD)
	await _seconds(1.0)
	var walked := z0 - p.global_position.z
	expect.call(walked > 2.4 and walked < 3.6, "walks forward, camera-relative (%.2f m in 1 s)" % walked)
	var leg := p.figure.part(&"LegL")
	expect.call(anim.move_blend > 0.9 and anim.phase > 3.0, "walk cycle runs (phase %.1f rad, leg %.2f rad)" % [anim.phase, leg.rotation.x])
	expect.call(int(_log["steps"]) >= 2, "footsteps reported (%d, surface %s)" % [int(_log["steps"]), str((_log["surfaces"] as Dictionary).keys())])
	var walk_fov := cam.fov
	p.teleport(Vector3(-1, 0, 4.2), Vector3(0, 0, -1))
	Input.action_press(PlayerInput.SPRINT)
	await _seconds(0.9)
	expect.call(anim.speed > 5.6, "sprints (%.1f m/s)" % anim.speed)
	expect.call(cam.fov > walk_fov + 3.0, "FOV widens when sprinting (%.1f -> %.1f)" % [walk_fov, cam.fov])
	expect.call(anim.run_blend > 0.6, "run cycle blends in (%.2f)" % anim.run_blend)
	_release_all()
	await _seconds(0.6)
	expect.call(anim.speed < 0.05 and anim.move_blend < 0.1, "stops and idles")

	# --- Mouse look ------------------------------------------------------------
	var yaw0 := rig.yaw
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(200, 0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Input.parse_input_event(motion)
	await _seconds(0.1)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	expect.call(absf(angle_difference(yaw0, rig.yaw)) > 0.2 or DisplayServer.get_name() == "headless",
			"mouse look turns the camera (%.2f rad)" % angle_difference(yaw0, rig.yaw))
	rig.rotate_look(0.6, 0.0)
	expect.call(absf(angle_difference(yaw0, rig.yaw)) > 0.5, "rotate_look turns the camera")

	# --- Spring arm: never through a wall --------------------------------------
	_go("wall")
	await _seconds(0.5)
	expect.call(cam.global_position.z < 4.95, "back to a wall: camera stays inside (z=%.2f, wall at 5.0, boom %.2f m)" % [cam.global_position.z, rig.boom_length()])
	p.teleport(Vector3(5.2, 0, -4.2), Vector3(-1, 0, 1))
	var clipped := 0
	for i in 12:
		rig.yaw = TAU * i / 12.0
		rig.pitch = -0.5 if i % 2 == 0 else 0.2
		await _seconds(0.2)
		if not _inside(cam.global_position, -6.0, 6.0, -5.0, 5.0, 4.6):
			clipped += 1
			print("      outside at yaw %d: %s" % [i * 30, cam.global_position])
	expect.call(clipped == 0, "in a corner, 12 camera angles: camera never leaves the room")

	# --- Shoulder swap ---------------------------------------------------------
	_go("start")
	rig.pitch = -0.16
	await _seconds(0.4)
	await _tap(PlayerInput.SWAP_SHOULDER)
	await _seconds(0.7)
	expect.call(_camera_side() < -0.3, "Q swaps to the left shoulder (%.2f m)" % _camera_side())
	await _tap(PlayerInput.SWAP_SHOULDER)
	await _seconds(0.7)
	expect.call(_camera_side() > 0.3, "and back to the right (%.2f m)" % _camera_side())

	# --- Tight framing in small rooms ------------------------------------------
	_go("closet")
	await _seconds(1.6)
	expect.call(rig.boom_length() < open_boom - 0.8, "closet: boom shortens (%.2f m vs %.2f m open, openness %.2f)" % [rig.boom_length(), open_boom, rig.openness()])
	expect.call(_inside(cam.global_position, 12.0, 15.0, -1.5, 1.5, 2.5), "closet: camera stays inside it %s" % cam.global_position)
	_go("corridor")
	await _seconds(1.6)
	expect.call(rig.boom_length() < open_boom - 0.6, "corridor: boom shortens (%.2f m)" % rig.boom_length())

	# --- Focus, prompt, head turn ----------------------------------------------
	_go("terminal")
	await _seconds(0.5)
	expect.call(p.focused() == _terminal, "looking at the keypunch focuses it")
	expect.call(p.prompt.text() == "E  Use keypunch", "prompt reads '%s'" % p.prompt.text())
	# Body angled away, camera still on the keypunch: the head turns to it.
	p.teleport(Vector3(2.9, 0, -2.6), Vector3(-0.8, 0, -1))
	rig.face(Vector3(-0.15, 0, -1))
	await _seconds(0.5)
	var head := p.figure.part(&"Head")
	expect.call(p.focused() == _terminal and absf(head.rotation.y) > 0.3, "head turns toward it (%.2f rad)" % head.rotation.y)
	# Body side-on to the keypunch, camera still on it: the player shuffles round.
	p.teleport(Vector3(2.9, 0, -2.6), Vector3(-1, 0, 0.3))
	rig.face(Vector3(-0.15, 0, -1))
	var peak_turn := 0.0
	for i in 100:
		await get_tree().physics_frame
		peak_turn = maxf(peak_turn, anim.turn_blend)
	var to_terminal := (_terminal.focus_point() - p.global_position) * Vector3(1, 0, 1)
	expect.call(p.facing_direction().dot(to_terminal.normalized()) > 0.9 and peak_turn > 0.3,
			"turns in place to face what it looks at (shuffle blend %.2f)" % peak_turn)
	expect.call(not p._can_see(Vector3(5.0, 1.45, -2.0), _notice.focus_point(), _notice), "walls block line of sight")

	# --- Over-the-shoulder interaction, held by a UI ---------------------------
	await _tap(PlayerInput.INTERACT)
	expect.call(p.is_interacting() and (_log["used"] as Array).has(_terminal), "E uses the keypunch (used signal)")
	expect.call(_overlay != null and is_instance_valid(_overlay), "world code opened its overlay")
	await _seconds(1.3)
	var stand := _terminal.stand_point.global_position
	expect.call(rig.shot_blend() > 0.99, "camera eased onto the framed shot")
	expect.call(p.global_position.distance_to(stand) < 0.12, "player walked onto the stand point (%.2f m off)" % p.global_position.distance_to(stand))
	var look_dir := -cam.global_basis.z
	var behind := (cam.global_position - p.global_position).dot(p.facing_direction())
	expect.call(behind < -0.6 and look_dir.dot((_terminal.focus_point() - cam.global_position).normalized()) > 0.9,
			"over-the-shoulder: camera behind the player, aimed at the keypunch")
	expect.call(cam.is_position_in_frustum(_terminal.focus_point()), "keypunch is in frame")
	var arm := p.figure.part(&"ArmR")
	expect.call(arm.rotation.x < -0.8, "typing pose (arm %.2f rad)" % arm.rotation.x)
	Input.action_press(PlayerInput.MOVE_BACK)
	await _tap(PlayerInput.CANCEL)
	await _seconds(0.3)
	Input.action_release(PlayerInput.MOVE_BACK)
	expect.call(p.is_interacting() and p.global_position.distance_to(stand) < 0.12, "held while the overlay is open (no walking, Esc belongs to the UI)")
	_overlay.queue_free()
	await _seconds(0.1)
	expect.call(not p.is_interacting() and (_log["ended"] as Array).has(_terminal), "closing the overlay releases the player")
	await _seconds(1.0)
	expect.call(rig.shot_blend() < 0.01 and _camera_side() > 0.3, "camera returns to the shoulder")

	# --- Two-shot with an NPC ----------------------------------------------------
	_go("npc")
	await _seconds(0.5)
	expect.call(p.focused() == _dot and p.prompt.text() == "E  Talk to Dot", "prompt reads '%s'" % p.prompt.text())
	await _tap(PlayerInput.INTERACT)
	await _seconds(1.3)
	expect.call(p.is_interacting() and rig.shot_blend() > 0.99, "talking to Dot holds the player in a shot")
	expect.call(cam.is_position_in_frustum(p.head_position()) and cam.is_position_in_frustum(_dot_figure.head_position()),
			"two-shot: both heads in frame")
	expect.call(_inside(cam.global_position, -6.0, 6.0, -5.0, 5.0, 4.6), "two-shot camera is inside the room")
	var dot_head := _dot_figure.part(&"Head")
	expect.call(absf(dot_head.rotation.y) > 0.02 or absf(dot_head.rotation.x) > 0.02, "Dot looks at the player")
	await _tap(PlayerInput.INTERACT)
	await _seconds(0.2)
	expect.call(not p.is_interacting(), "E again ends the conversation")
	await _seconds(0.9)

	# --- Hand-placed camera point ------------------------------------------------
	_go("shelf")
	await _seconds(0.5)
	expect.call(p.focused() == _shelf, "shelf focuses")
	await _tap(PlayerInput.INTERACT)
	await _seconds(1.2)
	expect.call(cam.global_position.distance_to(_shelf.camera_point.global_position) < 0.05, "shelf: camera sits exactly on its camera point")
	await _tap(PlayerInput.CANCEL)
	await _seconds(0.2)
	expect.call(not p.is_interacting(), "Esc steps back from the shelf")
	await _seconds(0.9)

	# --- Locked door, instant use ------------------------------------------------
	_go("door")
	await _seconds(0.5)
	expect.call(p.focused() == _door and p.prompt.text() == "E  Locked", "locked door prompt reads '%s'" % p.prompt.text())
	await _tap(PlayerInput.INTERACT)
	expect.call((_log["denied"] as Array).has(_door) and not (_log["used"] as Array).has(_door), "locked: use_denied fires, used does not")
	_door.locked = false
	await _seconds(0.1)
	expect.call(p.prompt.text() == "E  Open door", "unlocked prompt reads '%s'" % p.prompt.text())
	await _tap(PlayerInput.INTERACT)
	expect.call((_log["used"] as Array).has(_door) and not p.is_interacting(), "instant use: door opens, player keeps control")

	# --- Stairs and ramp ---------------------------------------------------------
	_go("stairs")
	await _seconds(0.3)
	Input.action_press(PlayerInput.MOVE_FORWARD)
	await _seconds(1.5)
	expect.call(p.global_position.y > 1.35, "climbs 8 real steps to the mezzanine (y=%.2f)" % p.global_position.y)
	_release_all()
	Input.action_press(PlayerInput.MOVE_BACK)
	await _seconds(1.7)
	_release_all()
	await _seconds(0.3)
	expect.call(p.global_position.y < 0.03 and p.is_on_floor(), "walks back down (y=%.2f)" % p.global_position.y)
	_go("ramp")
	await _seconds(0.3)
	Input.action_press(PlayerInput.MOVE_FORWARD)
	await _seconds(1.1)
	_release_all()
	await _seconds(0.3)
	expect.call(absf(p.global_position.y - 0.5) < 0.04, "walks up the ramp (y=%.2f)" % p.global_position.y)
	var surfaces: Dictionary = _log["surfaces"]
	expect.call(surfaces.has(&"lino") and surfaces.has(&"metal"), "footsteps carry the floor surface %s" % str(surfaces.keys()))

	# --- Control lock ------------------------------------------------------------
	_go("start")
	p.set_control_enabled(false)
	Input.action_press(PlayerInput.MOVE_FORWARD)
	await _seconds(0.4)
	_release_all()
	expect.call(p.global_position.distance_to(SPOTS["start"][0]) < 0.02, "set_control_enabled(false) freezes the player")
	p.set_control_enabled(true)

	print("PLAYER SELFTEST %s" % ("PASS" if failures.is_empty() else "FAIL: " + "; ".join(failures)))
	get_tree().quit(0 if failures.is_empty() else 1)
