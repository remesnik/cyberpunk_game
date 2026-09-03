class_name IceBindingProfile
extends RefCounted

enum Mode { ROAMING, HOST_BOUND }
var mode: Mode = Mode.ROAMING
var security_region_id: StringName
var allowed_node_ids: Array[StringName] = []
var allowed_node_types: Array[int] = []
var prohibited_node_ids: Array[StringName] = []

func permits(node: NetworkNodeDefinition) -> bool:
	if node == null or prohibited_node_ids.has(node.id): return false
	if not allowed_node_ids.is_empty() and not allowed_node_ids.has(node.id): return false
	if not allowed_node_types.is_empty() and not allowed_node_types.has(node.node_type): return false
	return true
