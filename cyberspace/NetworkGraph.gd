class_name NetworkGraph
extends RefCounted

signal traversal_started(from_node_id: StringName, to_node_id: StringName, link_id: StringName)
signal traversal_cost_spent(cost: int, remaining_points: int)
signal traversal_completed(from_node_id: StringName, to_node_id: StringName, link_id: StringName)
signal display_update_requested
signal security_sleeve_changed(sleeve_id: StringName)
signal outbound_path_state_changed(event: Dictionary)
signal security_event_reported(event: Dictionary)

enum TraversalError { OK, INVALID_SOURCE, INVALID_DESTINATION, NOT_CONNECTED, HIDDEN_LINK, LOCKED_LINK, DISABLED_LINK, AUTHORITY_REQUIRED, CAPABILITY_REQUIRED, INSUFFICIENT_POINTS, ALREADY_TRANSITIONING, SOURCE_EXIT_BLOCKED, DESTINATION_ENTRY_BLOCKED, SCRIPTED_GATE_BLOCKED, DIRECTION_LOCKED_DOWN }
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
	node.security_event_reported.connect(func(event: Dictionary): security_event_reported.emit(event))
	if node.sphere_id != &"": (spheres[node.sphere_id] as SphereDefinition).register_node(node.id)
	display_update_requested.emit()
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
	display_update_requested.emit()
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
	for link: NetworkLinkDefinition in links.values():
		for direction: TraversalDirectionDefinition in link.traversal_directions.values():
			var controller := direction.remote_controller_node_id if direction.remote_controller_node_id != &"" else direction.controller_node_id
			if not nodes.has(controller): issues.append({"severity": &"ERROR", "category": &"REMOTE_PATH_CONTROL", "entity_id": link.id, "reason": "Traversal controller does not exist.", "controller_node_id": controller})
			elif controller != direction.source_node_id and not _runtime_reachable_without_direction(direction.source_node_id, controller, link.id, direction.source_node_id, direction.destination_node_id):
				issues.append({"severity": &"WARNING" if direction.allow_circular_remote_gate else &"ERROR", "category": &"REMOTE_PATH_CONTROL", "entity_id": link.id, "reason": "Intentional circular remote gate override." if direction.allow_circular_remote_gate else "Remote controller is unreachable without crossing its controlled direction.", "source_node_id": direction.source_node_id, "destination_node_id": direction.destination_node_id, "controller_node_id": controller})
	return issues

func _runtime_reachable_without_direction(start: StringName, target: StringName, excluded_link_id: StringName, excluded_source: StringName, excluded_destination: StringName) -> bool:
	var visited: Dictionary = {start: true}; var frontier: Array[StringName] = [start]
	while not frontier.is_empty():
		var current: StringName = frontier.pop_front()
		for link: NetworkLinkDefinition in links.values():
			if not link.connects_from(current): continue
			var next: StringName = link.destination_from(current)
			if link.id == excluded_link_id and current == excluded_source and next == excluded_destination: continue
			if next == target: return true
			if next == &"" or visited.has(next): continue
			visited[next] = true; frontier.append(next)
	return start == target

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
		var direction := link.get_direction(from_node_id, destination_id)
		if direction == null or direction.state == TraversalDirectionDefinition.State.HIDDEN: continue
		if destination_id != &"" and not result.has(destination_id):
			result.append(destination_id)
	return result

func can_traverse(source_node_id: StringName, destination_id: StringName, position: PlayerNetworkPosition = null, known_link_ids: Array = [], requirement_resolver: Callable = Callable()) -> Dictionary:
	var evaluation_position := position
	if evaluation_position == null:
		evaluation_position = PlayerNetworkPosition.new(source_node_id, 2147483647)
	elif evaluation_position.current_node_id != source_node_id:
		return _result(TraversalError.INVALID_SOURCE, null, "SOURCE POSITION MISMATCH")
	return _can_traverse_position(evaluation_position, destination_id, known_link_ids, requirement_resolver)

func validate_traversal(position: PlayerNetworkPosition, destination_id: StringName, known_link_ids: Array = [], requirement_resolver: Callable = Callable()) -> Dictionary:
	return can_traverse(position.current_node_id if position != null else &"", destination_id, position, known_link_ids, requirement_resolver)

