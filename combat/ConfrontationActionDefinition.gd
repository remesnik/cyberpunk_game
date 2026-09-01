class_name ConfrontationActionDefinition
extends RefCounted

var action_type: ActionRequest.ActionType
var display_name: String
var base_cost: int
var range_in_links: int
var required_capabilities: Array[StringName]
var power: int
var trace_generated: int
var valid_target_kinds: Array[StringName]

func _init(p_type: ActionRequest.ActionType, p_name: String, p_cost: int, p_range: int, p_requirements: Array[StringName], p_power: int, p_trace: int, p_targets: Array[StringName]) -> void:
	action_type = p_type
	display_name = p_name
	base_cost = maxi(p_cost, 0)
	range_in_links = maxi(p_range, 0)
	required_capabilities = p_requirements.duplicate()
	power = maxi(p_power, 0)
	trace_generated = maxi(p_trace, 0)
	valid_target_kinds = p_targets.duplicate()
