class_name AddIceCommand
extends NetworkAuthorCommand

var ice: IceInstance

func _init(p_context := {}, p_ice: IceInstance = null) -> void:
	super(p_context); ice = p_ice

func execute() -> Dictionary:
	var controller := context.get("ice_controller") as IceController
	var success := controller != null and ice != null and controller.add_ice(ice)
	if success: graph().display_update_requested.emit()
	return {"success": success, "reason": "ICE added" if success else "Could not add ICE", "ice_id": ice.instance_id if ice != null else &""}

func undo() -> Dictionary:
	var controller := context.get("ice_controller") as IceController
	var success := controller != null and ice != null and controller.instances.erase(ice.instance_id)
	if success: graph().display_update_requested.emit()
	return {"success": success, "reason": "ICE removed" if success else "ICE not found"}
