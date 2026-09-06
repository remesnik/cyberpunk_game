extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://tests/SphereMinimapDebug.tscn") as PackedScene
	var debug_scene := scene.instantiate()
	root.add_child(debug_scene)
	await process_frame
	_expect(debug_scene.graph.get_nodes_in_sphere(&"SPHERE_ALPHA").size() == 10, "fixture contains ten Alpha nodes")
	_expect(debug_scene.graph.get_nodes_in_sphere(&"SPHERE_BETA").size() == 7, "fixture contains seven Beta nodes")
	var visible: Array[StringName] = debug_scene.minimap.canvas.visible_node_ids()
	_expect(visible.size() == 9 and visible.has(&"ALPHA_09") and not visible.has(&"ALPHA_10"), "default knowledge contains discovered and undiscovered Alpha nodes")
	_expect(debug_scene.minimap.canvas.external_connection_markers().size() == 1, "known Alpha-to-Beta boundary route is visible without drawing Beta")
	_expect(debug_scene.minimap.canvas.security_sleeve_overlay_records().size() == 2, "broken original Sleeve renders two current security groups")
	_expect(not debug_scene.minimap.canvas.security_sleeve_overlay_records().any(func(record): return record.node_ids.has(&"ALPHA_09")), "historical member ALPHA_09 visibly remains outside current protection")
	_expect(debug_scene.knowledge.get_node_view(&"ALPHA_06").capability_types.has(NodeCapabilityType.Value.ICE), "current detected ICE appears through knowledge")
	_expect(int(debug_scene.knowledge.get_node_view(&"ALPHA_04").stale_ice_count) == 1, "stale ICE appears only as last-known intelligence")
	_expect(bool(debug_scene.knowledge.get_node_view(&"ALPHA_01").local_san_present) and debug_scene.position_model.current_node_id == &"ALPHA_05", "SAN and player begin on distinct nodes")
	_expect(debug_scene.minimap.canvas.visible_trail_segments().size() == 3, "minimap consumes the active production trail")
	debug_scene.move_player()
	_expect(debug_scene.position_model.current_node_id == &"ALPHA_03" and debug_scene.minimap.canvas.visible_trail_segments().size() == 4, "player control traverses a real link and extends the production trail")

	debug_scene.toggle_sleeves()
	_expect(debug_scene.graph.get_nodes_in_sphere(&"SPHERE_ALPHA").size() == 10 and debug_scene.graph.get_node(&"ALPHA_09").sphere_id == &"SPHERE_ALPHA", "restoring security does not alter Sphere membership")
	_expect(debug_scene.minimap.canvas.security_sleeve_overlay_records().size() == 1 and debug_scene.minimap.canvas.security_sleeve_overlay_records()[0].node_ids.has(&"ALPHA_09"), "restored original Sleeve replaces the split overlay")
	debug_scene.toggle_sleeves()
	_expect(debug_scene.graph.get_nodes_in_sphere(&"SPHERE_ALPHA").size() == 10 and not debug_scene.minimap.canvas.security_sleeve_overlay_records().any(func(record): return record.node_ids.has(&"ALPHA_09")), "breaking security again retains the stable Sphere and unprotected member")

	debug_scene.relocate_san()
	_expect(bool(debug_scene.knowledge.get_node_view(&"ALPHA_07").local_san_present) and not bool(debug_scene.knowledge.get_node_view(&"ALPHA_01").local_san_present), "SAN relocation moves only its minimap marker")
	debug_scene.toggle_discovery()
	_expect(debug_scene.minimap.canvas.visible_node_ids().size() == 10 and debug_scene.san_controller.get_san(&"DEBUG_RUN").host_node_id == &"ALPHA_07", "discovery toggle reveals topology without resetting relocated SAN")
	debug_scene.toggle_ice_detection()
	_expect(not debug_scene.knowledge.get_node_view(&"ALPHA_06").capability_types.has(NodeCapabilityType.Value.ICE), "ICE detection toggle removes knowledge rather than authoritative topology")
	debug_scene.transition_sphere()
	_expect(debug_scene.minimap.canvas.current_sphere_id == &"SPHERE_BETA" and debug_scene.minimap.canvas.visible_node_ids() == [&"BETA_01"], "Sphere transition rebuilds minimap for Beta only")
	_expect(debug_scene.graph.get_nodes_in_sphere(&"SPHERE_ALPHA").size() == 10, "Sphere transition leaves Alpha membership intact")

	debug_scene.free()
	await process_frame
	print("%s: %d Sphere minimap debug-scene assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
