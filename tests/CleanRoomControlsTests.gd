extends Node

const CLEAN_ROOM := preload("res://ui/clean_room/CleanRoom.tscn")

var failures := 0
var assertions := 0

func _ready() -> void:
	var room := CLEAN_ROOM.instantiate() as CleanRoom
	add_child(room)
	room.visible = true
	await get_tree().process_frame
	_expect(room.controls_button.visible and "CONTROLS" in room.controls_button.text, "Controls icon is visible at the Clean-Room edge")
	_expect(not room.controls_button.get_global_rect().intersects(room.go_button.get_global_rect()), "Controls icon does not compete with or overlap GO")

	room.controls_button.pressed.emit()
	_expect(room.controls_sheet.visible, "mouse click opens the controls sheet")
	var all_text := room.primary_bindings.text + room.alternate_bindings.text
	_expect("CONTROLLER" in all_text and "KEYBOARD + MOUSE" in all_text, "controls sheet shows both input schemes")
	_expect("NETSPACE" in all_text and "CLEAN-ROOM" in all_text and "MEATSPACE" in all_text, "controls sheet explains all three play spaces")
	room._on_semantic_action(&"back_action")
	_expect(not room.controls_sheet.visible, "B/Circle or Escape semantic Back closes the sheet")

	room.controls_button.grab_focus()
	room._on_semantic_action(&"primary_action")
	_expect(room.controls_sheet.visible, "A/Cross semantic action opens the focused Controls icon")
	GameplayBindings._set_device_mode(GameplayBindings.DeviceMode.GAMEPAD, 0)
	_expect(room.primary_bindings.text.begins_with("CONTROLLER") and room.primary_bindings.modulate.a > room.alternate_bindings.modulate.a, "gamepad activity promotes controller labels")
	GameplayBindings._set_device_mode(GameplayBindings.DeviceMode.MOUSE_KEYBOARD)
	_expect(room.primary_bindings.text.begins_with("KEYBOARD + MOUSE") and room.primary_bindings.modulate.a > room.alternate_bindings.modulate.a, "mouse/keyboard activity promotes keyboard labels")

	print("%s: %d Clean-Room controls assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
