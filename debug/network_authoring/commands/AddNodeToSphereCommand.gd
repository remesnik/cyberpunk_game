class_name AddNodeToSphereCommand
extends NetworkAuthorCommand

var node_id: StringName
var sphere_id: StringName
var previous_sphere_id: StringName

func _init(p_context := {}, p_node_id: StringName = &"", p_sphere_id: StringName = &"") -> void:
	super(p_context); node_id = p_node_id; sphere_id = p_sphere_id

func execute() -> Dictionary:
	var node := graph().get_node(node_id) if graph() != null else null
	if node == null or graph().get_sphere(sphere_id) == null: return {"success": false, "reason": "Node or sphere not found"}
	previous_sphere_id = node.sphere_id; _move(sphere_id); return {"success": true, "reason": "Node moved to sphere"}

func undo() -> Dictionary:
	if graph().get_sphere(previous_sphere_id) == null: return {"success": false, "reason": "Previous sphere no longer exists"}
	_move(previous_sphere_id); return {"success": true, "reason": "Sphere membership restored"}

func _move(destination_id: StringName) -> void:
	var node := graph().get_node(node_id)
	var previous := graph().get_sphere(node.sphere_id); if previous != null: previous.node_ids.erase(node_id)
	for sleeve: SecuritySleeve in graph().security_sleeves.values(): sleeve.remove_current_member(node_id)
	node.sphere_id = destination_id
	var destination := graph().get_sphere(destination_id); destination.register_node(node_id)
	var sleeve := graph().get_security_sleeve(destination.original_security_sleeve_id)
	if sleeve != null: sleeve.add_current_member(node_id)
	graph().display_update_requested.emit()
