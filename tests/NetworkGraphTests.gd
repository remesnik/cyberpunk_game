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

func _expect(condition: bool, description: String) -> void:
	tests_run += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
