class_name PhysicalTeamMemberDefinition
extends RefCounted

var id: StringName
var display_name: String
var role: StringName
var capabilities: Array[StringName] = []
var equipment: Array[StringName] = []
var metadata: Dictionary = {}


func _init(member_id: StringName = &"", name: String = "", team_role: StringName = &"") -> void:
	id = member_id
	display_name = name
	role = team_role

