class_name ProgramDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var version: String
@export var rarity: StringName = &"COMMON"
@export var programming_recipe: Dictionary = {}
@export var programming_requirements: Dictionary = {}
@export var programming_duration := 0.0
@export var production_tags: Array[StringName] = []


func _init(
		p_id: StringName = &"",
		p_display_name: String = "",
		p_version: String = "1.0"
) -> void:
	id = p_id
	display_name = p_display_name
	version = p_version
