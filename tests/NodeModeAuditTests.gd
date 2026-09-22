extends SceneTree

const NodeModeSnapshot := preload("res://debug/NodeModeDebugSnapshot.gd")

var failures := 0
var assertions := 0

func _init() -> void:
	var lock_o := ExploitUtilityCatalog.definition(&"LOCKJAW_O")
	var lock_p := ExploitUtilityCatalog.definition(&"LOCKJAW_P")
	var side_o := ExploitUtilityCatalog.definition(&"SIDECAR_O")
	var side_p := ExploitUtilityCatalog.definition(&"SIDECAR_P")
	_expect(lock_o.utility_rating == lock_p.utility_rating and lock_o.memory_cost == lock_p.memory_cost and lock_o.strong_network_types == lock_p.strong_network_types, "Orange/Purple Lockjaw definitions are palette-equivalent")
	_expect(side_o.utility_rating == side_p.utility_rating and side_o.memory_cost == side_p.memory_cost and side_o.strong_network_types == side_p.strong_network_types, "Orange/Purple Sidecar definitions are palette-equivalent")
	var orange_route := _node(&"ORANGE_ROUTE", &"ROUTING", NetworkNodeDefinition.SecurityFamily.ORANGE, 4)
	var purple_data := _node(&"PURPLE_DATA", &"DATASTORE", NetworkNodeDefinition.SecurityFamily.PURPLE, 4)
	_expect(lock_o.network_affinity_label(orange_route) == &"STRONG" and lock_o.effective_exploit_rating(orange_route) == lock_o.utility_rating, "Orange Lockjaw is strong on Orange Routing")
	_expect(side_o.network_affinity_label(orange_route) == &"NEUTRAL" and side_o.effective_exploit_rating(orange_route) < side_o.utility_rating + 1, "Orange Sidecar is neutral on Orange Routing")
	_expect(lock_p.network_affinity_label(purple_data) == &"NEUTRAL" and lock_p.effective_exploit_rating(purple_data) == 1, "Purple Lockjaw is neutral on Purple Datastore")
	_expect(side_p.network_affinity_label(purple_data) == &"STRONG" and side_p.effective_exploit_rating(purple_data) == side_p.utility_rating, "Purple Sidecar is strong on Purple Datastore")
	_expect(lock_o.effective_exploit_rating(purple_data) == 0, "family mismatch provides no exploit contribution")
	var security := _node(&"SEC", &"SECURITY", NetworkNodeDefinition.SecurityFamily.ORANGE, 3)
	var admin := _node(&"ADMIN", &"SYSTEM_ADMINISTRATION", NetworkNodeDefinition.SecurityFamily.ORANGE, 3)
	_expect(lock_o.network_affinity_label(security) == &"NEUTRAL" and side_o.network_affinity_label(security) == &"NEUTRAL", "Security nodes give both exploit models neutral affinity")
	_expect(lock_o.network_affinity_label(admin) == &"WEAK" and side_o.network_affinity_label(admin) == &"WEAK", "System/Admin nodes give both exploit models weak affinity")

	var inventory := ProgramInventory.new(); inventory.storage_capacity = 8
	var loadout := ProgramLoadout.new(2); loadout.memory_capacity = 8
	for definition in [lock_o, side_o, lock_p, side_p]: inventory.add_instance(ProgramInstance.new(definition.id, definition))
	_expect(inventory.storage_used() == 4 and loadout.memory_used(inventory) == 0, "all four suites can be carried using Storage only")
	for id in [&"LOCKJAW_O", &"SIDECAR_O", &"LOCKJAW_P", &"SIDECAR_P"]: loadout.install(id, inventory)
	_expect(loadout.memory_used(inventory) == 8 and loadout.active_slots_used() == 0, "installing all four consumes severe Memory but no Active Slots")
	var sleeze := ProgramInstance.new(&"SLEEZE", ActiveBypassProgramCatalog.definition(&"SLEEZE")); inventory.add_instance(sleeze)
	var manager := DeckReconfigurationManager.new(); manager.configure(inventory, loadout, null, DeckResourceProfile.new())
	_expect(manager.request(DeckReconfigurationManager.Operation.START_ACTIVE, &"SLEEZE").reason == "INSUFFICIENT MEMORY", "Sleeze cannot start with insufficient Memory")
	for id in [&"LOCKJAW_O", &"SIDECAR_O", &"LOCKJAW_P", &"SIDECAR_P"]: loadout.uninstall(id)
	loadout.capacity = 0; loadout.active_slots.clear()
	_expect(manager.request(DeckReconfigurationManager.Operation.START_ACTIVE, &"SLEEZE").reason == "NO ACTIVE SLOT AVAILABLE", "Sleeze cannot start without an Active Slot")

	var profile := BypassProfile.new(); profile.defense_roll_min = 0; profile.defense_roll_max = 2
	var resolver := BypassResolver.new(profile)
	var quiet := resolver.resolve(orange_route, 4, ProgramInstance.new(&"LOCK", lock_o), true, {}, 1)
	_expect(quiet.success and not quiet.noisy, "successful compatible exploit bypass is quiet")
	var failed := resolver.resolve(orange_route, 0, ProgramInstance.new(&"LOCK", lock_o), true, {}, 2)
	_expect(not failed.success and failed.noisy and not failed.generated_security_event.is_empty(), "failed quiet bypass becomes noisy and generates an event")
	var bare := resolver.resolve(orange_route, 6, null, false, {}, 0)
	_expect(bare.success and bare.noisy, "successful bare bypass remains noisy")

	var graph := NetworkGraph.new(); graph.add_node(orange_route)
	var sleeve := SecuritySleeve.new(&"SLEEVE", "Sleeve", [&"ORANGE_ROUTE"]); graph.add_security_sleeve(sleeve)
	var ice := IceController.new(graph, PlayerNetworkPosition.new(&"ORANGE_ROUTE", 20), PlayerKnowledge.new())
	var local_def := IceDefinition.new(&"WARDEN", "Warden", 2, 999999); local_def.binding_mode = IceDefinition.BindingMode.HOST_BOUND
	var local := IceInstance.new(&"WARDEN", local_def, &"ORANGE_ROUTE"); ice.add_ice(local)
	var response := SecurityResponseController.new(graph, ice, load("res://data/security_escalation_profile.tres"))
	orange_route.report_security_event(SecurityEvent.new(&"ORANGE_ROUTE", &"NOISY_ACTION", 2, &"BYPASS", &"PLAYER", &"SESSION", [&"NOISY"], 1).to_dict())
	_expect(sleeve.security_count == 2, "node security event reaches its Security Sleeve")
	_expect(local.state == IceState.Value.ENGAGE and local.current_node_id == &"ORANGE_ROUTE", "stationary ICE owns the local defensive response")
	var snapshot: Dictionary = NodeModeSnapshot.capture(inventory, loadout, orange_route, failed, graph)
	_expect(snapshot.has("affinity") and snapshot.has("bypass") and snapshot.has("security_event") and snapshot.sleeves[0].security_count == 2, "debug snapshot exposes deck, affinity, bypass, event, and Sleeve state")

	var authored := load("res://data/authoring/first_contact_current.tres") as CyberspaceContentDocument
	var authored_graph := AuthoredNetworkRuntimeBuilder.build_graph(authored)
	authored_graph.apply_node_interaction(&"CONTROL", &"service_disabled", {"service_id": &"ROUTE_CONTROL"})
	var gate := authored_graph.can_traverse(&"SECURITY", &"DATA")
	_expect(not gate.allowed and gate.reason_code == &"HARD_SECURITY_BLOCKING", "Warden remains a hard gate until locally resolved")

	print("%s: %d Node Mode audit assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _node(id: StringName, type: StringName, family: NetworkNodeDefinition.SecurityFamily, difficulty: int) -> NetworkNodeDefinition:
	var node := NetworkNodeDefinition.new(id, String(id), NetworkNodeDefinition.NodeType.SYSTEM, difficulty)
	node.network_type = type; node.security_family = family; node.difficulty_rating = difficulty
	return node

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition: failures += 1; printerr("FAILED: %s" % description)
