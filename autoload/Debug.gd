extends Node

var overlay_visible := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	# Poll the action so focused Controls cannot consume F3 before the debug
	# service sees it. This also works during the project's pause modes.
	if Input.is_action_just_pressed("debug_toggle"):
		set_overlay_visible(not overlay_visible)


func set_overlay_visible(is_visible: bool) -> void:
	if overlay_visible == is_visible:
		return
	overlay_visible = is_visible
	EventBus.debug_visibility_changed.emit(overlay_visible)


func log_message(message: String) -> void:
	print("[DEBUG] %s" % message)
