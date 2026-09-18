class_name SphereDefinition
extends Resource

## Persistent logical subnet identity. Membership does not follow runtime changes
## to a SecuritySleeve.
@export var id: StringName = &""
@export var display_name := "Unnamed Sphere"
@export var node_ids: Array[StringName] = []
@export var original_security_sleeve_id: StringName = &""
@export var metadata: Dictionary = {}

func _init(p_id: StringName = &"", p_display_name := "Unnamed Sphere", p_node_ids: Array[StringName] = [], p_original_security_sleeve_id: StringName = &"") -> void:
	id = p_id
	display_name = p_display_name
	node_ids = p_node_ids.duplicate()
	original_security_sleeve_id = p_original_security_sleeve_id

func contains_node(node_id: StringName) -> bool:
	return node_ids.has(node_id)

func register_node(node_id: StringName) -> void:
	if node_id != &"" and not node_ids.has(node_id):
		node_ids.append(node_id)
		node_ids.sort()
