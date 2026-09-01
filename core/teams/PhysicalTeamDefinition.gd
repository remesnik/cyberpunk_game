class_name PhysicalTeamDefinition
extends RefCounted

enum TeamType { PLAYER_CONTRACTED, ALLY, CORPORATE_SECURITY, POLICE, RIVAL, UNKNOWN }

var id: StringName
var display_name: String
var team_type: TeamType
var faction: StringName
var members: Array[PhysicalTeamMemberDefinition] = []
var default_equipment: Array[StringName] = []
var movement_speed_multiplier := 1.0
var story_tags: Array[StringName] = []


func _init(definition_id: StringName = &"", name: String = "", type: TeamType = TeamType.UNKNOWN, team_faction: StringName = &"") -> void:
	id = definition_id
	display_name = name
	team_type = type
	faction = team_faction


func type_label() -> String:
	return TeamType.keys()[team_type].replace("_", " ")

