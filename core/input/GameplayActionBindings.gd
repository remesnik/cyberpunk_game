extends Node

signal binding_triggered(request: RefCounted)
signal bindings_changed(input_action: StringName)
signal program_instance_bound(binding_id: StringName, instance_id: StringName)
signal semantic_action_triggered(action_id: StringName)
signal device_mode_changed(mode: int)
signal joypad_connection_changed(device_id: int, connected: bool, device_name: String)

enum Context { DISABLED, CYBERSPACE, MEATSPACE, CLEAN_ROOM }
enum DeviceMode { MOUSE_KEYBOARD, GAMEPAD }

const LEFT_STICK_DEADZONE := 0.18
const RIGHT_STICK_DEADZONE := 0.23
const SEMANTIC_ACTIONS: Array[StringName] = [&"primary_action", &"back_action", &"execute_program", &"open_loadout", &"open_slot_management", &"previous_slot", &"next_slot", &"previous_context_command", &"next_context_command", &"class_skill", &"recenter_camera"]

const DEFAULT_PROFILE := preload("res://data/input/default_gameplay_bindings.tres")
const BindingRequestScript := preload("res://core/input/GameplayBindingRequest.gd")
const DEFAULT_CONFIG_PATH := "user://settings/gameplay_bindings.cfg"
var profile: Resource = DEFAULT_PROFILE
var context := Context.DISABLED
var explicit_program_instances: Dictionary = {}
var device_mode := DeviceMode.MOUSE_KEYBOARD
var active_joypad_id := -1
var last_action: StringName = &""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_install_default_input_actions()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	if FileAccess.file_exists(DEFAULT_CONFIG_PATH):
		load_configuration(DEFAULT_CONFIG_PATH)

func _unhandled_input(event: InputEvent) -> void:
	if context == Context.DISABLED or not event.is_pressed() or event.is_echo(): return
	for action: StringName in SEMANTIC_ACTIONS:
		if event.is_action_pressed(action):
			last_action = action; semantic_action_triggered.emit(action); get_viewport().set_input_as_handled(); return
	for command: Variant in profile.global_actions:
		if event.is_action_pressed(profile.global_actions[command]):
			_emit_request(BindingRequestScript.Category.GLOBAL_GAME_ACTION, StringName(command), StringName(profile.global_actions[command])); get_viewport().set_input_as_handled(); return
	if context != Context.CYBERSPACE: return
	for command: Variant in profile.cyberspace_commands:
		if event.is_action_pressed(profile.cyberspace_commands[command]):
			_emit_request(BindingRequestScript.Category.CYBERSPACE_COMMAND, StringName(command), StringName(profile.cyberspace_commands[command])); get_viewport().set_input_as_handled(); return
	for command: Variant in profile.program_bindings:
		if event.is_action_pressed(profile.program_bindings[command]):
			_emit_request(BindingRequestScript.Category.PROGRAM_BINDING, StringName(command), StringName(profile.program_bindings[command])); get_viewport().set_input_as_handled(); return

func set_context(next_context: Context) -> void:
	context = next_context

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		if event.pressed: _set_device_mode(DeviceMode.GAMEPAD, event.device)
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) >= (LEFT_STICK_DEADZONE if event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y] else RIGHT_STICK_DEADZONE): _set_device_mode(DeviceMode.GAMEPAD, event.device)
	elif event is InputEventKey or event is InputEventMouseButton:
		if event.is_pressed(): _set_device_mode(DeviceMode.MOUSE_KEYBOARD)
	elif event is InputEventMouseMotion and event.relative.length() >= 2.0:
		_set_device_mode(DeviceMode.MOUSE_KEYBOARD)

func camera_pan_vector() -> Vector2:
	return Input.get_vector(&"move_camera_left", &"move_camera_right", &"move_camera_backward", &"move_camera_forward", LEFT_STICK_DEADZONE)

func focus_vector() -> Vector2:
	return Input.get_vector(&"focus_left", &"focus_right", &"focus_up", &"focus_down", RIGHT_STICK_DEADZONE)

