extends Node

var failures := 0
var assertions := 0

func _ready() -> void:
	var package := NetworkDocumentSerializer.load_file("res://data/networks/first_contact.netspace")
	_expect(bool(package.get("success", false)), "encrypted First Contact package loads")
	if not bool(package.get("success", false)):
		get_tree().quit(failures)
		return
	var document: NetworkDocument = package.document
	_expect(document.network_id == &"FIRST_CONTACT" and document.nodes.size() == 7 and document.paths.size() == 6, "tutorial topology lives in NetworkDocument")
	_expect(_has_id(document.nodes, &"SAN") and _has_id(document.paths, &"SECURITY_DATA") and _has_id(document.services, &"ROUTE_CONTROL"), "stable tutorial topology and service IDs are preserved")
	_expect(document.spheres.any(func(sphere: Dictionary): return StringName(sphere.get("security_sleeve", {}).get("id", &"")) == &"OFFICE_SECURITY_SLEEVE" and &"SECURITY" in sphere.get("node_ids", [])), "legacy sleeve membership is explicit sphere data")
	_expect(not document.story_metadata.get("story_sequences", []).is_empty(), "tutorial progression metadata is separate and preserved")

	Game.create_new_game(GameMode.Value.STORY)
	Game.persistent_game_state.campaign_state["current_content_id"] = &"FIRST_CONTACT"
	Game.persistent_game_state.campaign_state["pending_entry_content_id"] = &"FIRST_CONTACT"
	Game.start_session()
	_expect(Game.active_content_document != null and Game.network_graph.get_node(&"SAN") != null and Game.entry_guidance != null, "Story Mode builds the playable tutorial through the shared network loader")

	var controller := NetworkAuthoringController.new()
	add_child(controller)
	controller.configure(null)
	_expect(controller.loaded_document_template != null and controller.current_document_path == "res://data/networks/first_contact.netspace", "authoring adopts the active Story package and its metadata")
	_expect(controller.set_mode(NetworkAuthoringState.Mode.AUTHOR_GOD), "debug build enters Author God Mode")
	controller.select_object(NetworkSelectionState.Kind.NODE, &"SAN")
	var add_node := controller.add_connected_node()
	var added_node_id := controller.selection.object_id
	_expect(bool(add_node.get("success", false)) and Game.network_graph.get_node(added_node_id) != null, "author adds a connected node live")
	controller.select_object(NetworkSelectionState.Kind.PATH, &"SAN_ACCESS")
	_expect(bool(controller.set_selected_path_locked(true).get("success", false)), "author changes a path lock live")
	controller.select_object(NetworkSelectionState.Kind.NODE, added_node_id)
	_expect(bool(controller.add_service(&"MESSAGING").get("success", false)), "author adds a service live")
	var sphere_id := StringName(document.spheres[0].get("id", &""))
	_expect(bool(controller.add_selected_node_to_sphere(sphere_id).get("success", false)), "author edits sphere membership live")
	var save_path := "res://.test_first_contact_migration_round_trip.netspace"
	var save_result := controller.save_current_network(save_path)
	if not bool(save_result.get("success", false)): printerr("SAVE DETAILS: %s" % JSON.stringify(save_result))
	_expect(bool(save_result.get("success", false)), "author saves the edited encrypted tutorial without conversion")
	var restarted := NetworkDocumentSerializer.load_file(save_path)
	var rebuilt := NetworkDocumentRuntimeLoader.build(restarted.document) if bool(restarted.get("success", false)) else {}
	_expect(bool(restarted.get("success", false)) and bool(rebuilt.get("success", false)) and rebuilt.graph.get_node(added_node_id) != null, "restart reloads authored topology through the gameplay loader")
	if bool(restarted.get("success", false)):
		_expect(restarted.document.network_id == &"FIRST_CONTACT" and not restarted.document.story_metadata.get("story_sequences", []).is_empty(), "authoring save preserves tutorial identity and progression references")
		var restored_content: CyberspaceContentDocument = restarted.document.to_content_document()
		if restored_content.find_entry(&"FIRST_CONTACT_CURRENT_LOOP") == {} or restored_content.find_entry(&"ROUTE_CONTROL") == {}: printerr("REFERENCE DETAILS: sequences=%d raw=%d sequence=%s service=%s" % [restored_content.story_sequences.size(), restarted.document.story_metadata.get("story_sequences", []).size(), JSON.stringify(restored_content.find_entry(&"FIRST_CONTACT_CURRENT_LOOP")), JSON.stringify(restored_content.find_entry(&"ROUTE_CONTROL"))])
		_expect(restored_content.find_entry(&"FIRST_CONTACT_CURRENT_LOOP") != {} and restored_content.find_entry(&"ROUTE_CONTROL") != {}, "tutorial script references still resolve after round trip")
	controller.set_mode(NetworkAuthoringState.Mode.PLAYER)
	controller.queue_free()
	Game.end_session()
	print("%s: %d First Contact NetworkDocument migration assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _has_id(items: Array[Dictionary], id: StringName) -> bool:
	return items.any(func(item: Dictionary): return StringName(item.get("id", &"")) == id)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
