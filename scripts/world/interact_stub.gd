# Code generated with AI assistance (Claude). Reviewed by team.
class_name InteractStub
extends Area3D
## PLACEHOLDER for Session A's Interactable component (/scripts/player/). Anything the
## player can use in the world is an Area3D with this script: a prompt, a Marker3D the
## camera should ease to while using it, and a `used` signal. To swap: replace this
## script on the Area3D with the real component and keep the three members below.
##
## All stubs are in group "interactable". They sit on collision layer 3 so a look-ray
## can find them without hitting walls' layer 1.

signal used(by: Node)

const LAYER := 4            # collision layer 3

@export var prompt_text: String = ""
@export var framing_point: Marker3D
## Free id the owner uses to tell stubs apart ("dot", "keypunch", "lift_call_0", ...).
@export var interact_id: String = ""
@export var enabled: bool = true
@export var reach: float = 2.8


func _init() -> void:
	collision_layer = LAYER
	collision_mask = 0
	monitoring = false
	add_to_group("interactable")


func use(by: Node = null) -> void:
	if enabled:
		used.emit(by)


## Builds a ready-to-use stub: a small sphere trigger plus its framing marker.
## `frame_from` is where the camera should sit (world space) looking at `at`.
static func make(parent: Node3D, id: String, prompt: String, at: Vector3, frame_from: Vector3 = Vector3.INF) -> InteractStub:
	var stub := InteractStub.new()
	stub.name = "Interact_" + id
	stub.interact_id = id
	stub.prompt_text = prompt
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.6
	shape.shape = sphere
	stub.add_child(shape)
	parent.add_child(stub)
	stub.position = at
	var marker := Marker3D.new()
	marker.name = "FramingPoint"
	stub.add_child(marker)
	if frame_from != Vector3.INF and not frame_from.is_equal_approx(at):
		marker.position = frame_from - at
		var flat := at - frame_from
		if absf(flat.x) + absf(flat.z) > 0.01:
			marker.basis = Basis.looking_at(flat, Vector3.UP)
	stub.framing_point = marker
	return stub
