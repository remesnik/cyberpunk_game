extends Node

signal binding_triggered(request: RefCounted)
signal bindings_changed(input_action: StringName)
signal program_instance_bound(binding_id: StringName, instance_id: StringName)

enum Context { DISABLED, CYBERSPACE, MEATSPACE }

const DEFAULT_PROFILE := preload("res://data/input/default_gameplay_bindings.tres")
const BindingRequestScript := preload("res://core/input/GameplayBindingRequest.gd")
const DEFAULT_CONFIG_PATH := "user://settings/gameplay_bindings.cfg"
var profile: Resource = DEFAULT_PROFILE
var context := Context.DISABLED
var explicit_program_instances: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_install_default_input_actions()
	if FileAccess.file_exists(DEFAULT_CONFIG_PATH):
		load_configuration(DEFAULT_CONFIG_PATH)

func _unhandled_input(event: InputEvent) -> void:
	if context == Context.DISABLED or not event.is_pressed() or event.is_echo(): return
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
