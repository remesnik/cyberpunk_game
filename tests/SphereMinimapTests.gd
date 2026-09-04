extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void:
	var graph := NetworkGraph.new()
	var sphere_a := SphereDefinition.new(&"SPHERE_A", "Operations", [], &"SLEEVE_A")
	var sphere_b := SphereDefinition.new(&"SPHERE_B", "External", [], &"SLEEVE_B")
	graph.add_sphere(sphere_a); graph.add_sphere(sphere_b)
	for data in [[&"A1", sphere_a.id], [&"A2", sphere_a.id], [&"A3", sphere_a.id], [&"B1", sphere_b.id]]:
		graph.add_node(NetworkNodeDefinition.new(data[0], String(data[0]), NetworkNodeDefinition.NodeType.SYSTEM, 2, true, &"CORP", data[1]))
	graph.add_link(NetworkLinkDefinition.new(&"A1_A2", &"A1", &"A2"))
	graph.add_link(NetworkLinkDefinition.new(&"A2_A3", &"A2", &"A3"))
	graph.add_link(NetworkLinkDefinition.new(&"A2_B1", &"A2", &"B1"))
	graph.add_security_sleeve(SecuritySleeve.new(&"SLEEVE_A", "Operations Sleeve", [&"A1", &"A2"]))
	graph.add_security_sleeve(SecuritySleeve.new(&"SLEEVE_B", "External Sleeve", [&"B1"]))
	var knowledge := PlayerKnowledge.new()
	for node_id in [&"A1", &"A2", &"A3", &"B1"]: knowledge.reveal_node(graph.get_node(node_id), KnowledgeLevel.Value.IDENTIFIED)
	knowledge.reveal_link(graph.get_link(&"A1_A2"), KnowledgeLevel.Value.IDENTIFIED)
	knowledge.reveal_link(graph.get_link(&"A2_B1"), KnowledgeLevel.Value.IDENTIFIED)
	knowledge.set_local_system_access_node(&"A1", &"LOCAL_SAN", true)
	knowledge.reveal_node_capability(&"A2", NodeCapabilityType.Value.OBJECTIVE, &"MISSION")
	knowledge.reveal_node_capability(&"A3", NodeCapabilityType.Value.ICE, &"ICE_OBSERVATION", &"ICE_1")
	knowledge.reveal_security_sleeve(graph.get_security_sleeve(&"SLEEVE_A"), graph)
	var position := PlayerNetworkPosition.new(&"A1", 10)
	var tracker := CurrentSphereTracker.new(graph); tracker.register_player(&"PLAYER", position)
	var canvas := SphereMinimapCanvas.new()
	canvas.size = Vector2(340, 178)
	canvas.set_models(graph, position, knowledge, tracker)
	var visible := canvas.visible_node_ids()
	_expect(visible.size() == 3 and visible.has(&"A1") and visible.has(&"A2") and visible.has(&"A3"), "minimap includes every known node in the current Sphere")
	_expect(not visible.has(&"B1"), "minimap excludes known nodes in unrelated Spheres")
	_expect(canvas.known_internal_links().size() == 1 and canvas.known_internal_links()[0].id == &"A1_A2", "only known internal connections are drawn")
	_expect(canvas.known_exit_links().size() == 1 and canvas.known_exit_links()[0].id == &"A2_B1", "known cross-Sphere connection is represented as an exit")
	_expect(not canvas.known_internal_links().any(func(link): return link.id == &"A2_A3"), "undiscovered connections remain hidden")
	_expect(knowledge.get_node_view(&"A1").local_san_present and knowledge.get_node_view(&"A2").capability_types.has(NodeCapabilityType.Value.OBJECTIVE) and knowledge.get_node_view(&"A3").capability_types.has(NodeCapabilityType.Value.ICE), "SAN, objective, and known ICE markers come from PlayerKnowledge")
	_expect(knowledge.knows_security_sleeve(&"SLEEVE_A") and knowledge.get_known_security_sleeves()[0].current_members.size() == 2, "current Security Sleeve relationships require explicit knowledge")
	var layout_before := SphereMapLayout.positions_for(graph, sphere_a.id)
	knowledge.reveal_node_level(graph.get_node(&"A2"))
	var layout_after := SphereMapLayout.positions_for(graph, sphere_a.id)
	_expect(layout_before == layout_after, "canonical Sphere positions remain stable as knowledge changes")
	position.relocate(&"B1"); canvas.refresh()
	_expect(canvas.current_sphere_id == sphere_b.id and canvas.visible_node_ids() == [&"B1"], "minimap switches cleanly when the player crosses Spheres")
	var scene := load("res://cyberspace/display/minimap/SphereMinimap.tscn") as PackedScene
	var panel := scene.instantiate()
	_expect(panel.find_child("ToggleButton", true, false) != null and panel.find_child("Canvas", true, false) != null, "production minimap is collapsible and retains a dedicated read-only canvas")
	panel.free(); canvas.free()
	print("%s: %d Sphere minimap assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
