class_name CapabilityDefinition
extends RefCounted

var id: StringName
var display_name: String
var description: String
var category: StringName

func _init(p_id: StringName, p_display_name: String, p_description: String, p_category: StringName = &"ACCESS") -> void:
	id = p_id
	display_name = p_display_name
	description = p_description
	category = p_category
