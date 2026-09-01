class_name EvidenceRecord
extends Resource

enum SourceType { VIDEO, COMMS, RADIO, ALARM_LOG, TEAM_TELEMETRY }

@export var id: StringName
@export var source_type: SourceType
@export var source_id: StringName
@export var recording_start: float = 0.0
@export var recording_end: float = -1.0
@export var content_reference: Dictionary = {"format": "TIMED_EVENTS", "events": []}
@export var metadata: Dictionary = {}
@export var story_tags: Array[StringName] = []
@export var reviewed: bool = false
@export var important: bool = false
@export_multiline var author_notes: String


func _init(record_id: StringName = &"", type: SourceType = SourceType.VIDEO, linked_source_id: StringName = &"") -> void:
	id = record_id
	source_type = type
	source_id = linked_source_id


func is_recording() -> bool:
	return recording_end < 0.0


func source_type_label() -> String:
	return SourceType.keys()[source_type].replace("_", " ")

