extends SceneTree

var failures := 0
var tests_run := 0

func _init() -> void:
	_test_valid_traversal()
	_test_locked_traversal()
	_test_hidden_link()
	_test_one_way_link()
	_test_disabled_link()
	_test_invalid_node()
	_test_traversal_cost()
	_test_directional_permissions()
	_test_node_path_controls()
	_test_remote_path_control()
	_test_hard_and_soft_security_gates()
	_test_lockdown_after_traversal()
	_test_direction_save_restore()
	print("%s: %d network graph assertions" % ["PASS" if failures == 0 else "FAIL", tests_run])
	quit(failures)

func _test_valid_traversal() -> void:
	var graph := TestNetworkFactory.create_graph()
	var player := TestNetworkFactory.create_player()
	var result := graph.traverse(player, TestNetworkFactory.ROUTER_A)
	_expect(result.error == NetworkGraph.TraversalError.OK, "valid traversal succeeds")
	_expect(player.current_node_id == TestNetworkFactory.ROUTER_A, "position changes")
	_expect(player.previous_node_id == TestNetworkFactory.PUBLIC_GATEWAY, "previous node recorded")
	_expect(player.traversal_history == [TestNetworkFactory.PUBLIC_GATEWAY, TestNetworkFactory.ROUTER_A], "history recorded")

func _test_locked_traversal() -> void:
	var graph := TestNetworkFactory.create_graph()
	var player := PlayerNetworkPosition.new(TestNetworkFactory.ROUTER_A, 10)
	var result := graph.traverse(player, TestNetworkFactory.AUTH_SERVER)
	_expect(result.error == NetworkGraph.TraversalError.LOCKED_LINK, "locked link rejected")
	_expect(player.current_node_id == TestNetworkFactory.ROUTER_A, "locked link preserves position")

func _test_hidden_link() -> void:
	var graph := TestNetworkFactory.create_graph()
	var player := PlayerNetworkPosition.new(TestNetworkFactory.AUTH_SERVER, 10)
	var visible := graph.get_visible_connected_nodes(TestNetworkFactory.AUTH_SERVER)
	var result := graph.traverse(player, TestNetworkFactory.SECURITY_SERVER)
	_expect(not visible.has(TestNetworkFactory.SECURITY_SERVER), "hidden link omitted from visible neighbors")
	_expect(result.error == NetworkGraph.TraversalError.HIDDEN_LINK, "hidden link rejected")

func _test_one_way_link() -> void:
	var graph := TestNetworkFactory.create_graph()
	var player := PlayerNetworkPosition.new(TestNetworkFactory.FILE_SERVER, 10)
	var result := graph.traverse(player, TestNetworkFactory.WORKSTATION_01)
	_expect(result.error == NetworkGraph.TraversalError.NOT_CONNECTED, "one-way reverse rejected")

func _test_disabled_link() -> void:
	var graph := TestNetworkFactory.create_graph()
	var player := PlayerNetworkPosition.new(TestNetworkFactory.WORKSTATION_02, 10)
	var result := graph.traverse(player, TestNetworkFactory.FILE_SERVER)
	_expect(result.error == NetworkGraph.TraversalError.DISABLED_LINK, "disabled link rejected")

func _test_invalid_node() -> void:
	var graph := TestNetworkFactory.create_graph()
	var player := TestNetworkFactory.create_player()
	var result := graph.traverse(player, &"DOES_NOT_EXIST")
	_expect(result.error == NetworkGraph.TraversalError.INVALID_DESTINATION, "invalid node rejected")

func _test_traversal_cost() -> void:
	var graph := TestNetworkFactory.create_graph()
	var player := TestNetworkFactory.create_player(1)
	var result := graph.traverse(player, TestNetworkFactory.ROUTER_A)
	_expect(result.error == NetworkGraph.TraversalError.OK, "affordable traversal succeeds")
	_expect(player.traversal_points == 0, "cost spent")
	_expect(player.total_traversal_cost_spent == 1, "spent cost tracked")
	var second_result := graph.traverse(player, TestNetworkFactory.WORKSTATION_01)
	_expect(second_result.error == NetworkGraph.TraversalError.INSUFFICIENT_POINTS, "unaffordable traversal rejected")

func _test_directional_permissions() -> void:
	var graph := NetworkGraph.new()
	graph.add_node(NetworkNodeDefinition.new(&"A", "A", NetworkNodeDefinition.NodeType.SYSTEM))
	graph.add_node(NetworkNodeDefinition.new(&"B", "B", NetworkNodeDefinition.NodeType.SYSTEM))
	var link := NetworkLinkDefinition.new(&"AB", &"A", &"B")
	link.configure_direction(&"A", &"B", {"state": &"LOCKED", "controller_node_id": &"A"})
	link.configure_direction(&"B", &"A", {"state": &"UNLOCKED", "controller_node_id": &"B"})
	graph.add_link(link)
	var at_a := PlayerNetworkPosition.new(&"A", 5)
	var denied := graph.validate_traversal(at_a, &"B", [&"AB"])
	_expect(denied.error == NetworkGraph.TraversalError.LOCKED_LINK and denied.controller_node_id == &"A", "A to B has independent source-controlled state")
	_expect(not graph.unlock_outbound_path(&"AB", &"A", &"B", false).success, "direction cannot be unlocked from Network Mode")
	_expect(graph.unlock_outbound_path(&"AB", &"A", &"B", true).success, "controller unlocks its outbound direction in Node Mode")
	_expect(graph.validate_traversal(at_a, &"B", [&"AB"]).error == NetworkGraph.TraversalError.OK, "unlocked outbound direction becomes traversable")
	var at_b := PlayerNetworkPosition.new(&"B", 5)
	link.get_direction(&"B", &"A").state = TraversalDirectionDefinition.State.DISCOVERED
	_expect(graph.validate_traversal(at_b, &"A", [&"AB"]).error == NetworkGraph.TraversalError.LOCKED_LINK, "discovery does not grant reverse traversal")

