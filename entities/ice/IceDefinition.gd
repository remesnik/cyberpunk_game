class_name IceDefinition
extends RefCounted

enum BindingMode { ROAMING, HOST_BOUND }

var id: StringName
var display_name: String
var detection_capability: int
var movement_cost: int
var scan_capability: int
var patrol_route: Array[StringName]
var maximum_integrity: int
var defense: int
var binding_mode := BindingMode.ROAMING
var allowed_binding_node_ids: Array[StringName] = []

func is_host_bound() -> bool:
	return binding_mode == BindingMode.HOST_BOUND

func permits_binding_node(node_id: StringName) -> bool:
	return allowed_binding_node_ids.is_empty() or allowed_binding_node_ids.has(node_id)

func _init(p_id: StringName, p_display_name: String, p_detection_capability := 1, p_movement_cost := 1, p_scan_capability := 1, p_patrol_route: Array[StringName] = [], p_maximum_integrity := 8, p_defense := 1) -> void:
	id = p_id
	display_name = p_display_name
	detection_capability = maxi(p_detection_capability, 0)
	movement_cost = maxi(p_movement_cost, 1)
	scan_capability = maxi(p_scan_capability, 0)
	patrol_route = p_patrol_route.duplicate()
	maximum_integrity = maxi(p_maximum_integrity, 1)
	defense = maxi(p_defense, 0)
