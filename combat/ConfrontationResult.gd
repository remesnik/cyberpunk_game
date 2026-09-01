class_name ConfrontationResult
extends RefCounted

var success: bool
var reason: String
var action_type: ActionRequest.ActionType
var cost: int
var trace_generated: int
var events: Array[Dictionary]

func _init(p_success := false, p_reason := "", p_type: ActionRequest.ActionType = ActionRequest.ActionType.DISRUPT, p_cost := 0, p_trace := 0, p_events: Array[Dictionary] = []) -> void:
	success = p_success
	reason = p_reason
	action_type = p_type
	cost = p_cost
	trace_generated = p_trace
	events = p_events.duplicate(true)
