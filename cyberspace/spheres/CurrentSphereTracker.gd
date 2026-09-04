class_name CurrentSphereTracker
extends RefCounted

signal sphere_changed(player_id: StringName, previous_sphere_id: StringName, new_sphere_id: StringName, entry_node_id: StringName)

var graph: NetworkGraph
var player_positions: Dictionary = {}
var current_sphere_ids: Dictionary = {}

func _init(p_graph: NetworkGraph = null) -> void:
	graph = p_graph

func register_player(player_id: StringName, position: PlayerNetworkPosition) -> bool:
	if player_id == &"" or position == null or graph == null or graph.get_node(position.current_node_id) == null: return false
	unregister_player(player_id)
	player_positions[player_id] = position
	current_sphere_ids[player_id] = _sphere_id_for_node(position.current_node_id)
	position.position_changed.connect(_on_position_changed.bind(player_id))
	return true

func unregister_player(player_id: StringName) -> void:
	var position := player_positions.get(player_id) as PlayerNetworkPosition
	if position != null:
		var callback := _on_position_changed.bind(player_id)
		if position.position_changed.is_connected(callback): position.position_changed.disconnect(callback)
	player_positions.erase(player_id)
	current_sphere_ids.erase(player_id)

func get_current_sphere(player_id: StringName) -> SphereDefinition:
	var position := player_positions.get(player_id) as PlayerNetworkPosition
	if position == null: return null
	# Query from authoritative occupancy so callers remain correct even if an
	# external system changed position before its signal was delivered.
	return get_sphere_for_node(position.current_node_id)

func get_current_sphere_id(player_id: StringName) -> StringName:
	var sphere := get_current_sphere(player_id)
	return sphere.id if sphere != null else &""

func get_sphere_for_node(node_id: StringName) -> SphereDefinition:
	return graph.sphere_for_node(node_id) if graph != null else null

func get_nodes_in_sphere(sphere_id: StringName) -> Array[StringName]:
	return graph.get_nodes_in_sphere(sphere_id) if graph != null else []

func _on_position_changed(_from_node_id: StringName, to_node_id: StringName, _link_id: StringName, player_id: StringName) -> void:
	var previous: StringName = current_sphere_ids.get(player_id, &"")
	var next := _sphere_id_for_node(to_node_id)
	current_sphere_ids[player_id] = next
	if previous != next:
		sphere_changed.emit(player_id, previous, next, to_node_id)

func _sphere_id_for_node(node_id: StringName) -> StringName:
	var sphere := get_sphere_for_node(node_id)
	return sphere.id if sphere != null else &""
