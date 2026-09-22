class_name SecurityResponseController
extends RefCounted

signal security_event_handled(event: Dictionary, sleeve_results: Array[Dictionary])
signal escalation_effect_applied(sleeve_id: StringName, effect: Dictionary)

var graph: NetworkGraph
var ice_controller: IceController
var profile: SecurityEscalationProfile
var _spawn_serial := 0
var _effect_handlers: Dictionary

func _init(p_graph: NetworkGraph, p_ice_controller: IceController, p_profile: SecurityEscalationProfile) -> void:
	graph = p_graph
	ice_controller = p_ice_controller
	profile = p_profile
	_effect_handlers = {
		&"PATH_DIFFICULTY": _apply_path_difficulty,
		&"SPAWN_STATIONARY_ICE": _spawn_stationary_ice,
		&"SYSTEM_TRACE": _start_system_trace,
		&"PUNITIVE_TAG": _apply_punitive_tag,
		&"ACCESS_DIFFICULTY": _apply_access_difficulty,
		&"SHUTDOWN_SYSTEM": _shutdown_system,
	}
	if graph != null and not graph.security_event_reported.is_connected(handle_security_event): graph.security_event_reported.connect(handle_security_event)

func handle_security_event(event: Dictionary) -> void:
	var node_id := StringName(event.get("source_node", event.get("node_id", &"")))
	if graph == null or graph.get_node(node_id) == null: return
	var results: Array[Dictionary] = []
	for sleeve_id: StringName in graph.get_current_sleeve_ids_for_node(node_id):
		var sleeve := graph.get_security_sleeve(sleeve_id)
		if sleeve == null: continue
		var result := sleeve.receive_security_event(event, profile)
		result["sleeve_id"] = sleeve_id
		results.append(result)
		for effect: Dictionary in result.effects: _apply_effect(sleeve, effect, node_id)
	_apply_local_ice_response(node_id, event)
	security_event_handled.emit(event, results)

func access_difficulty_modifier(node_id: StringName) -> int:
	var value := 0
	for sleeve_id: StringName in graph.get_current_sleeve_ids_for_node(node_id):
		var sleeve := graph.get_security_sleeve(sleeve_id)
		if sleeve != null: value = maxi(value, int(sleeve.metadata.get("access_difficulty_modifier", 0)))
	return value

func path_unlock_difficulty_modifier(node_id: StringName) -> int:
	var value := 0
	for sleeve_id: StringName in graph.get_current_sleeve_ids_for_node(node_id):
		var sleeve := graph.get_security_sleeve(sleeve_id)
		if sleeve != null: value = maxi(value, int(sleeve.metadata.get("path_unlock_difficulty_modifier", 0)))
	return value

func active_system_trace_pressure() -> int:
	var value := 0
	for sleeve: SecuritySleeve in graph.security_sleeves.values(): value = maxi(value, int(sleeve.metadata.get("system_trace_pressure", 0)))
	return value

func _apply_effect(sleeve: SecuritySleeve, effect: Dictionary, source_node: StringName) -> void:
	var handler: Callable = _effect_handlers.get(StringName(effect.get("type", &"")), Callable())
	if handler.is_valid():
		handler.call(sleeve, effect, source_node)
		escalation_effect_applied.emit(sleeve.id, effect)

func _apply_local_ice_response(node_id: StringName, event: Dictionary) -> void:
	if ice_controller == null: return
	for ice: IceInstance in ice_controller.instances.values():
		if not ice.operational or ice.current_node_id != node_id: continue
		ice.state = IceState.Value.ENGAGE
		ice.target_node_id = node_id
		ice.known_player_position = node_id
		ice.alert_level = mini(100, ice.alert_level + 10 * maxi(1, int(event.get("severity", 1))))
		ice_controller.ice_updated.emit(ice)

func _apply_path_difficulty(sleeve: SecuritySleeve, effect: Dictionary, _source_node: StringName) -> void:
	sleeve.metadata["path_unlock_difficulty_modifier"] = int(effect.get("value", 0))

func _apply_access_difficulty(sleeve: SecuritySleeve, effect: Dictionary, _source_node: StringName) -> void:
	sleeve.metadata["access_difficulty_modifier"] = int(effect.get("value", 0))

func _start_system_trace(sleeve: SecuritySleeve, effect: Dictionary, _source_node: StringName) -> void:
	sleeve.metadata["system_trace_active"] = true
	sleeve.metadata["system_trace_pressure"] = int(effect.get("pressure", 1))

func _apply_punitive_tag(sleeve: SecuritySleeve, effect: Dictionary, _source_node: StringName) -> void:
	var tags: Array = sleeve.metadata.get("punitive_tags", []).duplicate()
	var tag := StringName(effect.get("tag", &""))
	if not tag.is_empty() and not tags.has(tag): tags.append(tag)
	sleeve.metadata["punitive_tags"] = tags

func _spawn_stationary_ice(sleeve: SecuritySleeve, effect: Dictionary, source_node: StringName) -> void:
	if ice_controller == null: return
	var tier := maxi(1, int(effect.get("tier", 1)))
	for unused in maxi(0, int(effect.get("count", 1))):
		_spawn_serial += 1
		var definition := IceDefinition.new(StringName("SLEEVE_STATIONARY_T%d" % tier), "Stationary Sleeve ICE T%d" % tier, tier + 1, 999999, tier, [], 4 + tier * 3, tier + 1)
		definition.binding_mode = IceDefinition.BindingMode.HOST_BOUND
		definition.allowed_binding_node_ids.assign([source_node])
		var instance := IceInstance.new(StringName("%s_STATIONARY_%04d" % [sleeve.id, _spawn_serial]), definition, source_node, IceState.Value.DORMANT)
		ice_controller.add_ice(instance)

func _shutdown_system(sleeve: SecuritySleeve, _effect: Dictionary, _source_node: StringName) -> void:
	sleeve.metadata["system_shutdown"] = true
	for link: NetworkLinkDefinition in graph.links.values():
		if sleeve.contains_node(link.source) or sleeve.contains_node(link.destination): link.disabled = true
	graph.display_update_requested.emit()
