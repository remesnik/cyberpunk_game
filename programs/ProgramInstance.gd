class_name ProgramInstance
extends RefCounted

var instance_id: StringName
var definition: ProgramDefinition
var metadata: Dictionary = {}


func _init(
		p_instance_id: StringName,
		p_definition: ProgramDefinition,
		p_metadata: Dictionary = {}
) -> void:
	instance_id = p_instance_id
	definition = p_definition
	metadata = p_metadata.duplicate(true)


func definition_id() -> StringName:
	return definition.id if definition != null else &""
