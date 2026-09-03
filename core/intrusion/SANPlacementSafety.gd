class_name SANPlacementSafety
extends RefCounted

const IceBindingProfileScript := preload("res://entities/ice/IceBindingProfile.gd")

signal placement_adjusted(summary: Dictionary)

var graph: NetworkGraph
var _ice_controller_ref: WeakRef
var _san_manager_ref: WeakRef
var player_position: PlayerNetworkPosition
var suspended_host_bound_ice: Dictionary = {}

func _init(p_graph: NetworkGraph, p_ice_controller: IceController, p_player_position: PlayerNetworkPosition = null) -> void:
	graph = p_graph; _ice_controller_ref = weakref(p_ice_controller) if p_ice_controller != null else null; player_position = p_player_position

func bind_san_manager(manager: RefCounted) -> void:
	_san_manager_ref = weakref(manager) if manager != null else null

func prepare_node(target_node_id: StringName, intrusion_id: StringName, relocating_san_id: StringName = &"") -> Dictionary:
	var relocated: Array[Dictionary] = []; var suspended: Array[StringName] = []
	var ice_controller: IceController = _ice_controller_ref.get_ref() as IceController if _ice_controller_ref != null else null
	if graph == null or ice_controller == null or graph.get_node(target_node_id) == null:
		return {"success": false, "reason": "SAN target node is unavailable.", "relocated": relocated, "suspended": suspended}
	var ordered_ids: Array = ice_controller.instances.keys(); ordered_ids.sort_custom(func(a, b): return String(a) < String(b))
	for ice_id in ordered_ids:
		var ice := ice_controller.get_ice(ice_id)
		if ice == null or ice.current_node_id != target_node_id or ice.definition.binding.mode != IceBindingProfileScript.Mode.HOST_BOUND: continue
		var destination := _choose_destination(ice, target_node_id, intrusion_id, relocating_san_id)
		if destination.is_empty():
			_suspend(ice, target_node_id, intrusion_id); suspended.append(ice.instance_id)
		else:
			ice.current_node_id = destination; ice.target_node_id = &""; ice.movement_progress = 0
			relocated.append({"ice_id": ice.instance_id, "from_node_id": target_node_id, "to_node_id": destination})
	var summary := {"success": true, "reason": "SAN host prepared.", "relocated": relocated, "suspended": suspended}
	if not relocated.is_empty() or not suspended.is_empty(): placement_adjusted.emit(summary)
	return summary

func restore_suspended_when_possible(intrusion_id: StringName = &"") -> Array[Dictionary]:
	var restored: Array[Dictionary] = []
	var ids: Array = suspended_host_bound_ice.keys(); ids.sort_custom(func(a, b): return String(a) < String(b))
	for ice_id in ids:
		var record: Dictionary = suspended_host_bound_ice[ice_id]
		if not intrusion_id.is_empty() and record.intrusion_id != intrusion_id: continue
		var ice: IceInstance = record.ice
		var original_node := graph.get_node(record.original_node_id)
		var destination: StringName = record.original_node_id if ice.definition.binding.permits(original_node) and not _contains_other_san(record.original_node_id, record.intrusion_id, &"") else _choose_destination(ice, record.original_node_id, record.intrusion_id, &"")
		if destination.is_empty(): continue
		ice.current_node_id = destination; ice.operational = true; ice.placement_suspended = false
		suspended_host_bound_ice.erase(ice_id); restored.append({"ice_id": ice.instance_id, "to_node_id": destination})
	return restored

func _choose_destination(ice: IceInstance, source_node_id: StringName, intrusion_id: StringName, relocating_san_id: StringName) -> StringName:
	var source := graph.get_node(source_node_id); var candidates: Array[Dictionary] = []
	for node_id in graph.nodes:
		if node_id == source_node_id: continue
		var node := graph.get_node(node_id)
		if not ice.definition.binding.permits(node) or _contains_other_san(node_id, intrusion_id, relocating_san_id): continue
		var distance := _distance(source_node_id, node_id)
		if distance < 0: continue
		var same_region := _node_region(node) == _node_region(source)
		var visible := player_position != null and _distance(player_position.current_node_id, node_id) in [0, 1]
		candidates.append({"id": node_id, "direct": distance == 1, "same_region": same_region, "visible": visible, "distance": distance})
	if candidates.is_empty(): return &""
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.direct != b.direct: return a.direct
		if a.same_region != b.same_region: return a.same_region
		if a.visible != b.visible: return not a.visible
		if a.distance != b.distance: return a.distance < b.distance
		return String(a.id) < String(b.id))
	return candidates[0].id

func _node_region(node: NetworkNodeDefinition) -> StringName:
	return node.security_region_id if not node.security_region_id.is_empty() else node.owner_faction

func _contains_other_san(node_id: StringName, intrusion_id: StringName, relocating_san_id: StringName) -> bool:
	var manager: RefCounted = _san_manager_ref.get_ref() if _san_manager_ref != null else null
	if manager == null: return false
	for san: SystemAccessNode in manager.get_active_at(node_id, intrusion_id):
		if san.id != relocating_san_id: return true
	return false

func _distance(start: StringName, goal: StringName) -> int:
	if start == goal: return 0
	var frontier: Array[StringName] = [start]; var distances := {start: 0}
	while not frontier.is_empty():
		var current: StringName = frontier.pop_front(); var node := graph.get_node(current)
		if node == null: continue
		for link_id in node.connected_links:
			var link := graph.get_link(link_id)
			if link == null or link.disabled or not link.connects_from(current): continue
			var next := link.destination_from(current)
			if distances.has(next): continue
			distances[next] = int(distances[current]) + 1
			if next == goal: return distances[next]
			frontier.append(next)
	return -1

func _suspend(ice: IceInstance, original_node_id: StringName, intrusion_id: StringName) -> void:
	suspended_host_bound_ice[ice.instance_id] = {"ice": ice, "original_node_id": original_node_id, "intrusion_id": intrusion_id}
	ice.placement_suspended = true; ice.operational = false; ice.current_node_id = &""; ice.target_node_id = &""
