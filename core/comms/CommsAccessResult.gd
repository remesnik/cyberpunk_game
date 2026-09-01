class_name CommsAccessResult
extends RefCounted

enum Operation { DISCOVER, MONITOR, INTERCEPT, RECORD, INJECT }

var operation: Operation
var available := false
var reason: String
var missing_requirements: Array[StringName] = []
var authority_required := 0
var capability_required: StringName
var program_required: StringName
var trace_cost := 0
var detection_possible := false
var detection_risk := 0.0


func _init(target_operation: Operation = Operation.DISCOVER) -> void:
	operation = target_operation


func operation_label() -> String:
	return Operation.keys()[operation]


func status_text() -> String:
	if available:
		return "%s AVAILABLE" % operation_label()
	if not missing_requirements.is_empty():
		return "%s REQUIRES: %s" % [operation_label(), ", ".join(missing_requirements)]
	return "%s UNAVAILABLE%s" % [operation_label(), " // %s" % reason.to_upper() if not reason.is_empty() else ""]


func risk_text() -> String:
	var parts: PackedStringArray = ["TRACE %d" % trace_cost]
	parts.append("DETECTION %d%%" % int(round(detection_risk * 100.0)) if detection_possible else "DETECTION NONE")
	return " // ".join(parts)

