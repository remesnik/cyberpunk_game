extends Node

const ENTRY := &"ENTRY"
const NODE_01 := &"NODE_01"
const NODE_02 := &"NODE_02"
const NODE_03 := &"NODE_03"
const DOORSTOP_A := &"DOORSTOP_A"
const DOORSTOP_B := &"DOORSTOP_B"
const DOORSTOP_C := &"DOORSTOP_C"
const UTILITY_PROGRAM := &"UTILITY_PROGRAM_01"

var failures := 0
var assertions := 0
@onready var game: Node = get_node("/root/Game")


func _ready() -> void:
	game.start_session()
	_configure_scenario()
	_run_scenario()
	game.end_session()
	print("%s: %d Doorstop end-to-end assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)


func _configure_scenario() -> void:
	var graph := NetworkGraph.new()
	for node_data: Array in [
		[ENTRY, "Entry", NetworkNodeDefinition.NodeType.GATEWAY],
		[NODE_01, "Node 01", NetworkNodeDefinition.NodeType.ROUTER],
		[NODE_02, "Node 02", NetworkNodeDefinition.NodeType.SYSTEM],
		[NODE_03, "Node 03", NetworkNodeDefinition.NodeType.SECURITY_SERVER],
	]:
		graph.add_node(NetworkNodeDefinition.new(node_data[0], node_data[1], node_data[2], 1, node_data[0] == ENTRY, &"TEST_NET"))
	graph.add_link(NetworkLinkDefinition.new(&"ENTRY_TO_01", ENTRY, NODE_01))
	graph.add_link(NetworkLinkDefinition.new(&"NODE_01_TO_02", NODE_01, NODE_02))
	graph.add_link(NetworkLinkDefinition.new(&"NODE_02_TO_03", NODE_02, NODE_03))

	game.network_graph = graph
	game.player_network_position = PlayerNetworkPosition.new(ENTRY, 20)
	game.player_knowledge = PlayerKnowledge.new()
	game.player_knowledge.reveal_node(graph.get_node(ENTRY), KnowledgeLevel.Value.IDENTIFIED)
	game.ice_controller = IceController.new(graph, game.player_network_position, game.player_knowledge)
	game.scan_system = ScanSystem.new(graph, game.player_network_position, game.player_knowledge, game.ice_controller)
	game.progression_controller = GraphProgressionController.new(graph, game.player_network_position, game.player_knowledge)
	game.anchor_controller = AnchorController.new(graph)
	game.anchor_controller.register_anchor(AnchorDefinition.new(ENTRY, "Entry Anchor"))
	game.anchor_controller.activate_anchor(ENTRY)
	game.shortcut_controller = ShortcutController.new(graph)
	game.failure_controller = FailureRecoveryController.new(game.anchor_controller, game.resource_state, game.player_network_position)
	game.deep_exploration = DeepExplorationController.new(graph, game.anchor_controller, game.player_network_position)

	var definition := DoorstopDefinition.new(&"DOORSTOP_E2E", "Doorstop", "1.4")
	definition.programming_recipe = {&"MEMORY_SHARD": 1}
	definition.programming_duration = 30.0
	game.doorstop_programming_definition = definition
	game.program_inventory = ProgramInventory.new()
	game.program_loadout = ProgramLoadout.new(5)
	for instance_id: StringName in [DOORSTOP_A, DOORSTOP_B, DOORSTOP_C]:
		game.program_inventory.add_instance(ProgramInstance.new(instance_id, definition))
	var utility := ProgramDefinition.new(&"DIAGNOSTIC_SUITE", "Diagnostic Suite", "1.0")
	game.program_inventory.add_instance(ProgramInstance.new(UTILITY_PROGRAM, utility))
	game.program_loadout.install(DOORSTOP_A, game.program_inventory)
	game.program_loadout.install(DOORSTOP_B, game.program_inventory)
	game.doorstop_controller = DoorstopController.new(game.program_inventory, game.program_loadout)
	game.meatspace_management = MeatspaceManagement.new()
	game.meatspace_management.configure(game.program_inventory, game.program_loadout, game.equipment_order_manager, game.realtime_world_clock)
	game.meatspace_management.software_programming.add_resource(&"MEMORY_SHARD", 3)

	var policy := DoorstopSuspensionPolicy.new()
	policy.preserve_trace = true
	policy.trace_increase_per_second = 0.5
	policy.alarms_remain_active = true
	policy.ice_may_reposition = false
	game.configure_doorstop_suspension_policy(policy)


func _run_scenario() -> void:
	_expect(game.program_loadout.is_installed(DOORSTOP_A) and game.program_loadout.is_installed(DOORSTOP_B), "Doorstops A and B begin installed")
	_expect(game.program_inventory.has_instance(DOORSTOP_C), "Doorstop C begins owned")
	_expect(_traverse(NODE_01) and _traverse(NODE_02), "player traverses ENTRY -> NODE_01 -> NODE_02")

	game.player_knowledge.reveal_node(game.network_graph.get_node(NODE_03), KnowledgeLevel.Value.IDENTIFIED)
	# Raised, but deliberately below the mission's forced-disconnect threshold so
	# this test exercises the Doorstop lifecycle rather than Crash Cache creation.
	game.trace_level = 8
	var alarm: PhysicalAlarmInstance = game.physical_alarm_manager.instances.values()[0]
	_expect(alarm.apply_command(PhysicalAlarmDefinition.Command.TRIGGER), "physical alarm is triggered")
	var ice_definition := IceDefinition.new(&"E2E_ICE", "Test ICE")
	var ice := IceInstance.new(&"E2E_ICE_01", ice_definition, NODE_03, IceState.Value.PATROL)
	game.ice_controller.add_ice(ice)
	ice.operational = false
	game.resource_state.add_volatile(&"E2E_LOOT", 1)

	var deploy_a: ActionResult = game.request_doorstop_deployment(DOORSTOP_A)
	_expect(deploy_a.success, "Doorstop A deploys at NODE_02")
	_expect(not game.program_inventory.has_instance(DOORSTOP_A), "Doorstop A is removed from inventory")
	_expect(not game.program_loadout.is_installed(DOORSTOP_A), "Doorstop A is removed from loadout")
	_expect(game.program_loadout.is_installed(DOORSTOP_B), "Doorstop B remains installed")
	_expect(game.program_inventory.has_instance(DOORSTOP_C), "Doorstop C remains owned")
	var old_anchor: DoorstopAnchor = game.doorstop_controller.get_anchor(game.intrusion_run_id)
	_expect(old_anchor != null and old_anchor.cyberspace_node_id == NODE_02, "anchor records the exact NODE_02 return point")
	var trace_at_suspend: int = game.trace_level

	_expect(game.jack_out_through_doorstop().success, "Jack Out suspends through Doorstop")
	_expect(game.intrusion_session.lifecycle == IntrusionSession.Lifecycle.SUSPENDED_AT_DOORSTOP, "intrusion lifecycle is suspended")
	var install_result: Dictionary = game.meatspace_management.install_program(UTILITY_PROGRAM)
	_expect(install_result.success, "a different program is installed in meat space")
	var task_result: Dictionary = game.meatspace_management.start_programming(&"DOORSTOP_BUILD_E2E", game.doorstop_programming_definition)
	_expect(task_result.success, "a Doorstop programming task starts in real time")
	var upgrade_result: Dictionary = game.meatspace_management.upgrade_hardware(&"DECK_RAM", 10)
	_expect(upgrade_result.success, "computer hardware is upgraded in meat space")
	var suspended_advance: Dictionary = game.advance_suspended_intrusion(10.0)
	_expect(suspended_advance.success and game.trace_level == trace_at_suspend + 5, "configured suspension policy preserves and increases trace")

	var expected_loadout: Array[StringName] = game.program_loadout.installed_instance_ids.duplicate()
	var resume: Dictionary = game.jack_back_in_through_doorstop()
	_expect(resume.success and game.player_network_position.current_node_id == NODE_02, "Jack Back In returns to NODE_02")
	_expect(game.intrusion_session.lifecycle == IntrusionSession.Lifecycle.ACTIVE, "intrusion returns to ACTIVE")
	_expect(game.player_knowledge.knows_node(NODE_03), "discovered NODE_03 persists")
	_expect(game.trace_level == trace_at_suspend + 5, "trace follows the configured Doorstop rules")
	_expect(alarm.state == PhysicalAlarmInstance.State.TRIGGERED, "alarm state persists")
	_expect(not ice.operational, "disabled ICE remains disabled under the configured policy")
	_expect(int(game.resource_state.volatile_resources.get(&"E2E_LOOT", 0)) == 1, "acquired loot persists without duplication")
	_expect(game.intrusion_session.applied_loadout_instance_ids == expected_loadout and expected_loadout.has(UTILITY_PROGRAM), "new meat-space loadout is applied")
	_expect(not old_anchor.active and game.doorstop_controller.get_anchor(game.intrusion_run_id) == null, "consumed return anchor is destroyed")
	_expect(not game.program_inventory.has_instance(DOORSTOP_A), "Doorstop A is not restored")
	_expect(game.program_inventory.has_instance(DOORSTOP_B) and game.program_inventory.has_instance(DOORSTOP_C), "Doorstops B and C still exist")

	var second_resume: Dictionary = game.jack_back_in_through_doorstop()
	_expect(not second_resume.success, "a second Jack Back In through the old anchor fails cleanly")
	var deploy_b: ActionResult = game.request_doorstop_deployment(DOORSTOP_B)
	var new_anchor: DoorstopAnchor = game.doorstop_controller.get_anchor(game.intrusion_run_id)
	_expect(deploy_b.success and new_anchor != null and new_anchor != old_anchor, "Doorstop B creates a new independent anchor")
	_expect(new_anchor.source_program_instance_id == DOORSTOP_B and new_anchor.cyberspace_node_id == NODE_02, "new anchor records Doorstop B and current node")
	_expect(game.program_inventory.has_instance(DOORSTOP_C), "deploying B leaves Doorstop C untouched")


func _traverse(destination: StringName) -> bool:
	var origin: StringName = game.player_network_position.current_node_id
	var result: Dictionary = game.network_graph.apply_traversal(game.player_network_position, destination)
	if result.error == NetworkGraph.TraversalError.OK:
		game.player_knowledge.observe_traversal(game.network_graph, origin, destination)
		return true
	return false


func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
