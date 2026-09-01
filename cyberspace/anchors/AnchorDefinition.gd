class_name AnchorDefinition
extends RefCounted

var node_id: StringName
var display_name: String
var allows_fast_travel: bool
var allows_program_changes: bool
var allows_recovery: bool

func _init(p_node_id: StringName, p_display_name: String, p_fast_travel := true, p_program_changes := true, p_recovery := true) -> void:
	node_id = p_node_id
	display_name = p_display_name
	allows_fast_travel = p_fast_travel
	allows_program_changes = p_program_changes
	allows_recovery = p_recovery
