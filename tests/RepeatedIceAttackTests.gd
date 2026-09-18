extends Node

const DISPLAY := preload("res://cyberspace/display/NetworkDisplay.tscn")

var failures := 0
var assertions := 0

func _ready() -> void:
	var graph := TestNetworkFactory.create_graph()
	var player := PlayerNetworkPosition.new(TestNetworkFactory.SECURITY_SERVER, 50)
	var knowledge := TestNetworkFactory.create_player_knowledge(graph)
	knowledge.reveal_node(graph.get_node(TestNetworkFactory.SECURITY_SERVER), KnowledgeLevel.Value.IDENTIFIED)
	var ice_controller := IceController.new(graph, player, knowledge)
	var definition := IceDefinition.new(&"REPEAT_TEST", "Sentinel ICE", 1, 2, 1, [], 12, 1)
	var ice := IceInstance.new(&"ice_0042", definition, TestNetworkFactory.SECURITY_SERVER, IceState.Value.ENGAGE)
	_expect(ice_controller.add_ice(ice), "one canonical ICE instance is accepted")
	knowledge.report_ice(ice.instance_id, ice.current_node_id, ice.state, KnowledgeLevel.Value.SCANNED)
	var controller := ConfrontationController.new(graph, player, knowledge, ice_controller)
	var contact_id: StringName = knowledge.ice_records[ice.instance_id].contact_id

	var display := DISPLAY.instantiate() as NetworkDisplay
	add_child(display)
	display.position_model = player
	display.knowledge = knowledge
	display.focused_node_id = player.current_node_id
	var center := (load("res://cyberspace/display/NodeVisual.tscn") as PackedScene).instantiate() as NodeVisual
	center.position = Vector2(500, 350); center.size = Vector2(100, 100); display.node_layer.add_child(center)
	display.node_visuals[player.current_node_id] = center
	display.target_views = _views(player.current_node_id, contact_id, knowledge.ice_records[ice.instance_id])
	display.netspace_view_mode = NetworkDisplay.NetspaceViewMode.NETWORK
	_expect(display._enter_node_focus_mode(), "node focus opens on ICE, service, and file")
	await get_tree().create_timer(NetworkDisplay.NODE_FOCUS_TRANSITION_DURATION + 0.05).timeout
	_expect(display.local_target_visuals.size() == 3, "initial local-target count is exactly three")
	var original_visual_id := (display.local_target_visuals[contact_id] as Button).get_instance_id()
	var destroyed_events := 0
	var prior_hp := ice.integrity
	for attack_index in 10:
		if not ice.operational: break
		var result := controller.execute(ActionRequest.ActionType.ATTACK_PROCESS, {"kind": &"ICE", "ice_id": ice.instance_id})
		_expect(result.success and ice.instance_id == &"ice_0042" and ice.integrity < prior_hp, "attack %d damages the same stable ICE ID once" % (attack_index + 1))
		prior_hp = ice.integrity
		destroyed_events += result.events.filter(func(event: Dictionary) -> bool: return event.type == &"ICE_DESTROYED").size()
		display.target_views = _views(player.current_node_id, contact_id, knowledge.ice_records[ice.instance_id])
		display._reconcile_local_target_visuals(display._local_target_ids_for_node(player.current_node_id))
		_expect(ice_controller.instances.size() == 1 and display.local_target_visuals.size() == 3, "attack %d does not multiply gameplay or local targets" % (attack_index + 1))
		_expect((display.local_target_visuals[contact_id] as Button).get_instance_id() == original_visual_id, "attack %d updates the existing ICE visual" % (attack_index + 1))
		_expect(display.local_target_visuals.values().filter(func(button: Button) -> bool: return button.get_meta("local_target_id") == contact_id).size() == 1, "attack %d leaves one ICE icon and no stacked status visual" % (attack_index + 1))
	_expect(not ice.operational and destroyed_events == 1, "ICE performs one clean transition to destroyed")
	display._select_local_target(contact_id)
	_expect(&"ATTACK" not in display.get_valid_commands(contact_id), "destroyed ICE no longer offers Attack")
	_expect(not controller.execute(ActionRequest.ActionType.ATTACK_PROCESS, {"kind": &"ICE", "ice_id": ice.instance_id}).success, "destroyed ICE rejects further damage")
	display._exit_node_focus_mode()
	await get_tree().create_timer(NetworkDisplay.NODE_FOCUS_TRANSITION_DURATION + 0.05).timeout
	_expect(display._enter_node_focus_mode() and display.local_target_visuals.size() == 3, "leaving and re-entering node focus creates no duplicates")
	await get_tree().create_timer(NetworkDisplay.NODE_FOCUS_TRANSITION_DURATION + 0.05).timeout
	display._reconcile_local_target_visuals(display._local_target_ids_for_node(player.current_node_id))
	_expect(display.local_target_visuals.size() == 3 and ice_controller.instances.size() == 1, "return refresh preserves one entity and one representation")
	display.queue_free(); await get_tree().process_frame
	print("%s: %d repeated ICE attack assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _views(node_id: StringName, ice_contact: StringName, ice_record: Dictionary) -> Dictionary:
	return {
		node_id: {"kind": &"NODE", "title": "SECURITY RELAY", "node": {"id": node_id}},
		ice_contact: {"kind": &"ICE", "title": "SENTINEL ICE", "ice": ice_record.duplicate(true), "scanned": true, "attackable": bool(ice_record.get("operational", true)), "confrontation_target": {"kind": &"ICE", "contact_id": ice_contact}},
		&"SERVICE_LOCAL": {"kind": &"SERVICE", "title": "SECURITY SERVICE", "service": {"node_id": node_id}},
		&"FILE_LOCAL": {"kind": &"FILE", "title": "AUDIT FILE", "file": {"node_id": node_id}},
	}

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
