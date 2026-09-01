extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void:
	_test_movement_budget_and_investigation()
	_test_exact_detection_and_knowledge()
	_test_deterministic_patrol()
	print("%s: %d ICE controller assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _test_movement_budget_and_investigation() -> void:
	var fixture := _fixture(TestNetworkFactory.ROUTER_A)
	var controller: IceController = fixture.controller
	var knowledge: PlayerKnowledge = fixture.knowledge
	var ice := controller.get_ice(&"TEST_ICE")
	var request := ActionRequest.new(&"PLAYER", ActionRequest.ActionType.PING, null, 1)
	var first_events := controller.update(1, request)
	_expect(ice.state == IceState.Value.INVESTIGATE, "nearby activity wakes dormant ICE")
	_expect(ice.current_node_id == TestNetworkFactory.SECURITY_SERVER, "ICE stays until movement budget is met")
	_expect(not knowledge.knows_ice(ice.instance_id), "signal inference does not reveal exact ICE position")
	_expect(_has_event(first_events, &"SIGNAL_DETECTED"), "player receives an inferred signal event")
	controller.update(1, request)
	_expect(ice.current_node_id == TestNetworkFactory.AUTH_SERVER, "ICE moves one graph edge after enough time")

func _test_exact_detection_and_knowledge() -> void:
	var fixture := _fixture(TestNetworkFactory.SECURITY_SERVER)
	var controller: IceController = fixture.controller
	var knowledge: PlayerKnowledge = fixture.knowledge
	var request := ActionRequest.new(&"PLAYER", ActionRequest.ActionType.WAIT, null, 1)
	var events := controller.update(1, request)
	var ice := controller.get_ice(&"TEST_ICE")
	_expect(ice.state == IceState.Value.ENGAGE, "co-located ICE enters engage state")
	_expect(knowledge.ice_records[ice.instance_id].node_id == TestNetworkFactory.SECURITY_SERVER, "exact detection reveals ICE position")
	_expect(controller.pending_trace_increase == 2, "exact detection creates trace pressure")
	_expect(_has_event(events, &"PLAYER_DETECTED"), "exact detection produces an event")

func _test_deterministic_patrol() -> void:
	var graph := TestNetworkFactory.create_graph()
	var player := PlayerNetworkPosition.new(TestNetworkFactory.PUBLIC_GATEWAY, 10)
	var knowledge := PlayerKnowledge.new()
	var controller := IceController.new(graph, player, knowledge)
	var route: Array[StringName] = [TestNetworkFactory.WORKSTATION_01, TestNetworkFactory.ROUTER_A, TestNetworkFactory.WORKSTATION_02]
	var definition := IceDefinition.new(&"PATROLLER", "Patroller", 0, 1, 0, route)
	var ice := IceInstance.new(&"PATROL_ICE", definition, TestNetworkFactory.WORKSTATION_01, IceState.Value.PATROL)
	controller.add_ice(ice)
	controller.update(1, ActionRequest.new(&"SYSTEM", ActionRequest.ActionType.WAIT, null, 1))
	_expect(ice.current_node_id == TestNetworkFactory.ROUTER_A, "patrol follows its fixed route")

func _fixture(player_node: StringName) -> Dictionary:
	var graph := TestNetworkFactory.create_graph()
	var player := PlayerNetworkPosition.new(player_node, 10)
	var knowledge := PlayerKnowledge.new()
	var controller := IceController.new(graph, player, knowledge)
	var route: Array[StringName] = [TestNetworkFactory.SECURITY_SERVER, TestNetworkFactory.AUTH_SERVER, TestNetworkFactory.ROUTER_A]
	var definition := IceDefinition.new(&"TEST", "Test ICE", 1, 2, 2, route)
	controller.add_ice(IceInstance.new(&"TEST_ICE", definition, TestNetworkFactory.SECURITY_SERVER, IceState.Value.DORMANT))
	return {"controller": controller, "knowledge": knowledge}

func _has_event(events: Array[Dictionary], type: StringName) -> bool:
	for event in events:
		if event.get("type") == type:
			return true
	return false

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
