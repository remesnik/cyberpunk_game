extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void:
	_test_adjacent_attack_and_disruption()
	_test_information_and_capability_requirements()
	_test_spoof_redirect_and_hide()
	_test_link_control_trace_and_retreat()
	print("%s: %d confrontation assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _test_adjacent_attack_and_disruption() -> void:
	var fixture := _fixture(TestNetworkFactory.AUTH_SERVER, TestNetworkFactory.SECURITY_SERVER)
	var controller: ConfrontationController = fixture.controller
	var ice: IceInstance = fixture.ice
	var target := {"kind": &"ICE", "ice_id": ice.instance_id}
	var attack := controller.execute(ActionRequest.ActionType.ATTACK_PROCESS, target)
	_expect(attack.success and ice.integrity == ice.definition.maximum_integrity - 2, "adjacent program attack deterministically applies defense-adjusted damage")
	var disrupt := controller.execute(ActionRequest.ActionType.DISRUPT, target)
	_expect(disrupt.success and ice.disrupted_time == 2, "disrupt delays ICE by data-defined duration")
	_expect(attack.cost == 2 and attack.trace_generated == 2, "attack returns data-driven action cost and trace")

func _test_information_and_capability_requirements() -> void:
	var fixture := _fixture(TestNetworkFactory.AUTH_SERVER, TestNetworkFactory.SECURITY_SERVER, false)
	var controller: ConfrontationController = fixture.controller
	var target := {"kind": &"ICE", "ice_id": fixture.ice.instance_id}
	_expect(not controller.validate(ActionRequest.ActionType.ATTACK_PROCESS, target).success, "unidentified ICE cannot be precisely targeted")
	fixture.knowledge.report_ice(fixture.ice.instance_id, fixture.ice.current_node_id, fixture.ice.state)
	_expect(not controller.validate(ActionRequest.ActionType.SPOOF, target).success, "SPOOF action requires the capability")

func _test_spoof_redirect_and_hide() -> void:
	var fixture := _fixture(TestNetworkFactory.AUTH_SERVER, TestNetworkFactory.SECURITY_SERVER)
	var player: PlayerNetworkPosition = fixture.player
	var ice: IceInstance = fixture.ice
	var controller: ConfrontationController = fixture.controller
	player.grant_capability(CapabilityCatalog.SPOOF)
	player.grant_capability(CapabilityCatalog.GHOST)
	ice.known_player_position = player.current_node_id
	ice.alert_level = 80
	var target := {"kind": &"ICE", "ice_id": ice.instance_id}
	var spoof: ConfrontationResult = controller.execute(ActionRequest.ActionType.SPOOF, target)
	_expect(spoof.success and ice.state == IceState.Value.RETURN and ice.alert_level == 45, "spoof redirects ICE toward home and reduces alert")
	ice.known_player_position = player.current_node_id
	var hidden: ConfrontationResult = controller.execute(ActionRequest.ActionType.HIDE, {"kind": &"SELF"})
	_expect(hidden.success and ice.known_player_position == &"" and ice.state == IceState.Value.SEARCH, "GHOST hide removes current player fix")
	var redirect_target := {"kind": &"ICE", "ice_id": ice.instance_id, "redirect_node_id": TestNetworkFactory.AUTH_SERVER}
	var redirected: ConfrontationResult = controller.execute(ActionRequest.ActionType.REDIRECT, redirect_target)
	_expect(redirected.success and ice.target_node_id == TestNetworkFactory.AUTH_SERVER, "redirect selects a known adjacent topology target")

func _test_link_control_trace_and_retreat() -> void:
	var fixture := _fixture(TestNetworkFactory.ROUTER_A, TestNetworkFactory.AUTH_SERVER)
	var player: PlayerNetworkPosition = fixture.player
	var knowledge: PlayerKnowledge = fixture.knowledge
	var controller: ConfrontationController = fixture.controller
	player.grant_capability(CapabilityCatalog.DECRYPT)
	player.grant_capability(CapabilityCatalog.TRACE_SCRAMBLER)
	var link := fixture.graph.get_link(&"ROUTER_AUTH") as NetworkLinkDefinition
	knowledge.reveal_link(link, KnowledgeLevel.Value.SCANNED)
	var contact: StringName = knowledge.link_records[link.id].contact_id
	var broken: ConfrontationResult = controller.execute(ActionRequest.ActionType.BREAK_LOCK, {"kind": &"LINK", "contact_id": contact})
	_expect(broken.success and not link.locked, "break lock changes authoritative route control")
	var scramble: ConfrontationResult = controller.execute(ActionRequest.ActionType.TRACE_SCRAMBLE, {"kind": &"SELF"})
	_expect(scramble.success and scramble.events[0].reduction == 4, "trace scramble returns deterministic reduction")
	player.current_node_id = TestNetworkFactory.WORKSTATION_01
	var retreat: ConfrontationResult = controller.execute(ActionRequest.ActionType.RETREAT, {"kind": &"NODE", "node_id": TestNetworkFactory.ROUTER_A})
	_expect(retreat.success and player.current_node_id == TestNetworkFactory.ROUTER_A, "retreat is a discrete graph traversal")
	_expect(retreat.cost == 2, "retreat combines base action and route costs")

func _fixture(player_node: StringName, ice_node: StringName, identify_ice := true) -> Dictionary:
	var graph := TestNetworkFactory.create_graph()
	var player := PlayerNetworkPosition.new(player_node, 20)
	var knowledge := TestNetworkFactory.create_player_knowledge(graph)
	knowledge.reveal_node(graph.get_node(player_node), KnowledgeLevel.Value.IDENTIFIED)
	knowledge.reveal_node(graph.get_node(ice_node), KnowledgeLevel.Value.IDENTIFIED)
	var ice_controller := IceController.new(graph, player, knowledge)
	var definition := IceDefinition.new(&"DUELIST", "Duelist ICE", 1, 2, 2, [], 8, 1)
	var ice := IceInstance.new(&"DUELIST_01", definition, ice_node, IceState.Value.HUNT)
	ice_controller.add_ice(ice)
	if identify_ice:
		knowledge.report_ice(ice.instance_id, ice.current_node_id, ice.state)
	return {"graph": graph, "player": player, "knowledge": knowledge, "ice": ice, "controller": ConfrontationController.new(graph, player, knowledge, ice_controller)}

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
