class_name MeatspaceTarget3D
extends Area3D
## Physical target only; story actions belong to the authored interaction system.
signal selected(object_id: StringName)
var object_id: StringName
var authored_data: Dictionary
var visual_bindings: Array[Dictionary] = []

func configure(data: Dictionary, bounds: Vector3) -> void:
	authored_data = data.duplicate(true)
	object_id = StringName(data.get("id", &""))
	name = String(object_id)
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = bounds
	shape.shape = box
	shape.position.y = bounds.y / 2
	add_child(shape)

func activate() -> void:
	if visible: selected.emit(object_id)

func bind_visual(node: Node3D, property: StringName, key: StringName, inactive: Variant, active: Variant) -> void:
	visual_bindings.append({"node": node, "property": property, "key": key, "inactive": inactive, "active": active})

func apply_state(source: Variant) -> void:
	var state := source as PersistentGameState if source is PersistentGameState else null
	var flags: Dictionary = state.campaign_state.get("story_flags", {}) if state != null else ((source as Dictionary) if source is Dictionary else {})
	visible = StoryBindingEvaluator.visible(authored_data, state) if state != null else (authored_data.get("visibility", {}).is_empty() or bool(flags.get(authored_data.get("visibility", {}).get("flag", ""), false)) == bool(authored_data.get("visibility", {}).get("equals", true)))
	collision_layer = 1 if visible else 0
	var bindings: Dictionary = authored_data.get("visual_state", {})
	for binding: Dictionary in visual_bindings:
		var authored: Variant = bindings.get(binding.key, &"")
		var active := StoryBindingEvaluator.matches(authored if authored is Dictionary else {"scope": "flag", "id": authored, "value": true}, state) if state != null else bool(flags.get(StringName(authored), false))
		binding.node.set(binding.property, binding.active if active else binding.inactive)
	set_meta("story_variant", StoryBindingEvaluator.variant(authored_data, state))
