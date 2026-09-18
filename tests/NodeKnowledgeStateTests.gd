extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void:
	_test_independent_node_facts()
	_test_scan_and_visit_are_distinct()
	_test_authoritative_graph_is_unchanged()
	print("%s: %d node knowledge state assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _test_independent_node_facts() -> void:
	var node := NetworkNodeDefinition.new(&"VAULT", "Payroll Vault", NetworkNodeDefinition.NodeType.FILE_SERVER, 7, false, &"CORP")
	node.add_service(&"LEDGER", "Ledger", 8)
	var knowledge := PlayerKnowledge.new()
	knowledge.discover_node(node, &"INTERCEPTED_DATA")
	_expect(knowledge.player_knows_node_exists(node.id) and knowledge.get_node_knowledge_state(node.id) == &"UNKNOWN", "UNKNOWN records know a node exists without revealing its level")
	_expect(not knowledge.player_knows_node_level(node.id) and not knowledge.player_knows_node_contents(node.id), "node existence does not leak level or contents")
	knowledge.reveal_node_level(node, &"OTHER_HACKER")
	_expect(knowledge.player_knows_node_level(node.id) and knowledge.get_node_view(node.id).security_level == 7, "security level can arrive through independent intelligence")
	_expect(not knowledge.player_has_scanned_node(node.id) and not knowledge.player_knows_node_contents(node.id), "LEVEL_KNOWN does not imply scanned contents")
	knowledge.reveal_node_contents(node, &"STORY_INFORMATION")
	_expect(knowledge.player_knows_node_contents(node.id) and knowledge.get_node_view(node.id).service_ids == [&"LEDGER"], "contents and capabilities can be revealed separately")
	_expect(not knowledge.player_has_scanned_node(node.id), "content intelligence does not falsely record a player scan")

func _test_scan_and_visit_are_distinct() -> void:
	var scanned := NetworkNodeDefinition.new(&"SCANNED", "Scanned Host", NetworkNodeDefinition.NodeType.ROUTER, 4)
	var visited := NetworkNodeDefinition.new(&"VISITED", "Visited Host", NetworkNodeDefinition.NodeType.SYSTEM, 9)
	var knowledge := PlayerKnowledge.new()
	knowledge.mark_node_scanned(scanned, false, true)
	_expect(knowledge.player_has_scanned_node(scanned.id) and knowledge.player_knows_node_contents(scanned.id), "SCANNED tracks sufficient content discovery")
	_expect(not knowledge.player_knows_node_level(scanned.id) and not knowledge.player_has_visited_node(scanned.id), "a scan need not reveal level or imply visitation")
	knowledge.mark_node_visited(visited)
	_expect(knowledge.player_has_visited_node(visited.id) and knowledge.knows_node(visited.id), "entering a node records VISITED and its identity")
	_expect(not knowledge.player_has_scanned_node(visited.id) and not knowledge.player_knows_node_level(visited.id) and not knowledge.player_knows_node_contents(visited.id), "visiting does not automatically scan or reveal security and contents")

func _test_authoritative_graph_is_unchanged() -> void:
	var graph := NetworkGraph.new()
	var node := NetworkNodeDefinition.new(&"HIDDEN", "Hidden Host", NetworkNodeDefinition.NodeType.AUTH_SERVER, 6, false)
	graph.add_node(node)
	var knowledge := PlayerKnowledge.new(); knowledge.reveal_node_level(node, &"PREVIOUS_KNOWLEDGE"); knowledge.mark_node_scanned(node)
	_expect(not graph.get_node(node.id).discovered and graph.get_node(node.id).security_level == 6, "player knowledge never mutates authoritative node discovery or contents")
	_expect(knowledge.get_node_view(node.id).sources.has(&"PREVIOUS_KNOWLEDGE") and knowledge.get_node_view(node.id).sources.has(&"SCAN"), "node facts retain their discovery provenance")

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition: failures += 1; printerr("FAILED: %s" % description)
