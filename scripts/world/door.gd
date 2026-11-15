# Code generated with AI assistance (Claude). Reviewed by team.
class_name WorldDoor
extends Node3D
## A door in the facility (kit scene: /scenes/world/kit/door.tscn). Built from one entry
## of "doors" in data/facility_world.json. Unlocked doors swing or slide open on their
## own when the player or an NPC comes close, and close behind them. Locked doors carry
## an InteractStub ("E  Try the door"): they jiggle and report `locked_tried`.
##
## Local frame: the doorway spans local x, people walk through along local z.
## Types: swing, double, glass (double, see-through), slide, arch (no leaf).

signal locked_tried(door: WorldDoor)
signal moved(door: WorldDoor)

const OPEN_ANGLE := 1.75
const SENSE_RADIUS := 2.4

var data: Dictionary = {}
var door_id: String = ""
var kind: String = "swing"
var rooms: Array = []
var locked: bool = false
var open_amount: float = 0.0
var width: float = 1.0
var height: float = 2.2
## Set by FacilityWorld: returns actor positions (player + walking NPCs).
var actors: Callable
var play_sound: Callable
var stub: InteractStub

var _leaves: Array = []           # [{pivot, hinge, home}]
var _blocker: CollisionShape3D
var _hold: float = 0.0
var _swing: float = 1.0
var _jiggle: float = 0.0
var _was_moving: bool = false


func setup(entry: Dictionary, layers: int, texts: Dictionary) -> void:
	data = entry
	door_id = str(entry.get("id", ""))
	kind = str(entry.get("type", "swing"))
	rooms = entry.get("rooms", [])
	width = float(entry.get("w", 1.0))
	height = float(entry.get("h", 2.2))
	locked = bool(entry.get("locked", false))
	var at: Array = entry["at"]
	position = Vector3(float(at[0]), float(entry.get("y", 0.0)), float(at[1]))
	rotation.y = 0.0 if str(entry.get("axis", "x")) == "x" else PI / 2.0
	_build(layers, texts)
	set_physics_process(kind != "arch")


func see_through() -> bool:
	return kind == "arch" or kind == "glass" or open_amount > 0.02


func set_locked(value: bool) -> void:
	locked = value
	if stub != null:
		stub.enabled = value


func try_locked() -> void:
	_jiggle = 0.5
	if play_sound.is_valid():
		play_sound.call("door_locked", global_position + Vector3(0, 1.1, 0))
	locked_tried.emit(self)


