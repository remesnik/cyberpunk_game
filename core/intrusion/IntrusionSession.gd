class_name IntrusionSession
extends RefCounted

enum Lifecycle { ACTIVE, SUSPENDED_AT_DOORSTOP, COMPLETED, ABORTED, FAILED }

var id: StringName
var lifecycle: Lifecycle = Lifecycle.ACTIVE
var suspended_anchor: DoorstopAnchor
var suspended_at_realtime := -1.0
var suspended_security_elapsed := 0.0
var suspension_advanced_through := -1.0
var resume_state: Dictionary = {}
var applied_loadout_instance_ids: Array[StringName] = []
var system_access_nodes_by_owner: Dictionary = {}


func _init(p_id: StringName) -> void:
	id = p_id

func register_system_access_node(san: SystemAccessNode) -> bool:
	if san == null or san.intrusion_id != id or system_access_nodes_by_owner.has(san.owner_player_id): return false
	system_access_nodes_by_owner[san.owner_player_id] = san
	return true

func get_system_access_node(owner_player_id: StringName) -> SystemAccessNode:
	return system_access_nodes_by_owner.get(owner_player_id) as SystemAccessNode


func suspend_at_doorstop(anchor: DoorstopAnchor, realtime_marker: float, state: Dictionary) -> Dictionary:
	if lifecycle != Lifecycle.ACTIVE:
		return {"success": false, "reason": "Intrusion is not active."}
	if anchor == null or not anchor.active:
		return {"success": false, "reason": "No active Doorstop return point exists."}
	if anchor.intrusion_run_id != id:
		return {"success": false, "reason": "Doorstop belongs to a different intrusion."}
	suspended_anchor = anchor
	suspended_at_realtime = realtime_marker
	suspension_advanced_through = realtime_marker
	resume_state = state.duplicate(true)
	lifecycle = Lifecycle.SUSPENDED_AT_DOORSTOP
	return {"success": true, "reason": "Intrusion suspended at Doorstop.", "lifecycle": lifecycle}


func record_suspended_security_time(seconds: float) -> void:
	# Reserved for a future lightweight security simulation while in meat space.
	if lifecycle == Lifecycle.SUSPENDED_AT_DOORSTOP and seconds > 0.0:
		suspended_security_elapsed += seconds


func can_resume_through_doorstop() -> bool:
	return lifecycle == Lifecycle.SUSPENDED_AT_DOORSTOP and suspended_anchor != null and suspended_anchor.active


func resume_through_doorstop(anchor: DoorstopAnchor, current_loadout: Array[StringName]) -> Dictionary:
	if not can_resume_through_doorstop():
		return {"success": false, "reason": "No active Doorstop return route is available."}
	if anchor == null or anchor != suspended_anchor or anchor.intrusion_run_id != id:
		return {"success": false, "reason": "Doorstop return route does not belong to this suspended intrusion."}
	var return_node_id := suspended_anchor.cyberspace_node_id
	applied_loadout_instance_ids = current_loadout.duplicate()
	lifecycle = Lifecycle.ACTIVE
	return {"success": true, "reason": "Intrusion resumed through Doorstop.", "node_id": return_node_id}


func clear_consumed_return_route() -> void:
	suspended_anchor = null


func complete_normally(completion_data: Dictionary = {}) -> Dictionary:
	if lifecycle != Lifecycle.ACTIVE:
		return {"success": false, "reason": "Only an active intrusion can complete normally."}
	if suspended_anchor != null and suspended_anchor.active:
		return {"success": false, "reason": "An active Doorstop route must be resolved before normal completion."}
	lifecycle = Lifecycle.COMPLETED
	return {"success": true, "reason": "Intrusion completed normally.", "completion_data": completion_data.duplicate(true)}

func abort(reason := "Intrusion aborted.", abort_data: Dictionary = {}) -> Dictionary:
	if lifecycle == Lifecycle.COMPLETED or lifecycle == Lifecycle.ABORTED or lifecycle == Lifecycle.FAILED:
		return {"success": false, "reason": "Intrusion has already ended."}
	if suspended_anchor != null and suspended_anchor.active:
		suspended_anchor.invalidate()
	suspended_anchor = null
	resume_state.clear()
	lifecycle = Lifecycle.ABORTED
	return {"success": true, "reason": reason, "abort_data": abort_data.duplicate(true)}


func lifecycle_label() -> String:
	return Lifecycle.keys()[lifecycle]
