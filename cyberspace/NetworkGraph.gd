class_name NetworkGraph
extends RefCounted

signal traversal_started(from_node_id: StringName, to_node_id: StringName, link_id: StringName)
signal traversal_cost_spent(cost: int, remaining_points: int)
signal traversal_completed(from_node_id: StringName, to_node_id: StringName, link_id: StringName)
signal display_update_requested
signal security_sleeve_changed(sleeve_id: StringName)

enum TraversalError { OK, INVALID_SOURCE, INVALID_DESTINATION, NOT_CONNECTED, HIDDEN_LINK, LOCKED_LINK, DISABLED_LINK, AUTHORITY_REQUIRED, CAPABILITY_REQUIRED, INSUFFICIENT_POINTS, ALREADY_TRANSITIONING }
const LEGACY_UNASSIGNED_SPHERE_ID := &"LEGACY_UNASSIGNED_SPHERE"

var nodes: Dictionary = {}
var links: Dictionary = {}
var spheres: Dictionary = {}
var security_sleeves: Dictionary = {}

func add_sphere(sphere: SphereDefinition) -> bool:
	if sphere == null or sphere.id == &"" or spheres.has(sphere.id): return false
	spheres[sphere.id] = sphere
	return true

func add_security_sleeve(sleeve: SecuritySleeve) -> bool:
	if sleeve == null or sleeve.id == &"" or security_sleeves.has(sleeve.id): return false
	for node_id in sleeve.current_members:
		if not nodes.has(node_id): return false
	security_sleeves[sleeve.id] = sleeve
	sleeve.changed.connect(_on_security_sleeve_changed)
	return true

func _on_security_sleeve_changed(sleeve: SecuritySleeve) -> void:
	security_sleeve_changed.emit(sleeve.id)
	display_update_requested.emit()

func add_node(node: NetworkNodeDefinition) -> bool:
	if node.id == &"" or nodes.has(node.id) or (node.sphere_id != &"" and not spheres.has(node.sphere_id)):
		return false
	if node.sphere_id == &"":
		_ensure_legacy_sphere()
		node.sphere_id = LEGACY_UNASSIGNED_SPHERE_ID
	nodes[node.id] = node
	if node.sphere_id != &"": (spheres[node.sphere_id] as SphereDefinition).register_node(node.id)
	return true

func _ensure_legacy_sphere() -> void:
	if not spheres.has(LEGACY_UNASSIGNED_SPHERE_ID):
		add_sphere(SphereDefinition.new(LEGACY_UNASSIGNED_SPHERE_ID, "Legacy / Unassigned Sphere", [], &""))

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

func get_sphere(sphere_id: StringName) -> SphereDefinition:
	return spheres.get(sphere_id) as SphereDefinition

func get_security_sleeve(sleeve_id: StringName) -> SecuritySleeve:
	return security_sleeves.get(sleeve_id) as SecuritySleeve

