class_name ProgramLoadout
extends RefCounted

var capacity := 4
var installed_instance_ids: Array[StringName] = []


func _init(p_capacity := 4) -> void:
	capacity = maxi(0, p_capacity)


func install(instance_id: StringName, inventory: ProgramInventory) -> bool:
	if instance_id.is_empty() or inventory == null or not inventory.has_instance(instance_id):
		return false
	if installed_instance_ids.has(instance_id):
		return true
	if installed_instance_ids.size() >= capacity:
		return false
	installed_instance_ids.append(instance_id)
	return true


func uninstall(instance_id: StringName) -> bool:
	var index := installed_instance_ids.find(instance_id)
	if index < 0:
		return false
	installed_instance_ids.remove_at(index)
	return true


func is_installed(instance_id: StringName) -> bool:
	return installed_instance_ids.has(instance_id)