func control_hint(keyboard: String, gamepad: String) -> String:
	return gamepad if device_mode == DeviceMode.GAMEPAD else keyboard

func _set_device_mode(mode: DeviceMode, joy_id := -1) -> void:
	if mode == DeviceMode.GAMEPAD: active_joypad_id = joy_id
	if device_mode == mode: return
	device_mode = mode; device_mode_changed.emit(device_mode)

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	var joy_name := Input.get_joy_name(device) if connected else ""
	if not connected and device == active_joypad_id:
		active_joypad_id = -1; _set_device_mode(DeviceMode.MOUSE_KEYBOARD)
	joypad_connection_changed.emit(device, connected, joy_name)
	if OS.is_debug_build(): print("[Input] Joypad %s: id=%d name=%s" % ["connected" if connected else "disconnected", device, joy_name])

func rebind(input_action: StringName, events: Array[InputEvent]) -> bool:
	if input_action not in profile.all_input_actions(): return false
	if not InputMap.has_action(input_action): InputMap.add_action(input_action)
	InputMap.action_erase_events(input_action)
	for event in events:
		if event != null: InputMap.action_add_event(input_action, event)
	bindings_changed.emit(input_action)
	return true

func bind_program_instance(binding_id: StringName, instance_id: StringName) -> bool:
	if not profile.program_bindings.has(binding_id): return false
	if instance_id.is_empty(): explicit_program_instances.erase(binding_id)
	else: explicit_program_instances[binding_id] = instance_id
	bindings_changed.emit(StringName(profile.program_bindings[binding_id]))
	program_instance_bound.emit(binding_id, instance_id)
	return true

func get_binding_label(input_action: StringName) -> String:
	var events := InputMap.action_get_events(input_action)
	if events.is_empty(): return "UNBOUND"
	return (events[0] as InputEvent).as_text()

func resolve_program_instance(request: RefCounted, installed_instance_ids: Array[StringName]) -> StringName:
	if request.category != BindingRequestScript.Category.PROGRAM_BINDING: return &""
	var explicit := StringName(explicit_program_instances.get(request.command_id, &""))
	if not explicit.is_empty(): return explicit if explicit in installed_instance_ids else &""
	return installed_instance_ids[request.slot_index] if request.slot_index >= 0 and request.slot_index < installed_instance_ids.size() else &""

func save_configuration(path := DEFAULT_CONFIG_PATH) -> Error:
	var absolute_directory := ProjectSettings.globalize_path(path.get_base_dir())
	var error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if error != OK: return error
	var config := ConfigFile.new()
	for action in profile.all_input_actions():
		var encoded := PackedStringArray()
		for event in InputMap.action_get_events(action): encoded.append(var_to_str(event))
		config.set_value("input", String(action), encoded)
	for binding: Variant in explicit_program_instances: config.set_value("program_instances", String(binding), String(explicit_program_instances[binding]))
	return config.save(path)

func load_configuration(path := DEFAULT_CONFIG_PATH) -> Error:
	var config := ConfigFile.new()
	var error := config.load(path)
	if error != OK: return error
	for action in profile.all_input_actions():
		if not config.has_section_key("input", String(action)): continue
		var events: Array[InputEvent] = []
		for encoded: String in config.get_value("input", String(action), PackedStringArray()):
			var decoded: Variant = str_to_var(encoded)
			if decoded is InputEvent: events.append(decoded)
		rebind(action, events)
	explicit_program_instances.clear()
	for key in config.get_section_keys("program_instances"): explicit_program_instances[StringName(key)] = StringName(config.get_value("program_instances", key, ""))
	return OK

func _emit_request(category: int, command: StringName, action: StringName) -> void:
	var request: RefCounted = BindingRequestScript.new(category, command, action)
	if category == BindingRequestScript.Category.PROGRAM_BINDING:
		request.slot_index = int(String(command).trim_prefix("PROGRAM_SLOT_")) - 1
		request.program_instance_id = StringName(explicit_program_instances.get(command, &""))
	binding_triggered.emit(request)

