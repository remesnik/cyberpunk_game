class_name DoorstopController
extends RefCounted

var inventory: ProgramInventory
var loadout: ProgramLoadout
var anchors_by_run: Dictionary = {}
var san_manager: SystemAccessNodeManager
var owner_actor_id: StringName


func _init(p_inventory: ProgramInventory, p_loadout: ProgramLoadout) -> void:
	inventory = p_inventory
	loadout = p_loadout

func configure_system_access_node(p_san_manager: SystemAccessNodeManager, p_owner_actor_id: StringName) -> void:
	san_manager = p_san_manager
	owner_actor_id = p_owner_actor_id


func deploy(
		program_instance_id: StringName,
		intrusion_run_id: StringName,
		cyberspace_node_id: StringName,
		deployment_marker: float,
		resume_data: Dictionary = {},
		deployment_context: Dictionary = {}
) -> Dictionary:
	var validation := validate_deployment(program_instance_id, intrusion_run_id, cyberspace_node_id, deployment_context)
	if not validation.success:
		return validation
	var instance := inventory.get_instance(program_instance_id)
	var definition := instance.definition as DoorstopDefinition
	var san := san_manager.get_for_connection(owner_actor_id, intrusion_run_id)
	var previous_host_node_id: StringName = san.host_node_id
	var relocation := san_manager.relocate(san.id, cyberspace_node_id)
	if not relocation.success:
		return _failure(relocation.reason)
	var captured_resume_data := resume_data.duplicate(true)
	captured_resume_data["destroy_anchor_on_return"] = definition.destroy_anchor_on_return
	var anchor := DoorstopAnchor.new(
		program_instance_id,
		intrusion_run_id,
		cyberspace_node_id,
		deployment_marker,
		captured_resume_data,
		san.id
	)
	anchors_by_run[intrusion_run_id] = anchor
	if definition.burn_on_deploy:
		loadout.uninstall(program_instance_id)
		inventory.remove_instance(program_instance_id)
	return {
		"success": true,
		"reason": "Doorstop deployed.",
		"anchor": anchor,
		"burned_instance_id": program_instance_id if definition.burn_on_deploy else &"",
		"san": san,
		"previous_host_node_id": previous_host_node_id,
		"host_node_id": san.host_node_id,
	}


func validate_deployment(
		program_instance_id: StringName,
		intrusion_run_id: StringName,
		cyberspace_node_id: StringName,
		deployment_context: Dictionary = {}
) -> Dictionary:
	if inventory == null or loadout == null:
		return _failure("Program inventory is unavailable.")
	if intrusion_run_id.is_empty() or cyberspace_node_id.is_empty():
		return _failure("Doorstop requires a run and cyberspace node.")
	if san_manager == null or owner_actor_id.is_empty():
		return _failure("Doorstop requires an active System Access Node service.")
	var san := san_manager.get_for_connection(owner_actor_id, intrusion_run_id)
	if san == null or not san.active:
		return _failure("No active System Access Node exists for this intrusion.")
	var instance := inventory.get_instance(program_instance_id)
	if instance == null:
		return _failure("Doorstop instance is not owned.")
	var definition := instance.definition as DoorstopDefinition
	if definition == null:
		return _failure("Selected program instance is not Doorstop.")
	if not loadout.is_installed(program_instance_id):
		return _failure("Doorstop instance is not installed in the active loadout.")
	var restriction_reason := definition.validate_deployment(deployment_context)
	if not restriction_reason.is_empty():
		return _failure(restriction_reason)
	var existing := get_anchor(intrusion_run_id)
	if existing != null and existing.active:
		return _failure("An active Doorstop return point already exists for this intrusion.")
	if san.host_node_id == cyberspace_node_id:
		# Legal: deploying at the present SAN host still grants the one-use permission.
		pass
	return {"success": true, "reason": "", "anchor": null, "burned_instance_id": &""}


func get_anchor(intrusion_run_id: StringName) -> DoorstopAnchor:
	return anchors_by_run.get(intrusion_run_id) as DoorstopAnchor


func complete_return(intrusion_run_id: StringName, force_destroy := false) -> bool:
	var anchor := get_anchor(intrusion_run_id)
	if anchor == null or not anchor.active:
		return false
	# The source instance may already be burned, so the policy required to resume
	# is captured in anchor data at deployment rather than looked up in inventory.
	var destroy_on_return := bool(anchor.resume_data.get("destroy_anchor_on_return", true))
	if destroy_on_return or force_destroy:
		anchor.invalidate()
		anchors_by_run.erase(intrusion_run_id)
	return true


func _failure(reason: String) -> Dictionary:
	return {"success": false, "reason": reason, "anchor": null, "burned_instance_id": &""}
