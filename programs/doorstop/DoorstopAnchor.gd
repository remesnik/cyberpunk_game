class_name DoorstopAnchor
extends RefCounted

var source_program_instance_id: StringName
var intrusion_run_id: StringName
var cyberspace_node_id: StringName
var deployment_marker: float
var resume_data: Dictionary
var active := true


func _init(
		p_source_program_instance_id: StringName,
		p_intrusion_run_id: StringName,
		p_cyberspace_node_id: StringName,
		p_deployment_marker: float,
		p_resume_data: Dictionary = {}
) -> void:
	source_program_instance_id = p_source_program_instance_id
	intrusion_run_id = p_intrusion_run_id
	cyberspace_node_id = p_cyberspace_node_id
	deployment_marker = p_deployment_marker
	resume_data = p_resume_data.duplicate(true)


func invalidate() -> void:
	active = false
