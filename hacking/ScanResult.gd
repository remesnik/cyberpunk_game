class_name ScanResult
extends RefCounted

var success: bool
var target_kind: StringName
var target_id: StringName
var scan_depth: int
var time_spent: int
var trace_generated: int
var reason: String
var discoveries: Array[Dictionary]
var events_produced: Array[Dictionary]

func _init(p_success := false, p_target_kind: StringName = &"", p_target_id: StringName = &"", p_depth := 0, p_time := 0, p_trace := 0, p_reason := "", p_discoveries: Array[Dictionary] = [], p_events: Array[Dictionary] = []) -> void:
	success = p_success
	target_kind = p_target_kind
	target_id = p_target_id
	scan_depth = p_depth
	time_spent = p_time
	trace_generated = p_trace
	reason = p_reason
	discoveries = p_discoveries.duplicate(true)
	events_produced = p_events.duplicate(true)

func to_event() -> Dictionary:
	return {"type": &"SCAN_COMPLETED", "target_kind": target_kind, "target_id": target_id, "depth": scan_depth, "time": time_spent, "trace": trace_generated, "discoveries": discoveries.size()}
