# SI assistance metadata: This code used the help of SI.
extends Control

const NEXT_SCENE := "res://scenes/cutscenes/opening.tscn"

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventKey and event.pressed and not event.echo) \
			or (event is InputEventMouseButton and event.pressed):
		get_viewport().set_input_as_handled()
		SceneManager.change_scene(NEXT_SCENE)
