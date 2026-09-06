class_name SystemAccessNodeController
extends RefCounted

const SanModel := preload("res://core/san/SystemAccessNode.gd")

signal san_created(san: RefCounted)
signal san_relocated(san: RefCounted, previous_node_id: StringName, current_node_id: StringName)

var graph: NetworkGraph
var player_knowledge: PlayerKnowledge
var local_player_id: StringName
var sans_by_intrusion: Dictionary = {}
var ice_controller: IceController
var suspended_host_bound_ice: Dictionary = {}

func _init(p_graph: NetworkGraph, knowledge: PlayerKnowledge = null, p_local_player_id: StringName = &"PLAYER") -> void:
	graph = p_graph
	player_knowledge = knowledge
	local_player_id = p_local_player_id

func configure_ice_controller(controller: IceController) -> void:
	ice_controller = controller

func create_san(owner_id: StringName, intrusion_id: StringName, deck_id: StringName, host_node_id: StringName, timestamp := 0.0) -> Dictionary:
	if graph == null or graph.get_node(host_node_id) == null: return _failure("SAN host node is invalid.")
	if intrusion_id == &"" or sans_by_intrusion.has(intrusion_id): return _failure("Intrusion already has a System Access Node.")
	_prepare_host_for_san(host_node_id)
	var san: RefCounted = SanModel.new(StringName("SAN_%s_%s" % [owner_id, intrusion_id]), owner_id, intrusion_id, deck_id, host_node_id, timestamp)
	sans_by_intrusion[intrusion_id] = san
	if owner_id == local_player_id and player_knowledge != null: player_knowledge.set_local_system_access_node(host_node_id, san.id, true)
	san_created.emit(san)
	return {"success": true, "san": san, "reason": ""}

func get_san(intrusion_id: StringName) -> RefCounted:
	return sans_by_intrusion.get(intrusion_id) as RefCounted

func relocate_san(intrusion_id: StringName, target_node_id: StringName) -> Dictionary:
	var san: RefCounted = get_san(intrusion_id)
	if san == null: return _failure("Intrusion has no System Access Node.")
	if graph == null or graph.get_node(target_node_id) == null: return _failure("SAN destination node is invalid.")
	var previous: StringName = san.host_node_id
	if previous == target_node_id: return {"success": true, "san": san, "previous_node_id": previous, "node_id": target_node_id, "reason": ""}
	_prepare_host_for_san(target_node_id)
	if san.owner_player_id == local_player_id and player_knowledge != null:
		player_knowledge.set_local_system_access_node(previous, san.id, false)
	san.host_node_id = target_node_id
	if san.owner_player_id == local_player_id and player_knowledge != null:
		player_knowledge.set_local_system_access_node(target_node_id, san.id, true)
	san_relocated.emit(san, previous, target_node_id)
	restore_suspended_host_bound_ice()
	return {"success": true, "san": san, "previous_node_id": previous, "node_id": target_node_id, "reason": ""}

func _prepare_host_for_san(host_node_id: StringName) -> void:
	if ice_controller == null: return
	var ordered_ids: Array = ice_controller.instances.keys()
	ordered_ids.sort_custom(func(a, b): return String(a) < String(b))
	for instance_id in ordered_ids:
		var ice := ice_controller.get_ice(instance_id)
		if ice == null or ice.current_node_id != host_node_id or not ice.definition.is_host_bound(): continue
		var destination := _legal_host_bound_destination(ice, host_node_id)
		if destination != &"":
			ice.current_node_id = destination
		else:
			suspended_host_bound_ice[ice.instance_id] = {"ice": ice, "original_node_id": host_node_id, "was_operational": ice.operational}
			ice.current_node_id = &""
			ice.operational = false

func _legal_host_bound_destination(ice: IceInstance, blocked_node_id: StringName) -> StringName:
	var candidates: Array[StringName] = []
	var source := graph.get_node(blocked_node_id)
	if source == null: return &""
	for link_id in source.connected_links:
		var link := graph.get_link(link_id)
		if link == null or link.disabled: continue
		var candidate := link.destination_from(blocked_node_id)
		if candidate == &"" or candidate == blocked_node_id or not ice.definition.permits_binding_node(candidate): continue
		if _node_hosts_any_san(candidate): continue
		if not candidates.has(candidate): candidates.append(candidate)
	candidates.sort_custom(func(a: StringName, b: StringName):
		var a_hidden := player_knowledge == null or not player_knowledge.player_knows_node_exists(a)
		var b_hidden := player_knowledge == null or not player_knowledge.player_knows_node_exists(b)
		return String(a) < String(b) if a_hidden == b_hidden else a_hidden)
	return candidates[0] if not candidates.is_empty() else &""

func _node_hosts_any_san(node_id: StringName) -> bool:
	for san: RefCounted in sans_by_intrusion.values():
		if san.host_node_id == node_id: return true
	return false

func restore_suspended_host_bound_ice() -> int:
	var restored := 0
	for instance_id in suspended_host_bound_ice.keys().duplicate():
		var record: Dictionary = suspended_host_bound_ice[instance_id]
		var ice: IceInstance = record.ice
		var original: StringName = record.original_node_id
		var destination := original if not _node_hosts_any_san(original) and ice.definition.permits_binding_node(original) else _legal_host_bound_destination(ice, original)
		if destination == &"": continue
		ice.current_node_id = destination
		ice.operational = bool(record.was_operational)
		suspended_host_bound_ice.erase(instance_id)
		restored += 1
	return restored

func reveal_san_to_player(san: RefCounted) -> void:
	if san != null and player_knowledge != null:
		player_knowledge.reveal_node_capability(san.host_node_id, NodeCapabilityType.Value.SYSTEM_ACCESS_NODE, &"SAN_DISCOVERY", san.id)

func _failure(reason: String) -> Dictionary:
	return {"success": false, "san": null, "reason": reason}
