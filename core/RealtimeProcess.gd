class_name RealtimeProcess
extends RefCounted

enum ProcessType {
	VIDEO_FEED,
	VOICE_CALL,
	RADIO_NET,
	ALARM,
	SECURITY_TEAM,
	PENETRATION_TEAM,
	DELIVERY,
	DEVICE_STATE,
	PHYSICAL_SENSOR,
	CUSTOM,
}

enum State {
	UNKNOWN,
	AVAILABLE,
	ACTIVE,
	INTERRUPTED,
	LOST,
	COMPLETED,
	FAILED,
}

var id: StringName
var process_type: ProcessType
var source_id: StringName
var display_name: String
var state: State = State.AVAILABLE
var start_time := 0.0
var elapsed_time := 0.0
## Negative duration means that the process has no scheduled completion.
var duration := -1.0
var discovered := false
var accessible := false
var intercepted := false
var recording := false
var metadata: Dictionary = {}
var tags: Array[StringName] = []


func _init(
	process_id: StringName = &"",
	type: ProcessType = ProcessType.CUSTOM,
	name: String = "",
	source: StringName = &"",
	finite_duration := -1.0
) -> void:
	id = process_id
	process_type = type
	display_name = name
	source_id = source
	duration = finite_duration


func has_finite_duration() -> bool:
	return duration >= 0.0


func is_running() -> bool:
	return state == State.ACTIVE


func remaining_time() -> float:
	if not has_finite_duration():
		return -1.0
	return maxf(0.0, duration - elapsed_time)


func state_label() -> String:
	return State.keys()[state]


func type_label() -> String:
	return ProcessType.keys()[process_type]
