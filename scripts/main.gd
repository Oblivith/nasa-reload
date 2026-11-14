# Code generated with AI assistance (Claude). Reviewed by team.
extends Node
## Root scene. Owns the container that SceneManager swaps scenes into.

const START_SCENE := "res://scenes/ui/title_screen.tscn"

@onready var scene_container: Node = $SceneContainer


func _ready() -> void:
	SceneManager.register_container(scene_container)
	SceneManager.change_scene(START_SCENE)
