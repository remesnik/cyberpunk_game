class_name PhysicalAccessPointInstance
extends RefCounted

signal access_changed(access_point_id: StringName, locked: bool, source: StringName)

var definition: PhysicalAccessPointDefinition
var locked := true
var bypassed := false
var last_change_source: StringName


func _init(access_definition: PhysicalAccessPointDefinition = null) -> void:
	definition = access_definition
	if definition != null:
		locked = definition.initially_locked


func can_pass() -> bool:
	return not locked or bypassed


func unlock(source: StringName = &"CYBER_SUPPORT") -> void:
	locked = false
	last_change_source = source
	access_changed.emit(definition.id, locked, source)


func restore(source: StringName = &"SECURITY_SYSTEM") -> void:
	locked = definition.initially_locked
	bypassed = false
	last_change_source = source
	access_changed.emit(definition.id, locked, source)

