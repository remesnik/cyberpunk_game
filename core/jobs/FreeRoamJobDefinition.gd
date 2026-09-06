class_name FreeRoamJobDefinition
extends Resource

enum JobType { DATA_EXTRACTION, FEED_TAP, SYSTEM_CONTROL, DATABASE_QUERY, NETWORK_RECON }

@export var id: StringName
@export var job_type: JobType = JobType.DATA_EXTRACTION
@export var display_name := ""
@export_multiline var description := ""
@export var source_id: StringName = &"PUBLIC_JOB_EXCHANGE"
@export var target_network_id: StringName
@export var target_sphere_id: StringName
@export var target_node_id: StringName
@export var target_service_id: StringName
@export var reward_credits := 100
@export var prerequisite_flags: Array[StringName] = []
@export var tags: Array[StringName] = []

func is_valid() -> bool:
	return not id.is_empty() and not display_name.is_empty() and not target_network_id.is_empty() and not target_node_id.is_empty()