func _build(layers: int, texts: Dictionary) -> void:
	var bm := BrickMesh.new()
	var frame := Color(str(data.get("frame", "6b4f36")))
	var depth := 0.36
	if kind != "arch":
		for sx: float in [-1.0, 1.0]:
			bm.box(Vector3(sx * (width / 2 + 0.04), height / 2, 0), Vector3(0.08, height, depth), frame, "wood")
		bm.box(Vector3(0, height + 0.04, 0), Vector3(width + 0.16, 0.08, depth), frame, "wood")
	else:
		bm.box(Vector3(0, height + 0.03, 0), Vector3(width, 0.06, 0.32), frame, "wood")
	bm.box(Vector3(0, 0.005, 0), Vector3(width, 0.01, 0.3), Color("4d5b63"), "metal")
	bm.commit(self, layers, "Frame")
	var label := str(data.get("label", ""))
	if label != "":
		for side: float in [-1.0, 1.0]:
			if data.has("label_side") and float(data["label_side"]) != side:
				continue
			var plaque := Label3D.new()
			plaque.text = label
			plaque.font = ConsoleTheme.typewriter()
			plaque.font_size = int(data.get("label_size", 44))
			plaque.pixel_size = 0.004
			plaque.modulate = Color("fbf5e6")
			plaque.outline_size = 8
			plaque.outline_modulate = Color("2b2622")
			plaque.position = Vector3(0, height + 0.32, side * 0.19)
			plaque.rotation.y = 0.0 if side > 0.0 else PI
			plaque.visibility_range_end = 32.0
			plaque.layers = layers
			add_child(plaque)
	if kind == "arch":
		return
	var leaf_col := Color(str(data.get("color", "2a7b7b")))
	var count := 1 if kind == "swing" or kind == "slide" else 2
	var leaf_w := width / count
	for i in count:
		var hinge := -1.0 if i == 0 else 1.0
		var pivot := Node3D.new()
		pivot.name = "Leaf%d" % i
		pivot.position = Vector3(hinge * width / 2, 0, 0)
		add_child(pivot)
		var lm := BrickMesh.new()
		var cx := -hinge * leaf_w / 2
		if kind == "glass":
			lm.box(Vector3(cx, height / 2, 0), Vector3(leaf_w - 0.02, height - 0.02, 0.03), Color(0.75, 0.9, 0.95, 0.22), "glass")
			for sy: float in [0.04, height - 0.04]:
				lm.box(Vector3(cx, sy, 0), Vector3(leaf_w - 0.02, 0.08, 0.05), Color("8c8577"), "metal")
			for sx: float in [-1.0, 1.0]:
				lm.box(Vector3(cx + sx * (leaf_w / 2 - 0.04), height / 2, 0), Vector3(0.06, height, 0.05), Color("8c8577"), "metal")
		else:
			lm.box(Vector3(cx, height / 2, 0), Vector3(leaf_w - 0.02, height - 0.02, 0.05), leaf_col, "gloss")
			lm.box(Vector3(cx, 0.15, 0), Vector3(leaf_w - 0.02, 0.26, 0.06), Color("8c8577"), "metal")
			if bool(data.get("porthole", count == 2)):
				lm.box(Vector3(cx, height * 0.68, 0), Vector3(leaf_w * 0.4, 0.5, 0.055), Color("d8eef2"), "glow")
			if str(data.get("sign", "")) != "":
				lm.box(Vector3(cx, height * 0.66, 0), Vector3(leaf_w * 0.8, 0.34, 0.056), Color("fbf5e6"))
		lm.box(Vector3(-hinge * (leaf_w - 0.12), 1.05, 0), Vector3(0.05, 0.14, 0.14), Color("e9c46a"), "metal")
		lm.commit(pivot, layers, "LeafMesh")
		_leaves.append({"pivot": pivot, "hinge": hinge, "home": pivot.position})
	var sign_text := str(data.get("sign", ""))
	if sign_text != "" and not _leaves.is_empty():
		for side: float in [-1.0, 1.0]:
			if data.has("label_side") and float(data["label_side"]) != side:
				continue
			var notice := Label3D.new()
			notice.text = sign_text
			notice.font = ConsoleTheme.typewriter()
			notice.font_size = 22
			notice.pixel_size = 0.004
			notice.modulate = Color("c0392b")
			notice.outline_size = 0
			notice.width = width * 0.75 / 0.004
			notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var first_hinge: float = _leaves[0]["hinge"]
			notice.position = Vector3(-first_hinge * leaf_w / 2, height * 0.66, side * 0.032)
			notice.rotation.y = 0.0 if side > 0.0 else PI
			notice.visibility_range_end = 14.0
			notice.layers = layers
			(_leaves[0]["pivot"] as Node3D).add_child(notice)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	_blocker = CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(width, height, 0.24)
	_blocker.shape = bs
	_blocker.position.y = height / 2
	body.add_child(_blocker)
	add_child(body)
	var prompt := str(data.get("locked_prompt", texts.get("locked_prompt", "E  Try the door")))
	stub = InteractStub.make(self, "door_" + door_id, prompt, Vector3(0, 1.1, 0))
	stub.reach = 2.2
	stub.enabled = locked
	stub.used.connect(func(_by: Node) -> void: try_locked())


func _physics_process(delta: float) -> void:
	var before := open_amount
	if locked:
		open_amount = move_toward(open_amount, 0.0, delta * 2.0)
	else:
		var near := false
		if actors.is_valid():
			for p: Vector3 in actors.call():
				var local := p - global_position
				if absf(local.y) < 2.0 and Vector2(local.x, local.z).length() < SENSE_RADIUS:
					near = true
					if open_amount <= 0.01:
						var along := global_transform.basis.z.dot(local)
						_swing = -1.0 if along > 0.0 else 1.0
					break
		if near:
			_hold = 1.4
		else:
			_hold = maxf(0.0, _hold - delta)
		open_amount = move_toward(open_amount, 1.0 if _hold > 0.0 else 0.0, delta * (2.6 if _hold > 0.0 else 1.6))
	if _jiggle > 0.0:
		_jiggle = maxf(0.0, _jiggle - delta)
	if before == open_amount and _jiggle <= 0.0 and not _was_moving:
		return
	_was_moving = before != open_amount or _jiggle > 0.0
	_apply()
	if before <= 0.0 and open_amount > 0.0 and play_sound.is_valid():
		play_sound.call("door_open", global_position + Vector3(0, 1.1, 0))
	elif before > 0.0 and open_amount <= 0.0 and play_sound.is_valid():
		play_sound.call("door_close", global_position + Vector3(0, 1.1, 0))
	if (before <= 0.02) != (open_amount <= 0.02):
		moved.emit(self)


func _apply() -> void:
	var k := smoothstep(0.0, 1.0, open_amount)
	var shake := sin(_jiggle * 60.0) * 0.035 * minf(1.0, _jiggle * 4.0)
	for leaf: Dictionary in _leaves:
		var pivot: Node3D = leaf["pivot"]
		var hinge: float = leaf["hinge"]
		if kind == "slide":
			pivot.position = (leaf["home"] as Vector3) + Vector3(hinge * width * 0.96 * k + shake, 0, 0)
		else:
			pivot.rotation.y = hinge * _swing * OPEN_ANGLE * k + shake
	if _blocker != null:
		_blocker.disabled = open_amount > 0.45
