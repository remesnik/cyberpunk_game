class_name NetworkGraph
extends RefCounted

signal traversal_started(from_node_id: StringName, to_node_id: StringName, link_id: StringName)
signal traversal_cost_spent(cost: int, remaining_points: int)
signal traversal_completed(from_node_id: StringName, to_node_id: StringName, link_id: StringName)
signal display_update_requested

enum TraversalError { OK, INVALID_SOURCE, INVALID_DESTINATION, NOT_CONNECTED, HIDDEN_LINK, LOCKED_LINK, DISABLED_LINK, AUTHORITY_REQUIRED, CAPABILITY_REQUIRED, INSUFFICIENT_POINTS, ALREADY_TRANSITIONING }

var nodes: Dictionary = {}
var links: Dictionary = {}

func add_node(node: NetworkNodeDefinition) -> bool:
	if node.id == &"" or nodes.has(node.id):
		return false
	nodes[node.id] = node
	return true

func add_link(link: NetworkLinkDefinition) -> bool:
	if link.id == &"" or links.has(link.id) or not nodes.has(link.source) or not nodes.has(link.destination):
		return false
	links[link.id] = link
	(nodes[link.source] as NetworkNodeDefinition).add_connected_link(link.id)
	(nodes[link.destination] as NetworkNodeDefinition).add_connected_link(link.id)
	return true

func get_node(node_id: StringName) -> NetworkNodeDefinition:
	return nodes.get(node_id) as NetworkNodeDefinition

func get_link(link_id: StringName) -> NetworkLinkDefinition:
	return links.get(link_id) as NetworkLinkDefinition

func get_visible_connected_nodes(from_node_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	var node := get_node(from_node_id)
	if node == null:
		return result
	for link_id in node.connected_links:
		var link := get_link(link_id)
		if link == null or not link.connects_from(from_node_id) or not link.is_visible():
			continue
		var destination_id := link.destination_from(from_node_id)
		if destination_id != &"" and not result.has(destination_id):
			result.append(destination_id)
	return result

func validate_traversal(position: PlayerNetworkPosition, destination_id: StringName, known_link_ids: Array = []) -> Dictionary:
	if position.is_transitioning:
		return _result(TraversalError.ALREADY_TRANSITIONING)
	if not nodes.has(position.current_node_id):
		return _result(TraversalError.INVALID_SOURCE)
	if not nodes.has(destination_id):
		return _result(TraversalError.INVALID_DESTINATION)
	var candidate: NetworkLinkDefinition
	for link_id in get_node(position.current_node_id).connected_links:
		var link := get_link(link_id)
		if link != null and link.connects_from(position.current_node_id) and link.destination_from(position.current_node_id) == destination_id:
			candidate = link
			break
	if candidate == null:
		return _result(TraversalError.NOT_CONNECTED)
	if candidate.hidden and not candidate.discovered and not known_link_ids.has(candidate.id):
		return _result(TraversalError.HIDDEN_LINK, candidate)
	if candidate.disabled:
		return _result(TraversalError.DISABLED_LINK, candidate)
	if candidate.locked:
		return _result(TraversalError.LOCKED_LINK, candidate)
	if position.authority_level < candidate.authority_requirement:
		return _result(TraversalError.AUTHORITY_REQUIRED, candidate)
	if not candidate.access_requirements_met(position.capabilities, position.credentials):
		return _result(TraversalError.CAPABILITY_REQUIRED, candidate)
	var destination_node := get_node(destination_id)
	if not destination_node.access_requirements_met(position.capabilities, position.credentials):
		return _result(TraversalError.CAPABILITY_REQUIRED, candidate)
	if not position.can_afford(candidate.traversal_cost):
		return _result(TraversalError.INSUFFICIENT_POINTS, candidate)
	return _result(TraversalError.OK, candidate)

func traverse(position: PlayerNetworkPosition, destination_id: StringName, known_link_ids: Array = []) -> Dictionary:
	return apply_traversal(position, destination_id, known_link_ids)

func apply_traversal(position: PlayerNetworkPosition, destination_id: StringName, known_link_ids: Array = []) -> Dictionary:
	var validation := validate_traversal(position, destination_id, known_link_ids)
	if validation.error != TraversalError.OK:
		return validation
	var link: NetworkLinkDefinition = validation.link
	var origin := position.current_node_id
	position.begin_transition(destination_id, link.id)
	traversal_started.emit(origin, destination_id, link.id)
	position.spend_traversal_cost(link.traversal_cost)
	traversal_cost_spent.emit(link.traversal_cost, position.traversal_points)
	position.complete_transition()
	traversal_completed.emit(origin, destination_id, link.id)
	display_update_requested.emit()
	return validation

func find_link(from_node_id: StringName, destination_id: StringName) -> NetworkLinkDefinition:
	var source_node := get_node(from_node_id)
	if source_node == null:
		return null
	for link_id in source_node.connected_links:
		var link := get_link(link_id)
		if link != null and link.connects_from(from_node_id) and link.destination_from(from_node_id) == destination_id:
			return link
	return null

func _result(error: TraversalError, link: NetworkLinkDefinition = null) -> Dictionary:
	return {"error": error, "link": link}
