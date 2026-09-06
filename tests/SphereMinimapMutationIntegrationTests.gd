extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void:
	var graph := NetworkGraph.new()
	var local := SphereDefinition.new(&"LOCAL", "Local", [], &"SLEEVE_LOCAL")
	var remote := SphereDefinition.new(&"REMOTE", "Remote", [], &"SLEEVE_REMOTE")
	graph.add_sphere(local); graph.add_sphere(remote)
	for data in [[&"ENTRY", local.id], [&"RELAY", local.id], [&"TARGET", local.id], [&"ISOLATED", local.id], [&"REMOTE_NODE", remote.id]]:
		graph.add_node(NetworkNodeDefinition.new(data[0], String(data[0]), NetworkNodeDefinition.NodeType.SYSTEM, 2, true, &"CORP", data[1]))
	graph.add_link(NetworkLinkDefinition.new(&"ENTRY_RELAY", &"ENTRY", &"RELAY"))
	graph.add_link(NetworkLinkDefinition.new(&"RELAY_TARGET", &"RELAY", &"TARGET"))
	graph.add_link(NetworkLinkDefinition.new(&"TARGET_ISOLATED", &"TARGET", &"ISOLATED"))
	graph.add_link(NetworkLinkDefinition.new(&"TARGET_REMOTE", &"TARGET", &"REMOTE_NODE"))
	var sleeve := SecuritySleeve.new(&"SLEEVE_LOCAL", "Local Sleeve", [&"ENTRY", &"RELAY", &"TARGET", &"ISOLATED"])
	graph.add_security_sleeve(sleeve)

	var knowledge := PlayerKnowledge.new()
	for node_id in [&"ENTRY", &"RELAY", &"TARGET", &"ISOLATED"]: knowledge.reveal_node(graph.get_node(node_id), KnowledgeLevel.Value.IDENTIFIED)
	for link_id in [&"ENTRY_RELAY", &"RELAY_TARGET", &"TARGET_ISOLATED"]: knowledge.reveal_link(graph.get_link(link_id), KnowledgeLevel.Value.IDENTIFIED)
	knowledge.reveal_security_sleeve(sleeve, graph)
	var position := PlayerNetworkPosition.new(&"ENTRY")
	var tracker := CurrentSphereTracker.new(graph)
	tracker.register_player(&"PLAYER", position)
	var canvas := SphereMinimapCanvas.new()
	canvas.size = Vector2(420, 220)
	canvas.set_models(graph, position, knowledge, tracker)
	var original_nodes := canvas.visible_node_ids()

	var ice_controller := IceController.new(graph, position, knowledge)
	var host_definition := IceDefinition.new(&"HOST_GUARD", "Host Guard")
	host_definition.binding_mode = IceDefinition.BindingMode.HOST_BOUND
	host_definition.allowed_binding_node_ids = [&"ENTRY", &"RELAY"]
	var host_ice := IceInstance.new(&"HOST_ICE", host_definition, &"ENTRY")
	var roaming_definition := IceDefinition.new(&"ROAMER", "Roamer")
	var roaming_ice := IceInstance.new(&"ROAMING_ICE", roaming_definition, &"ENTRY")
	ice_controller.add_ice(host_ice); ice_controller.add_ice(roaming_ice)
	knowledge.report_ice(host_ice.instance_id, &"ENTRY", IceState.Value.DORMANT, KnowledgeLevel.Value.IDENTIFIED, 0, 3)
	var san_controller := SystemAccessNodeController.new(graph, knowledge, &"PLAYER")
	san_controller.configure_ice_controller(ice_controller)
	var created := san_controller.create_san(&"PLAYER", &"RUN", &"DECK", &"ENTRY")
	_expect(created.success and host_ice.current_node_id == &"RELAY", "SAN placement silently relocates host-bound ICE to a legal node")
	_expect(roaming_ice.current_node_id == &"ENTRY", "SAN placement does not relocate ordinary roaming ICE")
	_expect(knowledge.ice_records[host_ice.instance_id].node_id == &"ENTRY", "authoritative ICE relocation does not write its destination into PlayerKnowledge")
	_expect(not _known_ice_at(knowledge, &"RELAY"), "minimap knowledge does not magically reveal displaced ICE")
	knowledge.advance_knowledge_time(4)
	_expect(knowledge.ice_records[host_ice.instance_id].freshness == &"STALE" and knowledge.ice_records[host_ice.instance_id].node_id == &"" and knowledge.ice_records[host_ice.instance_id].last_known_node_id == &"ENTRY", "unobserved ICE ages into stale last-known information at its old node")

	graph.set_security_sleeve_state(sleeve.id, SecuritySleeve.State.BREACHED)
	_expect(canvas.security_sleeve_overlay_records()[0].state == SecuritySleeve.State.INTACT, "authoritative Sleeve changes do not bypass the knowledge boundary")
	knowledge.reveal_security_sleeve(sleeve, graph, &"SECURITY_OBSERVATION")
	_expect(canvas.security_sleeve_overlay_records()[0].state == SecuritySleeve.State.BREACHED, "an observed broken Sleeve updates the minimap overlay")
	_expect(canvas.visible_node_ids() == original_nodes and graph.get_nodes_in_sphere(local.id).size() == 4, "breaking a Sleeve retains every persistent Sphere member")

	graph.set_node_sleeve_protection(sleeve.id, &"ISOLATED", false)
	knowledge.reveal_security_sleeve(sleeve, graph, &"SECURITY_OBSERVATION")
	var breached_overlay := canvas.security_sleeve_overlay_records()[0]
	_expect(not breached_overlay.node_ids.has(&"ISOLATED") and canvas.visible_node_ids().has(&"ISOLATED"), "temporary protection loss changes the overlay without removing the node")
	_expect(graph.get_node(&"ISOLATED").sphere_id == local.id, "temporary protection loss never mutates node Sphere membership")

	graph.restore_security_sleeve(sleeve.id, [&"ENTRY", &"RELAY", &"TARGET", &"ISOLATED"])
	knowledge.reveal_security_sleeve(sleeve, graph, &"SECURITY_OBSERVATION")
	var restored_overlay := canvas.security_sleeve_overlay_records()[0]
	_expect(restored_overlay.state == SecuritySleeve.State.INTACT and restored_overlay.node_ids.has(&"ISOLATED"), "restoring a Sleeve restores its known overlay")
	_expect(canvas.visible_node_ids() == original_nodes, "restoring a Sleeve leaves the stable Sphere map unchanged")

	var inventory := ProgramInventory.new()
	var loadout := ProgramLoadout.new(2)
	var doorstop_definition := DoorstopDefinition.new(&"DOORSTOP_TEST", "Doorstop", "1.0")
	var doorstop_instance := ProgramInstance.new(&"DOORSTOP_INSTANCE", doorstop_definition)
	inventory.add_instance(doorstop_instance); loadout.install(doorstop_instance.instance_id, inventory)
	var doorstop := DoorstopController.new(inventory, loadout)
	doorstop.configure_san_controller(san_controller)
	var deployment := doorstop.deploy(doorstop_instance.instance_id, &"RUN", &"TARGET", 5.0, {}, {"node_id": &"TARGET", "node_is_valid": true, "node_transition_unresolved": false, "modal_action_unresolved": false, "jack_out_prohibited": false})
	_expect(deployment.success and san_controller.get_san(&"RUN").host_node_id == &"TARGET", "Doorstop relocates the single authoritative SAN")
	_expect(not bool(knowledge.get_node_view(&"ENTRY").local_san_present) and bool(knowledge.get_node_view(&"TARGET").local_san_present), "Doorstop atomically moves the knowledge-derived SAN minimap marker")
	_expect(canvas.current_sphere_id == local.id and canvas.visible_node_ids() == original_nodes, "same-Sphere Doorstop relocation does not rebuild or mutate Sphere membership")

	canvas.free()
	print("%s: %d Sphere mutation assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _known_ice_at(knowledge: PlayerKnowledge, node_id: StringName) -> bool:
	for record: Dictionary in knowledge.ice_records.values():
		if record.get("node_id", &"") == node_id: return true
	return false

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
