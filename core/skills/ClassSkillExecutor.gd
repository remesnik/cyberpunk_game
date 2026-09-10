class_name ClassSkillExecutor
extends RefCounted

func execute(player_class: StringName, current_target: Dictionary, run_state: Dictionary = {}) -> Dictionary:
	return {
		"success": false,
		"reason": "Class skill not available",
		"player_class": player_class,
		"target": current_target,
		"run_state": run_state,
	}
