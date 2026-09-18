class_name NetworkNodeDefinition
extends RefCounted

enum NodeType { GATEWAY, ROUTER, WORKSTATION, AUTH_SERVER, FILE_SERVER, SECURITY_SERVER, SERVICE_CLUSTER, SYSTEM }

var id: StringName
var display_name: String
var node_type: NodeType
var security_level: int
var discovered: bool
var owner_faction: StringName
## Authored logical region identity. Runtime sleeve changes never rewrite this.
var sphere_id: StringName = &""
var connected_links: Array[StringName] = []
var services: Array[Dictionary] = []
var required_capabilities_all: Array[StringName] = []
var required_capabilities_any: Array[StringName] = []
var accepted_credentials: Array[StringName] = []
var recommended_capabilities: Array[StringName] = []
var granted_capability_ids: Array[StringName] = []

func _init(p_id: StringName, p_display_name: String, p_node_type: NodeType, p_security_level := 0, p_discovered := false, p_owner_faction: StringName = &"", p_sphere_id: StringName = &"") -> void:
	id = p_id
	display_name = p_display_name
	node_type = p_node_type
	security_level = maxi(p_security_level, 0)
	discovered = p_discovered
	owner_faction = p_owner_faction
	sphere_id = p_sphere_id

func add_connected_link(link_id: StringName) -> void:
	if not connected_links.has(link_id):
		connected_links.append(link_id)

func add_service(service_id: StringName, service_name: String, service_security: int, vulnerabilities: Array[StringName] = [], tags: Array[StringName] = [], capability_types: Array = []) -> void:
	services.append({"id": service_id, "display_name": service_name, "security_level": maxi(service_security, 0), "vulnerabilities": vulnerabilities.duplicate(), "tags": tags.duplicate(), "capability_types": capability_types.duplicate()})

func access_requirements_met(capabilities: Array[StringName], credentials: Array[StringName]) -> bool:
	for requirement in required_capabilities_all:
		if not capabilities.has(requirement):
			return false
	if required_capabilities_any.is_empty() and accepted_credentials.is_empty():
		return true
	for requirement in required_capabilities_any:
		if capabilities.has(requirement):
			return true
	for credential in accepted_credentials:
		if credentials.has(credential):
			return true
	return false
