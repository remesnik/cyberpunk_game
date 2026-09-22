extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void:
	var graph := NetworkGraph.new()
	var source := NetworkNodeDefinition.new(&"SOURCE", "Source", NetworkNodeDefinition.NodeType.SYSTEM, 3)
	var neighbor := NetworkNodeDefinition.new(&"NEIGHBOR", "Neighbor", NetworkNodeDefinition.NodeType.ROUTER, 2)
	graph.add_node(source); graph.add_node(neighbor)
	graph.add_link(NetworkLinkDefinition.new(&"LINK", &"SOURCE", &"NEIGHBOR"))
	var sleeve := SecuritySleeve.new(&"TEST_SLEEVE", "Test Sleeve", [&"SOURCE", &"NEIGHBOR"])
	graph.add_security_sleeve(sleeve)
	var position := PlayerNetworkPosition.new(&"SOURCE", 20)
	var knowledge := PlayerKnowledge.new()
	var ice_controller := IceController.new(graph, position, knowledge)
	var local_definition := IceDefinition.new(&"LOCAL", "Local", 1, 999999)
	local_definition.binding_mode = IceDefinition.BindingMode.HOST_BOUND
	var local_ice := IceInstance.new(&"LOCAL_ICE", local_definition, &"SOURCE", IceState.Value.DORMANT)
	ice_controller.add_ice(local_ice)
	var profile := load("res://data/security_escalation_profile.tres") as SecurityEscalationProfile
	var controller := SecurityResponseController.new(graph, ice_controller, profile)

	var event := SecurityEvent.new(&"SOURCE", &"NOISY_ACTION", 2, &"BYPASS", &"PLAYER", &"SESSION_1", [&"NOISY"], 7).to_dict()
	source.report_security_event(event)
	_expect(sleeve.security_count == 2 and sleeve.escalation_level == SecuritySleeve.EscalationLevel.GUARDED, "node report advances Sleeve count to data-driven GUARDED state")
	_expect(event.source_node == &"SOURCE" and event.player_identity == &"PLAYER" and event.timestamp_state_marker == 7, "security event carries source, identity, tags, and state marker")
	_expect(local_ice.state == IceState.Value.ENGAGE and local_ice.current_node_id == &"SOURCE", "local ICE responds defensively without mobile behavior")
	_expect(controller.path_unlock_difficulty_modifier(&"SOURCE") == 1, "Sleeve escalation increases path-unlock difficulty")

	source.report_security_event(SecurityEvent.new(&"SOURCE", &"BYPASS_SECURITY_EVENT", 3, &"STEALTH_PROGRAM", &"PLAYER", &"SESSION_1", [&"FAILED_QUIET_ACTION"], 8).to_dict())
	_expect(sleeve.escalation_level == SecuritySleeve.EscalationLevel.ALERT and ice_controller.instances.size() == 2, "failed quiet action escalates Sleeve and spawns stationary ICE")
	var spawned: IceInstance = ice_controller.instances.values().filter(func(ice): return ice.instance_id != &"LOCAL_ICE")[0]
	_expect(spawned.definition.is_host_bound() and spawned.current_node_id == &"SOURCE", "spawned response ICE is stationary and host-bound")

	source.report_security_event(SecurityEvent.new(&"SOURCE", &"NOISY_ACTION", 4, &"INJECT", &"PLAYER", &"SESSION_1", [&"NOISY"], 9).to_dict())
	_expect(sleeve.escalation_level == SecuritySleeve.EscalationLevel.HOSTILE and controller.active_system_trace_pressure() == 1, "HOSTILE starts a system-wide trace as one escalation effect")
	_expect(controller.access_difficulty_modifier(&"SOURCE") == 1 and sleeve.metadata.get("punitive_tags", []).has(&"HOSTILE_INTRUDER"), "HOSTILE modifies access and applies punitive tags")

	source.report_security_event(SecurityEvent.new(&"SOURCE", &"NOISY_ACTION", 30, &"DELETE", &"PLAYER", &"SESSION_1", [&"DESTRUCTIVE"], 10).to_dict())
	_expect(sleeve.escalation_level == SecuritySleeve.EscalationLevel.SHUTDOWN and graph.get_link(&"LINK").disabled, "CRITICAL escalation reaches data-driven SHUTDOWN and closes the system")
	_expect(ice_controller.instances.size() >= 5, "crossed SEVERE and CRITICAL levels spawn additional stronger stationary ICE")

	print("%s: %d security response assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
