# SI assistance metadata: This code used the help of SI.
extends Node

const START_SCENE := "res://scenes/ui/title_screen.tscn"

@onready var scene_container: Node = $SceneContainer

func _ready() -> void:
	SceneManager.register_container(scene_container)
	SceneManager.change_scene(START_SCENE)
