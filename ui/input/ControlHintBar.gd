class_name ControlHintBar
extends Label
## Small reusable prompt that follows the last meaningful input device.

@export_multiline var keyboard_text := ""
@export_multiline var gamepad_text := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameplayBindings.device_mode_changed.connect(_on_device_mode_changed)
	_refresh()

func _exit_tree() -> void:
	if GameplayBindings.device_mode_changed.is_connected(_on_device_mode_changed):
		GameplayBindings.device_mode_changed.disconnect(_on_device_mode_changed)

func _on_device_mode_changed(_mode: int) -> void:
	_refresh()

func _refresh() -> void:
	text = GameplayBindings.control_hint(keyboard_text, gamepad_text)
