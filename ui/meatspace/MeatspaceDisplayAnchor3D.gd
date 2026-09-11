class_name MeatspaceDisplayAnchor3D
extends Node3D
## Persistent placements: world_state.physical_displays[location_id][anchor_id].
var location_id: StringName
var anchor_id: StringName
var current_item: Dictionary = {}
var authored_fallbacks: Array = []

func apply_state(state: PersistentGameState) -> void:
	var placements: Dictionary = state.world_state.get("physical_displays", {}).get(String(location_id), {}) if state != null else {}
	var item: Dictionary = placements.get(String(anchor_id), {})
	if item.is_empty() and state != null:
		item = _resolve_fallback(state)
	if item == current_item: return
	current_item = item.duplicate(true)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if not item.is_empty(): build_item(self, item)

func _resolve_fallback(state: PersistentGameState) -> Dictionary:
	var flags: Dictionary = state.campaign_state.get("story_flags", {})
	var inventory: Array = state.player_state.get("inventory", [])
	for candidate: Dictionary in authored_fallbacks:
		if candidate.has("when_flag") and bool(flags.get(candidate.when_flag, false)) != bool(candidate.get("equals", true)): continue
		if candidate.has("inventory_id") and not inventory.any(func(entry: Variant) -> bool:
			return (entry is Dictionary and String(entry.get("id", entry.get("item_id", ""))) == String(candidate.inventory_id)) or String(entry) == String(candidate.inventory_id)):
			continue
		return candidate.get("item", {}).duplicate(true)
	return {}

static func build_item(parent: Node3D, item: Dictionary) -> Node3D:
	var visual := String(item.get("visual", ""))
	if visual == "BACKPACK": return _build_backpack(parent)
	var dimensions := Vector3(0.3, 0.14, 0.22)
	var color := Color("496c70")
	match visual:
		"BOOK": dimensions = Vector3(0.3, 0.045, 0.22); color = Color("a18d67")
		"CUP": dimensions = Vector3(0.12, 0.18, 0.12); color = Color("a7a29a")
		"FOOD": dimensions = Vector3(0.28, 0.08, 0.22); color = Color("8e5b43")
		"CABLE": dimensions = Vector3(0.32, 0.035, 0.08); color = Color("262b2d")
		"JACKET": dimensions = Vector3(0.55, 0.09, 0.48); color = Color("35454c")
	return MeatspaceEnvironment3D.block(parent, dimensions, Vector3.ZERO, color)

static func _build_backpack(parent: Node3D) -> Node3D:
	var pack := Node3D.new()
	pack.name = "LowPolyBackpack"
	pack.set_meta("visual_profile", "fabric_backpack_with_straps_pocket_and_seams")
	parent.add_child(pack)
	var fabric := StandardMaterial3D.new()
	fabric.albedo_color = Color("344a52")
	fabric.roughness = 0.96
	var main := MeshInstance3D.new()
	main.name = "FabricBody"
	var body_mesh := SphereMesh.new(); body_mesh.radius = 0.5; body_mesh.height = 1.0; body_mesh.radial_segments = 12; body_mesh.rings = 7
	main.mesh = body_mesh; main.scale = Vector3(0.48, 0.6, 0.18); main.position = Vector3(0, 0.27, 0); main.material_override = fabric
	pack.add_child(main)
	var pocket := MeatspaceEnvironment3D.block(pack, Vector3(0.34, 0.25, 0.09), Vector3(0, 0.19, 0.14), Color("2b3d43"))
	pocket.name = "FrontPocket"
	var seam := MeatspaceEnvironment3D.block(pack, Vector3(0.38, 0.018, 0.025), Vector3(0, 0.32, 0.19), Color("829095"))
	seam.name = "PocketSeam"
	for side in [-1.0, 1.0]:
		var strap := MeatspaceEnvironment3D.block(pack, Vector3(0.055, 0.56, 0.035), Vector3(side * 0.17, 0.24, -0.13), Color("202e33"))
		strap.name = "ShoulderStrap%s" % ("Left" if side < 0 else "Right")
		strap.rotation_degrees.z = side * 10.0
	var handle := MeatspaceEnvironment3D.block(pack, Vector3(0.2, 0.035, 0.04), Vector3(0, 0.61, -0.02), Color("202e33"))
	handle.name = "CarryHandle"
	pack.rotation_degrees = Vector3(-8, 12, 4)
	return pack