func _can_traverse_position(position: PlayerNetworkPosition, destination_id: StringName, known_link_ids: Array, requirement_resolver: Callable) -> Dictionary:
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
	var direction := candidate.get_direction(position.current_node_id, destination_id)
	if direction == null: return _result(TraversalError.NOT_CONNECTED, candidate)
	if candidate.hidden and not candidate.discovered and not known_link_ids.has(candidate.id):
		return _result(TraversalError.HIDDEN_LINK, candidate, "PATH NOT DISCOVERED", {}, null, direction)
	if direction.state == TraversalDirectionDefinition.State.HIDDEN and not known_link_ids.has(candidate.id):
		return _result(TraversalError.HIDDEN_LINK, candidate, "DIRECTION NOT DISCOVERED", {}, null, direction)
	if candidate.disabled:
		return _result(TraversalError.DISABLED_LINK, candidate, "CONNECTION DISABLED", {}, null, direction)
	if candidate.locked:
		return _result(TraversalError.LOCKED_LINK, candidate, candidate.blocked_reason, {}, null, direction)
	if direction.state == TraversalDirectionDefinition.State.LOCKED_DOWN:
		return _result(TraversalError.DIRECTION_LOCKED_DOWN, candidate, direction.blocked_reason, direction.unlock_requirements, false, direction)
	if direction.gate_type == TraversalDirectionDefinition.GateType.HARD and not direction.security_resolved:
		return _result(TraversalError.LOCKED_LINK, candidate, direction.blocked_reason, direction.unlock_requirements, false, direction)
	if direction.state != TraversalDirectionDefinition.State.UNLOCKED:
		return _result(TraversalError.LOCKED_LINK, candidate, direction.blocked_reason, direction.unlock_requirements, false, direction)
	if candidate.gate_applies(position.current_node_id, destination_id):
		var requirement_result := _resolve_gate(candidate, position.current_node_id, destination_id, requirement_resolver)
		if not bool(requirement_result.get("satisfied", false)):
			var gate_error := TraversalError.SOURCE_EXIT_BLOCKED if candidate.traversal_gate_type == NetworkLinkDefinition.TraversalGateType.BLOCK_EXIT_UNTIL_RESOLVED else (TraversalError.DESTINATION_ENTRY_BLOCKED if candidate.traversal_gate_type == NetworkLinkDefinition.TraversalGateType.BLOCK_ENTRY_UNTIL_REQUIREMENT else TraversalError.SCRIPTED_GATE_BLOCKED)
			return _result(gate_error, candidate, String(requirement_result.get("reason", candidate.blocked_reason)), candidate.traversal_requirement, requirement_result.get("value", false), direction)
	if position.authority_level < candidate.authority_requirement:
		return _result(TraversalError.AUTHORITY_REQUIRED, candidate, "AUTHORITY REQUIRED", {}, null, direction)
	if not candidate.access_requirements_met(position.capabilities, position.credentials):
		return _result(TraversalError.CAPABILITY_REQUIRED, candidate, "PATH CAPABILITY REQUIRED", {}, null, direction)
	var destination_node := get_node(destination_id)
	if not destination_node.access_requirements_met(position.capabilities, position.credentials):
		return _result(TraversalError.CAPABILITY_REQUIRED, candidate, "DESTINATION CAPABILITY REQUIRED", {}, null, direction)
	if not position.can_afford(candidate.traversal_cost):
		return _result(TraversalError.INSUFFICIENT_POINTS, candidate, "INSUFFICIENT TRAVERSAL POINTS", {}, null, direction)
	var unauthorized := direction.gate_type == TraversalDirectionDefinition.GateType.SOFT and not direction.security_resolved
	var result := _result(TraversalError.OK, candidate, "SOFT-GATED ROUTE: TRAVERSAL WILL TRIGGER SECURITY" if unauthorized else "OUTBOUND PATH UNLOCKED", {}, true, direction)
	result["soft_gate_unauthorized"] = unauthorized
	result["warning"] = &"SOFT_SECURITY_CONSEQUENCES" if unauthorized else &""
	result["controlling_security"] = direction.controlling_security.duplicate(true)
	result["consequences"] = direction.on_unauthorized_traversal.duplicate(true) if unauthorized else []
	return result

func set_direction_state(link_id: StringName, from_node_id: StringName, to_node_id: StringName, state: TraversalDirectionDefinition.State) -> bool:
	var link := get_link(link_id)
	var direction := link.get_direction(from_node_id, to_node_id) if link != null else null
	if direction == null: return false
	direction.state = state
	if state == TraversalDirectionDefinition.State.UNLOCKED and direction.gate_type == TraversalDirectionDefinition.GateType.NONE: direction.security_resolved = true
	display_update_requested.emit()
	return true