func _test_node_path_controls() -> void:
	var graph := NetworkGraph.new()
	for node_id: StringName in [&"A", &"B", &"C", &"D", &"E"]: graph.add_node(NetworkNodeDefinition.new(node_id, node_id, NetworkNodeDefinition.NodeType.SYSTEM))
	for destination: StringName in [&"B", &"C", &"D", &"E"]:
		var link := NetworkLinkDefinition.new(StringName("A_%s" % destination), &"A", destination)
		link.get_direction(&"A", destination).state = TraversalDirectionDefinition.State.LOCKED_DOWN if destination == &"E" else TraversalDirectionDefinition.State.LOCKED
		graph.add_link(link)
	var single := NodePathControl.new(&"AUTH_B", &"authentication_succeeded"); single.subject_id = &"LOGIN_B"; single.destination_node_ids.assign([&"B"]); graph.get_node(&"A").add_path_control(single)
	var multiple := NodePathControl.new(&"BYPASS_BRANCH", &"ice_bypassed"); multiple.subject_id = &"ICE_BRANCH"; multiple.destination_node_ids.assign([&"B", &"C"]); graph.get_node(&"A").add_path_control(multiple)
	var all := NodePathControl.new(&"ROOT_CONTROL", &"objective_completed"); all.scope = NodePathControl.Scope.ALL_NORMAL; graph.get_node(&"A").add_path_control(all)
	_expect(graph.apply_node_interaction(&"A", &"authentication_succeeded", {"subject_id": &"WRONG"}).is_empty(), "different paths can require different matching interactions")
	var one := graph.apply_node_interaction(&"A", &"authentication_succeeded", {"subject_id": &"LOGIN_B"})
	_expect(one.size() == 1 and one[0].destination_node_id == &"B", "one interaction unlocks one specific outbound path")
	var many := graph.apply_node_interaction(&"A", &"ice_bypassed", {"ice_id": &"ICE_BRANCH"})
	_expect(many.size() == 1 and graph.get_link(&"A_C").get_direction(&"A", &"C").is_traversable(), "one interaction can unlock multiple selected paths without re-reporting open routes")
	var normal := graph.apply_node_interaction(&"A", &"objective_completed", {"objective_id": &"ROOT"})
	_expect(normal.size() == 1 and graph.get_link(&"A_D").get_direction(&"A", &"D").is_traversable(), "all-normal control unlocks remaining normal paths")
	_expect(graph.get_link(&"A_E").get_direction(&"A", &"E").state == TraversalDirectionDefinition.State.LOCKED_DOWN, "all-normal control leaves permanently unavailable path locked down")

func _test_remote_path_control() -> void:
	var graph := NetworkGraph.new()
	for node_id: StringName in [&"A", &"B", &"C"]: graph.add_node(NetworkNodeDefinition.new(node_id, node_id, NetworkNodeDefinition.NodeType.SYSTEM))
	var ab := NetworkLinkDefinition.new(&"AB", &"A", &"B")
	var gate := ab.get_direction(&"A", &"B"); gate.state = TraversalDirectionDefinition.State.LOCKED; gate.remote_controller_node_id = &"C"
	graph.add_link(ab); graph.add_link(NetworkLinkDefinition.new(&"AC", &"A", &"C"))
	var control := NodePathControl.new(&"REMOTE_AB", &"service_disabled"); control.subject_id = &"ROUTING_CONTROL"; control.link_ids.assign([&"AB"]); graph.get_node(&"C").add_path_control(control)
	var events := graph.apply_node_interaction(&"C", &"service_disabled", {"service_id": &"ROUTING_CONTROL"})
	_expect(events.size() == 1 and events[0].source_node_id == &"A" and gate.is_traversable(), "reachable remote controller can unlock another node's outbound path")
	_expect(graph.validate_structure().filter(func(issue: Dictionary): return issue.get("category") == &"REMOTE_PATH_CONTROL").is_empty(), "reachable remote controller passes structure validation")
	var circular := NetworkGraph.new()
	for node_id: StringName in [&"A", &"B", &"C"]: circular.add_node(NetworkNodeDefinition.new(node_id, node_id, NetworkNodeDefinition.NodeType.SYSTEM))
	var first := NetworkLinkDefinition.new(&"AB", &"A", &"B", true); first.get_direction(&"A", &"B").remote_controller_node_id = &"C"; circular.add_link(first)
	circular.add_link(NetworkLinkDefinition.new(&"BC", &"B", &"C", true))
	var errors := circular.validate_structure().filter(func(issue: Dictionary): return issue.get("severity") == &"ERROR" and issue.get("category") == &"REMOTE_PATH_CONTROL")
	_expect(errors.size() == 1, "circular remote-controller dependency is a level-design error")
	first.get_direction(&"A", &"B").allow_circular_remote_gate = true
	var warnings := circular.validate_structure().filter(func(issue: Dictionary): return issue.get("severity") == &"WARNING" and issue.get("category") == &"REMOTE_PATH_CONTROL")
	_expect(warnings.size() == 1, "explicit circular remote-gate override is retained as a warning")

