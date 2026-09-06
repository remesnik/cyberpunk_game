class_name MeatspaceDisplayAnchor3D
extends Node3D
## Persistent placements: world_state.physical_displays[location_id][anchor_id].
var location_id: StringName
var anchor_id: StringName
var current_item: Dictionary = {}

func apply_state(state: PersistentGameState) -> void:
	var placements: Dictionary = state.world_state.get("physical_displays", {}).get(String(location_id), {}) if state != null else {}
	var item: Dictionary = placements.get(String(anchor_id), {})
	if item == current_item: return
	current_item = item.duplicate(true)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if not item.is_empty(): build_item(self, item)

static func build_item(parent: Node3D, item: Dictionary) -> Node3D:
	var is_book := String(item.get("visual", "")) == "BOOK"
	return MeatspaceEnvironment3D.block(parent, Vector3(0.3, 0.045 if is_book else 0.14, 0.22), Vector3.ZERO, Color("a18d67") if is_book else Color("496c70"))
