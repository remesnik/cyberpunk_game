extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void:
	var inventory := ProgramInventory.new()
	inventory.storage_capacity = 8
	var loadout := ProgramLoadout.new(2)
	loadout.memory_capacity = 8
	for id: StringName in ExploitUtilityCatalog.IDS:
		_expect(inventory.add_instance(ProgramInstance.new(StringName("%s_INSTANCE" % id), ExploitUtilityCatalog.definition(id))), "%s fits in deck storage" % id)
	_expect(inventory.storage_used() == 4 and loadout.memory_used(inventory) == 0 and loadout.active_slots_used() == 0, "stored utilities consume only Storage")
	for id: StringName in ExploitUtilityCatalog.IDS:
		_expect(loadout.install(StringName("%s_INSTANCE" % id), inventory), "%s installs when Memory is available" % id)
	_expect(loadout.memory_used(inventory) == 8 and loadout.active_slots_used() == 0, "four passive exploit utilities severely consume Memory without Active Slots")

	var extra_utility := ExploitUtilityCatalog.definition(&"LOCKJAW_O")
	inventory.storage_capacity = 4
	_expect(not inventory.add_instance(ProgramInstance.new(&"EXTRA", extra_utility)), "Storage capacity rejects additional software")
	loadout.uninstall(&"SIDECAR_P_INSTANCE")
	var active_a := ProgramDefinition.new(&"ACTIVE_A", "Active A")
	active_a.memory_cost = 2
	active_a.storage_cost = 1
	active_a.consumes_active_slot = true
	inventory.storage_capacity = 10
	_expect(inventory.add_instance(ProgramInstance.new(&"ACTIVE_A_INSTANCE", active_a)), "active program can be carried in Storage")
	_expect(loadout.install(&"ACTIVE_A_INSTANCE", inventory), "active program launches with Memory and a slot")
	var active_b := ProgramDefinition.new(&"ACTIVE_B", "Active B")
	active_b.memory_cost = 1
	active_b.consumes_active_slot = true
	_expect(inventory.add_instance(ProgramInstance.new(&"ACTIVE_B_INSTANCE", active_b)), "second active program can be stored")
	_expect(not loadout.install(&"ACTIVE_B_INSTANCE", inventory), "active launch fails when Memory is exhausted")
	loadout.memory_capacity = 12
	_expect(loadout.install(&"ACTIVE_B_INSTANCE", inventory), "second active program launches after Memory becomes available")
	var active_c := ProgramDefinition.new(&"ACTIVE_C", "Active C")
	active_c.memory_cost = 1
	active_c.consumes_active_slot = true
	inventory.storage_capacity = 12
	_expect(inventory.add_instance(ProgramInstance.new(&"ACTIVE_C_INSTANCE", active_c)), "third active program can be stored")
	var no_slot := loadout.install_result(&"ACTIVE_C_INSTANCE", inventory)
	_expect(not no_slot.success and no_slot.reason == "NO ACTIVE SLOT AVAILABLE", "active launch fails when no Active Slot is available")
	print("%s: %d deck resource-model assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
