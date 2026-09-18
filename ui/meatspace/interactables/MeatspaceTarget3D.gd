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

func apply_state(flags: Dictionary) -> void:
	var rule: Dictionary = authored_data.get("visibility", {})
	visible = rule.is_empty() or bool(flags.get(rule.get("flag", ""), false)) == bool(rule.get("equals", true))
	collision_layer = 1 if visible else 0
	var bindings: Dictionary = authored_data.get("visual_state", {})
	for binding: Dictionary in visual_bindings:
		var flag := StringName(bindings.get(binding.key, &""))
		binding.node.set(binding.property, binding.active if bool(flags.get(flag, false)) else binding.inactive)
