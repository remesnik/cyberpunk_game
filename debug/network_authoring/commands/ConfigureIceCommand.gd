class_name ConfigureIceCommand
extends NetworkAuthorCommand

var ice: IceInstance
var changes: Dictionary
var previous: Dictionary

func _init(p_context := {}, p_ice: IceInstance = null, p_changes := {}) -> void:
	super(p_context); ice = p_ice; changes = p_changes.duplicate(true)

func execute() -> Dictionary:
	if ice == null: return {"success": false, "reason": "ICE not found"}
	previous = _snapshot(); _apply(changes); graph().display_update_requested.emit(); return {"success": true, "reason": "ICE configured", "ice_id": ice.instance_id}

func undo() -> Dictionary:
	if ice == null: return {"success": false, "reason": "ICE not found"}
	_apply(previous); graph().display_update_requested.emit(); return {"success": true, "reason": "ICE configuration restored"}

func _snapshot() -> Dictionary:
	return {"current_node_id": ice.current_node_id, "state": ice.state, "operational": ice.operational, "detection_capability": ice.definition.detection_capability, "patrol_route": ice.definition.patrol_route.duplicate()}

func _apply(values: Dictionary) -> void:
	ice.current_node_id = StringName(values.get("current_node_id", ice.current_node_id))
	ice.state = int(values.get("state", ice.state)) as IceState.Value
	ice.operational = bool(values.get("operational", ice.operational))
	ice.definition.detection_capability = maxi(0, int(values.get("detection_capability", ice.definition.detection_capability)))
	if values.has("patrol_route"):
		ice.definition.patrol_route.clear(); ice.definition.patrol_route.assign(values.patrol_route)
