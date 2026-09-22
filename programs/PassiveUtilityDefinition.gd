class_name PassiveUtilityDefinition
extends ProgramDefinition

func _init(p_id: StringName = &"", p_display_name: String = "", p_version: String = "1.0") -> void:
	super(p_id, p_display_name, p_version)
	program_type = &"PASSIVE_UTILITY"
	consumes_active_slot = false

func supports(operation: StringName, service: StringName = &"") -> bool:
	return supports_operation(operation) or supports_service(service)
