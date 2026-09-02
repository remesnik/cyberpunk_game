class_name HackerNPCDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var callsign: String
@export var faction: StringName = &"INDEPENDENT"
@export_multiline var description: String
@export var comms_channel_id: StringName
@export var visual_signature: StringName = &"REMOTE_PROCESS"
@export var player_relationship: StringName = &"NEUTRAL"
@export var local_visibility_hops := 1
@export var story_tags: Array[StringName] = []
@export var scripted_reactions: Array[Dictionary] = []


func _init(p_id: StringName = &"", p_display_name: String = "", p_callsign: String = "") -> void:
	id = p_id
	display_name = p_display_name
	callsign = p_callsign if not p_callsign.is_empty() else p_display_name