func unlock_outbound_path(link_id: StringName, actor_node_id: StringName, to_node_id: StringName, node_mode := true, requirement_resolver: Callable = Callable()) -> Dictionary:
	var link := get_link(link_id)
	var direction := link.get_direction(actor_node_id, to_node_id) if link != null else null
	if direction == null: return {"success": false, "reason": "DIRECTION DOES NOT EXIST"}
	var controller := direction.remote_controller_node_id if direction.remote_controller_node_id != &"" else direction.controller_node_id
	if not node_mode: return {"success": false, "reason": "ENTER NODE MODE TO CONTROL PATH"}
	if actor_node_id != controller: return {"success": false, "reason": "PATH CONTROLLED BY %s" % controller}
	if direction.state == TraversalDirectionDefinition.State.LOCKED_DOWN: return {"success": false, "reason": direction.blocked_reason}
	if not direction.unlock_requirements.is_empty():
		if not requirement_resolver.is_valid(): return {"success": false, "reason": direction.blocked_reason}
		var resolved: Variant = requirement_resolver.call(direction.unlock_requirements.duplicate(true), actor_node_id, to_node_id, link)
		if not (bool(resolved.get("satisfied", false)) if resolved is Dictionary else bool(resolved)): return {"success": false, "reason": direction.blocked_reason}
	direction.state = TraversalDirectionDefinition.State.UNLOCKED
	direction.security_resolved = true
	display_update_requested.emit()
	return {"success": true, "reason": "OUTBOUND PATH UNLOCKED", "security_consequences": direction.security_consequences.duplicate(true), "controlling_ice_id": direction.controlling_ice_id}

func apply_node_interaction(node_id: StringName, interaction: StringName, context: Dictionary = {}) -> Array[Dictionary]:
	var node := get_node(node_id)
	var events: Array[Dictionary] = []
	if node == null: return events
	for control: NodePathControl in node.outbound_path_controls:
		if not control.matches(interaction, context): continue
		var changed := false
		for link: NetworkLinkDefinition in links.values():
			for direction: TraversalDirectionDefinition in link.traversal_directions.values():
				var effective_controller := direction.remote_controller_node_id if direction.remote_controller_node_id != &"" else direction.controller_node_id
				if effective_controller != node_id: continue
				if control.scope == NodePathControl.Scope.ALL_NORMAL and direction.source_node_id != node_id: continue
				var destination := direction.destination_node_id
				if not control.selects(link, destination): continue
			# ALL_NORMAL deliberately excludes permanently unavailable routes.
				if direction.state == TraversalDirectionDefinition.State.LOCKED_DOWN and control.resulting_state == TraversalDirectionDefinition.State.UNLOCKED: continue
				if direction.state == control.resulting_state:
					if control.resulting_state == TraversalDirectionDefinition.State.UNLOCKED and direction.gate_type == TraversalDirectionDefinition.GateType.NONE and not direction.security_resolved:
						direction.security_resolved = true; changed = true
					continue
				direction.state = control.resulting_state
				if control.resulting_state == TraversalDirectionDefinition.State.UNLOCKED and direction.gate_type == TraversalDirectionDefinition.GateType.NONE: direction.security_resolved = true
				changed = true
				var destination_node := get_node(destination)
				var destination_label := destination_node.display_name.to_upper() if destination_node != null else String(destination)
				var opened_message := "ROUTE OPENED: %s" % destination_label
				if direction.gate_type == TraversalDirectionDefinition.GateType.HARD and not direction.security_resolved: opened_message = "ROUTE ACCESS OPEN: %s // %s" % [destination_label, direction.blocked_reason]
				var event := {"type": &"OUTBOUND_PATH_STATE_CHANGED", "control_id": control.id, "controller_node_id": node_id, "source_node_id": direction.source_node_id, "destination_node_id": destination, "link_id": link.id, "state": direction.state_name(), "message": opened_message if direction.state == TraversalDirectionDefinition.State.UNLOCKED else "ROUTE %s: %s" % [direction.state_name(), destination_label], "player_visible": true}
				events.append(event)
				outbound_path_state_changed.emit(event)
		if changed: control.activated = true
	if not events.is_empty(): display_update_requested.emit()
	return events

func apply_security_resolution(interaction: StringName, context: Dictionary = {}) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for link: NetworkLinkDefinition in links.values():
		for direction: TraversalDirectionDefinition in link.traversal_directions.values():
			if direction.security_resolved or direction.controlling_security.is_empty(): continue
			var resolve_on: Array = direction.controlling_security.get("resolve_on", [])
			if resolve_on.is_empty() and StringName(direction.controlling_security.get("kind", &"")) == &"ICE":
				resolve_on = [&"ice_destroyed", &"ice_bypassed", &"ice_disrupted"]
			if interaction not in resolve_on: continue
			var security_id := StringName(direction.controlling_security.get("id", &""))
			var subject := StringName(context.get("ice_id", context.get("service_id", context.get("subject_id", &""))))
			if security_id != &"" and subject != security_id: continue
			direction.security_resolved = true
			if direction.gate_type == TraversalDirectionDefinition.GateType.HARD: direction.state = TraversalDirectionDefinition.State.UNLOCKED
			var event := {"type": &"PATH_SECURITY_RESOLVED", "source_node_id": direction.source_node_id, "destination_node_id": direction.destination_node_id, "controller_node_id": direction.controller_node_id, "link_id": link.id, "message": "ROUTE OPENED: %s" % direction.destination_node_id, "player_visible": true}
			events.append(event); outbound_path_state_changed.emit(event)
	if not events.is_empty(): display_update_requested.emit()
	return events

