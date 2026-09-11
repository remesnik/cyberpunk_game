class_name ConfrontationController
extends RefCounted

var graph: NetworkGraph
var position: PlayerNetworkPosition
var knowledge: PlayerKnowledge
var ice_controller: IceController
var definitions: Dictionary

func _init(p_graph: NetworkGraph, p_position: PlayerNetworkPosition, p_knowledge: PlayerKnowledge, p_ice: IceController, p_definitions: Dictionary = {}) -> void:
	graph = p_graph
	position = p_position
	knowledge = p_knowledge
	ice_controller = p_ice
	definitions = ConfrontationActionCatalog.create_definitions() if p_definitions.is_empty() else p_definitions.duplicate()

func has_action(action_type: ActionRequest.ActionType) -> bool:
	return definitions.has(action_type)

func get_action_cost(action_type: ActionRequest.ActionType, target: Dictionary) -> int:
	var definition := definitions.get(action_type) as ConfrontationActionDefinition
	if definition == null:
		return 0
	if action_type == ActionRequest.ActionType.RETREAT:
		var link := graph.find_link(position.current_node_id, target.get("node_id", &""))
		return definition.base_cost + (link.traversal_cost if link != null else 0)
	return definition.base_cost

func validate(action_type: ActionRequest.ActionType, target: Dictionary) -> Dictionary:
	var definition := definitions.get(action_type) as ConfrontationActionDefinition
	if definition == null:
		return {"success": false, "reason": "Unknown confrontation action."}
	var target_kind: StringName = target.get("kind", &"")
	if not definition.valid_target_kinds.has(target_kind):
		return {"success": false, "reason": "Invalid target type for %s." % definition.display_name}
	for capability in definition.required_capabilities:
		if not position.has_capability(capability):
			return {"success": false, "reason": "%s capability required." % capability}
	match target_kind:
		&"SELF":
			return {"success": true, "reason": ""}
		&"ICE":
			var ice_id := _resolve_ice_target(target)
			var ice := ice_controller.get_ice(ice_id)
			if ice == null or not ice.operational:
				return {"success": false, "reason": "No operational ICE target."}
			if knowledge.get_ice_level(ice_id) < KnowledgeLevel.Value.IDENTIFIED:
				return {"success": false, "reason": "ICE must be identified before targeting."}
			if _graph_distance(position.current_node_id, ice.current_node_id) > definition.range_in_links:
				return {"success": false, "reason": "ICE is outside program range."}
			if action_type == ActionRequest.ActionType.REDIRECT:
				var redirect_node: StringName = target.get("redirect_node_id", &"")
				if not knowledge.knows_node(redirect_node) or graph.find_link(ice.current_node_id, redirect_node) == null:
					return {"success": false, "reason": "Redirect destination is not a known adjacent route."}
			return {"success": true, "reason": "", "ice_id": ice_id}
		&"LINK":
			var link_id := knowledge.resolve_link_contact(target.get("contact_id", &""))
			var link := graph.get_link(link_id)
			if link == null or not link.connects_from(position.current_node_id):
				return {"success": false, "reason": "Link is not locally addressable."}
			return {"success": true, "reason": "", "link_id": link_id}
		&"NODE":
			var node_id: StringName = target.get("node_id", &"")
			var traversal := graph.validate_traversal(position, node_id, knowledge.link_records.keys())
			return {"success": traversal.error == NetworkGraph.TraversalError.OK, "reason": "Retreat route is unavailable." if traversal.error != NetworkGraph.TraversalError.OK else ""}
	return {"success": false, "reason": "Unsupported confrontation target."}

