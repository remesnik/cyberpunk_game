class_name ModifySphereSecurityCommand
extends NetworkAuthorCommand

var sphere_id: StringName
var changes: Dictionary
var previous: Dictionary

func _init(p_context := {}, p_sphere_id: StringName = &"", p_changes := {}) -> void:
	super(p_context); sphere_id = p_sphere_id; changes = p_changes.duplicate(true)

func execute() -> Dictionary:
	var sphere := graph().get_sphere(sphere_id) if graph() != null else null
	var sleeve := graph().get_security_sleeve(sphere.original_security_sleeve_id) if sphere != null else null
	if sphere == null or sleeve == null: return {"success": false, "reason": "Sphere security sleeve not found"}
	previous = {"display_name": sphere.display_name, "state": sleeve.state, "security_count": sleeve.security_count, "metadata": sleeve.metadata.duplicate(true)}
	_apply(sphere, sleeve, changes); return {"success": true, "reason": "Sphere security updated", "sphere_id": sphere_id}

func undo() -> Dictionary:
	var sphere := graph().get_sphere(sphere_id) if graph() != null else null
	var sleeve := graph().get_security_sleeve(sphere.original_security_sleeve_id) if sphere != null else null
	if sphere == null or sleeve == null: return {"success": false, "reason": "Sphere security sleeve not found"}
	_apply(sphere, sleeve, previous); return {"success": true, "reason": "Sphere security restored"}

func _apply(sphere: SphereDefinition, sleeve: SecuritySleeve, values: Dictionary) -> void:
	sphere.display_name = String(values.get("display_name", sphere.display_name))
	if values.has("metadata"): sleeve.metadata = (values.metadata as Dictionary).duplicate(true)
	for key in [&"security_tier", &"access_difficulty_modifier", &"path_unlock_difficulty_modifier", &"system_trace_pressure", &"response_configuration", &"traversal_security_configuration", &"escalation_behavior"]:
		if values.has(key): sleeve.metadata[key] = values[key]
	sleeve.security_count = maxi(0, int(values.get("security_count", sleeve.security_count)))
	if values.has("state"): sleeve.state = int(values.state) as SecuritySleeve.State
	elif values.has("enabled"): sleeve.state = SecuritySleeve.State.INTACT if bool(values.enabled) else SecuritySleeve.State.DISABLED
	sleeve.metadata["security_count"] = sleeve.security_count
	sleeve.changed.emit(sleeve); graph().display_update_requested.emit()
