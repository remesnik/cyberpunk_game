class_name NodeServiceDefinition
extends RefCounted

var id: StringName
var display_name: String
var service_type: StringName
var security_level: int
var supported_operations: Array[StringName] = []
var vulnerabilities: Array[StringName] = []
var tags: Array[StringName] = []
var capability_types: Array = []
var bypass_operations: Array[StringName] = []
var metadata: Dictionary = {}

func _init(p_id: StringName = &"", p_display_name := "", p_service_type: StringName = NodeServiceCatalog.SERVICE_PROCESS_CONTROL, p_security_level := 0) -> void:
	id = p_id
	display_name = p_display_name
	service_type = NodeServiceCatalog.normalize(p_service_type)
	security_level = maxi(0, p_security_level)
	supported_operations = NodeServiceCatalog.default_operations(service_type)

func supports(operation: StringName) -> bool:
	return supported_operations.has(PlayerOperationCatalog.normalize(operation))

func to_record() -> Dictionary:
	var result := {"id": id, "display_name": display_name, "service_type": service_type, "security_level": security_level, "supported_operations": supported_operations.duplicate(), "vulnerabilities": vulnerabilities.duplicate(), "tags": tags.duplicate(), "capability_types": capability_types.duplicate(), "bypass_operations": bypass_operations.duplicate()}
	result.merge(metadata, false)
	return result
