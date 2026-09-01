class_name VideoFeedDefinition
extends RefCounted

enum CameraType { FIXED, PTZ, THERMAL, LOW_LIGHT, BODY_CAMERA, DRONE, CUSTOM }
enum PlaybackMode { LOOP, SCRIPT }

var id: StringName
var display_name: String
var physical_location_id: StringName
var network_endpoint_id: StringName
var camera_type: CameraType = CameraType.FIXED
var online := true
var recording := false
var player_access := false
var loop_or_script: PlaybackMode = PlaybackMode.SCRIPT
var story_tags: Array[StringName] = []
var can_disable := false
var can_record := true
var can_replay := false
var author_notes: String
var authored_event_timeline: Array[Dictionary] = []
var spoof_profiles: Dictionary = {}


func _init(feed_id: StringName = &"", name: String = "", location_id: StringName = &"", endpoint_id: StringName = &"") -> void:
	id = feed_id
	display_name = name
	physical_location_id = location_id
	network_endpoint_id = endpoint_id


func add_event(at_seconds: float, event_type: StringName, data: Dictionary = {}) -> void:
	var event := data.duplicate(true)
	event["time"] = maxf(0.0, at_seconds)
	event["type"] = event_type
	authored_event_timeline.append(event)
	authored_event_timeline.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.time) < float(b.time))


func camera_type_label() -> String:
	return CameraType.keys()[camera_type].replace("_", " ")
