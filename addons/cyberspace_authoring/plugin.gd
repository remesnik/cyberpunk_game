@tool
extends EditorPlugin

const AUTHORING_STUDIO_SCENE := preload("res://addons/cyberspace_authoring/AuthoringStudio.tscn")

var _studio: Control


func _enter_tree() -> void:
	_studio = AUTHORING_STUDIO_SCENE.instantiate()
	_studio.setup(get_editor_interface())
	add_control_to_bottom_panel(_studio, "CYBERSPACE")


func _exit_tree() -> void:
	if is_instance_valid(_studio):
		remove_control_from_bottom_panel(_studio)
		_studio.queue_free()
	_studio = null