func traverse(position: PlayerNetworkPosition, destination_id: StringName, known_link_ids: Array = []) -> Dictionary:
	return apply_traversal(position, destination_id, known_link_ids)

func apply_traversal(position: PlayerNetworkPosition, destination_id: StringName, known_link_ids: Array = [], requirement_resolver: Callable = Callable()) -> Dictionary:
	var validation := can_traverse(position.current_node_id, destination_id, position, known_link_ids, requirement_resolver)
	if validation.error != TraversalError.OK:
		return validation
	var link: NetworkLinkDefinition = validation.link
	var origin := position.current_node_id
	position.begin_transition(destination_id, link.id)
	traversal_started.emit(origin, destination_id, link.id)
	position.spend_traversal_cost(link.traversal_cost)
	traversal_cost_spent.emit(link.traversal_cost, position.traversal_points)
	position.complete_transition()
	validation["topology_consequences_applied"] = _apply_topology_consequences(validation, origin, destination_id)
	traversal_completed.emit(origin, destination_id, link.id)
	display_update_requested.emit()
	return validation

func _apply_topology_consequences(validation: Dictionary, source: StringName, destination: StringName) -> Array[Dictionary]:
	var applied: Array[Dictionary] = []
	if not bool(validation.get("soft_gate_unauthorized", false)): return applied
	for consequence: Dictionary in validation.get("consequences", []):
		var type := StringName(String(consequence.get("type", &"")).to_upper())
		if type not in [&"CLOSE_PATH", &"LOCK_PATH_BEHIND"]: continue
		var close_link := get_link(StringName(consequence.get("link_id", validation.get("link").id)))
		if close_link == null: continue
		var close_source := StringName(consequence.get("source", destination)); var close_destination := StringName(consequence.get("destination", source))
		var close_direction := close_link.get_direction(close_source, close_destination)
		if close_direction == null: continue
		close_direction.state = TraversalDirectionDefinition.State.LOCKED_DOWN if bool(consequence.get("locked_down", true)) else TraversalDirectionDefinition.State.LOCKED
		applied.append({"link_id": close_link.id, "source": close_source, "destination": close_destination, "state": close_direction.state_name()})
	return applied

func find_link(from_node_id: StringName, destination_id: StringName) -> NetworkLinkDefinition:
	var source_node := get_node(from_node_id)
	if source_node == null:
		return null
	for link_id in source_node.connected_links:
		var link := get_link(link_id)
		if link != null and link.connects_from(from_node_id) and link.destination_from(from_node_id) == destination_id:
			return link
	return null

func _resolve_gate(link: NetworkLinkDefinition, from_node_id: StringName, to_node_id: StringName, resolver: Callable) -> Dictionary:
	if link.traversal_gate_type == NetworkLinkDefinition.TraversalGateType.ONE_WAY: return {"satisfied": true, "value": true}
	if not resolver.is_valid(): return {"satisfied": false, "value": false, "reason": link.blocked_reason}
	var resolved: Variant = resolver.call(link.traversal_requirement.duplicate(true), from_node_id, to_node_id, link)
	if resolved is Dictionary: return resolved
	return {"satisfied": bool(resolved), "value": bool(resolved), "reason": link.blocked_reason}

func _result(error: TraversalError, link: NetworkLinkDefinition = null, reason := "", requirement: Dictionary = {}, requirement_value: Variant = null, direction: TraversalDirectionDefinition = null) -> Dictionary:
	var controller: StringName = &""
	if direction != null: controller = direction.remote_controller_node_id if direction.remote_controller_node_id != &"" else direction.controller_node_id
	var reason_code := StringName(TraversalError.keys()[error])
	if direction != null and direction.gate_type == TraversalDirectionDefinition.GateType.HARD and not direction.security_resolved: reason_code = &"HARD_SECURITY_BLOCKING"
	return {"allowed": error == TraversalError.OK, "error": error, "reason_code": reason_code, "warning": &"", "link": link, "direction": direction, "controller": controller, "controller_node_id": controller, "path_state": direction.state_name() if direction != null else &"", "traversal_state": direction.state_name() if direction != null else &"", "security_gate_type": StringName(TraversalDirectionDefinition.GateType.keys()[direction.gate_type]) if direction != null else &"NONE", "security_resolved": direction.security_resolved if direction != null else true, "reason": reason, "requirement": requirement.duplicate(true), "requirement_value": requirement_value}
