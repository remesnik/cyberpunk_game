class_name CommsParticipantDefinition
extends RefCounted

var id: StringName
var display_name: String
var callsign: String
var faction: StringName
var metadata: Dictionary = {}


func _init(participant_id: StringName = &"", name: String = "", participant_callsign: String = "", participant_faction: StringName = &"") -> void:
	id = participant_id
	display_name = name
	callsign = participant_callsign
	faction = participant_faction

