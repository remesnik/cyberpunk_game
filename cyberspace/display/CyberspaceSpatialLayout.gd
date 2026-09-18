class_name CyberspaceSpatialLayout
extends RefCounted

const NODE_BASE_HEIGHT := 0.0
const LAYER_DEPTH := 12.0
const BRANCH_WIDTH := 10.0
const CAMERA_DISTANCE := 26.0
const FOCAL_LENGTH := 620.0

var anchors: Dictionary = {}
var depths: Dictionary = {}
var lanes: Dictionary = {}
var primary_parents: Dictionary = {}
var edge_endpoints: Dictionary = {}
var edge_lengths: Dictionary = {}
var root_id: StringName = &""
var camera_anchor := Vector3.ZERO
var camera_from := Vector3.ZERO
var camera_to := Vector3.ZERO
var transition_progress := 1.0
var _camera_initialized := false
var _graph_instance_id := 0

func configure(graph: NetworkGraph, preferred_root: StringName) -> void:
	if graph == null: clear(); return
	var graph_instance_id := graph.get_instance_id()
	if _graph_instance_id != 0 and _graph_instance_id != graph_instance_id: clear()
	_graph_instance_id = graph_instance_id
	if root_id == &"":
		root_id = preferred_root
		_build_initial_layout(graph)
	else: _assign_new_nodes(graph)
	_cache_new_edges(graph)
	if anchors.has(preferred_root) and not _camera_initialized:
		camera_anchor = anchors[preferred_root]; _camera_initialized = true

func clear() -> void:
	anchors.clear(); depths.clear(); lanes.clear(); primary_parents.clear(); edge_endpoints.clear(); edge_lengths.clear()
	root_id = &""; camera_anchor = Vector3.ZERO; transition_progress = 1.0; _camera_initialized = false; _graph_instance_id = 0

func _build_initial_layout(graph: NetworkGraph) -> void:
	var traversal := _rooted_traversal(graph)
	depths = traversal.depths; primary_parents = traversal.parents
	var ids: Array = graph.nodes.keys(); ids.sort_custom(_sort_ids)
	var layers: Dictionary = {}
	for id_value: Variant in ids:
		var id := StringName(id_value)
		if not depths.has(id):
			depths[id] = _deepest_layer() + 1
		var layer: Array = layers.get(int(depths[id]), [])
		layer.append(id); layers[int(depths[id])] = layer
	for depth_value: Variant in layers:
		var layer: Array = layers[depth_value]
		for index in layer.size():
			var id := StringName(layer[index])
			lanes[id] = float(index) - float(layer.size() - 1) * 0.5
			_commit_anchor(id)

func _rooted_traversal(graph: NetworkGraph) -> Dictionary:
	var result_depths := {}; var parents := {}; var children := {}
	if not graph.nodes.has(root_id): return {"depths": result_depths, "parents": parents, "children": children}
	result_depths[root_id] = 0
	var queue: Array[StringName] = [root_id]
	while not queue.is_empty():
		var source: StringName = queue.pop_front()
		var neighbors := graph.get_visible_connected_nodes(source); neighbors.sort_custom(_sort_ids)
		for destination: StringName in neighbors:
			if result_depths.has(destination): continue
			result_depths[destination] = int(result_depths[source]) + 1; parents[destination] = source
			var branch: Array = children.get(source, []); branch.append(destination); children[source] = branch
			queue.append(destination)
	return {"depths": result_depths, "parents": parents, "children": children}

func _assign_subtree_lane(node_id: StringName, children: Dictionary, next_leaf: Array) -> float:
	var branch: Array = children.get(node_id, [])
	if branch.is_empty():
		var leaf_lane := float(next_leaf[0]); next_leaf[0] = leaf_lane + 1.0; lanes[node_id] = leaf_lane; return leaf_lane
	var child_lanes: Array[float] = []
	for child_value: Variant in branch: child_lanes.append(_assign_subtree_lane(StringName(child_value), children, next_leaf))
	var lane := (child_lanes[0] + child_lanes[child_lanes.size() - 1]) * 0.5; lanes[node_id] = lane; return lane

func _assign_new_nodes(graph: NetworkGraph) -> void:
	var traversal := _rooted_traversal(graph)
	var ids: Array = graph.nodes.keys(); ids.sort_custom(_sort_ids)
	for id_value: Variant in ids:
		var id := StringName(id_value)
		if anchors.has(id): continue
		var depth := int((traversal.depths as Dictionary).get(id, _deepest_layer() + 1))
		var parent := StringName((traversal.parents as Dictionary).get(id, &""))
		depths[id] = depth; primary_parents[id] = parent
		lanes[id] = _nearest_free_lane(depth, float(lanes.get(parent, 0.0)))
		_commit_anchor(id)

