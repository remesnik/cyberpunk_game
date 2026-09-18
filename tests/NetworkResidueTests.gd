extends Node

var failures := 0
var assertions := 0

func _ready() -> void:
	_test_explicit_residue_and_recovery()
	await _test_runtime_return_restore()
	print("%s: %d network residue assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _test_explicit_residue_and_recovery() -> void:
	var graph := TestNetworkFactory.create_graph()
	var ledger := NetworkResidueState.new()
	ledger.mark(&"SERVICE", &"PUBLIC_RELAY", &"DISABLED", 10.0, {"delay": 20.0, "state": &"ACTIVE"})
	ledger.mark(&"FILE", &"PAYROLL", &"DELETED", 10.0, {"delay": 30.0, "state": &"RESTORED"})
	ledger.mark(&"DEVICE", &"CAMERA_1", &"CONTROLLED", 10.0)
	var knowledge := TestNetworkFactory.create_player_knowledge(graph)
	knowledge.reveal_service(graph.get_node(TestNetworkFactory.PUBLIC_GATEWAY).services[0], TestNetworkFactory.PUBLIC_GATEWAY, KnowledgeLevel.Value.SCANNED)
	ledger.apply_to_graph(graph)
	ledger.apply_to_knowledge(knowledge)
	_expect(bool(graph.get_node(TestNetworkFactory.PUBLIC_GATEWAY).services[0].disabled), "disabled service residue applies to a rebuilt graph")
	_expect(knowledge.get_node_view(TestNetworkFactory.PUBLIC_GATEWAY).concise_status == "disabled", "known residue remains visibly attached to its node")
	_expect(ledger.has_state(&"FILE", &"PAYROLL", &"DELETED") and ledger.has_state(&"DEVICE", &"CAMERA_1", &"CONTROLLED"), "deleted files and controlled devices retain explicit source state")
	_expect(ledger.advance(29.0).is_empty() and ledger.has_state(&"SERVICE", &"PUBLIC_RELAY", &"DISABLED"), "recovery never occurs before its authored deadline")
	var recovered := ledger.advance(40.0)
	_expect(recovered.size() == 2 and ledger.has_state(&"SERVICE", &"PUBLIC_RELAY", &"ACTIVE") and ledger.has_state(&"FILE", &"PAYROLL", &"RESTORED"), "authored service restart and backup restoration occur at their deadlines")
	var serialized := ledger.to_save_data()
	var restored := NetworkResidueState.new(); restored.configure(serialized)
	_expect(restored.has_state(&"FILE", &"PAYROLL", &"RESTORED"), "residue survives save-data round trip")

func _test_runtime_return_restore() -> void:
	Game.create_new_game(GameMode.Value.FREE_ROAM)
	Game.start_session()
	var node_ids: Array = Game.network_graph.nodes.keys()
	var remembered_id := StringName(node_ids[mini(1, node_ids.size() - 1)])
	Game.player_knowledge.mark_node_scanned(Game.network_graph.get_node(remembered_id), true, true)
	var link_id := StringName(Game.network_graph.links.keys()[0])
	Game.network_graph.get_link(link_id).disabled = true
	var ice_id := StringName(Game.ice_controller.instances.keys()[0])
	(Game.ice_controller.instances[ice_id] as IceInstance).operational = false
	Game._synchronize_persistent_state_from_runtime()
	Game.end_session()
	Game.start_session()
	_expect(Game.player_knowledge.player_has_scanned_node(remembered_id), "scanned node state survives an ordinary Meatspace return")
	_expect(Game.player_knowledge.node_records.has(remembered_id), "discovered-node knowledge survives runtime reconstruction")
	_expect(Game.network_graph.get_link(link_id).disabled, "disabled topology remains disabled after runtime reconstruction")
	_expect(not (Game.ice_controller.instances[ice_id] as IceInstance).operational, "destroyed ICE does not respawn on scene reconstruction")
	Game.end_session()
	await get_tree().process_frame

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