func _test_hard_and_soft_security_gates() -> void:
	var graph := NetworkGraph.new()
	for node_id: StringName in [&"A", &"B", &"C"]: graph.add_node(NetworkNodeDefinition.new(node_id, node_id, NetworkNodeDefinition.NodeType.SYSTEM))
	var hard := NetworkLinkDefinition.new(&"AB", &"A", &"B")
	var hard_direction := hard.get_direction(&"A", &"B"); hard_direction.gate_type = TraversalDirectionDefinition.GateType.HARD; hard_direction.security_resolved = false; hard_direction.controlling_security = {"kind": &"ICE", "id": &"WARDEN"}
	graph.add_link(hard)
	var soft := NetworkLinkDefinition.new(&"AC", &"A", &"C")
	var soft_direction := soft.get_direction(&"A", &"C"); soft_direction.gate_type = TraversalDirectionDefinition.GateType.SOFT; soft_direction.security_resolved = false; soft_direction.controlling_security = {"kind": &"ICE", "id": &"WATCHER"}; soft_direction.on_unauthorized_traversal.assign([{"type": &"INCREASE_TRACE", "amount": 2}, {"type": &"NOTIFY_ICE", "ice_id": &"WATCHER"}])
	graph.add_link(soft)
	var position := PlayerNetworkPosition.new(&"A", 10)
	_expect(graph.validate_traversal(position, &"B").error == NetworkGraph.TraversalError.LOCKED_LINK, "unresolved hard security gate blocks traversal")
	hard_direction.security_resolved = true
	_expect(graph.validate_traversal(position, &"B").error == NetworkGraph.TraversalError.OK, "resolved hard security gate permits traversal")
	var warning := graph.validate_traversal(position, &"C")
	_expect(warning.error == NetworkGraph.TraversalError.OK and warning.soft_gate_unauthorized and warning.consequences.size() == 2, "soft security gate remains traversable and exposes authored consequences")
	var crossed := graph.apply_traversal(position, &"C")
	_expect(crossed.error == NetworkGraph.TraversalError.OK and position.current_node_id == &"C", "soft gate never forces Node Mode or blocks traversal")
	position.relocate(&"A"); soft_direction.security_resolved = true
	_expect(not bool(graph.validate_traversal(position, &"C").get("soft_gate_unauthorized", false)), "resolved soft security suppresses unauthorized consequences")

func _test_lockdown_after_traversal() -> void:
	var graph := NetworkGraph.new(); graph.add_node(NetworkNodeDefinition.new(&"A", "A", NetworkNodeDefinition.NodeType.SYSTEM)); graph.add_node(NetworkNodeDefinition.new(&"B", "B", NetworkNodeDefinition.NodeType.SYSTEM))
	var link := NetworkLinkDefinition.new(&"AB", &"A", &"B"); var forward := link.get_direction(&"A", &"B")
	forward.gate_type = TraversalDirectionDefinition.GateType.SOFT; forward.security_resolved = false; forward.on_unauthorized_traversal.assign([{"type": &"LOCK_PATH_BEHIND", "link_id": &"AB"}]); graph.add_link(link)
	var position := PlayerNetworkPosition.new(&"A", 5); var result := graph.apply_traversal(position, &"B")
	_expect(result.allowed and link.get_direction(&"B", &"A").state == TraversalDirectionDefinition.State.LOCKED_DOWN, "soft-gate traversal can lock down the return path behind the player")

func _test_direction_save_restore() -> void:
	var original := TraversalDirectionDefinition.new(&"A", &"B", TraversalDirectionDefinition.State.LOCKED, &"C")
	original.gate_type = TraversalDirectionDefinition.GateType.SOFT; original.security_resolved = false; original.allow_circular_remote_gate = true; original.on_unauthorized_traversal.assign([{"type": &"INCREASE_TRACE", "amount": 3}])
	var restored := TraversalDirectionDefinition.new(&"A", &"B"); restored.apply_authored(original.snapshot())
	_expect(restored.state == TraversalDirectionDefinition.State.LOCKED and restored.controller_node_id == &"C" and restored.gate_type == TraversalDirectionDefinition.GateType.SOFT and restored.on_unauthorized_traversal.size() == 1 and restored.allow_circular_remote_gate, "save/load snapshot preserves directional path and security state")

func _expect(condition: bool, description: String) -> void:
	tests_run += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
