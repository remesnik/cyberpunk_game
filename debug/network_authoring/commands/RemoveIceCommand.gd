class_name RemoveIceCommand
extends NetworkAuthorCommand

var ice_id: StringName
var removed: IceInstance

func _init(p_context := {}, p_ice_id: StringName = &"") -> void:
	super(p_context); ice_id = p_ice_id

func execute() -> Dictionary:
	var controller := context.get("ice_controller") as IceController
	removed = controller.get_ice(ice_id) if controller != null else null
	if removed == null: return {"success": false, "reason": "ICE not found"}
	controller.instances.erase(ice_id); graph().display_update_requested.emit(); return {"success": true, "reason": "ICE removed", "ice_id": ice_id}

func undo() -> Dictionary:
	var controller := context.get("ice_controller") as IceController
	var success := controller != null and removed != null and controller.add_ice(removed)
	if success: graph().display_update_requested.emit()
	return {"success": success, "reason": "ICE restored" if success else "Could not restore ICE"}
