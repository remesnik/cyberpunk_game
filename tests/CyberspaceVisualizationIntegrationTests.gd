extends SceneTree

const CONFIG := preload("res://cyberspace/display/cyberspace_visualization_config.tres")

var failures := 0
var assertions := 0

func _init() -> void:
	_test_end_to_end_contract()
	_test_debug_scene_contract()
	print("%s: %d cyberspace visualization integration assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _test_end_to_end_contract() -> void:
	var node := NetworkNodeDefinition.new(&"CAMERA_HUB", "Camera Hub", NetworkNodeDefinition.NodeType.SECURITY_SERVER, 4, false, &"CORP")
	node.add_service(&"CAM_A", "Camera A", 2, [], [&"VIDEO", &"SECURITY"])
	node.add_service(&"CAM_B", "Camera B", 2, [], [&"VIDEO", &"SECURITY"])
	var knowledge := PlayerKnowledge.new()
	knowledge.discover_node(node)
	var visual := NodeVisual.new()
	visual.apply_visualization_config(CONFIG)
	visual.configure_view(knowledge.get_node_view(node.id), false, true, false)
	_expect(CONFIG.node_scale >= 1.25, "hex nodes retain the revised larger scale")
	_expect(visual.resolved_level_style() == CONFIG.unknown_level_style and visual.level_glyph() == "L?", "unknown level renders with configured grey style and accessible glyph")
	_expect(visual.capability_socket_assignments().is_empty(), "authoritative undiscovered services do not leak into rendering")
	knowledge.reveal_node_level(node, &"INTERCEPTED_INTEL")
	visual.configure_view(knowledge.get_node_view(node.id), false, true, false)
	_expect(visual.resolved_level_style() == CONFIG.style_for_level(4, true), "independent level discovery reveals the level appearance")
	var partial := NetworkNodeDefinition.new(&"PARTIAL", "Partial Host", NetworkNodeDefinition.NodeType.SYSTEM, 3)
	partial.add_service(&"ARCHIVE", "Archive", 2, [], [&"DATABASE"])
	knowledge.mark_node_scanned(partial, false, true)
	_expect(knowledge.player_has_scanned_node(partial.id) and knowledge.player_knows_node_contents(partial.id) and not knowledge.player_knows_node_level(partial.id), "scan results can reveal contents without revealing level")
	knowledge.reveal_node_contents(node)
	visual.configure_view(knowledge.get_node_view(node.id), false, true, true)
	var assignments := visual.capability_socket_assignments()
	_expect(assignments.size() > 0 and assignments.all(func(item): return visual.capability_socket_position(item.socket, visual.size * 0.5, CONFIG.radius(false)).distance_to(visual.size * 0.5) > CONFIG.radius(false)), "discovered capabilities occupy sockets outside the hex")
	var feed := assignments.filter(func(item): return item.get("capability_type", -1) == NodeCapabilityType.Value.FEED)
	_expect(feed.size() == 1 and feed[0].count == 2, "duplicate capability categories aggregate into one counted indicator")
	knowledge.set_local_system_access_node(node.id, &"SAN_LOCAL", true)
	knowledge.reveal_node_capability(node.id, NodeCapabilityType.Value.ICE, &"ICE_OBSERVATION", &"ICE_1")
	knowledge.reveal_node_capability(node.id, NodeCapabilityType.Value.OBJECTIVE, &"MISSION")
	visual.configure_view(knowledge.get_node_view(node.id), true, true, true)
	var types := visual.capability_socket_assignments().map(func(item): return item.get("capability_type", -1))
	_expect(types.has(NodeCapabilityType.Value.SYSTEM_ACCESS_NODE), "SAN appears as a hosted perimeter indicator")
	_expect(types.has(NodeCapabilityType.Value.SECURITY) and types.has(NodeCapabilityType.Value.ICE), "known ICE remains distinct from generic security infrastructure")
	var semantic_style := visual.resolved_level_style()
	_expect(types.has(NodeCapabilityType.Value.OBJECTIVE) and semantic_style == CONFIG.style_for_level(4, true), "objective indicator does not replace security-level appearance")
	visual.set_destination_emphasis(true)
	_expect(visual.is_current and visual.is_destination and visual.resolved_level_style() == semantic_style, "current and selection overlays preserve semantic state")
	var stable_assignments := visual.capability_socket_assignments()
	visual.configure_view(knowledge.get_node_view(node.id), true, true, true)
	_expect(stable_assignments == visual.capability_socket_assignments(), "perimeter sockets remain deterministic across graph updates")
	visual.set_reduced_animation(true)
	visual.play_knowledge_resolution({"level_known": false, "capability_types": []})
	_expect(not visual.is_resolving_knowledge(), "reduced-animation mode resolves knowledge without motion")
	visual.set_view_context(0.35, 100)
	var far_types := visual.displayed_capability_types()
	_expect(visual.detail_level == NodeVisual.DetailLevel.FAR and far_types.has(NodeCapabilityType.Value.SYSTEM_ACCESS_NODE) and far_types.has(NodeCapabilityType.Value.OBJECTIVE) and far_types.has(NodeCapabilityType.Value.ICE), "FAR LOD remains usable and preserves connection, objective, and danger")
	_expect(not visual.shows_node_label() and visual.capability_socket_assignments().size() <= 3, "FAR LOD removes unreadable label and icon noise")
	visual.free()

func _test_debug_scene_contract() -> void:
	var scene := load("res://debug/visualization/NodeVisualizationLab.tscn") as PackedScene
	var lab := scene.instantiate()
	var controls := ["KnowledgeToggle", "LevelToggle", "ScanToggle", "CapabilityToggle", "SanToggle", "IceToggle", "ObjectiveToggle", "CompromiseToggle", "SecurityLevel", "ReducedAnimation", "ZoomSlider"]
	_expect(controls.all(func(control): return lab.find_child(control, true, false) != null), "visualization lab exposes every required state toggle plus animation and LOD controls")
	lab.free()

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
