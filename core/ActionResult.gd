class_name ActionResult
extends RefCounted

var success: bool
var time_spent: int
var reason: String
var events_produced: Array[Dictionary]
var details: Dictionary

func _init(p_success := false, p_time_spent := 0, p_reason := "", p_events: Array[Dictionary] = [], p_details: Dictionary = {}) -> void:
	success = p_success
	time_spent = p_time_spent
	reason = p_reason
	events_produced = p_events.duplicate(true)
	details = p_details.duplicate(true)
