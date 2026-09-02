class_name ProgramInventory
extends RefCounted

signal instance_added(instance: ProgramInstance)
signal instance_removed(instance: ProgramInstance)

var _instances: Dictionary = {}


func add_instance(instance: ProgramInstance) -> bool:
	if instance == null or instance.definition == null or instance.instance_id.is_empty():
		return false
	if _instances.has(instance.instance_id):
		return false
	_instances[instance.instance_id] = instance
	instance_added.emit(instance)
	return true


func has_instance(instance_id: StringName) -> bool:
	return _instances.has(instance_id)


func get_instance(instance_id: StringName) -> ProgramInstance:
	return _instances.get(instance_id) as ProgramInstance


func remove_instance(instance_id: StringName) -> ProgramInstance:
	var instance := get_instance(instance_id)
	if instance != null:
		_instances.erase(instance_id)
		instance_removed.emit(instance)
	return instance


func all_instances() -> Array[ProgramInstance]:
	var result: Array[ProgramInstance] = []
	for instance: ProgramInstance in _instances.values():
		result.append(instance)
	return result


func instances_for_definition(definition_id: StringName) -> Array[ProgramInstance]:
	var result: Array[ProgramInstance] = []
	for instance: ProgramInstance in _instances.values():
		if instance.definition_id() == definition_id:
			result.append(instance)
	return result
