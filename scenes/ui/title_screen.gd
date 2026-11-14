# Code generated with AI assistance (Claude). Reviewed by team.
extends Control
## Title card. Any key or click walks into the facility.

const NEXT_SCENE := "res://scenes/world/facility/facility.tscn"


func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventKey and event.pressed and not event.echo) \
			or (event is InputEventMouseButton and event.pressed):
		get_viewport().set_input_as_handled()
		SceneManager.change_scene(NEXT_SCENE)
