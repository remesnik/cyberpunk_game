class_name PhysicalAlarmDefinition
extends RefCounted

enum AlarmType { BURGLAR_ALARM, FIRE_ALARM, DOOR_FORCED, MOTION_SENSOR, GLASS_BREAK, EQUIPMENT_ALARM, SERVER_ROOM_TEMPERATURE, CUSTOM }
enum Command { MONITOR, ACKNOWLEDGE, SILENCE, BYPASS, RESTORE, TRIGGER }

var id: StringName
var display_name: String
var alarm_type: AlarmType
var physical_location_id: StringName
var network_endpoint_id: StringName
var realtime_process_id: StringName
var action_policies: Dictionary = {}
var authored_timeline: Array[Dictionary] = []
var story_tags: Array[StringName] = []
var author_notes: String


func _init(alarm_id: StringName = &"", name: String = "", type: AlarmType = AlarmType.CUSTOM, location_id: StringName = &"", endpoint_id: StringName = &"", process_id: StringName = &"") -> void:
	id = alarm_id
	display_name = name
	alarm_type = type
	physical_location_id = location_id
	network_endpoint_id = endpoint_id
	realtime_process_id = process_id


func set_action_policy(command: Command, authority := 0, capability: StringName = &"") -> void:
	action_policies[command] = {"authority": maxi(0, authority), "capability": capability}


func add_timeline_event(at_seconds: float, event_type: StringName, data: Dictionary = {}) -> void:
	var event := data.duplicate(true)
	event["time"] = maxf(0.0, at_seconds)
	event["type"] = event_type
	authored_timeline.append(event)
	authored_timeline.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.time) < float(b.time))


func type_label() -> String:
	return AlarmType.keys()[alarm_type].replace("_", " ")

