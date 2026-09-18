extends Node

const DISPLAY := preload("res://cyberspace/display/NetworkDisplay.tscn")

var failures := 0
var assertions := 0

func _ready() -> void:
	var display := DISPLAY.instantiate() as NetworkDisplay
	add_child(display)
	var position := PlayerNetworkPosition.new(&"CURRENT", 20)
	display.position_model = position
	display.knowledge = PlayerKnowledge.new()
	display.focused_node_id = &"CURRENT"
	display.target_views = {
		&"CURRENT": {"kind": &"NODE", "title": "CURRENT", "current": true, "node": {"id": &"CURRENT", "scanned": true}},
		&"ADJACENT": {"kind": &"NODE", "title": "ADJACENT", "node": {"id": &"ADJACENT", "scanned": true}, "link": {"traversal_cost": 1}},
		&"ICE_LOCAL": {"kind": &"ICE", "actor_id": &"ice_local_01", "title": "LOCAL ICE", "ice": {"id": &"ice_local_01", "node_id": &"CURRENT", "scanned": true}, "attackable": true},
		&"ICE_ROAMING": {"kind": &"ICE", "actor_id": &"ice_roaming_01", "title": "ROAMING ICE", "ice": {"id": &"ice_roaming_01", "node_id": &"ADJACENT", "scanned": true}, "attackable": true},
		&"USER_LOCAL": {"kind": &"USER", "actor_id": &"user_07", "title": "USER", "user": {"id": &"user_07", "node_id": &"CURRENT", "scanned": true}, "scanned": true},
		&"HACKER_LOCAL": {"kind": &"HACKER", "actor_id": &"hacker_12", "title": "HACKER", "hacker": {"id": &"hacker_12", "node_id": &"CURRENT", "scanned": true}, "scanned": true},
		&"SERVICE_LOCAL": {"kind": &"SERVICE", "title": "SERVICE", "service": {"node_id": &"CURRENT", "scanned": true}, "connectable": true},
		&"FILE_LOCAL": {"kind": &"FILE", "title": "FILE", "file": {"node_id": &"CURRENT"}, "downloadable": true},
		&"DEVICE_LOCAL": {"kind": &"DEVICE_OBJECT", "title": "DEVICE", "device": {"node_id": &"CURRENT"}, "controllable": true},
	}
	display.netspace_view_mode = NetworkDisplay.NetspaceViewMode.NETWORK
	display.selected_target_id = &"CURRENT"
	display.get_node("BottomBar").visible = true
	display.ambient_activity.reconcile_actors([
		{"actor_id": &"ice_local_01", "node_id": &"CURRENT", "actor_type": AmbientNetworkActivity.ActorType.ICE, "scope": &"LOCAL"},
		{"actor_id": &"ice_roaming_01", "node_id": &"ADJACENT", "actor_type": AmbientNetworkActivity.ActorType.ICE, "scope": &"ROAMING"},
		{"actor_id": &"user_07", "node_id": &"CURRENT", "actor_type": AmbientNetworkActivity.ActorType.NORMAL, "scope": &"ROAMING"},
		{"actor_id": &"hacker_12", "node_id": &"CURRENT", "actor_type": AmbientNetworkActivity.ActorType.HACKER_UNKNOWN, "scope": &"ROAMING"},
	])
	var warden := NetspaceBossEncounter.create(NetspaceBossEncounter.Archetype.WARDEN, &"WARDEN_UI", &"CURRENT")
	display.attach_boss_encounter(warden)
	display._apply_view_mode_presentation()

	_expect(display.netspace_view_mode == NetworkDisplay.NetspaceViewMode.NETWORK, "Netspace begins in authoritative NETWORK mode")
	_expect(display.local_target_visuals.is_empty() and not display.local_target_layer.visible and not display.service_list.visible, "Network mode suppresses local files, services, devices, and local ICE")
	_expect(display._target_allowed_in_view_mode(&"CURRENT") and display._target_allowed_in_view_mode(&"ICE_ROAMING"), "network nodes and roaming actors remain selectable")
	_expect(not display._target_allowed_in_view_mode(&"SERVICE_LOCAL") and not display._target_allowed_in_view_mode(&"ICE_LOCAL"), "local targets cannot compete in Network mode")
	_expect(display.actor_presentation_count(&"ice_local_01") == 0 and display.actor_presentation_count(&"ice_roaming_01") == 1, "host-bound ICE stays local while roaming ICE has one Network-scale representation")
	_expect(display.actor_presentation_count(&"user_07") == 1 and display.actor_presentation_count(&"hacker_12") == 1, "users and hackers retain stable Network-scale identities")

	var node_before := position.current_node_id
	display._on_semantic_action(&"primary_action")
	_expect(display.netspace_view_mode == NetworkDisplay.NetspaceViewMode.NODE_FOCUS, "Primary Action on the current node enters NODE_FOCUS")
	_expect(display._mode_transition_active and (display.local_target_visuals[&"FILE_LOCAL"] as Button).scale.x < 1.0, "Node Focus begins as a smooth local-target reveal")
	_expect(position.current_node_id == node_before, "entering Node Focus does not traverse or change current_node")
	_expect(display.local_target_visuals.size() == 11 and display.local_target_layer.visible, "Node Focus exposes local ICE, actors, services, files, devices, and boss components")
	var stable_positions := display._local_target_final_positions.duplicate()
	display._on_semantic_action(&"primary_action")
	_expect(display.local_target_visuals.size() == 11, "repeated transition input creates no duplicate local targets")
	await get_tree().create_timer(NetworkDisplay.NODE_FOCUS_TRANSITION_DURATION + 0.05).timeout
	_expect(display.node_layer.visible and not display._target_allowed_in_view_mode(&"ADJACENT"), "dimmed network presentation remains intact but traversal targets cannot compete")
	_expect(display._local_target_final_positions == stable_positions, "local target positions remain deterministic through the reveal")
	_expect((display.local_target_visuals[&"FILE_LOCAL"] as Button).size.x >= 260.0, "local targets are substantially enlarged")
	_expect(display.actor_presentation_count(&"user_07") == 1 and display.local_target_for_actor(&"hacker_12") == &"HACKER_LOCAL", "Network actors reconcile to one selectable local representation by stable ID")
	var dial_center := display.command_dial.position.x + display.command_dial.size.x * 0.5
	var selected_command_buttons := display.command_dial.get_children().filter(func(child: Node) -> bool: return child is Button and (child as Button).button_pressed)
	_expect(display.command_dial.position.y < display.get_node("BottomBar").position.y and absf(dial_center - display.size.x * 0.5) < 2.0, "Node Focus command dial is fixed above the active program bar")
	_expect(selected_command_buttons.size() == 1 and absf((selected_command_buttons[0] as Button).position.x + (selected_command_buttons[0] as Button).size.x * 0.5 - display.command_dial.size.x * 0.5) < 2.0, "selected contextual command remains centered and larger than its neighbors")
	_expect(display.selected_command_id == &"SCAN", "an unscanned local target defaults to Scan")
	_expect(display.target_details.text.split("\n").size() <= 3 and display.target_details.text.contains("DEVICE"), "selected-target metadata stays concise")
	var file_view := display.target_views[&"FILE_LOCAL"] as Dictionary
	file_view["scanned"] = true
	(file_view.file as Dictionary)["scanned"] = true
	display._select_local_target(&"FILE_LOCAL")
	_expect(display.target_title.text == "FILE" and &"DOWNLOAD" in display._valid_contextual_commands, "switching targets immediately refreshes summary and valid commands")
	_expect(display.get_valid_commands(&"SERVICE_LOCAL").has(&"CONNECT") and display.get_valid_commands(&"ADJACENT").is_empty(), "contextual commands are scoped by view mode")
	_expect(display.get_node("BottomBar").visible, "active program slots remain visible in Node Focus")
	for boss_target_id: StringName in warden.target_views():
		display._select_local_target(boss_target_id)
		_expect(display.focused_local_target_id == boss_target_id and not display.get_valid_commands(boss_target_id).is_empty(), "boss component %s uses normal local targeting and contextual commands" % boss_target_id)

	display._on_semantic_action(&"back_action")
	await get_tree().create_timer(NetworkDisplay.NODE_FOCUS_TRANSITION_DURATION + 0.05).timeout
	_expect(display.netspace_view_mode == NetworkDisplay.NetspaceViewMode.NETWORK and display.focused_local_target_id.is_empty(), "Back returns one level to Network mode")
	_expect(position.current_node_id == node_before, "Back from Node Focus does not alter current_node")
	_expect(display.node_layer.visible and display.get_node("BottomBar").visible, "network presentation and active slots are restored")
	display.netspace_view_mode = NetworkDisplay.NetspaceViewMode.NODE_FOCUS
	display._on_game_domain_changed(Game.GameDomain.MEATSPACE, Game.GameDomain.CYBERSPACE)
	_expect(display.netspace_view_mode == NetworkDisplay.NetspaceViewMode.NETWORK, "entering Netspace always establishes Network mode")

	display.queue_free()
	await get_tree().process_frame
	print("%s: %d Netspace view mode assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
