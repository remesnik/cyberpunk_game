extends Node

var failures := 0
var assertions := 0
@onready var game: Node = get_node("/root/Game")


func _ready() -> void:
	game.start_session()
	_configure_sec_relay_fixture()
	_run_test()
	game.end_session()
	print("%s: %d First Contact SEC_RELAY Doorstop assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)


func _configure_sec_relay_fixture() -> void:
	var graph := NetworkGraph.new()
	graph.add_node(NetworkNodeDefinition.new(&"CAM_CTL", "Camera Control", NetworkNodeDefinition.NodeType.SYSTEM, 1, true))
	graph.add_node(NetworkNodeDefinition.new(&"SEC_RELAY", "Security Relay", NetworkNodeDefinition.NodeType.SECURITY_SERVER, 2, true))
	graph.add_node(NetworkNodeDefinition.new(&"COMM_NODE", "Communications Node", NetworkNodeDefinition.NodeType.SERVICE_CLUSTER, 1, true))
	graph.add_node(NetworkNodeDefinition.new(&"OPS_SERVER", "Operations Server", NetworkNodeDefinition.NodeType.SYSTEM, 2, true))
	graph.add_node(NetworkNodeDefinition.new(&"EXIT_GATE", "Maintenance Egress", NetworkNodeDefinition.NodeType.GATEWAY, 1, true))
	graph.add_link(NetworkLinkDefinition.new(&"CAM_SECURITY", &"CAM_CTL", &"SEC_RELAY"))
	graph.add_link(NetworkLinkDefinition.new(&"SEC_COMM", &"SEC_RELAY", &"COMM_NODE"))
	graph.add_link(NetworkLinkDefinition.new(&"SEC_OPS", &"SEC_RELAY", &"OPS_SERVER"))
	graph.add_link(NetworkLinkDefinition.new(&"OPS_EXIT", &"OPS_SERVER", &"EXIT_GATE", true))
	game.network_graph = graph
	game.player_network_position = PlayerNetworkPosition.new(&"SEC_RELAY", 10)
	game.player_network_position.previous_node_id = &"CAM_CTL"
	game.player_knowledge = PlayerKnowledge.new()
	for id: StringName in graph.nodes: game.player_knowledge.reveal_node(graph.get_node(id), KnowledgeLevel.Value.IDENTIFIED)
	game.ice_controller = IceController.new(graph, game.player_network_position, game.player_knowledge)
	var passive_definition := IceDefinition.new(&"PASSIVE_AUDITOR_MK1", "Passive Audit Process", 0, 3, 1, [&"SEC_RELAY", &"COMM_NODE"] as Array[StringName], 6, 0)
	var passive_ice := IceInstance.new(&"SEC_RELAY_AUDITOR_01", passive_definition, &"COMM_NODE", IceState.Value.INVESTIGATE)
	passive_ice.target_node_id = &"SEC_RELAY"
	passive_ice.alert_level = 25
	game.ice_controller.add_ice(passive_ice)
	game.player_knowledge.detect_ice(passive_ice.instance_id)
	game.player_knowledge.report_ice(passive_ice.instance_id, passive_ice.current_node_id, passive_ice.state, KnowledgeLevel.Value.SCANNED)
	game.confrontation_controller = ConfrontationController.new(graph, game.player_network_position, game.player_knowledge, game.ice_controller)
	game.trace_level = 6
	game.anchor_controller = AnchorController.new(graph)
	game.anchor_controller.register_anchor(AnchorDefinition.new(&"CAM_CTL", "Camera Anchor"))
	game.anchor_controller.activate_anchor(&"CAM_CTL")
	game.failure_controller = FailureRecoveryController.new(game.anchor_controller, game.resource_state, game.player_network_position)
	game.deep_exploration = DeepExplorationController.new(graph, game.anchor_controller, game.player_network_position)

	var definition_data: Dictionary = (load("res://data/authoring/first_contact.tres") as CyberspaceContentDocument).find_entry(&"DOORSTOP_TUTORIAL_1_0")
	var doorstop := DoorstopDefinition.new(definition_data.id, definition_data.display_name, definition_data.version)
	doorstop.programming_recipe = definition_data.programming_recipe.duplicate(true)
	doorstop.programming_duration = definition_data.programming_duration
	game.program_inventory = ProgramInventory.new()
	game.program_loadout = ProgramLoadout.new(5)
	game.program_inventory.add_instance(ProgramInstance.new(&"FIRST_CONTACT_DOORSTOP_INSTANCE", doorstop, {"source": &"FILE_CACHE_SOFTWARE_BUNDLE"}))
	game.program_inventory.add_instance(ProgramInstance.new(&"MEATSPACE_UTILITY_INSTANCE", ProgramDefinition.new(&"SERVICE_PROBE", "Service Probe", "1.0")))
	game.program_loadout.install(&"FIRST_CONTACT_DOORSTOP_INSTANCE", game.program_inventory)
	game.doorstop_controller = DoorstopController.new(game.program_inventory, game.program_loadout)
	game.doorstop_programming_definition = doorstop
	game.meatspace_management = MeatspaceManagement.new()
	game.meatspace_management.configure(game.program_inventory, game.program_loadout, game.equipment_order_manager, game.realtime_world_clock)
	game.meatspace_management.software_programming.add_resource(&"MEMORY_SHARD", 2)
	game.meatspace_management.software_programming.add_resource(&"ROUTING_KERNEL", 2)


func _run_test() -> void:
	var level := load("res://data/authoring/first_contact.tres") as CyberspaceContentDocument
	var sequence: Dictionary = level.find_entry(&"FIRST_CONTACT_SEC_RELAY_DOORSTOP")
	var conditions: Array = sequence.beats[0].trigger.conditions
	_expect(conditions.any(func(condition): return condition.get("type", &"") == &"TRACE_AT_LEAST"), "recommendation requires elevated trace")
	_expect(conditions.any(func(condition): return condition.get("type", &"") == &"PROGRAM_OWNED"), "recommendation requires an owned Doorstop")
	_expect(conditions.any(func(condition): return condition.get("type", &"") == &"MEANINGFUL_PROGRESS_AT_LEAST"), "recommendation requires meaningful prior progress")
	var ice: IceInstance = game.ice_controller.get_ice(&"SEC_RELAY_AUDITOR_01")
	_expect(ice.state == IceState.Value.INVESTIGATE and ice.target_node_id == &"SEC_RELAY", "passive ICE is suspicious and approaching through actual ICE state")

	var trace_before: int = game.trace_level
	var deploy: ActionResult = game.request_doorstop_deployment(&"FIRST_CONTACT_DOORSTOP_INSTANCE")
	_expect(deploy.success, "actual Doorstop program action deploys at SEC_RELAY")
	_expect(not game.program_inventory.has_instance(&"FIRST_CONTACT_DOORSTOP_INSTANCE") and not game.program_loadout.is_installed(&"FIRST_CONTACT_DOORSTOP_INSTANCE"), "deployment burns the exact tutorial Doorstop instance")
	var anchor: DoorstopAnchor = game.doorstop_controller.get_anchor(game.intrusion_run_id)
	_expect(anchor != null and anchor.cyberspace_node_id == &"SEC_RELAY", "real DoorstopAnchor records SEC_RELAY")
	_expect(game.trace_level >= trace_before and ice.state != IceState.Value.ENGAGE, "deployment preserves trace while low-threat ICE remains short of engagement")
	var alarm: PhysicalAlarmInstance = game.physical_alarm_manager.instances.values()[0]
	alarm.apply_command(PhysicalAlarmDefinition.Command.TRIGGER)
	var alarm_state: int = alarm.state
	var jack_out: Dictionary = game.jack_out_through_doorstop()
	_expect(jack_out.success and game.intrusion_session.lifecycle == IntrusionSession.Lifecycle.SUSPENDED_AT_DOORSTOP, "Jack Out uses the real suspended-intrusion lifecycle")
	_expect(game.intrusion_session.suspended_anchor == anchor and anchor.active, "one-use return route remains active after suspension")
	_expect(not JSON.stringify(sequence).contains("CHECKPOINT") and not JSON.stringify(sequence).contains("SAVE POINT"), "authored sequence contains no fake checkpoint language or state")

	var management_sequence: Dictionary = level.find_entry(&"FIRST_CONTACT_MEATSPACE_MANAGEMENT")
	_expect(management_sequence.beats.size() == 4 and management_sequence.domain == &"MEATSPACE", "authored management guidance runs in the meat-space domain")
	var cyber_tick_before: int = game.action_clock.current_tick
	var persistent_trace: int = game.trace_level
	var deck_view: Dictionary = game.meatspace_management.inspect_deck()
	_expect(deck_view.success and not deck_view.owned_programs.any(func(program): return program.instance_id == &"FIRST_CONTACT_DOORSTOP_INSTANCE"), "deck inspection shows the deployed Doorstop is already consumed")
	var loadout_change: Dictionary = game.meatspace_management.install_program(&"MEATSPACE_UTILITY_INSTANCE")
	_expect(loadout_change.success and game.program_loadout.is_installed(&"MEATSPACE_UTILITY_INSTANCE"), "player changes one real loadout instance in meat space")
	var programming: Dictionary = game.meatspace_management.start_programming(&"FIRST_CONTACT_REPLACEMENT_DOORSTOP", game.doorstop_programming_definition)
	_expect(programming.success and game.meatspace_management.programming_tasks.has(&"FIRST_CONTACT_REPLACEMENT_DOORSTOP"), "player starts a real realtime Doorstop programming task")
	_expect(game.action_clock.current_tick == cyber_tick_before, "deck management and programming start consume zero cyberspace ticks")
	_expect(game.trace_level == persistent_trace and alarm.state == alarm_state and ice.state != IceState.Value.DORMANT, "trace, alarm, and ICE state persist while managing in meat space")
	var expected_loadout: Array[StringName] = game.program_loadout.installed_instance_ids.duplicate()
	var jack_back: Dictionary = game.jack_back_in_through_doorstop()
	_expect(jack_back.success and game.player_network_position.current_node_id == &"SEC_RELAY", "JACK BACK IN returns through the exact SEC_RELAY anchor")
	_expect(game.intrusion_session.applied_loadout_instance_ids == expected_loadout, "re-entry applies the changed meat-space loadout")
	_expect(not anchor.active and game.doorstop_controller.get_anchor(game.intrusion_run_id) == null, "successful re-entry destroys the temporary anchor")
	_expect(not game.program_inventory.has_instance(&"FIRST_CONTACT_DOORSTOP_INSTANCE"), "consumed tutorial Doorstop does not return after re-entry")
	_expect(game.trace_level == persistent_trace and alarm.state == alarm_state, "re-entry preserves trace and alarm state according to Doorstop policy")
	ice.state = IceState.Value.HUNT
	ice.target_node_id = &"SEC_RELAY"
	ice.alert_level = maxi(ice.alert_level, 40)
	game.player_knowledge.report_ice(ice.instance_id, ice.current_node_id, ice.state, KnowledgeLevel.Value.SCANNED)
	var ice_target := {"kind": &"ICE", "ice_id": ice.instance_id}
	var retreat_target := {"kind": &"NODE", "node_id": &"CAM_CTL"}
	_expect(game.confrontation_controller.validate(ActionRequest.ActionType.DISRUPT, ice_target).success, "resumed encounter offers real adjacent ICE disruption")
	_expect(game.confrontation_controller.validate(ActionRequest.ActionType.ATTACK_PROCESS, ice_target).success, "resumed encounter offers real process-disable pressure")
	_expect(game.confrontation_controller.validate(ActionRequest.ActionType.RETREAT, retreat_target).success, "resumed encounter offers a real graph-based evasion route")
	var evade: ActionResult = game.request_confrontation(ActionRequest.ActionType.RETREAT, retreat_target)
	_expect(evade.success and game.player_network_position.current_node_id == &"CAM_CTL", "player can resolve the forgiving encounter by evading through topology")
	_expect(ice.operational and ice.state != IceState.Value.ENGAGE, "auditor remains a forgiving real ICE process after the evasion choice")
	game.network_graph.apply_traversal(game.player_network_position, &"SEC_RELAY")
	game.network_graph.apply_traversal(game.player_network_position, &"OPS_SERVER")
	game.resource_state.add_volatile(&"SERVICE_ROUTE_MANIFEST", 1)
	game.network_graph.apply_traversal(game.player_network_position, &"EXIT_GATE")
	var normal_completion: Dictionary = game.intrusion_session.complete_normally({"level_id": &"FIRST_CONTACT", "objective_id": &"RETRIEVE_ROUTE_MANIFEST", "exit_node_id": &"EXIT_GATE"})
	_expect(normal_completion.success and game.intrusion_session.lifecycle == IntrusionSession.Lifecycle.COMPLETED, "normal EXIT_GATE completion finishes rather than suspends the intrusion")
	_expect(game.doorstop_controller.get_anchor(game.intrusion_run_id) == null, "normal mission exit creates no replacement Doorstop route")


func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
