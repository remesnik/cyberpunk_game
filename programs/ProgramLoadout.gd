class_name ProgramLoadout
extends RefCounted

var capacity := 4
var installed_instance_ids: Array[StringName] = []
var active_slots: Array[StringName] = []
var installed_utility_ids: Array[StringName] = []
var memory_capacity := -1


func _init(p_capacity := 4) -> void:
	capacity = maxi(0, p_capacity)
	active_slots.resize(capacity)
	for index in active_slots.size(): active_slots[index] = &""


func install(instance_id: StringName, inventory: ProgramInventory) -> bool:
	return bool(install_result(instance_id, inventory).success)

func install_result(instance_id: StringName, inventory: ProgramInventory) -> Dictionary:
	if instance_id.is_empty() or inventory == null or not inventory.has_instance(instance_id):
		return {"success": false, "reason": "PROGRAM NOT IN STORAGE"}
	if installed_instance_ids.has(instance_id):
		return {"success": true, "reason": "PROGRAM ALREADY INSTALLED"}
	var instance := inventory.get_instance(instance_id)
	if memory_capacity >= 0 and memory_used(inventory) + instance.definition.memory_cost > memory_capacity:
		return {"success": false, "reason": "INSUFFICIENT MEMORY"}
	if instance.definition.is_passive_utility():
		installed_utility_ids.append(instance_id)
		_rebuild_installed_ids()
		return {"success": true, "reason": "UTILITY INSTALLED"}
	for index in active_slots.size():
		if active_slots[index].is_empty():
			active_slots[index] = instance_id
			_rebuild_installed_ids()
			return {"success": true, "reason": "ACTIVE PROGRAM RUNNING", "slot": index}
	return {"success": false, "reason": "NO ACTIVE SLOT AVAILABLE"}


func install_at(slot_index: int, instance_id: StringName, inventory: ProgramInventory) -> bool:
	if slot_index < 0 or slot_index >= capacity or instance_id.is_empty() or inventory == null:
		return false
	if not inventory.has_instance(instance_id) or installed_instance_ids.has(instance_id):
		return false
	var instance := inventory.get_instance(instance_id)
	if instance.definition.is_passive_utility(): return false
	if memory_capacity >= 0 and memory_used(inventory) + instance.definition.memory_cost > memory_capacity: return false
	if not active_slots[slot_index].is_empty():
		return false
	active_slots[slot_index] = instance_id
	_rebuild_installed_ids()
	return true


func uninstall(instance_id: StringName) -> bool:
	if installed_utility_ids.has(instance_id):
		installed_utility_ids.erase(instance_id)
		_rebuild_installed_ids()
		return true
	var index := active_slots.find(instance_id)
	if index < 0: return false
	active_slots[index] = &""
	_rebuild_installed_ids()
	return true


func uninstall_at(slot_index: int) -> StringName:
	if slot_index < 0 or slot_index >= capacity: return &""
	var instance_id := active_slots[slot_index]
	active_slots[slot_index] = &""
	_rebuild_installed_ids()
	return instance_id


func instance_at(slot_index: int) -> StringName:
	return active_slots[slot_index] if slot_index >= 0 and slot_index < active_slots.size() else &""


func is_installed(instance_id: StringName) -> bool:
	return installed_instance_ids.has(instance_id)

func memory_used(inventory: ProgramInventory) -> int:
	if inventory == null: return 0
	var used := 0
	for instance_id: StringName in installed_instance_ids:
		var instance := inventory.get_instance(instance_id)
		if instance != null: used += maxi(0, instance.definition.memory_cost)
	return used

func active_slots_used() -> int:
	return active_slots.reduce(func(total: int, id: StringName) -> int: return total + (0 if id.is_empty() else 1), 0)

func supporting_utilities(inventory: ProgramInventory, operation: StringName, service: StringName = &"") -> Array[ProgramInstance]:
	var result: Array[ProgramInstance] = []
	if inventory == null: return result
	for instance_id: StringName in installed_utility_ids:
		var instance := inventory.get_instance(instance_id)
		if instance != null and (instance.definition.supports_operation(operation) or instance.definition.supports_service(service)): result.append(instance)
	return result


func _rebuild_installed_ids() -> void:
	installed_instance_ids.clear()
	installed_instance_ids.append_array(installed_utility_ids)
	for instance_id in active_slots:
		if not instance_id.is_empty(): installed_instance_ids.append(instance_id)
