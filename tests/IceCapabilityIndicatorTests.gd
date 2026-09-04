extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void:
	var graph := NetworkGraph.new()
	for id: StringName in [&"SEC_NODE", &"NEXT_NODE", &"PLAYER_NODE"]:
		graph.add_node(NetworkNodeDefinition.new(id, String(id), NetworkNodeDefinition.NodeType.SYSTEM, 2))
	graph.add_link(NetworkLinkDefinition.new(&"ICE_ROUTE", &"SEC_NODE", &"NEXT_NODE"))
	graph.get_node(&"SEC_NODE").add_service(&"SEC_INFRA", "Security Infrastructure", 2, [], [&"SECURITY"])
	var knowledge := PlayerKnowledge.new()
	knowledge.reveal_node_contents(graph.get_node(&"SEC_NODE"))
	_expect(knowledge.get_known_node_capability_counts(&"SEC_NODE").get(NodeCapabilityType.Value.SECURITY, 0) == 1, "security infrastructure produces SECURITY independently")
	_expect(not knowledge.get_known_node_capabilities(&"SEC_NODE").has(NodeCapabilityType.Value.ICE), "security infrastructure does not imply ICE occupancy")
	knowledge.detect_ice(&"ICE_1")
	_expect(not knowledge.get_known_node_capabilities(&"SEC_NODE").has(NodeCapabilityType.Value.ICE), "detecting an ICE signal without a position does not reveal a node icon")
	for id: StringName in [&"ICE_1", &"ICE_2", &"ICE_3"]:
		knowledge.report_ice(id, &"SEC_NODE", IceState.Value.PATROL)
	_expect(knowledge.get_known_node_capability_counts(&"SEC_NODE").get(NodeCapabilityType.Value.ICE, 0) == 3, "three confirmed ICE aggregate to ICE x3")
	knowledge.mark_ice_position_stale(&"ICE_1")
	_expect(knowledge.get_known_node_capability_counts(&"SEC_NODE").get(NodeCapabilityType.Value.ICE, 0) == 2 and knowledge.get_node_view(&"SEC_NODE").stale_ice_count == 1, "stale ICE is separated from confirmed occupants")
	knowledge.report_ice(&"ICE_1", &"NEXT_NODE", IceState.Value.SEARCH)
	_expect(knowledge.get_node_view(&"SEC_NODE").stale_ice_count == 0 and knowledge.get_known_node_capabilities(&"NEXT_NODE").has(NodeCapabilityType.Value.ICE), "fresh observation moves the known ICE indicator")

	var movement_knowledge := PlayerKnowledge.new()
	var definition := IceDefinition.new(&"PATROLLER", "Patroller", 0, 1, 0, [&"NEXT_NODE"] as Array[StringName])
	var instance := IceInstance.new(&"MOVING_ICE", definition, &"SEC_NODE", IceState.Value.PATROL)
	var position := PlayerNetworkPosition.new(&"PLAYER_NODE")
	var controller := IceController.new(graph, position, movement_knowledge)
	controller.add_ice(instance)
	movement_knowledge.report_ice(instance.instance_id, &"SEC_NODE", instance.state)
	controller.update(1, ActionRequest.new(&"PLAYER", ActionRequest.ActionType.WAIT, null, 1))
	_expect(instance.current_node_id == &"NEXT_NODE", "objective ICE moves normally")
	_expect(not movement_knowledge.get_known_node_capabilities(&"NEXT_NODE").has(NodeCapabilityType.Value.ICE), "hidden ICE movement does not reveal its destination")
	_expect(movement_knowledge.get_node_view(&"SEC_NODE").stale_ice_count == 1, "unobserved departure leaves a stale last-known marker")

	var visual := NodeVisual.new()
	visual.configure_view(movement_knowledge.get_node_view(&"SEC_NODE"), false, true, false)
	var stale := visual.capability_socket_assignments().filter(func(assignment): return assignment.kind == &"STALE_ICE")
	_expect(stale.size() == 1 and stale[0].count == 1, "stale ICE uses an explicit uncertain perimeter state")
	visual.free()
	print("%s: %d ICE capability indicator assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
