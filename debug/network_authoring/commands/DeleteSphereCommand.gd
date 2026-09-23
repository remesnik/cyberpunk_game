class_name DeleteSphereCommand
extends NetworkAuthorCommand

var sphere_id: StringName
var removed_sphere: SphereDefinition
var removed_sleeve: SecuritySleeve
var member_ids: Array[StringName] = []

func _init(p_context := {}, p_sphere_id: StringName = &"") -> void:
	super(p_context); sphere_id = p_sphere_id

func execute() -> Dictionary:
	if sphere_id == NetworkGraph.LEGACY_UNASSIGNED_SPHERE_ID: return {"success": false, "reason": "The unassigned fallback sphere is required"}
	removed_sphere = graph().get_sphere(sphere_id) if graph() != null else null
	if removed_sphere == null: return {"success": false, "reason": "Sphere not found"}
	graph()._ensure_legacy_sphere(); member_ids = removed_sphere.node_ids.duplicate()
	for node_id in member_ids: AddNodeToSphereCommand.new(context, node_id, NetworkGraph.LEGACY_UNASSIGNED_SPHERE_ID).execute()
	removed_sleeve = graph().remove_security_sleeve(removed_sphere.original_security_sleeve_id)
	var removed := graph().remove_sphere(sphere_id)
	return {"success": removed != null, "reason": "Sphere deleted; nodes moved to Unassigned", "sphere_id": sphere_id}

func undo() -> Dictionary:
	if removed_sphere == null or not graph().add_sphere(removed_sphere): return {"success": false, "reason": "Could not restore sphere"}
	if removed_sleeve != null: graph().add_security_sleeve(removed_sleeve)
	for node_id in member_ids: AddNodeToSphereCommand.new(context, node_id, sphere_id).execute()
	return {"success": true, "reason": "Sphere restored"}
