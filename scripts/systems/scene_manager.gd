# Code generated with AI assistance (Claude). Reviewed by team.
extends Node
## Global scene switcher (autoload "SceneManager").
## Main registers a container node; scenes are swapped inside it.

signal scene_changed(path: String)

var _container: Node = null
var _current: Node = null
var current_path: String = ""


func register_container(container: Node) -> void:
	_container = container


func change_scene(path: String) -> void:
	if _container == null:
		push_error("SceneManager: no container registered (is Main loaded?).")
		return
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("SceneManager: cannot load scene '%s'." % path)
		return
	if _current != null:
		_current.queue_free()
	_current = packed.instantiate()
	current_path = path
	_container.add_child(_current)
	scene_changed.emit(path)
