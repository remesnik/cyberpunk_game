class_name ProgramDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var version: String
@export var rarity: StringName = &"COMMON"
@export var programming_recipe: Dictionary = {}
@export var programming_requirements: Dictionary = {}
@export var programming_duration := 0.0
@export var production_tags: Array[StringName] = []
@export var program_type: StringName = &"UTILITY"
@export var exploit_security_family: StringName = &""
@export var utility_rating: int = 0
@export var utility_model: StringName = &""
@export var bypass_supported_operations: Array[StringName] = []
@export var supported_operations: Array[StringName] = []
@export var supported_services: Array[StringName] = []
@export var affinity_type: StringName = &""
@export var strong_network_types: Array[StringName] = []
@export var neutral_network_types: Array[StringName] = []
@export var weak_network_types: Array[StringName] = []
@export_range(0, 99, 1) var storage_cost: int = 1
@export_range(0, 99, 1) var memory_cost: int = 1
@export var consumes_active_slot: bool = true


func _init(
		p_id: StringName = &"",
		p_display_name: String = "",
		p_version: String = "1.0"
) -> void:
	id = p_id
	display_name = p_display_name
	version = p_version

func exploit_family_matches(node: NetworkNodeDefinition) -> bool:
	return node != null and not exploit_security_family.is_empty() and exploit_security_family == node.security_family_name()

func bypass_contribution(node: NetworkNodeDefinition) -> int:
	return maxi(0, utility_rating) if exploit_family_matches(node) else 0

func is_passive_utility() -> bool:
	return not consumes_active_slot

func is_stealth_program() -> bool:
	return program_type in [&"STEALTH", &"STEALTH_PROGRAM"] or id == &"SLEEZE" or display_name.to_upper().contains("SLEEZE")

func supports_bypass_operation(operation: StringName) -> bool:
	return operation != &"" and bypass_supported_operations.has(operation)

func supports_operation(operation: StringName) -> bool:
	return operation != &"" and supported_operations.has(operation)

func supports_service(service: StringName) -> bool:
	return service != &"" and supported_services.has(service)

func network_affinity_label(node: NetworkNodeDefinition) -> StringName:
	if node == null: return &"NEUTRAL"
	var type := StringName(String(node.network_type).to_upper())
	if strong_network_types.has(type): return &"STRONG"
	if weak_network_types.has(type): return &"WEAK"
	return &"NEUTRAL"

func effective_exploit_rating(node: NetworkNodeDefinition) -> int:
	if not exploit_family_matches(node): return 0
	match network_affinity_label(node):
		&"STRONG": return maxi(0, utility_rating)
		&"WEAK": return maxi(0, roundi(float(utility_rating) * 0.25))
		_: return maxi(0, roundi(float(utility_rating) * 0.5))
