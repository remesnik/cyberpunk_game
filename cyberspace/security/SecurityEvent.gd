class_name SecurityEvent
extends RefCounted

var source_node: StringName
var event_type: StringName
var severity: int
var noisy_action_type: StringName
var player_identity: StringName
var session_identity: StringName
var tags: Array[StringName] = []
var timestamp_state_marker: Variant
var metadata: Dictionary = {}

func _init(p_source_node: StringName = &"", p_event_type: StringName = &"SECURITY_EVENT", p_severity := 1, p_noisy_action_type: StringName = &"", p_player_identity: StringName = &"PLAYER", p_session_identity: StringName = &"", p_tags: Array[StringName] = [], p_timestamp_state_marker: Variant = 0) -> void:
	source_node = p_source_node
	event_type = p_event_type
	severity = maxi(1, p_severity)
	noisy_action_type = p_noisy_action_type
	player_identity = p_player_identity
	session_identity = p_session_identity
	tags = p_tags.duplicate()
	timestamp_state_marker = p_timestamp_state_marker

func to_dict() -> Dictionary:
	var result := {"source_node": source_node, "node_id": source_node, "event_type": event_type, "type": event_type, "severity": severity, "noisy_action_type": noisy_action_type, "player_identity": player_identity, "session_identity": session_identity, "tags": tags.duplicate(), "timestamp_state_marker": timestamp_state_marker, "player_visible": true}
	result.merge(metadata, false)
	return result
