class_name CommsChannelDefinition
extends RefCounted

enum ChannelType { PHONE_CALL, SECURITY_RADIO, PRIVATE_RADIO, VOIP_CALL, INTERCOM, TACTICAL_COMMS, CUSTOM }

var id: StringName
var display_name: String
var channel_type: ChannelType
var source_endpoint_id: StringName
var participant_ids: Array[StringName] = []
var encryption_level := 0
var intercept_requirement: StringName
var recording_allowed := true
var story_tags: Array[StringName] = []
## Per-operation authoring data. Absence means no additional requirement.
## Detection is opt-in; a non-detecting endpoint never becomes detectable merely
## because content was intercepted.
var access_policies: Dictionary = {}


func _init(channel_id: StringName = &"", name: String = "", type: ChannelType = ChannelType.CUSTOM, endpoint_id: StringName = &"") -> void:
	id = channel_id
	display_name = name
	channel_type = type
	source_endpoint_id = endpoint_id


func type_label() -> String:
	return ChannelType.keys()[channel_type].replace("_", " ")


func set_access_policy(operation: CommsAccessResult.Operation, authority := 0, capability: StringName = &"", program: StringName = &"", trace_cost := 0, detection_enabled := false, detection_risk := 0.0) -> void:
	access_policies[operation] = {
		"authority": maxi(0, authority),
		"capability": capability,
		"program": program,
		"trace_cost": maxi(0, trace_cost),
		"detection_enabled": detection_enabled,
		"detection_risk": clampf(detection_risk, 0.0, 1.0),
	}


func get_access_policy(operation: CommsAccessResult.Operation) -> Dictionary:
	return (access_policies.get(operation, {}) as Dictionary).duplicate(true)
