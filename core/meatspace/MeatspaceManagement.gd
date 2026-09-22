class_name MeatspaceManagement
extends RefCounted

var program_inventory: ProgramInventory
var program_loadout: ProgramLoadout
var equipment_orders: EquipmentOrderManager
var realtime_clock: RealtimeWorldClock
signal hardware_changed(component_id: StringName, level: int)
var hardware_levels: Dictionary = {&"DECK_CPU": 1, &"DECK_RAM": 1, &"DECK_STORAGE": 1, &"DECK_SENSORS": 1}
var story_interactions: Array[Dictionary] = []
var software_programming: SoftwareProgrammingManager
var deck_reconfiguration: DeckReconfigurationManager
signal loadout_changed
var programming_tasks: Dictionary:
	get: return software_programming.tasks if software_programming != null else {}


func configure(inventory: ProgramInventory, loadout: ProgramLoadout, orders: EquipmentOrderManager, clock: RealtimeWorldClock) -> void:
	program_inventory = inventory
	program_loadout = loadout
	equipment_orders = orders
	realtime_clock = clock
	software_programming = SoftwareProgrammingManager.new()
	software_programming.configure(program_inventory, realtime_clock)
	deck_reconfiguration = DeckReconfigurationManager.new()
	var profile := load("res://data/deck_resource_profile.tres") as DeckResourceProfile
	deck_reconfiguration.configure(program_inventory, program_loadout, realtime_clock, profile, func() -> Dictionary: return hardware_levels)
	deck_reconfiguration.operation_completed.connect(func(_view: Dictionary) -> void: loadout_changed.emit())


func upgrade_hardware(component_id: StringName, credit_cost: int) -> Dictionary:
	if not hardware_levels.has(component_id):
		return _failure("Unknown deck component.")
	if equipment_orders == null or credit_cost < 0 or equipment_orders.credits < credit_cost:
		return _failure("Insufficient fictional credits.")
	equipment_orders.credits -= credit_cost
	hardware_levels[component_id] = int(hardware_levels[component_id]) + 1
	hardware_changed.emit(component_id, int(hardware_levels[component_id]))
	return {"success": true, "reason": "Hardware upgraded.", "level": hardware_levels[component_id]}


func inspect_deck() -> Dictionary:
	if program_inventory == null or program_loadout == null:
		return _failure("Deck state is unavailable.")
	var owned: Array[Dictionary] = []
	for instance: ProgramInstance in program_inventory.all_instances():
		owned.append({
			"instance_id": instance.instance_id,
			"definition_id": instance.definition_id(),
			"display_name": instance.definition.display_name,
			"version": instance.definition.version,
			"installed": program_loadout.is_installed(instance.instance_id),
			"memory_cost": instance.definition.memory_cost,
			"storage_cost": instance.definition.storage_cost,
			"consumes_active_slot": instance.definition.consumes_active_slot,
		})
	owned.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.instance_id) < String(b.instance_id))
	return {
		"success": true,
		"reason": "Deck inspected.",
		"hardware_levels": hardware_levels.duplicate(true),
		"capacity": program_loadout.capacity,
		"active_slots_used": program_loadout.active_slots_used(),
		"memory_used": program_loadout.memory_used(program_inventory),
		"memory_capacity": program_loadout.memory_capacity,
		"storage_used": program_inventory.storage_used(),
		"storage_capacity": program_inventory.storage_capacity,
		"installed_instance_ids": program_loadout.installed_instance_ids.duplicate(),
		"owned_programs": owned,
	}


func install_program(instance_id: StringName) -> Dictionary:
	var instance := program_inventory.get_instance(instance_id)
	if instance == null: return _failure("PROGRAM NOT IN STORAGE")
	var operation := DeckReconfigurationManager.Operation.INSTALL_UTILITY if instance.definition.is_passive_utility() else DeckReconfigurationManager.Operation.START_ACTIVE
	return deck_reconfiguration.request(operation, instance_id)


func remove_program(instance_id: StringName) -> Dictionary:
	var instance := program_inventory.get_instance(instance_id)
	if instance == null or not program_loadout.is_installed(instance_id): return _failure("Program is not installed.")
	var operation := DeckReconfigurationManager.Operation.UNINSTALL_UTILITY if instance.definition.is_passive_utility() else DeckReconfigurationManager.Operation.STOP_ACTIVE
	return deck_reconfiguration.request(operation, instance_id)

func swap_active_program(running_instance_id: StringName, stored_instance_id: StringName) -> Dictionary:
	return deck_reconfiguration.request(DeckReconfigurationManager.Operation.SWAP_ACTIVE, running_instance_id, stored_instance_id)

func start_active_program_in_slot(instance_id: StringName, slot_index: int) -> Dictionary:
	return deck_reconfiguration.request(DeckReconfigurationManager.Operation.START_ACTIVE, instance_id, &"", slot_index)


func order_equipment(equipment_id: StringName, vendor_id: StringName, quantity: int, destination: StringName) -> Dictionary:
	if equipment_orders == null:
		return _failure("Equipment ordering is unavailable.")
	var order := equipment_orders.create_cart(equipment_id, vendor_id, quantity, destination)
	if order == null:
		return _failure("Vendor cannot fulfill that order.")
	return equipment_orders.place_order(order.id)


func start_programming(task_id: StringName, definition: ProgramDefinition, duration: float = -1.0) -> Dictionary:
	return software_programming.start_task(task_id, definition, duration)


func collect_programming(task_id: StringName) -> Dictionary:
	return software_programming.collect(task_id)


func update_tasks() -> void:
	software_programming.update()

func deck_reconfiguration_view() -> Dictionary:
	return deck_reconfiguration.view() if deck_reconfiguration != null else {}


func grant_program_reward(definition: ProgramDefinition, source_id: StringName = &"") -> Dictionary:
	return software_programming.grant_loot(definition, source_id)


func perform_story_interaction(interaction_id: StringName, choice_id: StringName = &"") -> Dictionary:
	if interaction_id.is_empty():
		return _failure("Story interaction is invalid.")
	var event := {"interaction_id": interaction_id, "choice_id": choice_id, "realtime": realtime_clock.elapsed_seconds if realtime_clock != null else 0.0}
	story_interactions.append(event)
	return {"success": true, "reason": "Meat-space interaction recorded.", "event": event}


func _failure(reason: String) -> Dictionary:
	return {"success": false, "reason": reason}
