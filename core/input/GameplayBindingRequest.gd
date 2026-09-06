class_name GameplayBindingRequest
extends RefCounted

enum Category { GLOBAL_GAME_ACTION, CYBERSPACE_COMMAND, PROGRAM_BINDING }

var category: Category
var command_id: StringName
var input_action: StringName
var program_instance_id: StringName
var slot_index := -1

func _init(p_category: Category, p_command_id: StringName, p_input_action: StringName) -> void:
	category = p_category
	command_id = p_command_id
	input_action = p_input_action
