extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void:
	_test_basic_camera_and_rules()
	_test_deterministic_layered_network()
	print("%s: %d cyberspace spatial traversal assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _test_basic_camera_and_rules() -> void:
	var graph := NetworkGraph.new()
	for id: StringName in [&"ENTRY", &"RELAY", &"VAULT", &"SIDE_CHANNEL"]:
		graph.add_node(NetworkNodeDefinition.new(id, String(id), NetworkNodeDefinition.NodeType.SYSTEM))
	graph.add_link(NetworkLinkDefinition.new(&"ENTRY_RELAY", &"ENTRY", &"RELAY"))
	graph.add_link(NetworkLinkDefinition.new(&"RELAY_VAULT", &"RELAY", &"VAULT"))
	graph.add_link(NetworkLinkDefinition.new(&"RELAY_SIDE", &"RELAY", &"SIDE_CHANNEL"))
	var layout := CyberspaceSpatialLayout.new()
	layout.configure(graph, &"ENTRY")
	var initial := layout.debug_snapshot()
	_expect(initial.anchors[&"VAULT"].z < initial.anchors[&"RELAY"].z, "deeper sensor topology occupies greater horizon depth")
	_expect(is_zero_approx(float(initial.anchors[&"ENTRY"].y)) and is_zero_approx(float(initial.anchors[&"RELAY"].y)) and is_zero_approx(float(initial.anchors[&"VAULT"].y)), "successive graph layers remain on a horizontal world plane")
	_expect(not is_equal_approx(float(initial.anchors[&"RELAY"].x), float(initial.anchors[&"VAULT"].x)), "an unbranched route uses stable lateral drift instead of a vertical stack")
	_expect(absf(float(initial.anchors[&"VAULT"].x) - float(initial.anchors[&"SIDE_CHANNEL"].x)) >= CyberspaceSpatialLayout.BRANCH_WIDTH, "parallel branches spread into distinct left and right lanes")
	var rect := Rect2(0, 0, 1200, 700)
	var relay_scale := float(layout.project(&"RELAY", rect).scale)
	var vault_scale := float(layout.project(&"VAULT", rect).scale)
	_expect(absf(relay_scale - vault_scale) < 0.35, "distance compensation keeps far node panels readable")
	_expect(layout.begin_transition(&"ENTRY", &"RELAY"), "an authored adjacent transition has stable camera endpoints")
	_expect(is_equal_approx(float(layout.debug_snapshot().transition_progress), 0.0), "camera transition begins without changing topology")
	layout.set_transition_progress(0.5)
	var halfway := layout.debug_snapshot()
	_expect(halfway.camera_anchor != initial.camera_anchor, "camera glides through the stable world layout")
	layout.set_transition_progress(1.0)
	var finished := layout.debug_snapshot()
	_expect(finished.camera_anchor == finished.anchors[&"RELAY"], "camera transition ends at the destination viewpoint")
	_expect(initial.anchors == finished.anchors, "movement never reflows or rebuilds world coordinates")
	var position := PlayerNetworkPosition.new(&"ENTRY", 5)
	var changes := [0]
	graph.traversal_completed.connect(func(_a, _b, _c): changes[0] += 1)
	var accepted := graph.apply_traversal(position, &"RELAY")
	_expect(accepted.error == NetworkGraph.TraversalError.OK and changes[0] == 1 and position.current_node_id == &"RELAY", "adjacent traversal updates logical position exactly once")
	var rejected := graph.apply_traversal(position, &"ENTRY")
	_expect(rejected.error == NetworkGraph.TraversalError.OK, "reverse traversal follows the authored edge")
	var non_adjacent := graph.apply_traversal(position, &"VAULT")
	_expect(non_adjacent.error == NetworkGraph.TraversalError.NOT_CONNECTED and position.current_node_id == &"ENTRY", "non-adjacent selection cannot move or pathfind")

func _test_deterministic_layered_network() -> void:
	var graph := NetworkGraph.new()
	for id: StringName in [&"A", &"B", &"C", &"D", &"E", &"F", &"G", &"H"]:
		graph.add_node(NetworkNodeDefinition.new(id, String(id), NetworkNodeDefinition.NodeType.SYSTEM))
	for link_data: Array in [[&"AB", &"A", &"B"], [&"AC", &"A", &"C"], [&"BD", &"B", &"D"], [&"BE", &"B", &"E"], [&"CF", &"C", &"F"], [&"EG", &"E", &"G"], [&"FG", &"F", &"G"], [&"GH", &"G", &"H"]]:
		graph.add_link(NetworkLinkDefinition.new(link_data[0], link_data[1], link_data[2]))
	var layout := CyberspaceSpatialLayout.new(); layout.configure(graph, &"A")
	var initial := layout.debug_snapshot()
	_expect(initial.depths[&"A"] == 0 and initial.depths[&"B"] == 1 and initial.depths[&"C"] == 1 and initial.depths[&"G"] == 3 and initial.depths[&"H"] == 4, "rooted BFS assigns strict forward layers on the deterministic debug graph")
	_expect(float(initial.lanes[&"B"]) < float(initial.lanes[&"C"]), "subtree allocation places the B branch left of the C branch")
	_expect((initial.anchors.values() as Array).all(func(position: Vector3): return is_equal_approx(position.y, CyberspaceSpatialLayout.NODE_BASE_HEIGHT)), "all debug graph nodes share one world-space height")
	_expect(layout.validation_issues().is_empty(), "layered layout satisfies height and forward-edge invariants")
	var original_anchors: Dictionary = initial.anchors.duplicate(true)
	var original_endpoints: Dictionary = initial.edge_endpoints.duplicate(true)
	var original_length := layout.edge_world_length(&"BE")
	for route: Array in [[&"A", &"B"], [&"B", &"E"], [&"E", &"G"], [&"G", &"H"], [&"H", &"G"], [&"G", &"E"], [&"E", &"B"]]:
		layout.begin_transition(route[0], route[1]); layout.set_transition_progress(0.5); layout.set_transition_progress(1.0)
	_expect(layout.debug_snapshot().anchors == original_anchors, "forward and backward camera travel never mutates node positions")
	_expect(layout.debug_snapshot().edge_endpoints == original_endpoints and is_equal_approx(layout.edge_world_length(&"BE"), original_length), "camera travel preserves fixed edge endpoints and world length")
	graph.add_node(NetworkNodeDefinition.new(&"I", "I", NetworkNodeDefinition.NodeType.SYSTEM))
	graph.add_link(NetworkLinkDefinition.new(&"EI", &"E", &"I"))
	layout.configure(graph, &"H")
	var expanded := layout.debug_snapshot()
	_expect(original_anchors.keys().all(func(id: Variant): return expanded.anchors[id] == original_anchors[id]), "sensor-style topology expansion positions only the newly added node")
	_expect(expanded.depths[&"I"] == 3 and (expanded.anchors[&"I"] as Vector3).z < (expanded.anchors[&"E"] as Vector3).z, "newly revealed nodes inherit rooted depth and remain forward")

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