func get_current_sleeve_ids_for_node(node_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for sleeve: SecuritySleeve in security_sleeves.values():
		if sleeve.state != SecuritySleeve.State.DISABLED and sleeve.contains_node(node_id): result.append(sleeve.id)
	result.sort()
	return result

func split_security_sleeve(source_sleeve_id: StringName, partitions: Dictionary) -> bool:
	var source := get_security_sleeve(source_sleeve_id)
	if source == null or partitions.is_empty(): return false
	var proposed: Array[SecuritySleeve] = []
	var assigned: Array[StringName] = []
	for new_id_value in partitions:
		var new_id := StringName(new_id_value)
		if new_id == &"" or security_sleeves.has(new_id): return false
		var members: Array[StringName] = []
		members.assign(partitions[new_id_value])
		for node_id in members:
			if not nodes.has(node_id) or not source.current_members.has(node_id) or assigned.has(node_id): return false
			assigned.append(node_id)
		proposed.append(SecuritySleeve.new(new_id, String(new_id).replace("_", " ").capitalize(), members, SecuritySleeve.State.INTACT))
	# The historical sleeve stays addressable for Sphere provenance but no
	# longer represents an active boundary after segmentation.
	source.current_members.clear()
	source.set_state(SecuritySleeve.State.SPLIT)
	for sleeve in proposed: add_security_sleeve(sleeve)
	security_sleeve_changed.emit(source.id)
	display_update_requested.emit()
	return true

func set_security_sleeve_state(sleeve_id: StringName, state: SecuritySleeve.State) -> bool:
	var sleeve := get_security_sleeve(sleeve_id)
	if sleeve == null: return false
	sleeve.set_state(state)
	return true

func set_node_sleeve_protection(sleeve_id: StringName, node_id: StringName, protected: bool) -> bool:
	var sleeve := get_security_sleeve(sleeve_id)
	if sleeve == null or not nodes.has(node_id): return false
	return sleeve.add_current_member(node_id) if protected else sleeve.remove_current_member(node_id)

func restore_security_sleeve(sleeve_id: StringName, members: Array[StringName]) -> bool:
	var sleeve := get_security_sleeve(sleeve_id)
	if sleeve == null: return false
	for node_id in members:
		if not nodes.has(node_id): return false
	sleeve.current_members = members.duplicate()
	sleeve.current_members.sort()
	sleeve.state = SecuritySleeve.State.INTACT
	sleeve.changed.emit(sleeve)
	return true

func move_node_to_sphere(node_id: StringName, new_sphere_id: StringName) -> bool:
	## Explicit story/level reconfiguration path. Sleeve APIs never call this.
	var node := get_node(node_id)
	var destination := get_sphere(new_sphere_id)
	if node == null or destination == null or node.sphere_id == new_sphere_id: return false
	var previous := get_sphere(node.sphere_id)
	if previous != null: previous.node_ids.erase(node_id)
	node.sphere_id = new_sphere_id
	destination.register_node(node_id)
	return true

func sphere_for_node(node_id: StringName) -> SphereDefinition:
	var node := get_node(node_id)
	return get_sphere(node.sphere_id) if node != null and node.sphere_id != &"" else null

func get_sphere_for_node(node_id: StringName) -> SphereDefinition:
	return sphere_for_node(node_id)

func get_nodes_in_sphere(sphere_id: StringName) -> Array[StringName]:
	var sphere := get_sphere(sphere_id)
	return sphere.node_ids.duplicate() if sphere != null else []

func validate_structure() -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	for node: NetworkNodeDefinition in nodes.values():
		if node.sphere_id != &"" and not spheres.has(node.sphere_id):
			issues.append({"category": &"SPHERE", "entity_id": node.id, "reason": "Node references nonexistent sphere."})
		elif node.sphere_id != &"" and not (spheres[node.sphere_id] as SphereDefinition).contains_node(node.id):
			issues.append({"category": &"SPHERE", "entity_id": node.id, "reason": "Sphere membership is not reciprocal."})
	for sphere: SphereDefinition in spheres.values():
		if sphere.original_security_sleeve_id != &"" and not security_sleeves.has(sphere.original_security_sleeve_id):
			issues.append({"category": &"SPHERE", "entity_id": sphere.id, "reason": "Original Security Sleeve does not exist."})
		for node_id in sphere.node_ids:
			var member := get_node(node_id)
			if member == null: issues.append({"category": &"SPHERE", "entity_id": sphere.id, "reason": "Sphere contains nonexistent node.", "node_id": node_id})
			elif member.sphere_id != sphere.id: issues.append({"category": &"SPHERE", "entity_id": member.id, "reason": "Node belongs to a different sphere."})
	for sleeve: SecuritySleeve in security_sleeves.values():
		for node_id in sleeve.current_members:
			if not nodes.has(node_id): issues.append({"category": &"SECURITY_SLEEVE", "entity_id": sleeve.id, "reason": "Current member node does not exist.", "node_id": node_id})
	return issues

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
