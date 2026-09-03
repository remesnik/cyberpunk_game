extends Node

const SANPlacementSafetyScript := preload("res://core/intrusion/SANPlacementSafety.gd")
const IceBindingProfileScript := preload("res://entities/ice/IceBindingProfile.gd")

var failures := 0
var assertions := 0

func _ready() -> void:
	_test_creation_without_ice()
	_test_host_bound_relocation_and_mixed_ice()
	_test_multiple_host_bound_ice()
	_test_suspension_and_restore()
	_test_doorstop_relocation()
	print("%s: %d SAN placement safety assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _test_creation_without_ice() -> void:
	var fixture := _fixture()
	var result: Dictionary = fixture.manager.create_san(&"PLAYER", &"RUN", &"DECK", &"A")
	_expect(result.success and result.san.host_node_id == &"A" and fixture.safety.suspended_host_bound_ice.is_empty(), "SAN creation with no ICE needs no adjustment")

func _test_host_bound_relocation_and_mixed_ice() -> void:
	var fixture := _fixture()
	var bound := _ice(&"BOUND", true, &"A"); var roaming := _ice(&"ROAMING", false, &"A")
	fixture.ice.add_ice(bound); fixture.ice.add_ice(roaming)
	var result: Dictionary = fixture.manager.create_san(&"PLAYER", &"RUN", &"DECK", &"A")
	_expect(result.success and bound.current_node_id == &"B" and bound.operational, "one host-bound ICE moves to a directly connected legal node before SAN creation")
	_expect(roaming.current_node_id == &"A" and roaming.operational, "roaming ICE is untouched by SAN placement")
	_expect(bound.integrity == bound.definition.maximum_integrity and bound.state == IceState.Value.PATROL, "behind-the-scenes relocation does not defeat or run normal movement against ICE")

func _test_multiple_host_bound_ice() -> void:
	var fixture := _fixture()
	for id in [&"BOUND_1", &"BOUND_2", &"BOUND_3"]: fixture.ice.add_ice(_ice(id, true, &"A"))
	fixture.manager.create_san(&"PLAYER", &"RUN", &"DECK", &"A")
	_expect(fixture.ice.instances.values().all(func(ice): return ice.current_node_id != &"A" and ice.operational), "several host-bound ICE are all preserved and removed from the SAN host")

func _test_suspension_and_restore() -> void:
	var fixture := _fixture()
	var bound := _ice(&"ISOLATED", true, &"A"); bound.definition.binding.allowed_node_ids.assign([&"A"])
	fixture.ice.add_ice(bound)
	fixture.manager.create_san(&"PLAYER", &"RUN", &"DECK", &"A")
	_expect(bound.placement_suspended and not bound.operational and bound.current_node_id.is_empty(), "host-bound ICE is stored rather than killed when no legal destination exists")
	bound.definition.binding.allowed_node_ids.assign([&"B"])
	var restored: Array[Dictionary] = fixture.safety.restore_suspended_when_possible(&"RUN")
	_expect(restored.size() == 1 and bound.current_node_id == &"B" and bound.operational and not bound.placement_suspended, "stored host-bound ICE returns when a valid location becomes available")

func _test_doorstop_relocation() -> void:
	var fixture := _fixture()
	var san: SystemAccessNode = fixture.manager.create_san(&"PLAYER", &"RUN", &"DECK", &"A").san
	var bound := _ice(&"DOORSTOP_BOUND", true, &"C"); bound.definition.binding.allowed_node_ids.assign([&"B"])
	fixture.ice.add_ice(bound)
	var inventory := ProgramInventory.new(); var loadout := ProgramLoadout.new()
	var definition := DoorstopDefinition.new(&"DOORSTOP", "Doorstop", "1.0")
	var instance := ProgramInstance.new(&"DOORSTOP_INSTANCE", definition); inventory.add_instance(instance); loadout.install(instance.instance_id, inventory)
	var doorstop := DoorstopController.new(inventory, loadout); doorstop.configure_system_access_node(fixture.manager, &"PLAYER")
	var result := doorstop.deploy(instance.instance_id, &"RUN", &"C", 1.0, {}, {"node_id": &"C", "node_is_valid": true})
	_expect(result.success and san.host_node_id == &"C" and bound.current_node_id == &"B", "Doorstop SAN relocation applies host-bound ICE safety before moving the existing SAN")
	_expect(fixture.manager.instances.size() == 1 and result.anchor.system_access_node_id == san.id, "safe Doorstop placement neither duplicates nor replaces the SAN")

func _fixture() -> Dictionary:
	var graph := NetworkGraph.new()
	for id in [&"A", &"B", &"C", &"D"]:
		var node := NetworkNodeDefinition.new(id, String(id), NetworkNodeDefinition.NodeType.ROUTER, 1, id != &"D", &"CORP")
		node.security_region_id = &"INNER" if id in [&"A", &"B", &"C"] else &"OUTER"; graph.add_node(node)
	graph.add_link(NetworkLinkDefinition.new(&"AB", &"A", &"B")); graph.add_link(NetworkLinkDefinition.new(&"BC", &"B", &"C")); graph.add_link(NetworkLinkDefinition.new(&"BD", &"B", &"D"))
	var position := PlayerNetworkPosition.new(&"A"); var ice := IceController.new(graph, position, PlayerKnowledge.new())
	var manager := SystemAccessNodeManager.new(); var safety: RefCounted = SANPlacementSafetyScript.new(graph, ice, position); manager.configure_placement_safety(safety)
	return {"graph": graph, "ice": ice, "manager": manager, "safety": safety}

func _ice(id: StringName, host_bound: bool, node_id: StringName) -> IceInstance:
	var definition := IceDefinition.new(StringName("%s_DEF" % id), String(id))
	definition.binding.mode = IceBindingProfileScript.Mode.HOST_BOUND if host_bound else IceBindingProfileScript.Mode.ROAMING
	return IceInstance.new(id, definition, node_id, IceState.Value.PATROL)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition: failures += 1; printerr("FAILED: %s" % description)