func execute(action_type: ActionRequest.ActionType, target: Dictionary) -> ConfrontationResult:
	var validation := validate(action_type, target)
	if not validation.success:
		return ConfrontationResult.new(false, validation.reason, action_type)
	var definition := definitions[action_type] as ConfrontationActionDefinition
	var resolved_cost := get_action_cost(action_type, target)
	var events: Array[Dictionary] = []
	match action_type:
		ActionRequest.ActionType.DISRUPT:
			var ice := ice_controller.get_ice(validation.ice_id)
			ice.disrupted_time += definition.power
			ice.alert_level = maxi(0, ice.alert_level - 15)
			events.append({"type": &"ICE_DISRUPTED", "ice_id": ice.instance_id, "duration": definition.power})
		ActionRequest.ActionType.HIDE:
			for ice_id in ice_controller.instances:
				var ice := ice_controller.get_ice(ice_id)
				if ice.known_player_position != &"":
					ice.last_known_player_position = ice.known_player_position
					ice.known_player_position = &""
					ice.state = IceState.Value.SEARCH
			events.append({"type": &"PLAYER_SIGNAL_HIDDEN", "power": definition.power})
		ActionRequest.ActionType.SPOOF:
			var ice := ice_controller.get_ice(validation.ice_id)
			ice.alert_level = maxi(0, ice.alert_level - definition.power)
			ice.known_player_position = &""
			ice.target_node_id = ice.home_node
			ice.state = IceState.Value.RETURN
			events.append({"type": &"IDENTITY_SPOOFED", "ice_id": ice.instance_id})
		ActionRequest.ActionType.ATTACK_PROCESS:
			var ice := ice_controller.get_ice(validation.ice_id)
			var hp_before := ice.integrity
			var was_operational := ice.operational
			var damage := maxi(1, definition.power - ice.definition.defense)
			ice.integrity = maxi(0, ice.integrity - damage)
			if ice.integrity == 0:
				ice.operational = false
				ice.state = IceState.Value.DORMANT
			events.append({"type": &"ICE_INTEGRITY_DAMAGED", "ice_id": ice.instance_id, "damage": damage, "remaining": ice.integrity, "disabled": not ice.operational})
			if was_operational and not ice.operational:
				events.append({"type": &"ICE_DESTROYED", "ice_id": ice.instance_id, "node_id": ice.current_node_id})
			knowledge.observe_ice_combat_state(ice.instance_id, ice.integrity, ice.definition.maximum_integrity, ice.operational, ice.state)
			if OS.is_debug_build(): print("[ICE ATTACK] target_id=%s hp_before=%d damage=%d hp_after=%d" % [ice.instance_id, hp_before, damage, ice.integrity])
		ActionRequest.ActionType.BREAK_LOCK:
			var link := graph.get_link(validation.link_id)
			link.locked = false
			knowledge.reveal_link(link, KnowledgeLevel.Value.SCANNED)
			events.append({"type": &"LINK_LOCK_BROKEN", "link_id": link.id})
		ActionRequest.ActionType.REDIRECT:
			var ice := ice_controller.get_ice(validation.ice_id)
			ice.target_node_id = target.redirect_node_id
			ice.state = IceState.Value.INVESTIGATE
			events.append({"type": &"ICE_REDIRECTED", "ice_id": ice.instance_id, "target": ice.target_node_id})
		ActionRequest.ActionType.TRACE_SCRAMBLE:
			events.append({"type": &"TRACE_SCRAMBLED", "reduction": definition.power})
		ActionRequest.ActionType.RETREAT:
			var origin := position.current_node_id
			var movement := graph.apply_traversal(position, target.node_id, knowledge.link_records.keys())
			if movement.error != NetworkGraph.TraversalError.OK:
				return ConfrontationResult.new(false, "Retreat failed.", action_type)
			knowledge.observe_traversal(graph, origin, target.node_id)
			events.append({"type": &"PLAYER_RETREATED", "from": origin, "to": target.node_id})
	return ConfrontationResult.new(true, "%s resolved." % definition.display_name, action_type, resolved_cost, definition.trace_generated, events)

func _resolve_ice_target(target: Dictionary) -> StringName:
	if target.has("ice_id") and knowledge.knows_ice(target.ice_id):
		return target.ice_id
	return knowledge.resolve_ice_contact(target.get("contact_id", &""))

func _graph_distance(start: StringName, goal: StringName) -> int:
	if start == goal:
		return 0
	var frontier: Array[StringName] = [start]
	var distances: Dictionary = {start: 0}
	while not frontier.is_empty():
		var current := StringName(frontier.pop_front())
		var node := graph.get_node(current)
		if node == null:
			continue
		var links := node.connected_links.duplicate()
		links.sort()
		for link_id in links:
			var link := graph.get_link(link_id)
			if link == null or link.disabled or not link.connects_from(current):
				continue
			var neighbor := link.destination_from(current)
			if distances.has(neighbor):
				continue
			distances[neighbor] = int(distances[current]) + 1
			if neighbor == goal:
				return int(distances[neighbor])
			frontier.append(neighbor)
	return 999
