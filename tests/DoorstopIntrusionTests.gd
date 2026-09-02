extends Node

var failures := 0
var assertions := 0
@onready var game: Node = get_node("/root/Game")
var doorstop_feedback_events: Array[Dictionary] = []


func _ready() -> void:
	EventBus.doorstop_feedback.connect(func(event): doorstop_feedback_events.append(event.duplicate(true)))
	game.start_session()
	_test_invalid_intrusion_states()
	_test_successful_deployment_and_copy_isolation()
	_test_second_anchor_is_rejected()
	_test_doorstop_jack_out_suspends_and_preserves_state()
	_test_meatspace_management_and_anchor_only_reentry()
	_test_complete_ux_feedback_sequence()
	game.end_session()
	print("%s: %d Doorstop intrusion assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)


func _test_invalid_intrusion_states() -> void:
	var instance_id: StringName = game.installed_doorstop_instance_ids()[0]
	game.player_network_position.is_transitioning = true
	var transition_result: ActionResult = game.request_doorstop_deployment(instance_id)
	game.player_network_position.is_transitioning = false
	_expect(not transition_result.success and "transition" in transition_result.reason.to_lower(), "deployment rejects an unresolved node transition")
	game.set_modal_action_selection_unresolved(true)
	var modal_result: ActionResult = game.request_doorstop_deployment(instance_id)
	game.set_modal_action_selection_unresolved(false)
	_expect(not modal_result.success and "modal" in modal_result.reason.to_lower(), "deployment rejects unresolved modal/action selection")
	game.set_jack_out_prohibited(true)
	var encounter_result: ActionResult = game.request_doorstop_deployment(instance_id)
	game.set_jack_out_prohibited(false)
	_expect(not encounter_result.success and "prohibits jack out" in encounter_result.reason.to_lower(), "deployment respects encounter Jack Out prohibition")
	_expect(game.program_inventory.has_instance(instance_id), "invalid deployments do not burn the installed copy")


func _test_successful_deployment_and_copy_isolation() -> void:
	var deployed_id: StringName = game.installed_doorstop_instance_ids()[0]
	var expected_node: StringName = game.player_network_position.current_node_id
	var trace_before: int = game.trace_level
	var ice_controller_before: IceController = game.ice_controller
	var alarm_manager_before: Variant = game.physical_alarm_manager
	var result: ActionResult = game.request_doorstop_deployment(deployed_id)
	_expect(result.success, "installed Doorstop deploys during an active intrusion")
	_expect(not game.program_inventory.has_instance(deployed_id) and not game.program_loadout.is_installed(deployed_id), "the activated instance is burned from inventory and loadout")
	_expect(game.program_inventory.has_instance(&"DOORSTOP_INSTANCE_002") and game.program_inventory.has_instance(&"DOORSTOP_GHOST_INSTANCE_001"), "other copies and variants remain owned")
	var anchor: DoorstopAnchor = game.doorstop_controller.get_anchor(game.intrusion_run_id)
	_expect(anchor != null and anchor.cyberspace_node_id == expected_node, "anchor records the exact occupied node")
	_expect(anchor.source_program_instance_id == deployed_id and anchor.intrusion_run_id == game.intrusion_run_id, "anchor records exact instance and intrusion IDs")
	_expect(game.trace_level >= trace_before, "deployment does not reset trace")
	_expect(game.ice_controller == ice_controller_before and game.physical_alarm_manager == alarm_manager_before, "deployment does not reset ICE or alarms")


func _test_second_anchor_is_rejected() -> void:
	var second_id := &"DOORSTOP_INSTANCE_002"
	_expect(game.program_loadout.install(second_id, game.program_inventory), "a second owned copy can be installed")
	var result: ActionResult = game.request_doorstop_deployment(second_id)
	_expect(not result.success and "already exists" in result.reason.to_lower(), "a second active Doorstop is rejected clearly")
	_expect(game.program_inventory.has_instance(second_id) and game.program_loadout.is_installed(second_id), "rejected second Doorstop remains owned and installed")


func _test_doorstop_jack_out_suspends_and_preserves_state() -> void:
	var anchor: DoorstopAnchor = game.doorstop_controller.get_anchor(game.intrusion_run_id)
	var anchor_node := anchor.cyberspace_node_id
	game.trace_level = 37
	game.resource_state.add_volatile(&"TEST_LOOT", 5)
	game.outbound_comms_manager.flags[&"PERSISTENT_STORY_FLAG"] = true
	var link: NetworkLinkDefinition = game.network_graph.links.values()[0]
	link.disabled = true
	var knowledge_before: Dictionary = game.player_knowledge.node_records.duplicate(true)
	var ice_before: Dictionary = {}
	for ice_id in game.ice_controller.instances:
		var ice: IceInstance = game.ice_controller.instances[ice_id]
		ice_before[ice_id] = {"node": ice.current_node_id, "state": ice.state, "alert": ice.alert_level}
	var alarms_before: Dictionary = {}
	for alarm_id in game.physical_alarm_manager.instances:
		var alarm: PhysicalAlarmInstance = game.physical_alarm_manager.instances[alarm_id]
		alarms_before[alarm_id] = alarm.state
	var result: Dictionary = game.jack_out_through_doorstop()
	_expect(result.success, "Doorstop Jack Out succeeds with an active anchor")
	_expect(game.intrusion_session.lifecycle == IntrusionSession.Lifecycle.SUSPENDED_AT_DOORSTOP, "intrusion lifecycle becomes SUSPENDED_AT_DOORSTOP")
	_expect(game.game_domain == game.GameDomain.MEATSPACE and game.session_active, "game enters meat space without ending the intrusion")
	_expect(anchor.active and game.doorstop_controller.get_anchor(game.intrusion_run_id) == anchor, "Doorstop anchor remains active while suspended")
	_expect(game.intrusion_session.can_resume_through_doorstop(), "suspended intrusion remains eligible for later Doorstop resume")
	_expect(anchor.cyberspace_node_id == anchor_node and game.player_network_position.current_node_id == anchor_node, "cyberspace position remains at the anchored node")
	_expect(game.trace_level == 37 and game.resource_state.volatile_resources.TEST_LOOT == 5, "trace and collected loot are preserved")
	_expect(game.player_knowledge.node_records == knowledge_before and link.disabled, "knowledge and route state are preserved")
	_expect(game.outbound_comms_manager.flags.PERSISTENT_STORY_FLAG, "story flags are preserved")
	for ice_id in ice_before:
		var ice: IceInstance = game.ice_controller.instances[ice_id]
		_expect(ice.current_node_id == ice_before[ice_id].node and ice.state == ice_before[ice_id].state and ice.alert_level == ice_before[ice_id].alert, "ICE state is preserved for %s" % ice_id)
	for alarm_id in alarms_before:
		_expect(game.physical_alarm_manager.instances[alarm_id].state == alarms_before[alarm_id], "alarm state is preserved for %s" % alarm_id)
	_expect(not game.program_inventory.has_instance(anchor.source_program_instance_id), "consumed Doorstop is not restored")
	_expect(game.intrusion_session.resume_state.current_node_id == anchor_node and game.intrusion_session.resume_state.trace == 37, "resume record captures exact node and trace")
	_expect(not game.request_action(ActionRequest.new(&"PLAYER", ActionRequest.ActionType.WAIT)).success, "cyberspace actions are blocked while suspended")
	_expect(game.realtime_world_clock.running, "meat-space realtime remains active while intrusion is suspended")
	_expect(game.advance_suspended_security_time(3.0) and game.intrusion_session.suspended_security_elapsed == 3.0, "suspended security advancement hook records elapsed time without simulating it")


func _test_meatspace_management_and_anchor_only_reentry() -> void:
	var manager: MeatspaceManagement = game.meatspace_management
	var tick_before: int = game.action_clock.current_tick
	var anchor: DoorstopAnchor = game.intrusion_session.suspended_anchor
	var return_node := anchor.cyberspace_node_id
	var upgrade: Dictionary = manager.upgrade_hardware(&"DECK_RAM", 10)
	_expect(upgrade.success and manager.hardware_levels.DECK_RAM == 2, "deck hardware can be upgraded in meat space")
	var installed_id := &"DOORSTOP_INSTANCE_002"
	_expect(manager.remove_program(installed_id).success and not game.program_loadout.is_installed(installed_id), "installed programs can be removed from the suspended loadout")
	var reserve_id := &"DOORSTOP_GHOST_INSTANCE_001"
	_expect(manager.install_program(reserve_id).success and game.program_loadout.is_installed(reserve_id), "owned programs can be installed before re-entry")
	var expected_loadout: Array[StringName] = game.program_loadout.installed_instance_ids.duplicate()
	var vendor_ids: Array = game.equipment_order_manager.vendors.keys()
	var vendor: VendorDefinition = game.equipment_order_manager.vendors[vendor_ids[0]]
	var order: Dictionary = manager.order_equipment(vendor.inventory[0], vendor.id, 1, vendor.delivery_destinations[0])
	_expect(order.success, "equipment can be ordered while the intrusion is suspended")
	var programming: Dictionary = manager.start_programming(&"TEST_DOORSTOP_BUILD", game.doorstop_programming_definition, 2.0)
	_expect(programming.success, "software programming tasks can start in meat space")
	game.realtime_world_clock.restore(game.realtime_world_clock.elapsed_seconds + 3.0, true)
	manager.update_tasks()
	var collected: Dictionary = manager.collect_programming(&"TEST_DOORSTOP_BUILD")
	_expect(collected.success and game.program_inventory.has_instance(collected.program_instance_id), "completed software tasks add their unique program instance to inventory")
	_expect(manager.perform_story_interaction(&"SAFEHOUSE_CONTACT", &"ACKNOWLEDGE").success, "story/meat-space interactions remain available")
	_expect(game.action_clock.current_tick == tick_before, "meat-space management does not advance cyberspace ticks")
	_expect(not game.program_inventory.has_instance(anchor.source_program_instance_id), "management never restores the consumed Doorstop")
	var persistent_trace: int = game.trace_level
	var persistent_knowledge: Dictionary = game.player_knowledge.node_records.duplicate(true)
	var persistent_flags: Dictionary = game.outbound_comms_manager.flags.duplicate(true)
	# Even if presentation or future meat-space code displaces the position model,
	# re-entry has no destination input and must use the anchor's stored node.
	var displaced_candidates: Array = game.network_graph.nodes.keys().filter(func(id): return id != return_node)
	var displaced_node: StringName = displaced_candidates[0]
	game.player_network_position.relocate(displaced_node)
	var resume: Dictionary = game.jack_back_in_through_doorstop()
	_expect(resume.success and resume.node_id == return_node, "Jack Back In returns only to the Doorstop node")
	_expect(game.player_network_position.current_node_id == return_node and game.game_domain == game.GameDomain.CYBERSPACE, "re-entry restores cyberspace mode at the anchored position")
	_expect(game.intrusion_session.lifecycle == IntrusionSession.Lifecycle.ACTIVE, "suspended intrusion returns to ACTIVE")
	_expect(game.intrusion_session.applied_loadout_instance_ids == expected_loadout and game.program_loadout.installed_instance_ids == expected_loadout, "current meat-space loadout is applied to the resumed intrusion")
	_expect(game.trace_level == persistent_trace and game.player_knowledge.node_records == persistent_knowledge and game.outbound_comms_manager.flags == persistent_flags, "persistent intrusion state survives re-entry")
	_expect(not anchor.active and game.doorstop_controller.get_anchor(game.intrusion_run_id) == null and game.intrusion_session.suspended_anchor == null, "Jack Back In destroys and clears the DoorstopAnchor")
	_expect(not game.program_inventory.has_instance(anchor.source_program_instance_id), "original Doorstop instance remains consumed after re-entry")
	var second_resume: Dictionary = game.jack_back_in_through_doorstop()
	_expect(not second_resume.success and "no suspended" in String(second_resume.reason).to_lower(), "a second Jack Back In attempt fails cleanly")


func _test_complete_ux_feedback_sequence() -> void:
	var kinds: Array[StringName] = []
	for event: Dictionary in doorstop_feedback_events:
		kinds.append(event.get("kind", &""))
	for expected: StringName in [&"ACQUIRED", &"INVALID", &"DEPLOYED", &"BURNED", &"SUSPENDED", &"REENTRY", &"CLOSED"]:
		_expect(kinds.has(expected), "Doorstop UX emits %s feedback" % expected)
	_expect(doorstop_feedback_events.any(func(event): return event.kind == &"ACQUIRED" and not String(event.help_text).is_empty()), "first Doorstop acquisition includes contextual help")
	_expect(doorstop_feedback_events.any(func(event): return event.kind == &"DEPLOYED" and not String(event.help_text).is_empty()), "first Doorstop deployment includes contextual help")


func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
