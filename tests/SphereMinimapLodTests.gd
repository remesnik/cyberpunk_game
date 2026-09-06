extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void:
	_test_density(5, SphereMinimapNode.DetailLevel.CLOSE)
	_test_density(15, SphereMinimapNode.DetailLevel.MEDIUM)
	_test_density(30, SphereMinimapNode.DetailLevel.DENSE)
	_test_dense_semantic_priority(55)
	print("%s: %d Sphere minimap LOD assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _test_density(count: int, expected_detail: int) -> void:
	var fixture := _fixture(count)
	var canvas: SphereMinimapCanvas = fixture.canvas
	_expect(canvas.visible_node_ids().size() == count, "%d-node Sphere keeps every known node" % count)
	_expect(canvas.known_internal_links().size() == count - 1, "%d-node Sphere preserves known topology" % count)
	_expect(canvas.detail_level_for_current_view() == expected_detail, "%d-node Sphere selects its semantic LOD" % count)
	var sample := canvas.minimap_node_for(StringName("N_%02d" % mini(1, count - 1)))
	_expect((sample.display_label().is_empty()) == (expected_detail == SphereMinimapNode.DetailLevel.DENSE), "%d-node label visibility follows LOD rather than arbitrary node hiding" % count)
	canvas.free()

func _test_dense_semantic_priority(count: int) -> void:
	var fixture := _fixture(count)
	var canvas: SphereMinimapCanvas = fixture.canvas
	var knowledge: PlayerKnowledge = fixture.knowledge
	knowledge.set_local_system_access_node(&"N_00", &"SAN", true)
	knowledge.reveal_node_capability(&"N_01", NodeCapabilityType.Value.OBJECTIVE, &"MISSION", &"OBJECTIVE")
	knowledge.reveal_node_capability(&"N_02", NodeCapabilityType.Value.ICE, &"DETECTION", &"HUNTER")
	knowledge.reveal_node_capability(&"N_04", NodeCapabilityType.Value.ICE, &"DETECTION", &"PASSIVE")
	knowledge.ice_records[&"HUNTER"] = {"id": &"HUNTER", "node_id": &"N_02", "level": KnowledgeLevel.Value.IDENTIFIED, "state": IceState.Value.HUNT}
	knowledge.ice_records[&"PASSIVE"] = {"id": &"PASSIVE", "node_id": &"N_04", "level": KnowledgeLevel.Value.IDENTIFIED, "state": IceState.Value.PATROL}
	knowledge.knowledge_changed.emit()
	var current := canvas.minimap_node_for(&"N_00")
	var objective := canvas.minimap_node_for(&"N_01")
	var threat := canvas.minimap_node_for(&"N_02")
	var exit_node := canvas.minimap_node_for(&"N_03")
	var passive := canvas.minimap_node_for(&"N_04")
	_expect(current.semantic_markers().has(&"CURRENT") and current.semantic_markers().has(&"SAN"), "dense LOD always retains player and SAN")
	_expect(objective.semantic_markers().has(&"OBJECTIVE") and exit_node.semantic_markers().has(&"SPHERE_EXIT"), "dense LOD always retains objectives and Sphere exits")
	_expect(threat.semantic_markers().has(&"ICE") and not passive.semantic_markers().has(&"ICE"), "dense LOD retains immediate ICE threats while suppressing low-priority detected entities")
	canvas.set_minimap_zoom(1.6)
	_expect(canvas.detail_level_for_current_view() == SphereMinimapNode.DetailLevel.MEDIUM and not canvas.minimap_node_for(&"N_05").display_label().is_empty(), "zooming a 50+ node Sphere restores medium inspection detail")
	canvas.set_minimap_zoom(2.3)
	_expect(canvas.detail_level_for_current_view() == SphereMinimapNode.DetailLevel.CLOSE, "further zoom restores close inspection detail")
	_expect(canvas.center_on_node(&"N_40") and canvas.visible_node_ids().size() == count, "panning/centering inspects dense regions without hiding arbitrary nodes")
	canvas.free()

func _fixture(count: int) -> Dictionary:
	var graph := NetworkGraph.new()
	var sphere := SphereDefinition.new(&"LARGE", "Large")
	var external := SphereDefinition.new(&"EXTERNAL", "External")
	graph.add_sphere(sphere); graph.add_sphere(external)
	for index in count:
		var node_id := StringName("N_%02d" % index)
		graph.add_node(NetworkNodeDefinition.new(node_id, "Node %02d" % index, NetworkNodeDefinition.NodeType.SYSTEM, index % 6, true, &"CORP", sphere.id))
		if index > 0: graph.add_link(NetworkLinkDefinition.new(StringName("L_%02d" % index), StringName("N_%02d" % (index - 1)), node_id))
	graph.add_node(NetworkNodeDefinition.new(&"OUTSIDE", "Outside", NetworkNodeDefinition.NodeType.ROUTER, 3, true, &"CORP", external.id))
	graph.add_link(NetworkLinkDefinition.new(&"EXIT", &"N_03", &"OUTSIDE"))
	var knowledge := PlayerKnowledge.new()
	for index in count: knowledge.reveal_node(graph.get_node(StringName("N_%02d" % index)), KnowledgeLevel.Value.SCANNED)
	for index in range(1, count): knowledge.reveal_link(graph.get_link(StringName("L_%02d" % index)), KnowledgeLevel.Value.IDENTIFIED)
	knowledge.reveal_link(graph.get_link(&"EXIT"), KnowledgeLevel.Value.IDENTIFIED)
	var position := PlayerNetworkPosition.new(&"N_00")
	var canvas := SphereMinimapCanvas.new(); canvas.size = Vector2(340, 178); canvas.set_models(graph, position, knowledge)
	return {"canvas": canvas, "knowledge": knowledge}

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
