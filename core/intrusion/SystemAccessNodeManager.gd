class_name SystemAccessNodeManager
extends RefCounted

signal san_created(san: SystemAccessNode)
signal san_relocated(san: SystemAccessNode, previous_host_node_id: StringName)
signal san_destroyed(san: SystemAccessNode)

var instances: Dictionary = {}
var _connection_ids: Dictionary = {}
var _sequence := 0
var placement_safety: RefCounted

func configure_placement_safety(safety: RefCounted) -> void:
	placement_safety = safety
	if placement_safety != null: placement_safety.bind_san_manager(self)

func create_san(
		owner_player_id: StringName,
		intrusion_id: StringName,
		deck_id: StringName,
		host_node_id: StringName,
		created_at := 0.0,
		integrity := 100
) -> Dictionary:
	if owner_player_id.is_empty() or intrusion_id.is_empty() or deck_id.is_empty() or host_node_id.is_empty():
		return _failure("SAN requires owner, intrusion, deck, and host node IDs.")
	var key := _key(owner_player_id, intrusion_id)
	if _connection_ids.has(key):
		return _failure("This actor already has a System Access Node for the intrusion.")
	if placement_safety != null:
		var preparation: Dictionary = placement_safety.prepare_node(host_node_id, intrusion_id)
		if not preparation.success: return _failure(preparation.reason)
	_sequence += 1
	var san := SystemAccessNode.new(StringName("SAN_%06d" % _sequence), owner_player_id, intrusion_id, deck_id, host_node_id, created_at, integrity)
	instances[san.id] = san
	_connection_ids[key] = san.id
	san_created.emit(san)
	if placement_safety != null: placement_safety.restore_suspended_when_possible(intrusion_id)
	return {"success": true, "reason": "", "san": san}

func get_san(san_id: StringName) -> SystemAccessNode:
	return instances.get(san_id) as SystemAccessNode

func get_for_connection(owner_player_id: StringName, intrusion_id: StringName) -> SystemAccessNode:
	return get_san(_connection_ids.get(_key(owner_player_id, intrusion_id), &""))

func get_active_at(host_node_id: StringName, intrusion_id: StringName = &"") -> Array[SystemAccessNode]:
	var found: Array[SystemAccessNode] = []
	for san: SystemAccessNode in instances.values():
		if san.active and san.host_node_id == host_node_id and (intrusion_id.is_empty() or san.intrusion_id == intrusion_id): found.append(san)
	return found

func relocate(san_id: StringName, host_node_id: StringName) -> Dictionary:
	var san := get_san(san_id)
	if san == null or not san.active: return _failure("System Access Node is unavailable.")
	if host_node_id.is_empty(): return _failure("SAN host node is required.")
	if placement_safety != null:
		var preparation: Dictionary = placement_safety.prepare_node(host_node_id, san.intrusion_id, san.id)
		if not preparation.success: return _failure(preparation.reason)
	var previous := san.host_node_id
	if not san.relocate(host_node_id): return _failure("System Access Node could not be relocated.")
	san_relocated.emit(san, previous)
	if placement_safety != null: placement_safety.restore_suspended_when_possible(san.intrusion_id)
	return {"success": true, "reason": "", "san": san}

func destroy_san(san_id: StringName) -> bool:
	var san := get_san(san_id)
	if san == null or not san.active: return false
	san.destroy(); san_destroyed.emit(san)
	if placement_safety != null: placement_safety.restore_suspended_when_possible(san.intrusion_id)
	return true

func _key(owner_player_id: StringName, intrusion_id: StringName) -> String:
	return "%s::%s" % [intrusion_id, owner_player_id]

func _failure(reason: String) -> Dictionary:
	return {"success": false, "reason": reason, "san": null}
