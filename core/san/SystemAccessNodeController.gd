class_name SystemAccessNodeController
extends RefCounted

const SanModel := preload("res://core/san/SystemAccessNode.gd")

signal san_created(san: RefCounted)
signal san_relocated(san: RefCounted, previous_node_id: StringName, current_node_id: StringName)

var graph: NetworkGraph
var player_knowledge: PlayerKnowledge
var local_player_id: StringName
var sans_by_intrusion: Dictionary = {}

func _init(p_graph: NetworkGraph, knowledge: PlayerKnowledge = null, p_local_player_id: StringName = &"PLAYER") -> void:
	graph = p_graph
	player_knowledge = knowledge
	local_player_id = p_local_player_id

func create_san(owner_id: StringName, intrusion_id: StringName, deck_id: StringName, host_node_id: StringName, timestamp := 0.0) -> Dictionary:
	if graph == null or graph.get_node(host_node_id) == null: return _failure("SAN host node is invalid.")
	if intrusion_id == &"" or sans_by_intrusion.has(intrusion_id): return _failure("Intrusion already has a System Access Node.")
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
	if san.owner_player_id == local_player_id and player_knowledge != null:
		player_knowledge.set_local_system_access_node(previous, san.id, false)
	san.host_node_id = target_node_id
	if san.owner_player_id == local_player_id and player_knowledge != null:
		player_knowledge.set_local_system_access_node(target_node_id, san.id, true)
	san_relocated.emit(san, previous, target_node_id)
	return {"success": true, "san": san, "previous_node_id": previous, "node_id": target_node_id, "reason": ""}

func reveal_san_to_player(san: RefCounted) -> void:
	if san != null and player_knowledge != null:
		player_knowledge.reveal_node_capability(san.host_node_id, NodeCapabilityType.Value.SYSTEM_ACCESS_NODE, &"SAN_DISCOVERY", san.id)

func _failure(reason: String) -> Dictionary:
	return {"success": false, "san": null, "reason": reason}
