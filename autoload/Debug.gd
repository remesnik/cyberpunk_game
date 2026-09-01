extends Node

var overlay_visible := true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		overlay_visible = not overlay_visible
		EventBus.debug_visibility_changed.emit(overlay_visible)
		get_viewport().set_input_as_handled()


func log_message(message: String) -> void:
	print("[DEBUG] %s" % message)

