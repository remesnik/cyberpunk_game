class_name RemoveNodeFromSphereCommand
extends AddNodeToSphereCommand

func _init(p_context := {}, p_node_id: StringName = &"") -> void:
	super(p_context, p_node_id, NetworkGraph.LEGACY_UNASSIGNED_SPHERE_ID)
