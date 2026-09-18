class_name InputDebugPanel
extends PanelContainer
## Opt-in physical-controller diagnostics. Disabled in the shipped scene.

@export var enabled := false:
	set(value):
		enabled = value
		visible = value and OS.is_debug_build()

var readout: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	readout = Label.new()
	readout.add_theme_font_size_override("font_size", 14)
	add_child(readout)
	visible = enabled and OS.is_debug_build()

func _process(_delta: float) -> void:
	if not visible: return
	var joy := GameplayBindings.active_joypad_id
	var left := Vector2.ZERO; var right := Vector2.ZERO
	if joy >= 0:
		left = Vector2(Input.get_joy_axis(joy, JOY_AXIS_LEFT_X), Input.get_joy_axis(joy, JOY_AXIS_LEFT_Y))
		right = Vector2(Input.get_joy_axis(joy, JOY_AXIS_RIGHT_X), Input.get_joy_axis(joy, JOY_AXIS_RIGHT_Y))
	var display := get_tree().root.find_child("NetworkDisplay", true, false)
	var slot := int(display.get("_selected_active_slot")) + 1 if display != null else 0
	var focus_mode := String(display.get("netspace_view_mode")) if display != null else "--"
	var focused_node := String(display.get("focused_node_id")) if display != null else "--"
	var focused_local := String(display.get("focused_local_target_id")) if display != null else "--"
	var command := String(display.get("selected_command_id")) if display != null else "--"
	var room := get_tree().root.find_child("PlayerBedroom", true, false)
	var meatspace_focus := String(room.get("focused_id")) if room != null else "--"
	var hovered := get_viewport().gui_get_hovered_control()
	var blocker := "NONE"
	if hovered != null and hovered != room and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		blocker = String(hovered.get_path())
	var domain: String = ["MEATSPACE", "CLEAN_ROOM", "NETSPACE"][Game.game_domain] if Game.game_domain >= 0 and Game.game_domain < 3 else str(Game.game_domain)
	var current_mode: String = ("NODE_FOCUS" if int(display.get("netspace_view_mode")) == 1 else "NETWORK") if display != null and Game.game_domain == Game.GameDomain.CYBERSPACE else domain
	readout.text = "ACTIVE DEVICE: %s\nMOUSE POS: %s\nPRIMARY ACTION: %s\nWORLD CLICK BLOCKED BY: %s\nCURRENT MODE: %s\nJOY ID: %d\nJOY NAME: %s\nLEFT STICK:  x=%.2f  y=%.2f\nRIGHT STICK: x=%.2f  y=%.2f\nFOCUSED MEATSPACE TARGET: %s\nFOCUS MODE: %s\nFOCUSED NODE: %s\nFOCUSED LOCAL TARGET: %s\nSELECTED COMMAND: %s\nSELECTED ACTIVE SLOT: %d\nLAST INPUT ACTION: %s" % [
		"GAMEPAD" if GameplayBindings.device_mode == GameplayBindings.DeviceMode.GAMEPAD else "MOUSE_KEYBOARD",
		get_viewport().get_mouse_position(), "PRESSED" if Input.is_action_pressed(&"primary_action") else "NOT PRESSED", blocker, current_mode,
		joy, Input.get_joy_name(joy) if joy >= 0 else "--", left.x, left.y, right.x, right.y,
		meatspace_focus if meatspace_focus != "" else "--", focus_mode if focus_mode != "" else "--", focused_node if focused_node != "" else "--", focused_local if focused_local != "" else "--", command if command != "" else "--", slot, GameplayBindings.last_action if GameplayBindings.last_action != &"" else "--"]
