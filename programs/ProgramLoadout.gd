class_name ProgramLoadout
extends RefCounted

var capacity := 4
var installed_instance_ids: Array[StringName] = []
var active_slots: Array[StringName] = []


func _init(p_capacity := 4) -> void:
	capacity = maxi(0, p_capacity)
	active_slots.resize(capacity)
	for index in active_slots.size(): active_slots[index] = &""


func install(instance_id: StringName, inventory: ProgramInventory) -> bool:
	if instance_id.is_empty() or inventory == null or not inventory.has_instance(instance_id):
		return false
	if installed_instance_ids.has(instance_id):
		return true
	for index in active_slots.size():
		if active_slots[index].is_empty(): return install_at(index, instance_id, inventory)
	return false


func install_at(slot_index: int, instance_id: StringName, inventory: ProgramInventory) -> bool:
	if slot_index < 0 or slot_index >= capacity or instance_id.is_empty() or inventory == null:
		return false
	if not inventory.has_instance(instance_id) or installed_instance_ids.has(instance_id):
		return false
	if not active_slots[slot_index].is_empty():
		return false
	active_slots[slot_index] = instance_id
	_rebuild_installed_ids()
	return true


func uninstall(instance_id: StringName) -> bool:
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


func _rebuild_installed_ids() -> void:
	installed_instance_ids.clear()
	for instance_id in active_slots:
		if not instance_id.is_empty(): installed_instance_ids.append(instance_id)
