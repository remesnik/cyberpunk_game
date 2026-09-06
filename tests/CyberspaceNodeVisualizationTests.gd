extends Node

const VisualizationConfigScript := preload("res://cyberspace/display/CyberspaceVisualizationConfig.gd")

var failures := 0
var assertions := 0
@onready var game: Node = get_node("/root/Game")

func _ready() -> void:
	game.start_session()
	var display: Control = (load("res://cyberspace/display/NetworkDisplay.tscn") as PackedScene).instantiate() as Control
	add_child(display)
	await get_tree().process_frame
	var config: Resource = display.visualization_config
	_expect(is_equal_approx(config.node_scale, 1.3), "default reusable node scale increases hexes by 30 percent")
	_test_security_legend(display, config)
	_test_capability_glossary(display, config)
	_test_security_level_styles(config)
	_test_sparse_hex_interior(config)
	_test_restrained_state_animation(config)
	var current := display.node_visuals[game.player_network_position.current_node_id] as NodeVisual
	_expect(current.size.x >= 270.0 and current.size.y >= 190.0, "selection bounds and hitbox grow with the configured visual size")
	_expect(is_equal_approx(config.radius(false), 54.6) and is_equal_approx(config.radius(true), 70.2), "connected and current hex radii both use the shared scale")
	var reachable: NodeVisual
	for candidate: NodeVisual in display.node_visuals.values():
		if candidate.is_selectable: reachable = candidate; break
	_expect(reachable != null and reachable.clickable_local_rect() == Rect2(Vector2.ZERO, reachable.size), "the click target covers the full rendered node billboard")
	var selected_from_edge := [false]
	reachable.selected.connect(func(_id: StringName): selected_from_edge[0] = true)
	var edge_click := InputEventMouseButton.new(); edge_click.pressed = true; edge_click.button_index = MOUSE_BUTTON_LEFT; edge_click.position = reachable.size - Vector2.ONE
	reachable._gui_input(edge_click)
	_expect(selected_from_edge[0], "clicking at the outer edge of a visible node selects it")
	var current_center := current.position + current.size * 0.5
	for link: LinkVisual in display.link_visuals.values():
		_expect(link.points[0].distance_to(current_center) >= config.radius(true), "connection begins outside the current hex perimeter")
		_expect(link.width < 2.0 and link.width < config.radius(false) * 0.05, "graph edges remain visually subordinate to enlarged nodes")
	var centers: Array[Vector2] = []
	for visual: NodeVisual in display.node_visuals.values(): centers.append(visual.position + visual.size * 0.5)
	for a in centers.size():
		for b in range(a + 1, centers.size()):
			_expect(centers[a].distance_to(centers[b]) >= config.radius(false) * 2.0, "layout keeps neighboring hex interiors separate")
	var custom: Resource = VisualizationConfigScript.new(); custom.node_scale = 1.1
	current.apply_visualization_config(custom)
	_expect(is_equal_approx(current.size.x, custom.visual_size().x) and is_equal_approx(custom.radius(false), 46.2), "node geometry remains configurable through the visualization resource")
	display.queue_free(); game.end_session()
	print("%s: %d cyberspace node visualization assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _test_security_level_styles(config: Resource) -> void:
	var visual := NodeVisual.new()
	visual.apply_visualization_config(config)
	visual.configure_view({"id": &"VISIBLE", "display_name": "Visible Host", "identity_known": true, "level_known": false}, false, true, false)
	var unknown_style: Resource = visual.resolved_level_style()
	_expect(unknown_style == config.unknown_level_style, "graph visibility alone uses the UNKNOWN level style")
	_expect(visual.level_glyph() == "L?", "unknown security is communicated with a non-color glyph")
	var unknown_color: Color = unknown_style.border_color
	_expect(absf(unknown_color.r - unknown_color.g) < 0.12 and absf(unknown_color.g - unknown_color.b) < 0.12, "UNKNOWN has a neutral grey configured style")

	var knowledge := PlayerKnowledge.new()
	var node := NetworkNodeDefinition.new(&"INTEL_NODE", "Intel Node", NetworkNodeDefinition.NodeType.SYSTEM, 4)
	knowledge.discover_node(node, &"GRAPH_CONTACT")
	knowledge.reveal_node_level(node, &"OTHER_HACKER")
	visual.configure_view(knowledge.get_node_view(node.id), false, true, false)
	var known_style: Resource = visual.resolved_level_style()
	_expect(known_style == config.style_for_level(4, true), "level intelligence selects its configured style without scan or visitation")
	_expect(not knowledge.player_has_scanned_node(node.id) and not knowledge.player_has_visited_node(node.id), "rendering level intelligence does not depend on scan or visit state")
	_expect(visual.level_glyph() == "L4", "known security has an accessible level glyph")
	visual.set_destination_emphasis(true)
	_expect(visual.resolved_level_style() == known_style, "selection emphasis does not replace the security-level base style")
	visual.is_current = true
	_expect(visual.resolved_level_style() == known_style, "current-node emphasis does not replace the security-level base style")
	visual.free()

func _test_security_legend(display: Control, config: Resource) -> void:
	var legend: Control = display.get_node("SecurityLevelLegend")
	var entries: Array[Dictionary] = legend.legend_entries()
	_expect(entries.size() == config.level_styles.size() + 1, "legend contains UNKNOWN plus every configured security level")
	_expect(entries[0].style == config.unknown_level_style and entries[0].display_name == config.unknown_level_style.display_name, "legend reuses the configured UNKNOWN style and name")
	for index in config.level_styles.size():
		_expect(entries[index + 1].style == config.level_styles[index], "legend row reuses its configured level style")
	_expect(legend.display_mode == SecurityLevelLegend.DisplayMode.COLLAPSED and not legend.get_node("Margin/Content/Rows").visible, "legend defaults to compact collapsed mode")
	legend.set_display_mode(SecurityLevelLegend.DisplayMode.EXPANDED)
	_expect(legend.visible and legend.get_node("Margin/Content/Rows").visible, "legend can expand")
	legend.set_display_mode(SecurityLevelLegend.DisplayMode.DISABLED)
	_expect(not legend.visible, "legend can be disabled")

func _test_capability_glossary(display: Control, config: Resource) -> void:
	var glossary: Control = display.get_node("CapabilityGlossary")
	var entries: Array[Dictionary] = glossary.glossary_entries()
	_expect(entries.size() == NodeCapabilityType.Value.size(), "compact glossary covers every capability icon")
	_expect(entries[0].definition == config.capability_catalog.definition_for(NodeCapabilityType.Value.IO), "glossary references the same icon definition used by node sockets")
	_expect(entries[NodeCapabilityType.Value.FEED].description.contains("video") and entries[NodeCapabilityType.Value.MEATSPACE].description.contains("physical"), "glossary descriptions come from the shared capability catalog")
	_expect(glossary.display_mode == CapabilityGlossary.DisplayMode.COLLAPSED and not glossary.get_node("Margin/Content/GlossaryScroll").visible, "icon glossary defaults to a compact collapsed control")
	glossary.set_display_mode(CapabilityGlossary.DisplayMode.EXPANDED)
	_expect(glossary.visible and glossary.get_node("Margin/Content/GlossaryScroll").visible, "icon glossary can expand without permanently occupying graph space")
	glossary.set_display_mode(CapabilityGlossary.DisplayMode.DISABLED)
	_expect(not glossary.visible, "icon glossary can be disabled")

func _test_sparse_hex_interior(config: Resource) -> void:
	var visual := NodeVisual.new()
	visual.apply_visualization_config(config)
	visual.configure_view({"id": &"RELAY-04", "display_name": "Corporate Communications Relay Four", "identity_known": true, "level_known": true, "security_level": 2, "concise_status": "compromised", "service_ids": [&"SECRET_SERVICE"], "capability_types": [NodeCapabilityType.Value.COMMUNICATIONS]}, false, true, false)
	_expect(visual.interior_lines() == PackedStringArray(["RELAY-04", "L2", "COMPROMISED"]), "hex interior contains only short label, known level, and concise status")
	_expect(not " ".join(visual.interior_lines()).contains("SERVICE") and not " ".join(visual.interior_lines()).contains("COMMUNICATIONS"), "services and capability names stay out of the hex interior")
	visual.configure_view({"id": &"UNKNOWN_LEVEL", "display_name": "Known Host", "identity_known": true, "level_known": false}, false, true, false)
	_expect(visual.interior_lines() == PackedStringArray(["KNOWN HOST"]), "unknown security level is omitted rather than filling the hex with explanatory text")
	visual.configure_unknown(&"CONTACT")
	_expect(visual.interior_lines() == PackedStringArray(["???"]), "unidentified graph contact keeps a single sparse interior label")
	visual.free()

func _test_restrained_state_animation(config: Resource) -> void:
	var visual := NodeVisual.new()
	visual.apply_visualization_config(config)
	visual.configure_view({"id": &"QUIET", "display_name": "Quiet", "identity_known": true, "level_known": false}, false, true, false)
	_expect(not visual.has_state_animation(), "ordinary graph nodes do not animate constantly")
	visual.configure_view({"id": &"SIGNALS", "display_name": "Signals", "identity_known": true, "level_known": true, "security_level": 2, "capability_types": [NodeCapabilityType.Value.FEED, NodeCapabilityType.Value.ACTIVE_PROCESS, NodeCapabilityType.Value.ICE, NodeCapabilityType.Value.OBJECTIVE]}, false, true, true)
	_expect(visual.has_state_animation(), "known feed, process, ICE, and objective state opts into restrained semantic animation")
	var socket_positions: Array[Vector2] = []
	for assignment: Dictionary in visual.capability_socket_assignments():
		socket_positions.append(visual.capability_socket_position(int(assignment.socket), visual.size * 0.5, config.radius(false)))
	visual._process(1.0)
	var assignments := visual.capability_socket_assignments()
	for index in assignments.size():
		_expect(socket_positions[index] == visual.capability_socket_position(int(assignments[index].socket), visual.size * 0.5, config.radius(false)), "state animation leaves deterministic icon hitboxes fixed")
	visual.play_knowledge_resolution({"level_known": false, "capability_types": []})
	_expect(visual.is_resolving_knowledge(), "new knowledge starts the short security-and-icon resolution sequence")
	visual._process(config.scan_resolution_duration + 0.01)
	_expect(not visual.is_resolving_knowledge(), "knowledge resolution completes within its configured 0.25-0.75 second window")
	visual.set_reduced_animation(false)
	visual.configure_view({"id": &"PARTIAL", "display_name": "Identified Relay", "identity_known": true, "level_known": false, "concise_status": "signal only", "capability_types": [NodeCapabilityType.Value.FEED]}, false, true, false)
	visual.play_knowledge_resolution({"id": &"PARTIAL", "display_name": "Unknown", "identity_known": false, "level_known": false, "capability_types": []})
	_expect(visual.is_resolving_knowledge(), "a partial scan animates only newly learned identity, status, and capability data without requiring a level reveal")
	visual.set_reduced_animation(true)
	visual.play_knowledge_resolution({"level_known": false, "capability_types": []})
	_expect(not visual.is_resolving_knowledge(), "reduced-animation mode resolves new knowledge immediately")
	visual.free()

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition: failures += 1; printerr("FAILED: %s" % description)
