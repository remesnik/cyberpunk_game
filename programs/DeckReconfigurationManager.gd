class_name DeckReconfigurationManager
extends RefCounted

signal operation_started(view: Dictionary)
signal operation_progressed(view: Dictionary)
signal operation_completed(view: Dictionary)

enum Operation { INSTALL_UTILITY, UNINSTALL_UTILITY, START_ACTIVE, STOP_ACTIVE, SWAP_ACTIVE }

var inventory: ProgramInventory
var loadout: ProgramLoadout
var clock: RealtimeWorldClock
var profile: DeckResourceProfile
var hardware_provider: Callable
var debug_instant_override := false
var active_operation: Dictionary = {}
var _serial := 0

func configure(p_inventory: ProgramInventory, p_loadout: ProgramLoadout, p_clock: RealtimeWorldClock, p_profile: DeckResourceProfile, p_hardware_provider: Callable = Callable()) -> void:
	inventory = p_inventory
	loadout = p_loadout
	clock = p_clock
	profile = p_profile
	hardware_provider = p_hardware_provider
	if clock != null and not clock.elapsed_time_changed.is_connected(_on_time_changed): clock.elapsed_time_changed.connect(_on_time_changed)

func request(operation: Operation, instance_id: StringName, replacement_id: StringName = &"", preferred_slot: int = -1) -> Dictionary:
	if not active_operation.is_empty(): return _failure("DECK RECONFIGURATION ALREADY IN PROGRESS")
	var validation := _validate(operation, instance_id, replacement_id, preferred_slot)
	if not validation.success: return validation
	_serial += 1
	var duration := 0.0 if debug_instant_override else _duration(operation)
	var now := clock.elapsed_seconds if clock != null else 0.0
	active_operation = {"id": StringName("DECK_RECONFIG_%06d" % _serial), "operation": operation, "operation_name": Operation.keys()[operation], "instance_id": instance_id, "replacement_id": replacement_id, "preferred_slot": preferred_slot, "started_at": now, "duration": duration, "progress": 0.0, "state": &"IN_PROGRESS"}
	operation_started.emit(view())
	if duration <= 0.0: _complete()
	return {"success": true, "reason": "DECK RECONFIGURATION STARTED", "operation": view()}

func view() -> Dictionary:
	if active_operation.is_empty(): return {}
	var result := active_operation.duplicate(true)
	var now := clock.elapsed_seconds if clock != null else float(result.started_at)
	var duration := float(result.duration)
	result["elapsed"] = clampf(now - float(result.started_at), 0.0, duration)
	result["progress"] = 1.0 if duration <= 0.0 else clampf(float(result.elapsed) / duration, 0.0, 1.0)
	result["remaining"] = maxf(0.0, duration - float(result.elapsed))
	return result

func _on_time_changed(_now: float) -> void:
	if active_operation.is_empty(): return
	var current := view()
	active_operation["progress"] = current.progress
	operation_progressed.emit(current)
	if current.progress >= 1.0: _complete()

func _complete() -> void:
	if active_operation.is_empty(): return
	var operation := int(active_operation.operation) as Operation
	var instance_id := StringName(active_operation.instance_id)
	var replacement_id := StringName(active_operation.replacement_id)
	var success := false
	match operation:
		Operation.INSTALL_UTILITY: success = loadout.install(instance_id, inventory)
		Operation.START_ACTIVE:
			var preferred_slot := int(active_operation.get("preferred_slot", -1))
			success = loadout.install_at(preferred_slot, instance_id, inventory) if preferred_slot >= 0 else loadout.install(instance_id, inventory)
		Operation.UNINSTALL_UTILITY, Operation.STOP_ACTIVE: success = loadout.uninstall(instance_id)
		Operation.SWAP_ACTIVE:
			var slot := loadout.active_slots.find(instance_id)
			if slot >= 0:
				loadout.uninstall(instance_id)
				success = loadout.install_at(slot, replacement_id, inventory)
				if not success: loadout.install_at(slot, instance_id, inventory)
	var completed := active_operation.duplicate(true)
	completed["state"] = &"COMPLETED" if success else &"FAILED"
	completed["progress"] = 1.0
	active_operation.clear()
	operation_completed.emit(completed)

func _validate(operation: Operation, instance_id: StringName, replacement_id: StringName, preferred_slot: int = -1) -> Dictionary:
	if inventory == null or loadout == null: return _failure("DECK UNAVAILABLE")
	var instance := inventory.get_instance(instance_id)
	match operation:
		Operation.INSTALL_UTILITY:
			if instance == null or not instance.definition.is_passive_utility(): return _failure("PASSIVE UTILITY REQUIRED")
			if loadout.is_installed(instance_id): return _failure("UTILITY ALREADY INSTALLED")
			if loadout.memory_capacity >= 0 and loadout.memory_used(inventory) + instance.definition.memory_cost > loadout.memory_capacity: return _failure("INSUFFICIENT MEMORY")
		Operation.UNINSTALL_UTILITY:
			if instance == null or not instance.definition.is_passive_utility() or not loadout.is_installed(instance_id): return _failure("UTILITY IS NOT INSTALLED")
		Operation.START_ACTIVE:
			if instance == null or instance.definition.is_passive_utility(): return _failure("ACTIVE PROGRAM REQUIRED")
			if preferred_slot >= 0 and (preferred_slot >= loadout.capacity or not loadout.instance_at(preferred_slot).is_empty()): return _failure("ACTIVE SLOT UNAVAILABLE")
			if loadout.active_slots_used() >= loadout.capacity: return _failure("NO ACTIVE SLOT AVAILABLE")
			if loadout.memory_capacity >= 0 and loadout.memory_used(inventory) + instance.definition.memory_cost > loadout.memory_capacity: return _failure("INSUFFICIENT MEMORY")
		Operation.STOP_ACTIVE:
			if instance == null or instance.definition.is_passive_utility() or not loadout.is_installed(instance_id): return _failure("ACTIVE PROGRAM IS NOT RUNNING")
		Operation.SWAP_ACTIVE:
			var replacement := inventory.get_instance(replacement_id)
			if instance == null or instance.definition.is_passive_utility() or not loadout.is_installed(instance_id): return _failure("ACTIVE PROGRAM IS NOT RUNNING")
			if replacement == null or replacement.definition.is_passive_utility() or loadout.is_installed(replacement_id): return _failure("REPLACEMENT ACTIVE PROGRAM REQUIRED")
			var projected := loadout.memory_used(inventory) - instance.definition.memory_cost + replacement.definition.memory_cost
			if loadout.memory_capacity >= 0 and projected > loadout.memory_capacity: return _failure("INSUFFICIENT MEMORY")
	return {"success": true, "reason": "RECONFIGURATION VALID"}

func _duration(operation: Operation) -> float:
	var cpu_level := 1
	if hardware_provider.is_valid(): cpu_level = int(hardware_provider.call().get(&"DECK_CPU", 1))
	var base := profile.install_utility_seconds
	match operation:
		Operation.UNINSTALL_UTILITY: base = profile.uninstall_utility_seconds
		Operation.START_ACTIVE: base = profile.start_active_program_seconds
		Operation.STOP_ACTIVE: base = profile.stop_active_program_seconds
		Operation.SWAP_ACTIVE: base = profile.swap_active_program_seconds
	return profile.reconfiguration_duration(base, cpu_level)

func _failure(reason: String) -> Dictionary:
	return {"success": false, "reason": reason}
