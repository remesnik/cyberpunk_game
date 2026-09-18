extends Node

var failures := 0
var assertions := 0

func _ready() -> void:
	var game := get_node("/root/Game")
	game.create_new_game(GameMode.Value.STORY)
	StoryState.new(game.persistent_game_state).set_flag(&"FIRST_CONTACT_COMPLETE", true)
	game.persistent_game_state.campaign_state["pending_entry_content_id"] = &"FIRST_CONTACT"
	game.start_session(); game.story_mission_system.start_mission(&"glasshouse_01")
	game.persistent_game_state.campaign_state["pending_entry_content_id"] = &"GLASSHOUSE_01"
	game.start_session(); game.game_domain = game.GameDomain.CYBERSPACE
	var graph: NetworkGraph = game.network_graph
	var position: PlayerNetworkPosition = game.player_network_position
	for id: StringName in [&"SECURITY", &"WARDEN", &"OBJECTIVE"]: game.player_knowledge.reveal_node(graph.get_node(id), KnowledgeLevel.Value.SCANNED)
	for id: StringName in [&"GH_SECURITY_WARDEN", &"GH_WARDEN_OBJECTIVE"]: game.player_knowledge.reveal_link(graph.get_link(id), KnowledgeLevel.Value.SCANNED)
	position.relocate(&"SECURITY")

	var normal: ActionResult = game.request_traversal(&"WARDEN")
	_expect(normal.success, "connected normal edge remains traversable")
	_expect(position.current_node_id == &"WARDEN", "player can enter Warden from Security")
	_expect(not game.active_boss_encounter.is_resolved(), "Warden begins unresolved")
	var blocked: ActionResult = game.request_traversal(&"OBJECTIVE")
	_expect(not blocked.success, "unresolved Warden blocks onward movement")
	_expect(position.current_node_id == &"WARDEN", "blocked movement does not update position")
	_expect(blocked.reason == "WARDEN BLOCKS ACCESS", "blocked movement returns authored feedback")
	var retreat: ActionResult = game.request_traversal(&"SECURITY")
	_expect(retreat.success and position.current_node_id == &"SECURITY", "reverse retreat remains available")

	position.relocate(&"WARDEN"); game.active_boss_encounter.disable_service(&"AUTHENTICATION")
	_expect(not game.active_boss_encounter.is_resolved(), "one disabled support does not resolve Warden")
	_expect(not game.request_traversal(&"OBJECTIVE").success, "partial boss progress keeps edge blocked")
	game.active_boss_encounter.disable_actor(&"WARDEN")
	_expect(game.active_boss_encounter.resolution() == NetspaceBossEncounter.BossResolution.DEFEATED, "defeated Warden exposes authoritative resolution")
	_expect(game.request_traversal(&"OBJECTIVE").success, "defeat unlocks Warden progression edge")

	position.relocate(&"WARDEN"); game.active_boss_encounter.cleanup(); var bypass_boss := NetspaceBossEncounter.create(NetspaceBossEncounter.Archetype.WARDEN, &"GLASSHOUSE_WARDEN", &"WARDEN", graph); bypass_boss.bypassed = true; bypass_boss.bind_action_clock(game.action_clock, position); game.active_boss_encounter = bypass_boss
	_expect(bypass_boss.resolution() == NetspaceBossEncounter.BossResolution.BYPASSED, "bypass exposes distinct authoritative resolution")
	_expect(game.request_traversal(&"OBJECTIVE").success, "bypass unlocks Warden progression edge")

	_test_generic_entry_gate()
	_test_one_way_gate()

	# Scene/input regression: both click and controller activation converge on
	# request_traversal, so neither may start camera movement for a blocked gate.
	game.active_boss_encounter.cleanup(); game.active_boss_encounter = NetspaceBossEncounter.create(NetspaceBossEncounter.Archetype.WARDEN, &"GLASSHOUSE_WARDEN", &"WARDEN", graph); game.active_boss_encounter.bind_action_clock(game.action_clock, position)
	position.relocate(&"WARDEN")
	var display := load("res://cyberspace/display/NetworkDisplay.tscn").instantiate() as NetworkDisplay
	add_child(display); await get_tree().process_frame
	display._on_node_selected(&"OBJECTIVE")
	_expect(position.current_node_id == &"WARDEN" and not display._transition_active, "mouse click on blocked node does not start traversal camera")
	_expect("WARDEN BLOCKS ACCESS" in display.status_label.text, "mouse path displays block reason")
	display.selected_target_id = &"OBJECTIVE"; display.target_views[&"OBJECTIVE"] = {"kind": &"NODE", "enterable": true, "node": {"scanned": true}}
	display.netspace_view_mode = NetworkDisplay.NetspaceViewMode.NETWORK
	display._on_semantic_action(&"primary_action")
	_expect(position.current_node_id == &"WARDEN" and not display._transition_active, "controller activation cannot cross blocked edge")
	var link_visual := display.link_visuals.get(&"GH_WARDEN_OBJECTIVE") as LinkVisual
	_expect(link_visual == null or link_visual.runtime_state == &"BLOCKED", "gated connection is visually blocked when rendered")

	display.queue_free(); game.end_session()
	print("%s: %d traversal gate assertions" % ["PASS" if failures == 0 else "FAIL", assertions]); get_tree().quit(failures)

func _test_generic_entry_gate() -> void:
	var graph := NetworkGraph.new(); graph.add_node(NetworkNodeDefinition.new(&"A", "A", NetworkNodeDefinition.NodeType.SYSTEM)); graph.add_node(NetworkNodeDefinition.new(&"B", "B", NetworkNodeDefinition.NodeType.SYSTEM))
	var link := NetworkLinkDefinition.new(&"AB", &"A", &"B"); link.traversal_gate_type = NetworkLinkDefinition.TraversalGateType.BLOCK_ENTRY_UNTIL_REQUIREMENT; link.traversal_requirement = {"type": &"story_flag", "id": &"ACCESS"}; graph.add_link(link)
	var position := PlayerNetworkPosition.new(&"A", 5)
	var denied := graph.validate_traversal(position, &"B", [], func(_r, _f, _t, _l): return false)
	_expect(denied.error == NetworkGraph.TraversalError.DESTINATION_ENTRY_BLOCKED and graph.get_node(&"B") != null, "entry-gated destination remains visible but inaccessible")
	var allowed := graph.apply_traversal(position, &"B", [], func(_r, _f, _t, _l): return true)
	_expect(allowed.error == NetworkGraph.TraversalError.OK and position.current_node_id == &"B", "entry requirement unlocks without changing topology")

func _test_one_way_gate() -> void:
	var graph := NetworkGraph.new(); graph.add_node(NetworkNodeDefinition.new(&"A", "A", NetworkNodeDefinition.NodeType.SYSTEM)); graph.add_node(NetworkNodeDefinition.new(&"B", "B", NetworkNodeDefinition.NodeType.SYSTEM))
	var link := NetworkLinkDefinition.new(&"AB", &"A", &"B", true); link.traversal_gate_type = NetworkLinkDefinition.TraversalGateType.ONE_WAY; graph.add_link(link)
	var forward := PlayerNetworkPosition.new(&"A", 5); var reverse := PlayerNetworkPosition.new(&"B", 5)
	_expect(graph.validate_traversal(forward, &"B").error == NetworkGraph.TraversalError.OK, "one-way edge permits authored direction")
	_expect(graph.validate_traversal(reverse, &"A").error == NetworkGraph.TraversalError.NOT_CONNECTED, "one-way edge rejects reverse direction")

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition: failures += 1; printerr("FAILED: %s" % description)
