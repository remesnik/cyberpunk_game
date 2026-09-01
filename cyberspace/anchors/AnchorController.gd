class_name AnchorController
extends RefCounted

signal anchor_activated(node_id: StringName)
signal resources_committed(node_id: StringName, resources: Dictionary)
signal fast_travel_completed(from_node_id: StringName, to_node_id: StringName)

var graph: NetworkGraph
var anchors: Dictionary = {}
var activated_anchor_ids: Array[StringName] = []
var last_anchor_node_id: StringName = &""

func _init(p_graph: NetworkGraph) -> void:
	graph = p_graph

func register_anchor(anchor: AnchorDefinition) -> bool:
	if graph.get_node(anchor.node_id) == null or anchors.has(anchor.node_id):
		return false
	anchors[anchor.node_id] = anchor
	return true

func activate_anchor(node_id: StringName) -> bool:
	if not anchors.has(node_id):
		return false
	last_anchor_node_id = node_id
	if not activated_anchor_ids.has(node_id):
		activated_anchor_ids.append(node_id)
		activated_anchor_ids.sort()
		anchor_activated.emit(node_id)
	return true

func is_active_anchor(node_id: StringName) -> bool:
	return activated_anchor_ids.has(node_id)

func commit_resources(node_id: StringName, resources: PlayerResourceState) -> Dictionary:
	if not is_active_anchor(node_id):
		return {}
	var committed := resources.commit_all()
	resources_committed.emit(node_id, committed)
	return committed

func can_fast_travel(from_node_id: StringName, to_node_id: StringName) -> bool:
	if not is_active_anchor(from_node_id) or not is_active_anchor(to_node_id):
		return false
	var source := anchors[from_node_id] as AnchorDefinition
	var destination := anchors[to_node_id] as AnchorDefinition
	return source.allows_fast_travel and destination.allows_fast_travel

func fast_travel(position: PlayerNetworkPosition, destination_node_id: StringName) -> bool:
	if not can_fast_travel(position.current_node_id, destination_node_id):
		return false
	var origin := position.current_node_id
	position.relocate(destination_node_id)
	last_anchor_node_id = destination_node_id
	fast_travel_completed.emit(origin, destination_node_id)
	return true
