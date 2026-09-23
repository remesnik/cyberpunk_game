class_name CreateSphereCommand
extends NetworkAuthorCommand

var sphere: SphereDefinition
var sleeve: SecuritySleeve
var initial_node_id: StringName
var previous_sphere_id: StringName

func _init(p_context := {}, p_sphere: SphereDefinition = null, p_sleeve: SecuritySleeve = null, p_node_id: StringName = &"") -> void:
	super(p_context); sphere = p_sphere; sleeve = p_sleeve; initial_node_id = p_node_id

func execute() -> Dictionary:
	var node := graph().get_node(initial_node_id) if graph() != null else null
	if node == null or sphere == null or sleeve == null: return {"success": false, "reason": "Invalid sphere command"}
	previous_sphere_id = node.sphere_id
	if not graph().add_security_sleeve(sleeve) or not graph().add_sphere(sphere):
		graph().remove_security_sleeve(sleeve.id); return {"success": false, "reason": "Could not create sphere"}
	_move_node(node, sphere.id)
	return {"success": true, "reason": "Sphere created", "sphere_id": sphere.id, "sleeve_id": sleeve.id}

func undo() -> Dictionary:
	var node := graph().get_node(initial_node_id)
	if node != null: _move_node(node, previous_sphere_id)
	graph().remove_sphere(sphere.id); graph().remove_security_sleeve(sleeve.id)
	return {"success": true, "reason": "Sphere creation undone"}

func _move_node(node: NetworkNodeDefinition, destination_id: StringName) -> void:
	var previous := graph().get_sphere(node.sphere_id); if previous != null: previous.node_ids.erase(node.id)
	node.sphere_id = destination_id
	var destination := graph().get_sphere(destination_id); if destination != null: destination.register_node(node.id)
	for candidate: SecuritySleeve in graph().security_sleeves.values(): candidate.remove_current_member(node.id)
	if destination != null:
		var destination_sleeve := graph().get_security_sleeve(destination.original_security_sleeve_id)
		if destination_sleeve != null: destination_sleeve.add_current_member(node.id)
	graph().display_update_requested.emit()
