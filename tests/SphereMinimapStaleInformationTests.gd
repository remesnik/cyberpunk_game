extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void:
	var graph := NetworkGraph.new()
	var sphere := SphereDefinition.new(&"OPS", "Operations")
	graph.add_sphere(sphere)
	graph.add_node(NetworkNodeDefinition.new(&"NODE_4", "Node 4", NetworkNodeDefinition.NodeType.SYSTEM, 2, true, &"CORP", sphere.id))
	graph.add_node(NetworkNodeDefinition.new(&"NODE_5", "Node 5", NetworkNodeDefinition.NodeType.SYSTEM, 3, true, &"CORP", sphere.id))
	graph.add_link(NetworkLinkDefinition.new(&"TEMP_ROUTE", &"NODE_4", &"NODE_5"))
	var knowledge := PlayerKnowledge.new()
	knowledge.reveal_node(graph.get_node(&"NODE_4"), KnowledgeLevel.Value.SCANNED)
	knowledge.reveal_node(graph.get_node(&"NODE_5"), KnowledgeLevel.Value.SCANNED)
	knowledge.reveal_link(graph.get_link(&"TEMP_ROUTE"), KnowledgeLevel.Value.IDENTIFIED)
	knowledge.report_ice(&"ICE_TRACKER", &"NODE_4", IceState.Value.SEARCH, KnowledgeLevel.Value.IDENTIFIED, 0, 3)
	var position := PlayerNetworkPosition.new(&"NODE_5")
	var canvas := SphereMinimapCanvas.new(); canvas.size = Vector2(340, 178); canvas.set_models(graph, position, knowledge)
	_expect(canvas.minimap_node_for(&"NODE_4").semantic_markers().has(&"ICE"), "fresh ICE observation renders as currently present")
	knowledge.advance_knowledge_time(5)
	var stale_visual := canvas.minimap_node_for(&"NODE_4")
	_expect(not stale_visual.semantic_markers().has(&"ICE") and stale_visual.semantic_markers().has(&"ICE_STALE"), "unrefreshed ICE position becomes last-known rather than definite")
	_expect("5 TICKS AGO" in stale_visual.known_name_for_inspection(), "stale ICE tooltip exposes observation age without revealing a new position")
	knowledge.report_ice(&"ICE_TRACKER", &"NODE_5", IceState.Value.HUNT, KnowledgeLevel.Value.IDENTIFIED, 5, 3)
	_expect(not canvas.minimap_node_for(&"NODE_4").semantic_markers().has(&"ICE_STALE") and canvas.minimap_node_for(&"NODE_5").semantic_markers().has(&"ICE"), "a fresh observation replaces stale location with the newly observed location")
	knowledge.observe_dynamic_node_state(&"ACTIVE_PROCESS", &"PROC_1", &"NODE_4", &"RUNNING", 5, 2, 6)
	knowledge.observe_dynamic_link_state(&"TEMPORARY_ROUTE", &"ROUTE_1", &"TEMP_ROUTE", &"OPEN", 5, 2, 6)
	knowledge.set_sphere_security_state(sphere.id, &"ELEVATED", &"MONITOR", 5, 2)
	_expect(knowledge.get_node_view(&"NODE_4").has_current_dynamic_status and canvas.dynamic_link_freshness(&"TEMP_ROUTE") == &"CURRENT", "fresh process and temporary-route observations render as current")
	knowledge.advance_knowledge_time(8)
	_expect(knowledge.get_node_view(&"NODE_4").has_stale_dynamic_status and canvas.dynamic_link_freshness(&"TEMP_ROUTE") == &"STALE", "dynamic node and route observations fade to stale after their configured age")
	_expect(knowledge.get_sphere_view(sphere.id).security_state_freshness == &"STALE", "security condition tracks its last-observed tick independently")
	knowledge.advance_knowledge_time(12)
	_expect(not knowledge.get_node_view(&"NODE_4").has_stale_dynamic_status and canvas.dynamic_link_freshness(&"TEMP_ROUTE") == &"UNKNOWN", "expired dynamic observations become absent instead of lingering forever")
	_expect(knowledge.player_knows_node_exists(&"NODE_4") and knowledge.get_link_level(&"TEMP_ROUTE") >= KnowledgeLevel.Value.IDENTIFIED, "dynamic staleness never erases static node or topology knowledge")
	canvas.free()
	print("%s: %d Sphere minimap stale-information assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
