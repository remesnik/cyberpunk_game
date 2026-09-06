extends Node

const BindingRequest := preload("res://core/input/GameplayBindingRequest.gd")

var failures := 0
var assertions := 0
var config_path := "user://gameplay_binding_test/bindings.cfg"

func _ready() -> void:
	var bindings := get_node("/root/GameplayBindings")
	_expect(bindings.profile.global_actions.has(&"TOGGLE_MINIMAP") and bindings.profile.global_actions.has(&"TOGGLE_MONITOR") and bindings.profile.global_actions.has(&"TOGGLE_TEAM_STATUS") and bindings.profile.global_actions.has(&"OPEN_NODE_INSPECTOR") and bindings.profile.global_actions.has(&"OPEN_PROGRAM_LOADOUT"), "all HUD commands are configurable global actions")
	_expect(bindings.profile.cyberspace_commands.has(&"SCAN") and bindings.profile.program_bindings.has(&"PROGRAM_SLOT_1"), "global, cyberspace, and program binding namespaces are distinct")
	_expect(InputMap.has_action(&"cyber_scan") and InputMap.has_action(&"toggle_monitor") and InputMap.has_action(&"toggle_team_status") and InputMap.has_action(&"open_node_inspector") and InputMap.has_action(&"program_slot_8"), "profile actions are installed in Godot InputMap")

	var key := InputEventKey.new(); key.physical_keycode = KEY_K
	var key_events: Array[InputEvent] = [key]
	_expect(bindings.rebind(&"cyber_scan", key_events), "cyberspace command can be rebound through configuration API")
	_expect((InputMap.action_get_events(&"cyber_scan")[0] as InputEventKey).physical_keycode == KEY_K, "InputMap receives the rebound keyboard event")
	var pad := InputEventJoypadButton.new(); pad.button_index = JOY_BUTTON_Y
	var pad_events: Array[InputEvent] = [pad]
	_expect(bindings.rebind(&"cyber_attack", pad_events) and InputMap.action_get_events(&"cyber_attack")[0] is InputEventJoypadButton, "bindings accept controller events")

	var emitted: Array[RefCounted] = []
	bindings.binding_triggered.connect(func(request: RefCounted) -> void: emitted.append(request))
	bindings.set_context(bindings.Context.CYBERSPACE)
	bindings._unhandled_input(_action(&"cyber_scan"))
	bindings._unhandled_input(_action(&"program_slot_1"))
	_expect(emitted.size() == 2 and emitted[0].category == BindingRequest.Category.CYBERSPACE_COMMAND and emitted[0].command_id == &"SCAN", "InputMap action resolves to a semantic cyberspace command")
	_expect(emitted[1].category == BindingRequest.Category.PROGRAM_BINDING and emitted[1].slot_index == 0, "program hotkey resolves to a loadout slot rather than a program name")

	var installed: Array[StringName] = [&"ICEBREAKER_INSTANCE_A", &"DOORSTOP_INSTANCE_B"]
	_expect(bindings.resolve_program_instance(emitted[1], installed) == &"ICEBREAKER_INSTANCE_A", "slot binding resolves the current installed instance")
	_expect(bindings.bind_program_instance(&"PROGRAM_SLOT_1", &"DOORSTOP_INSTANCE_B") and bindings.resolve_program_instance(emitted[1], installed) == &"DOORSTOP_INSTANCE_B", "player may bind a specific installed program instance")
	installed.erase(&"DOORSTOP_INSTANCE_B")
	_expect(bindings.resolve_program_instance(emitted[1], installed).is_empty(), "specific binding does not run an instance that is no longer installed")

	emitted.clear(); bindings.set_context(bindings.Context.MEATSPACE)
	bindings._unhandled_input(_action(&"cyber_scan"))
	bindings._unhandled_input(_action(&"network_map"))
	bindings._unhandled_input(_action(&"toggle_monitor"))
	_expect(emitted.size() == 2 and emitted[1].command_id == &"TOGGLE_MONITOR" and emitted[1].category == BindingRequest.Category.GLOBAL_GAME_ACTION, "meat-space context ignores cyber commands while retaining global monitor controls")

	_cleanup()
	bindings.bind_program_instance(&"PROGRAM_SLOT_1", &"ICEBREAKER_INSTANCE_A")
	_expect(bindings.save_configuration(config_path) == OK, "rebinding configuration saves independently of gameplay state")
	bindings.bind_program_instance(&"PROGRAM_SLOT_1", &"")
	InputMap.action_erase_events(&"cyber_scan")
	_expect(bindings.load_configuration(config_path) == OK and not InputMap.action_get_events(&"cyber_scan").is_empty(), "saved keyboard configuration reloads")
	_expect(bindings.explicit_program_instances.get(&"PROGRAM_SLOT_1", &"") == &"ICEBREAKER_INSTANCE_A", "specific program bindings reload")
	bindings.set_context(bindings.Context.DISABLED)
	_cleanup()
	print("%s: %d gameplay binding assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _action(action: StringName) -> InputEventAction:
	var event := InputEventAction.new(); event.action = action; event.pressed = true
	return event

func _cleanup() -> void:
	var file := ProjectSettings.globalize_path(config_path)
	if FileAccess.file_exists(file): DirAccess.remove_absolute(file)
	var directory := ProjectSettings.globalize_path(config_path.get_base_dir())
	if DirAccess.dir_exists_absolute(directory): DirAccess.remove_absolute(directory)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition: failures += 1; printerr("FAILED: %s" % description)
