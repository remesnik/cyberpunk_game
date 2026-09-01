class_name RealtimeEndpointDefinition
extends RefCounted

enum EndpointType {
	VIDEO,
	AUDIO,
	COMMS,
	ALARM,
	SENSOR,
	ACCESS_CONTROL,
	TEAM_TRACKING,
	DEVICE_CONTROL,
	CUSTOM,
}

var id: StringName
var endpoint_type: EndpointType
var network_node_id: StringName
var service_id: StringName
var associated_realtime_process_ids: Array[StringName] = []
var discovery_requirement: KnowledgeLevel.Value = KnowledgeLevel.Value.SCANNED
var access_requirement: StringName
var authority_requirement := 0
var capability_requirement: StringName
var description: String
var tags: Array[StringName] = []


func _init(
	endpoint_id: StringName = &"",
	type: EndpointType = EndpointType.CUSTOM,
	node_id: StringName = &"",
	linked_service_id: StringName = &"",
	process_ids: Array[StringName] = []
) -> void:
	id = endpoint_id
	endpoint_type = type
	network_node_id = node_id
	service_id = linked_service_id
	associated_realtime_process_ids = process_ids.duplicate()


func discovery_requirement_met(scan_level: KnowledgeLevel.Value) -> bool:
	return scan_level >= discovery_requirement


func access_requirements_met(authority_level: int, capabilities: Array[StringName], credentials: Array[StringName]) -> bool:
	if authority_level < authority_requirement:
		return false
	if capability_requirement != &"" and not capabilities.has(capability_requirement):
		return false
	if access_requirement != &"" and not credentials.has(access_requirement):
		return false
	return true


func type_label() -> String:
	return EndpointType.keys()[endpoint_type]

