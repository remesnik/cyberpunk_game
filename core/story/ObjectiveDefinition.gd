class_name ObjectiveDefinition
extends Resource
## Authored, event-driven mission objective.

const INACTIVE := &"INACTIVE"
const ACTIVE := &"ACTIVE"
const COMPLETED := &"COMPLETED"
const FAILED := &"FAILED"

const SUPPORTED_TYPES := [
	&"DOWNLOAD_FILE", &"SCAN_TARGET", &"DISABLE_SERVICE", &"INTERCEPT_STREAM",
	&"REACH_NODE", &"AVOID_ALARM", &"AVOID_TRACE", &"TAKE_CONTROL", &"CUSTOM_EVENT",
]

@export var objective_id: StringName
@export var description := ""
@export var objective_type: StringName
@export var required := true
@export var optional := false
@export var hidden := false
@export var target_id: StringName
@export var event_name: StringName
@export var required_progress := 1
@export var condition: Dictionary = {}

static func from_dict(data: Dictionary, category: StringName) -> ObjectiveDefinition:
	var objective := ObjectiveDefinition.new()
	objective.objective_id = StringName(data.get("objective_id", data.get("id", &"")))
	objective.description = String(data.get("description", ""))
	objective.objective_type = StringName(data.get("type", &"CUSTOM_EVENT")).to_upper()
	objective.optional = category == &"optional" or bool(data.get("optional", false))
	objective.hidden = category == &"hidden" or bool(data.get("hidden", false))
	objective.required = bool(data.get("required", not objective.optional and not objective.hidden))
	objective.target_id = StringName(data.get("target_id", data.get("target", &"")))
	objective.event_name = StringName(data.get("event", &""))
	objective.required_progress = maxi(1, int(data.get("required_progress", 1)))
	objective.condition = (data.get("condition", {}) as Dictionary).duplicate(true)
	return objective

func expected_event() -> StringName:
	if not event_name.is_empty(): return event_name
	return {
		&"DOWNLOAD_FILE": &"file_downloaded", &"SCAN_TARGET": &"target_scanned",
		&"DISABLE_SERVICE": &"service_disabled", &"INTERCEPT_STREAM": &"stream_intercepted",
		&"REACH_NODE": &"node_reached", &"AVOID_ALARM": &"alarm_triggered",
		&"AVOID_TRACE": &"trace_completed", &"TAKE_CONTROL": &"control_taken",
	}.get(objective_type, &"custom_event")

func validate() -> Array[String]:
	var errors: Array[String] = []
	if objective_id.is_empty(): errors.append("Objective has no objective_id.")
	if description.strip_edges().is_empty(): errors.append("Objective '%s' has no description." % objective_id)
	if objective_type not in SUPPORTED_TYPES: errors.append("Objective '%s' has unsupported type '%s'." % [objective_id, objective_type])
	if objective_type not in [&"AVOID_ALARM", &"AVOID_TRACE", &"CUSTOM_EVENT"] and target_id.is_empty(): errors.append("Objective '%s' has no target reference." % objective_id)
	return errors

func initial_state() -> Dictionary:
	return {"objective_id": objective_id, "description": description, "type": objective_type, "required": required, "optional": optional, "hidden": hidden, "target_id": target_id, "state": ACTIVE, "progress": 0, "required_progress": required_progress}
