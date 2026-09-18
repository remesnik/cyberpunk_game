extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://tests/SphereMinimapDebug.tscn") as PackedScene
	var fixture := scene.instantiate()
	root.add_child(fixture)
	await process_frame
	var canvas: SphereMinimapCanvas = fixture.minimap.canvas
	var alpha_members: Array[StringName] = fixture.graph.get_nodes_in_sphere(&"SPHERE_ALPHA")
	_expect(canvas.current_sphere_id == &"SPHERE_ALPHA", "1: minimap represents the player's current Sphere")
	_expect(alpha_members.size() == 10 and fixture.graph.get_sphere(&"SPHERE_ALPHA").display_name == "Alpha Operations", "2: Sphere is a named logical subnet")
	_expect(fixture.graph.get_sphere(&"SPHERE_ALPHA").original_security_sleeve_id == &"ALPHA_ORIGINAL" and alpha_members.has(&"ALPHA_09"), "3: Sphere retains historical original-Sleeve membership")
	fixture.toggle_sleeves(); fixture.toggle_sleeves()
	_expect(fixture.graph.get_nodes_in_sphere(&"SPHERE_ALPHA") == alpha_members, "4: breaking and restoring a Sleeve cannot remove Sphere nodes")
	_expect(not canvas.visible_node_ids().has(&"ALPHA_10"), "5: authoritative but undiscovered nodes remain hidden")
	var unknown_visual := canvas.minimap_node_for(&"ALPHA_02")
	_expect(unknown_visual.resolved_level_style() == unknown_visual.visualization_config.unknown_level_style, "6: known node with unknown level uses shared grey UNKNOWN style")
	var known_visual := canvas.minimap_node_for(&"ALPHA_03")
	_expect(known_visual.resolved_level_style() == known_visual.visualization_config.style_for_level(3, true), "7: known security level uses configured level appearance")
	_expect(canvas.minimap_node_for(fixture.position_model.current_node_id).semantic_markers().has(&"CURRENT"), "8: current player location has a dedicated marker")
	_expect(canvas.minimap_node_for(&"ALPHA_01").semantic_markers().has(&"SAN"), "9: SAN host has a distinct marker")
	var trails := canvas.visible_trail_segments()
	_expect(trails.size() == 3 and canvas.trail_alpha_for(trails[2]) > canvas.trail_alpha_for(trails[0]), "10: permitted own trail is visually followable and age-weighted")
	_expect(canvas.minimap_node_for(&"ALPHA_06").semantic_markers().has(&"ICE") and canvas.minimap_node_for(&"ALPHA_04").semantic_markers().has(&"ICE_STALE"), "11: ICE markers distinguish detected-current from stale last-known intelligence")
	_expect(canvas.minimap_node_for(&"ALPHA_08").semantic_markers().has(&"OBJECTIVE"), "12: discovered mission objective remains visible")
	var sleeve_records := canvas.security_sleeve_overlay_records()
	_expect(sleeve_records.size() == 2 and not sleeve_records.any(func(record): return record.node_ids.has(&"ALPHA_09")), "13: current Sleeve groups render separately from stable Sphere membership")
	_expect(canvas.external_connection_markers().size() == 1 and canvas.external_connection_markers()[0].destination_label == "BETA ARCHIVE", "14: known exits identify the adjacent Sphere without drawing it")
	fixture.transition_sphere()
	_expect(canvas.current_sphere_id == &"SPHERE_BETA" and canvas.visible_node_ids() == [&"BETA_01"], "15: crossing the boundary rebuilds the minimap for the destination Sphere")
	fixture.transition_sphere()
	var position_before: StringName = fixture.position_model.current_node_id
	var history_before: int = fixture.position_model.traversal_history.size()
	_expect(canvas.request_focus_node(&"ALPHA_08") and fixture.position_model.current_node_id == position_before and fixture.position_model.traversal_history.size() == history_before, "16: minimap selection focuses only and cannot bypass movement")

	var dense := _dense_fixture(55)
	var dense_canvas: SphereMinimapCanvas = dense.canvas
	_expect(dense_canvas.visible_node_ids().size() == 55 and dense_canvas.detail_level_for_current_view() == SphereMinimapNode.DetailLevel.DENSE and dense_canvas.minimap_node_for(&"DENSE_00").semantic_markers().has(&"CURRENT"), "17: large Spheres preserve topology and critical state through semantic LOD")
	_expect(not _has_owned_authority_collections(canvas), "minimap owns only disposable view caches and source references")

	dense_canvas.free()
	fixture.free()
	await process_frame
	print("%s: %d complete Sphere minimap assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _dense_fixture(count: int) -> Dictionary:
	var graph := NetworkGraph.new(); var sphere := SphereDefinition.new(&"DENSE", "Dense Sphere"); graph.add_sphere(sphere)
	var knowledge := PlayerKnowledge.new()
	for index in count:
		var node_id := StringName("DENSE_%02d" % index)
		graph.add_node(NetworkNodeDefinition.new(node_id, String(node_id), NetworkNodeDefinition.NodeType.SYSTEM, index % 5 + 1, false, &"CORP", sphere.id))
		knowledge.reveal_node(graph.get_node(node_id), KnowledgeLevel.Value.IDENTIFIED)
		if index > 0:
			var link := NetworkLinkDefinition.new(StringName("DENSE_LINK_%02d" % index), StringName("DENSE_%02d" % (index - 1)), node_id)
			graph.add_link(link); knowledge.reveal_link(link, KnowledgeLevel.Value.IDENTIFIED)
	var position := PlayerNetworkPosition.new(&"DENSE_00")
	var canvas := SphereMinimapCanvas.new(); canvas.size = Vector2(500, 300); canvas.set_models(graph, position, knowledge)
	return {"graph": graph, "knowledge": knowledge, "position": position, "canvas": canvas}

func _has_owned_authority_collections(canvas: SphereMinimapCanvas) -> bool:
	for property: Dictionary in canvas.get_property_list():
		if StringName(property.name) in [&"nodes", &"links", &"spheres", &"security_sleeves", &"ice_instances", &"objectives", &"trail_segments"]: return true
	return false

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
