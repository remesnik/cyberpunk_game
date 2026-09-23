class_name NetworkSelectionState
extends RefCounted

## Ephemeral inspector selection; persistent object data stays in NetworkGraph.
enum Kind { NONE, NODE, PATH, SPHERE, SECURITY_SLEEVE, SERVICE, ICE }

var kind := Kind.NONE
var object_id: StringName = &""
var node_ids: Array[StringName] = []

func select(next_kind: Kind, next_id: StringName) -> void:
	kind = next_kind
	object_id = next_id
	node_ids.clear()
	if kind == Kind.NODE and object_id != &"": node_ids.append(object_id)

func select_nodes(ids: Array[StringName]) -> void:
	node_ids = ids.duplicate()
	kind = Kind.NODE if not node_ids.is_empty() else Kind.NONE
	object_id = node_ids.back() if not node_ids.is_empty() else &""

func clear() -> void:
	select(Kind.NONE, &"")

func kind_label() -> String:
	return Kind.keys()[kind]
