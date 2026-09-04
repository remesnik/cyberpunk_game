extends SceneTree

const FIXTURE := preload("res://tests/LargeGraphVisualizationFixture.gd")
const CONFIG := preload("res://cyberspace/display/cyberspace_visualization_config.tres")

var failures := 0
var assertions := 0

func _init() -> void:
	for count in [10, 25, 50, 100]: _test_network_size(count)
	_test_semantic_lod()
	print("%s: %d large-graph visualization assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _test_network_size(count: int) -> void:
	var fixture: Dictionary = FIXTURE.generate(count)
	var graph: NetworkGraph = fixture.graph
	var views: Array = fixture.views
	_expect(graph.nodes.size() == count and graph.links.size() == count - 1, "%d-node deterministic test network is connected" % count)
	var detail := CONFIG.detail_level_for(1.0, count)
	var expected := NodeVisual.DetailLevel.CLOSE if count == 10 else (NodeVisual.DetailLevel.MEDIUM if count == 25 else NodeVisual.DetailLevel.FAR)
	_expect(detail == expected, "%d-node network selects density-appropriate LOD" % count)
	var positions := FIXTURE.grid_positions(count, Vector2(1600, 900))
	var nearest := INF
	for a in positions.size():
		for b in range(a + 1, positions.size()): nearest = minf(nearest, positions[a].distance_to(positions[b]))
	var visual_extent := CONFIG.radius_for_lod(false, detail) + CONFIG.capability_socket_border_gap + CONFIG.capability_indicator_radius * 2.0
	_expect(nearest >= visual_extent * 1.75, "%d-node layout avoids excessive perimeter-icon overlap" % count)
	var unknown_style: Resource = CONFIG.style_for_level(0, false)
	var known_style: Resource = CONFIG.style_for_level(3, true)
	_expect(unknown_style.border_color != known_style.border_color and unknown_style.label == "L?", "%d-node graph keeps unknown nodes visually distinct" % count)
	_expect(views.any(func(view): return bool(view.local_san_present)), "%d-node graph contains a findable local SAN" % count)
	_expect(count < 17 or views.any(func(view): return (view.capability_types as Array).has(NodeCapabilityType.Value.OBJECTIVE)), "%d-node graph contains visible objective markers when large enough" % count)

func _test_semantic_lod() -> void:
	var fixture: Dictionary = FIXTURE.generate(100)
	var busy_view: Dictionary = fixture.views[3]
	var visual := NodeVisual.new()
	visual.apply_visualization_config(CONFIG)
	visual.configure_view(busy_view, false, true, true)
	visual.set_view_context(1.0, 10)
	_expect(visual.detail_level == NodeVisual.DetailLevel.CLOSE and visual.displayed_capability_types().size() > 6, "CLOSE shows full discovered content")
	_expect(visual.shows_node_label() and visual.shows_status_text() and visual.shows_capability_counts(), "CLOSE retains labels, status, and counts")
	visual.set_view_context(0.7, 25)
	_expect(visual.detail_level == NodeVisual.DetailLevel.MEDIUM and visual.displayed_capability_types().size() < busy_view.capability_types.size(), "MEDIUM keeps only major capability categories")
	_expect(visual.shows_node_label() and not visual.shows_status_text() and not visual.shows_capability_counts(), "MEDIUM keeps short labels but removes detail noise")
	visual.set_view_context(0.35, 100)
	var far_types := visual.displayed_capability_types()
	_expect(visual.detail_level == NodeVisual.DetailLevel.FAR and far_types.all(func(type): return CONFIG.far_capability_types.has(type)), "FAR filters rather than shrinking all icons")
	_expect(far_types.has(NodeCapabilityType.Value.SYSTEM_ACCESS_NODE) and far_types.has(NodeCapabilityType.Value.OBJECTIVE) and far_types.has(NodeCapabilityType.Value.ICE), "FAR preserves SAN, objective, and known danger")
	_expect(not visual.shows_node_label() and visual.level_glyph().begins_with("L"), "FAR preserves level/state glyph while suppressing unreadable labels")
	_expect(visual.capability_socket_assignments().size() <= 3, "FAR icons cannot dominate the network")
	var link := LinkVisual.new()
	link.configure(&"LOD_LINK", Vector2.ZERO, Vector2(100, 0), false, CONFIG)
	link.set_view_context(0.35, 100, CONFIG)
	_expect(link.width <= CONFIG.edge_width and link.default_color.a < 0.5, "FAR edges remain present but visually subordinate")
	visual.free(); link.free()

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
