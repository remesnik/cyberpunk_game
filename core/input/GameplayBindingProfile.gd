class_name GameplayBindingProfile
extends Resource

const BindingRequestScript := preload("res://core/input/GameplayBindingRequest.gd")

@export var global_actions: Dictionary = {}
@export var cyberspace_commands: Dictionary = {}
@export var program_bindings: Dictionary = {}

func input_action_for(category: int, command_id: StringName) -> StringName:
	var source := global_actions if category == BindingRequestScript.Category.GLOBAL_GAME_ACTION else (cyberspace_commands if category == BindingRequestScript.Category.CYBERSPACE_COMMAND else program_bindings)
	return StringName(source.get(command_id, &""))

func all_input_actions() -> Array[StringName]:
	var result: Array[StringName] = []
	for source: Dictionary in [global_actions, cyberspace_commands, program_bindings]:
		for value: Variant in source.values():
			var action := StringName(value)
			if not action.is_empty() and action not in result: result.append(action)
	return result
