extends SceneTree

var failures := 0
var assertions := 0


func _init() -> void:
	_test_burns_only_activated_instance()
	_test_variants_and_unique_ids_remain_distinct()
	_test_rejects_unowned_and_non_doorstop_instances()
	print("%s: %d Doorstop assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)


func _test_burns_only_activated_instance() -> void:
	var definition := _doorstop(&"DOORSTOP_V1", "1.0")
	var inventory := ProgramInventory.new()
	var loadout := ProgramLoadout.new(4)
	var first := ProgramInstance.new(&"PROGRAM_INSTANCE_001", definition)
	var second := ProgramInstance.new(&"PROGRAM_INSTANCE_002", definition)
	_expect(inventory.add_instance(first) and inventory.add_instance(second), "copies with unique instance IDs can coexist")
	_expect(loadout.install(first.instance_id, inventory) and loadout.install(second.instance_id, inventory), "individual copies can be installed")
	var controller := _controller(inventory, loadout, &"RUN_01", &"ENTRY")
	var result := controller.deploy(first.instance_id, &"RUN_01", &"AUTH_SERVER", 17.0, {"trace": 12}, _valid_context(&"AUTH_SERVER"))
	_expect(result.success, "installed Doorstop deploys")
	_expect(not inventory.has_instance(first.instance_id) and not loadout.is_installed(first.instance_id), "activated instance is removed from inventory and loadout")
	_expect(inventory.has_instance(second.instance_id) and loadout.is_installed(second.instance_id), "another copy remains owned and installed")
	var anchor := controller.get_anchor(&"RUN_01")
	_expect(anchor != null and anchor.source_program_instance_id == first.instance_id, "anchor retains the exact burned source instance ID")
	_expect(anchor.cyberspace_node_id == &"AUTH_SERVER" and anchor.resume_data.trace == 12, "anchor retains node and resume state")


func _test_variants_and_unique_ids_remain_distinct() -> void:
	var v1 := _doorstop(&"DOORSTOP_V1", "1.0")
	var v2 := _doorstop(&"DOORSTOP_GHOST", "2.3")
	v2.rarity = &"RARE"
	var inventory := ProgramInventory.new()
	var loadout := ProgramLoadout.new(3)
	var old_copy := ProgramInstance.new(&"DS_OLD_7", v1)
	var new_copy := ProgramInstance.new(&"DS_GHOST_3", v2)
	inventory.add_instance(old_copy)
	inventory.add_instance(new_copy)
	loadout.install(new_copy.instance_id, inventory)
	var result := _controller(inventory, loadout, &"RUN_02", &"ENTRY").deploy(new_copy.instance_id, &"RUN_02", &"FILE_SERVER", 3.5, {}, _valid_context(&"FILE_SERVER"))
	_expect(result.success and inventory.has_instance(old_copy.instance_id), "burning one version leaves another version untouched")
	_expect(not inventory.has_instance(new_copy.instance_id), "the selected variant instance alone is burned")
	_expect(not inventory.add_instance(ProgramInstance.new(old_copy.instance_id, v2)), "duplicate physical instance IDs are rejected")


func _test_rejects_unowned_and_non_doorstop_instances() -> void:
	var inventory := ProgramInventory.new()
	var loadout := ProgramLoadout.new()
	var ordinary := ProgramInstance.new(&"SCANNER_01", ProgramDefinition.new(&"SCANNER", "Scanner", "1.0"))
	inventory.add_instance(ordinary)
	loadout.install(ordinary.instance_id, inventory)
	var controller := _controller(inventory, loadout, &"RUN", &"ENTRY")
	_expect(not controller.deploy(&"MISSING", &"RUN", &"NODE", 0.0, {}, _valid_context(&"NODE")).success, "an unowned instance cannot deploy")
	_expect(not controller.deploy(ordinary.instance_id, &"RUN", &"NODE", 0.0, {}, _valid_context(&"NODE")).success, "a non-Doorstop program cannot deploy")
	_expect(inventory.has_instance(ordinary.instance_id), "failed deployment never consumes an instance")


func _doorstop(id: StringName, version: String) -> DoorstopDefinition:
	var definition := DoorstopDefinition.new(id, "Doorstop %s" % version, version)
	definition.programming_recipe = {&"MEMORY_SHARD": 2}
	definition.programming_requirements = {&"capability": &"ROOTKIT"}
	definition.programming_duration = 4.0
	definition.destroy_anchor_on_return = true
	return definition


func _valid_context(node_id: StringName) -> Dictionary:
	return {"node_id": node_id, "node_is_valid": true, "node_transition_unresolved": false, "modal_action_unresolved": false, "jack_out_prohibited": false}

func _controller(inventory: ProgramInventory, loadout: ProgramLoadout, run_id: StringName, host_node_id: StringName) -> DoorstopController:
	var manager := SystemAccessNodeManager.new()
	manager.create_san(&"PLAYER", run_id, &"DECK", host_node_id)
	var controller := DoorstopController.new(inventory, loadout)
	controller.configure_system_access_node(manager, &"PLAYER")
	return controller


func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
