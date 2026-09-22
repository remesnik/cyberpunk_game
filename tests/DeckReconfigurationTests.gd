extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void:
	var clock := RealtimeWorldClock.new()
	root.add_child(clock)
	clock.start()
	var inventory := ProgramInventory.new()
	inventory.storage_capacity = 20
	var loadout := ProgramLoadout.new(1)
	loadout.memory_capacity = 5
	var utility := ProgramInstance.new(&"UTILITY", ExploitUtilityCatalog.definition(&"LOCKJAW_P"))
	var active_a := _active(&"ACTIVE_A", 2)
	var active_b := _active(&"ACTIVE_B", 3)
	inventory.add_instance(utility); inventory.add_instance(active_a); inventory.add_instance(active_b)
	var profile := DeckResourceProfile.new()
	profile.install_utility_seconds = 4.0
	profile.uninstall_utility_seconds = 2.0
	profile.start_active_program_seconds = 3.0
	profile.stop_active_program_seconds = 1.0
	profile.swap_active_program_seconds = 5.0
	var manager := DeckReconfigurationManager.new()
	manager.configure(inventory, loadout, clock, profile, func() -> Dictionary: return {&"DECK_CPU": 1})

	var result := manager.request(DeckReconfigurationManager.Operation.INSTALL_UTILITY, &"UTILITY")
	_expect(result.success and not loadout.is_installed(&"UTILITY"), "utility installation is not immediate")
	clock.restore(2.0)
	_expect(not loadout.is_installed(&"UTILITY") and is_equal_approx(float(manager.view().progress), 0.5), "installation reports real-time progress")
	clock.restore(4.0)
	_expect(loadout.is_installed(&"UTILITY"), "utility installs when real-time duration completes")

	result = manager.request(DeckReconfigurationManager.Operation.START_ACTIVE, &"ACTIVE_A")
	_expect(result.success and not loadout.is_installed(&"ACTIVE_A"), "active program start is delayed")
	clock.restore(7.0)
	_expect(loadout.is_installed(&"ACTIVE_A") and loadout.active_slots_used() == 1, "active program starts after its duration")
	result = manager.request(DeckReconfigurationManager.Operation.START_ACTIVE, &"ACTIVE_B")
	_expect(not result.success and result.reason == "NO ACTIVE SLOT AVAILABLE", "active slot constraint is checked before scheduling")

	result = manager.request(DeckReconfigurationManager.Operation.SWAP_ACTIVE, &"ACTIVE_A", &"ACTIVE_B")
	_expect(result.success and loadout.is_installed(&"ACTIVE_A"), "swap leaves the running program active while progressing")
	clock.restore(12.0)
	_expect(not loadout.is_installed(&"ACTIVE_A") and loadout.is_installed(&"ACTIVE_B"), "swap commits atomically after real time")

	manager.debug_instant_override = true
	result = manager.request(DeckReconfigurationManager.Operation.STOP_ACTIVE, &"ACTIVE_B")
	_expect(result.success and not loadout.is_installed(&"ACTIVE_B"), "debug override permits instant reconfiguration")

	print("%s: %d deck reconfiguration assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _active(id: StringName, memory: int) -> ProgramInstance:
	var definition := ProgramDefinition.new(id, String(id))
	definition.memory_cost = memory
	definition.storage_cost = 1
	definition.consumes_active_slot = true
	return ProgramInstance.new(id, definition)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