func _install_default_input_actions() -> void:
	var defaults := {
		&"game_inventory": KEY_I, &"network_map": KEY_M, &"gameplay_jack_out": KEY_J, &"toggle_monitor": KEY_C,
		&"toggle_team_status": KEY_Y, &"open_node_inspector": KEY_N,
		&"cyber_scan": KEY_R, &"cyber_inspect": KEY_F, &"cyber_confirm": KEY_E,
		&"cyber_attack": KEY_X, &"cyber_evade": KEY_V, &"cyber_target_previous": KEY_Q,
		&"cyber_target_next": KEY_TAB, &"cyber_cancel": KEY_BACKSPACE,
		&"comms_intercept": KEY_T,
		&"program_slot_1": KEY_1, &"program_slot_2": KEY_2, &"program_slot_3": KEY_3,
		&"program_slot_4": KEY_4, &"program_slot_5": KEY_5, &"program_slot_6": KEY_6,
		&"program_slot_7": KEY_7, &"program_slot_8": KEY_8,
	}
	for action: StringName in defaults:
		if InputMap.has_action(action): continue
		InputMap.add_action(action)
		var event := InputEventKey.new(); event.physical_keycode = defaults[action]
		InputMap.action_add_event(action, event)
	_install_semantic_actions()

func _install_semantic_actions() -> void:
	_add_action(&"move_camera_left", [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)], LEFT_STICK_DEADZONE)
	_add_action(&"move_camera_right", [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)], LEFT_STICK_DEADZONE)
	_add_action(&"move_camera_forward", [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)], LEFT_STICK_DEADZONE)
	_add_action(&"move_camera_backward", [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)], LEFT_STICK_DEADZONE)
	_add_action(&"focus_left", [_axis(JOY_AXIS_RIGHT_X, -1.0)], RIGHT_STICK_DEADZONE)
	_add_action(&"focus_right", [_axis(JOY_AXIS_RIGHT_X, 1.0)], RIGHT_STICK_DEADZONE)
	_add_action(&"focus_up", [_axis(JOY_AXIS_RIGHT_Y, -1.0)], RIGHT_STICK_DEADZONE)
	_add_action(&"focus_down", [_axis(JOY_AXIS_RIGHT_Y, 1.0)], RIGHT_STICK_DEADZONE)
	_add_action(&"primary_action", [_key(KEY_ENTER), _mouse(MOUSE_BUTTON_LEFT), _button(JOY_BUTTON_A)])
	_add_action(&"back_action", [_key(KEY_ESCAPE), _mouse(MOUSE_BUTTON_RIGHT), _button(JOY_BUTTON_B)])
	_add_action(&"execute_program", [_key(KEY_F), _button(JOY_BUTTON_X), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
	_add_action(&"open_loadout", [_button(JOY_BUTTON_Y)])
	_add_action(&"open_slot_management", [_key(KEY_TAB), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)])
	_add_action(&"previous_slot", [_key(KEY_Q), _button(JOY_BUTTON_LEFT_SHOULDER)])
	_add_action(&"next_slot", [_key(KEY_E), _button(JOY_BUTTON_RIGHT_SHOULDER)])
	_add_action(&"previous_context_command", [_key(KEY_Z), _button(JOY_BUTTON_DPAD_LEFT)])
	_add_action(&"next_context_command", [_key(KEY_PERIOD), _button(JOY_BUTTON_DPAD_RIGHT)])
	_add_action(&"class_skill", [_key(KEY_U), _button(JOY_BUTTON_DPAD_UP)])
	_add_action(&"recenter_camera", [_key(KEY_SPACE), _button(JOY_BUTTON_RIGHT_STICK)])
	_add_action(&"pause_game", [_button(JOY_BUTTON_START)])

func _add_action(id: StringName, events: Array, deadzone := 0.5) -> void:
	if not InputMap.has_action(id): InputMap.add_action(id, deadzone)
	for event: InputEvent in events:
		if not InputMap.action_has_event(id, event): InputMap.action_add_event(id, event)
func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new(); event.physical_keycode = code; return event
func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new(); event.button_index = button; return event
func _button(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new(); event.button_index = button; return event
func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new(); event.axis = axis; event.axis_value = value; return event