func _nearest_free_lane(depth: int, preferred: float) -> float:
	var occupied: Array[float] = []
	for id_value: Variant in lanes:
		if int(depths.get(id_value, -1)) == depth: occupied.append(float(lanes[id_value]))
	if not occupied.has(preferred): return preferred
	for distance in range(1, occupied.size() + 2):
		if not occupied.has(preferred - distance): return preferred - distance
		if not occupied.has(preferred + distance): return preferred + distance
	return preferred

func _commit_anchor(node_id: StringName) -> void:
	anchors[node_id] = Vector3(float(lanes[node_id]) * BRANCH_WIDTH, NODE_BASE_HEIGHT, -float(depths[node_id]) * LAYER_DEPTH)

func _cache_new_edges(graph: NetworkGraph) -> void:
	var ids: Array = graph.links.keys(); ids.sort_custom(_sort_ids)
	for id_value: Variant in ids:
		var id := StringName(id_value)
		if edge_endpoints.has(id): continue
		var link := graph.get_link(id)
		if link == null or not anchors.has(link.source) or not anchors.has(link.destination): continue
		var endpoints := PackedVector3Array([anchors[link.source], anchors[link.destination]])
		edge_endpoints[id] = endpoints; edge_lengths[id] = endpoints[0].distance_to(endpoints[1])

func begin_transition(from_id: StringName, to_id: StringName) -> bool:
	if not anchors.has(from_id) or not anchors.has(to_id): return false
	camera_from = anchors[from_id]; camera_to = anchors[to_id]; camera_anchor = camera_from; transition_progress = 0.0; return true
func set_transition_progress(value: float) -> void:
	transition_progress = clampf(value, 0.0, 1.0)
	var eased := transition_progress * transition_progress * (3.0 - 2.0 * transition_progress)
	camera_anchor = camera_from.lerp(camera_to, eased)
func snap_to(node_id: StringName) -> void:
	if anchors.has(node_id): camera_anchor = anchors[node_id]; _camera_initialized = true
	transition_progress = 1.0
func world_position(node_id: StringName) -> Vector3: return anchors.get(node_id, Vector3.ZERO)
func edge_world_endpoints(link_id: StringName) -> PackedVector3Array: return edge_endpoints.get(link_id, PackedVector3Array())
func edge_world_length(link_id: StringName) -> float: return float(edge_lengths.get(link_id, 0.0))

func project(node_id: StringName, rect: Rect2) -> Dictionary:
	var relative := world_position(node_id) - camera_anchor
	var depth := maxf(2.5, CAMERA_DISTANCE - relative.z)
	var scale := clampf(FOCAL_LENGTH / depth / 66.0, 0.88, 1.30)
	var center := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.72)
	return {"position": center + Vector2(relative.x * FOCAL_LENGTH / depth, -relative.y * FOCAL_LENGTH / depth - (depth - CAMERA_DISTANCE) * 16.0), "scale": scale, "depth": depth}

func validation_issues() -> PackedStringArray:
	var issues := PackedStringArray()
	for id_value: Variant in anchors:
		var id := StringName(id_value); var position: Vector3 = anchors[id]
		if not is_equal_approx(position.y, NODE_BASE_HEIGHT): issues.append("%s has invalid height" % id)
		var parent := StringName(primary_parents.get(id, &""))
		if parent != &"" and anchors.has(parent) and position.z >= (anchors[parent] as Vector3).z: issues.append("%s is not forward of %s" % [id, parent])
	return issues

func debug_lines() -> PackedStringArray:
	var result := PackedStringArray(["FORWARD AXIS // -Z"]); var ids: Array = anchors.keys(); ids.sort_custom(_sort_ids)
	for id_value: Variant in ids:
		var id := StringName(id_value); result.append("%s  depth=%d  lane=%.1f  pos=%s" % [id, int(depths[id]), float(lanes[id]), anchors[id]])
	return result
func debug_snapshot() -> Dictionary:
	return {"anchors": anchors.duplicate(true), "depths": depths.duplicate(true), "lanes": lanes.duplicate(true), "edge_endpoints": edge_endpoints.duplicate(true), "edge_lengths": edge_lengths.duplicate(true), "camera_anchor": camera_anchor, "transition_progress": transition_progress}
func _deepest_layer() -> int:
	var result := -1
	for value: Variant in depths.values(): result = maxi(result, int(value))
	return result
func _sort_ids(a: Variant, b: Variant) -> bool: return String(a) < String(b)
