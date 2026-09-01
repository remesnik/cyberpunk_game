class_name IceInstance
extends RefCounted

var instance_id: StringName
var definition: IceDefinition
var current_node_id: StringName
var target_node_id: StringName = &""
var state: IceState.Value
var alert_level := 0
var known_player_position: StringName = &""
var last_known_player_position: StringName = &""
var home_node: StringName
var movement_progress := 0
var patrol_index := 0
var integrity: int
var disrupted_time := 0
var operational := true

var detection_capability: int:
	get: return definition.detection_capability
var movement_cost: int:
	get: return definition.movement_cost
var scan_capability: int:
	get: return definition.scan_capability

func _init(p_instance_id: StringName, p_definition: IceDefinition, p_start_node: StringName, p_state: IceState.Value = IceState.Value.DORMANT) -> void:
	instance_id = p_instance_id
	definition = p_definition
	current_node_id = p_start_node
	home_node = p_start_node
	state = p_state
	integrity = definition.maximum_integrity
