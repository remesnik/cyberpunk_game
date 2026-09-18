extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void:
	var graph := _graph()
	var position := PlayerNetworkPosition.new(&"A", 20)
	var knowledge := PlayerKnowledge.new()
	knowledge.mark_node_visited(graph.get_node(&"A"))
	var sensors := SensorTopologyController.new()

	sensors.configure(graph, position, knowledge, 0)
	_expect(_visible(sensors) == [&"A", &"B"], "Sensors 0 exposes current and immediate nodes")
	_expect(not knowledge.player_knows_node_exists(&"C") and not knowledge.player_knows_node_exists(&"E"), "Sensors 0 detects no distant topology")

	sensors.set_sensors_rating(1)
	_expect(_visible(sensors) == [&"A", &"B", &"C", &"E"], "Sensors 1 exposes one layer beyond immediate nodes: %s" % [_visible(sensors)])
	_assert_unknown(knowledge, &"C")
	_assert_unknown(knowledge, &"E")
	_expect(not knowledge.player_knows_node_exists(&"D") and not knowledge.player_knows_node_exists(&"F"), "Sensors 1 remains bounded")

	sensors.set_sensors_rating(2)
	_expect(_visible(sensors) == [&"A", &"B", &"C", &"E"], "Sensors 2 currently shares Sensors 1 range: %s" % [_visible(sensors)])
	sensors.set_sensors_rating(3)
	_expect(_visible(sensors) == [&"A", &"B", &"C", &"D", &"E", &"F"], "Sensors 3 exposes two layers beyond immediate nodes: %s" % [_visible(sensors)])
	for id in [&"C", &"D", &"E", &"F"]: _assert_unknown(knowledge, id)
	_expect(sensors.current_view().edges.size() == 5, "branching and cycles create no duplicate BFS edges")

	knowledge.mark_node_scanned(graph.get_node(&"C"))
	sensors.recalculate()
	_expect(knowledge.get_node_level(&"C") == KnowledgeLevel.Value.SCANNED and knowledge.get_node_view(&"C").display_name == "C SECRET", "Sensors never downgrade scanned knowledge")
	var rejected := graph.validate_traversal(position, &"C", knowledge.link_records.keys())
	_expect(rejected.error == NetworkGraph.TraversalError.NOT_CONNECTED, "distant detected nodes cannot be traversed to")
	_expect(not graph.get_node(&"D").discovered and graph.get_node(&"D").display_name == "D SECRET", "Sensors never mutate authoritative graph nodes")

	position.relocate(&"B")
	_expect(_visible(sensors).has(&"D") and _visible(sensors).has(&"F"), "movement recalculates from current position")
	sensors.set_sensors_rating(0)
	_expect(_visible(sensors) == [&"A", &"B", &"C", &"E"], "lower rating contracts current sensor view")
	_expect(knowledge.player_knows_node_exists(&"D") and knowledge.get_node_level(&"D") == KnowledgeLevel.Value.DETECTED, "detected topology persists in player knowledge outside range")
	var restored := PlayerKnowledge.new()
	restored.node_records = knowledge.node_records.duplicate(true)
	restored.link_records = knowledge.link_records.duplicate(true)
	_expect(restored.get_node_knowledge_state(&"D") == &"DETECTED" and restored.get_node_view(&"D").sources.has(&"DECK_SENSORS"), "detected topology and provenance survive knowledge persistence")
	graph.add_node(NetworkNodeDefinition.new(&"G", "G SECRET", NetworkNodeDefinition.NodeType.SYSTEM, 9))
	graph.add_link(NetworkLinkDefinition.new(&"BG", &"B", &"G"))
	_expect(_visible(sensors).has(&"G") and knowledge.knows_node(&"G"), "graph topology changes recalculate immediate sensor view")

	_expect(SensorTopologyController.get_sensor_lookahead_depth(0) == 0 and SensorTopologyController.get_sensor_lookahead_depth(1) == 1 and SensorTopologyController.get_sensor_lookahead_depth(2) == 1 and SensorTopologyController.get_sensor_lookahead_depth(3) == 2, "rating mapping is centralized and explicit")
	_expect("Node B [CURRENT] depth=0" in "\n".join(sensors.debug_lines()), "development debug output includes current depth")
	print("%s: %d sensor topology assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _graph() -> NetworkGraph:
	var graph := NetworkGraph.new()
	for id in [&"A", &"B", &"C", &"D", &"E", &"F"]:
		graph.add_node(NetworkNodeDefinition.new(id, "%s SECRET" % id, NetworkNodeDefinition.NodeType.SYSTEM, 7, false, &"HIDDEN_OWNER"))
	for data in [[&"AB", &"A", &"B"], [&"BC", &"B", &"C"], [&"CD", &"C", &"D"], [&"BE", &"B", &"E"], [&"EF", &"E", &"F"], [&"CE", &"C", &"E"]]:
		graph.add_link(NetworkLinkDefinition.new(data[0], data[1], data[2]))
	return graph

func _visible(sensors: SensorTopologyController) -> Array[StringName]:
	var ids: Array[StringName] = []
	for item: Dictionary in sensors.current_view().nodes: ids.append(StringName(item.node_id))
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids

func _assert_unknown(knowledge: PlayerKnowledge, id: StringName) -> void:
	var view := knowledge.get_node_view(id)
	_expect(knowledge.get_node_level(id) == KnowledgeLevel.Value.DETECTED and not bool(view.identity_known), "%s is DETECTED with no identity" % id)
	_expect(not view.has("display_name") and not view.has("node_type") and not view.has("security_level") and not view.has("owner_faction") and not view.has("service_ids"), "%s exposes no hidden node data" % id)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
