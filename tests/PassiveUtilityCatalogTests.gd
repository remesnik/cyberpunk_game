extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void:
	var definitions := PassiveUtilityCatalog.all()
	_expect(definitions.size() == 11, "catalog contains seven general and four exploit utilities")
	for definition: PassiveUtilityDefinition in definitions:
		_expect(definition != null and not definition.display_name.is_empty() and definition.utility_rating > 0, "%s has a name and numerical rating" % definition.id)
		_expect(definition.memory_cost > 0 and definition.storage_cost > 0 and definition.is_passive_utility(), "%s consumes Memory and Storage but no Active Slot" % definition.id)
		_expect(not definition.supported_operations.is_empty() and not definition.supported_services.is_empty(), "%s declares supported operations and services" % definition.id)

	_expect(PassiveUtilityCatalog.definition(&"CRYPT").supports_operation(&"DOWNLOAD") and PassiveUtilityCatalog.definition(&"CRYPT").supports_service(&"ENCRYPTED_DATA"), "Crypt enables protected data operations")
	_expect(PassiveUtilityCatalog.definition(&"CULTERLY").supports_service(&"PHYSICAL_CONTROL"), "Culterly supports physical I/O")
	_expect(PassiveUtilityCatalog.definition(&"HERMES").supports_operation(&"INTERCEPT"), "Hermes supports communications")
	_expect(PassiveUtilityCatalog.definition(&"TAMTAMA").supports_operation(&"SEARCH"), "Tamtama supports paydata searches")
	_expect(PassiveUtilityCatalog.definition(&"DISINF3CT").supports_service(&"MALWARE"), "disinf3ct supports malware defense")
	_expect(PassiveUtilityCatalog.definition(&"HYPERPIPER").supports_operation(&"REQUEST"), "HyperPiper enables Sleeve modification attempts")
	_expect(PassiveUtilityCatalog.definition(&"SHAKESPEARE").supports_operation(&"FORGE"), "Shakespeare supports logfile forging")

	var lockjaw_o := PassiveUtilityCatalog.definition(&"LOCKJAW_O")
	var lockjaw_p := PassiveUtilityCatalog.definition(&"LOCKJAW_P")
	_expect(lockjaw_o.utility_rating == lockjaw_p.utility_rating and lockjaw_o.memory_cost == lockjaw_p.memory_cost and lockjaw_o.exploit_security_family != lockjaw_p.exploit_security_family, "Lockjaw variants differ mechanically only by security family")
	var inventory := ProgramInventory.new(); inventory.storage_capacity = 20
	var loadout := ProgramLoadout.new(1); loadout.memory_capacity = 20
	var crypt := ProgramInstance.new(&"CRYPT_INSTANCE", PassiveUtilityCatalog.definition(&"CRYPT"))
	inventory.add_instance(crypt); loadout.install(crypt.instance_id, inventory)
	_expect(loadout.supporting_utilities(inventory, &"DECRYPT").has(crypt), "installed utility behavior is discovered from resource tags")

	print("%s: %d passive utility catalog assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
