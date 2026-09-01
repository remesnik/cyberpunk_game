class_name StoryEvent
extends RefCounted

enum Type {
	COMMS_INTERCEPTED,
	COMMS_RECORDED,
	HEARD_COMMS_EVENT,
	VIDEO_OBSERVED,
	VIDEO_EVENT_SEEN,
	ALARM_TRIGGERED,
	ALARM_BYPASSED,
	TEAM_REACHED_LOCATION,
	TEAM_LOST,
	TEAM_SUCCESS,
	EQUIPMENT_DELIVERED,
	REALTIME_EVENT_OCCURRED,
}

var id: StringName
var event_type: Type
var source_id: StringName
var realtime_seconds: float
var payload: Dictionary = {}
var story_tags: Array[StringName] = []


func _init(type: Type = Type.REALTIME_EVENT_OCCURRED, source: StringName = &"", realtime: float = 0.0, data: Dictionary = {}) -> void:
	event_type = type
	source_id = source
	realtime_seconds = realtime
	payload = data.duplicate(true)


func type_name() -> StringName:
	return StringName(Type.keys()[event_type])


func to_context() -> Dictionary:
	return {"id": id, "event_type": type_name(), "source_id": source_id, "realtime": realtime_seconds, "payload": payload.duplicate(true), "story_tags": story_tags.duplicate()}

