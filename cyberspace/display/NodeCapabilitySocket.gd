class_name NodeCapabilitySocket
extends Control

signal activated(capability_type: int)
signal focus_changed(socket: int, focused: bool)

var socket_index := -1
var capability_type := -1

func configure(socket: int, capability: int, tooltip: String, hit_size: float) -> void:
	socket_index = socket
	capability_type = capability
	custom_minimum_size = Vector2.ONE * hit_size
	size = custom_minimum_size
	tooltip_text = tooltip
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_entered.connect(func() -> void: focus_changed.emit(socket_index, true))
	focus_exited.connect(func() -> void: focus_changed.emit(socket_index, false))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		grab_focus()
		activated.emit(capability_type)
		accept_event()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_SPACE]:
		activated.emit(capability_type)
		accept_event()

