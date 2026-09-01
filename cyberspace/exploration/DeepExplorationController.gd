class_name DeepExplorationController
extends RefCounted

var graph: NetworkGraph
var anchors: AnchorController
var position: PlayerNetworkPosition
var current_depth := 0
var maximum_depth := 0
var risk_score := 0

func _init(p_graph: NetworkGraph, p_anchors: AnchorController, p_position: PlayerNetworkPosition) -> void:
	graph = p_graph
	anchors = p_anchors
	position = p_position

func update(trace_level: int) -> Dictionary:
	current_depth = distance_from_anchor(position.current_node_id)
	maximum_depth = maxi(maximum_depth, current_depth)
	risk_score = maxi(current_depth, 0) * 10 + maxi(trace_level, 0)
	return {"type": &"EXPLORATION_RISK_UPDATED", "node_id": position.current_node_id, "anchor_node_id": anchors.last_anchor_node_id, "depth": current_depth, "maximum_depth": maximum_depth, "trace": trace_level, "risk_score": risk_score}

func distance_from_anchor(node_id: StringName) -> int:
	var start := anchors.last_anchor_node_id
	if start == &"" or graph.get_node(start) == null or graph.get_node(node_id) == null:
		return -1
	if start == node_id:
		return 0
	var frontier: Array[StringName] = [start]
	var distances: Dictionary = {start: 0}
	while not frontier.is_empty():
		var current := StringName(frontier.pop_front())
		var node := graph.get_node(current)
		var ordered_links := node.connected_links.duplicate()
		ordered_links.sort()
		for link_id in ordered_links:
			var link := graph.get_link(link_id)
			if link == null or link.disabled or not link.connects_from(current):
				continue
			var neighbor := link.destination_from(current)
			if distances.has(neighbor):
				continue
			distances[neighbor] = int(distances[current]) + 1
			if neighbor == node_id:
				return int(distances[neighbor])
			frontier.append(neighbor)
	return -1
