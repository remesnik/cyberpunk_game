class_name SensorTopologyController
extends RefCounted
## Converts authoritative nearby topology into sanitized, player-specific knowledge.
## Detected knowledge persists; the current view is recalculated from position/rating.
signal sensor_view_changed

const SOURCE := &"DECK_SENSORS"

var graph: NetworkGraph
var position: PlayerNetworkPosition
var knowledge: PlayerKnowledge
var sensors_rating := 0
var _current_view: Dictionary = {"nodes": [], "edges": [], "depths": {}}

static func get_sensor_lookahead_depth(rating: int) -> int:
	if rating >= 3: return 2
	if rating >= 1: return 1
	return 0

func configure(p_graph: NetworkGraph, p_position: PlayerNetworkPosition, p_knowledge: PlayerKnowledge, rating: int) -> void:
	_disconnect_models()
	graph = p_graph
	position = p_position
	knowledge = p_knowledge
	sensors_rating = maxi(0, rating)
	if position != null: position.position_changed.connect(_on_position_changed)
	if graph != null: graph.display_update_requested.connect(recalculate)
	recalculate()

func set_sensors_rating(rating: int) -> void:
	var normalized := maxi(0, rating)
	if sensors_rating == normalized: return
	sensors_rating = normalized
	recalculate()

func maximum_bfs_depth() -> int:
	return 1 + get_sensor_lookahead_depth(sensors_rating)

func current_view() -> Dictionary:
	return _current_view.duplicate(true)

func debug_lines() -> PackedStringArray:
	var lines := PackedStringArray(["SENSORS %d // EXTRA %d // BFS MAX %d" % [sensors_rating, get_sensor_lookahead_depth(sensors_rating), maximum_bfs_depth()]])
	var depths: Dictionary = _current_view.get("depths", {})
	var ids: Array = depths.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		var depth_a := int(depths[a]); var depth_b := int(depths[b])
		return String(a) < String(b) if depth_a == depth_b else depth_a < depth_b)
	for id: Variant in ids:
		var depth := int(depths[id])
		var state := "CURRENT" if depth == 0 else ("IDENTIFIED" if knowledge.knows_node(StringName(id)) else "DETECTED:SENSORS")
		lines.append("Node %s [%s] depth=%d" % [id, state, depth])
	return lines

func recalculate() -> void:
	if graph == null or position == null or knowledge == null or graph.get_node(position.current_node_id) == null:
		_current_view = {"nodes": [], "edges": [], "depths": {}}
		sensor_view_changed.emit()
		return
	var max_depth := maximum_bfs_depth()
	var queue: Array[Dictionary] = [{"id": position.current_node_id, "depth": 0}]
	var visited := {position.current_node_id: true}
	var depths := {position.current_node_id: 0}
	var nodes: Array[Dictionary] = [{"node_id": position.current_node_id, "depth": 0, "knowledge": knowledge.get_node_view(position.current_node_id)}]
	var edges: Array[Dictionary] = []
	var cursor := 0
	while cursor < queue.size():
		var item: Dictionary = queue[cursor]
		cursor += 1
		var source_id := StringName(item.id)
		var depth := int(item.depth)
		if depth >= max_depth: continue
		var source := graph.get_node(source_id)
		for link_id: StringName in source.connected_links:
			var link := graph.get_link(link_id)
			if link == null or link.disabled or link.hidden and not link.discovered or not link.connects_from(source_id): continue
			var destination_id := link.destination_from(source_id)
			if destination_id == &"" or visited.has(destination_id): continue
			var next_depth := depth + 1
			visited[destination_id] = true
			depths[destination_id] = next_depth
			queue.append({"id": destination_id, "depth": next_depth})
			edges.append({"link_id": link.id, "source": source_id, "destination": destination_id, "depth": next_depth})
			if next_depth == 1:
				knowledge.reveal_node(graph.get_node(destination_id), KnowledgeLevel.Value.IDENTIFIED)
				knowledge.reveal_link(link, KnowledgeLevel.Value.IDENTIFIED)
			else:
				knowledge.reveal_topology_node(graph.get_node(destination_id), SOURCE)
				knowledge.reveal_topology_link(link, SOURCE)
			nodes.append({"node_id": destination_id, "depth": next_depth, "knowledge": knowledge.get_node_view(destination_id)})
	_current_view = {"nodes": nodes, "edges": edges, "depths": depths, "rating": sensors_rating, "extra_depth": get_sensor_lookahead_depth(sensors_rating), "maximum_depth": max_depth}
	sensor_view_changed.emit()

func _on_position_changed(_from: StringName, _to: StringName, _link: StringName) -> void:
	recalculate()

func _disconnect_models() -> void:
	if position != null and position.position_changed.is_connected(_on_position_changed): position.position_changed.disconnect(_on_position_changed)
	if graph != null and graph.display_update_requested.is_connected(recalculate): graph.display_update_requested.disconnect(recalculate)

func refresh_for_knowledge_change() -> void:
	# Identity/scan changes do not alter range, but consumers need fresh sanitized views.
	recalculate()
