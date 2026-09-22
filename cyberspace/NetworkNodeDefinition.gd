class_name NetworkNodeDefinition
extends RefCounted

signal security_event_reported(event: Dictionary)

enum NodeType { GATEWAY, ROUTER, WORKSTATION, AUTH_SERVER, FILE_SERVER, SECURITY_SERVER, SERVICE_CLUSTER, SYSTEM }
enum SecurityFamily { VIRAL, ORANGE, PURPLE }

var id: StringName
var display_name: String
var node_type: NodeType
## Functional role in the network. Independent from the security implementation.
var network_type: StringName
var security_family: SecurityFamily = SecurityFamily.VIRAL
var difficulty_rating: int = 0
var security_level: int
var discovered: bool
var owner_faction: StringName
## Authored logical region identity. Runtime sleeve changes never rewrite this.
var sphere_id: StringName = &""
var connected_links: Array[StringName] = []
var services: Array[Dictionary] = []
var service_definitions: Array[NodeServiceDefinition] = []
var required_capabilities_all: Array[StringName] = []
var required_capabilities_any: Array[StringName] = []
var accepted_credentials: Array[StringName] = []
var recommended_capabilities: Array[StringName] = []
var granted_capability_ids: Array[StringName] = []
var outbound_path_controls: Array[NodePathControl] = []

func _init(p_id: StringName, p_display_name: String, p_node_type: NodeType, p_security_level := 0, p_discovered := false, p_owner_faction: StringName = &"", p_sphere_id: StringName = &"") -> void:
	id = p_id
	display_name = p_display_name
	node_type = p_node_type
	network_type = StringName(NodeType.keys()[p_node_type])
	security_level = maxi(p_security_level, 0)
	difficulty_rating = security_level
	discovered = p_discovered
	owner_faction = p_owner_faction
	sphere_id = p_sphere_id

func security_family_name() -> StringName:
	return StringName(SecurityFamily.keys()[security_family])

func add_connected_link(link_id: StringName) -> void:
	if not connected_links.has(link_id):
		connected_links.append(link_id)

func add_path_control(control: NodePathControl) -> void:
	if control != null: outbound_path_controls.append(control)

func add_service(service_id: StringName, service_name: String, service_security: int, vulnerabilities: Array[StringName] = [], tags: Array[StringName] = [], capability_types: Array = [], bypass_operations: Array[StringName] = [], service_type: StringName = NodeServiceCatalog.SERVICE_PROCESS_CONTROL, supported_operations: Array[StringName] = []) -> void:
	add_service_record({"id": service_id, "display_name": service_name, "service_type": service_type, "security_level": service_security, "vulnerabilities": vulnerabilities, "tags": tags, "capability_types": capability_types, "bypass_operations": bypass_operations, "supported_operations": supported_operations})

func add_service_record(record: Dictionary) -> void:
	var definition := NodeServiceDefinition.new(StringName(record.get("id", &"")), String(record.get("display_name", "SERVICE")), StringName(record.get("service_type", NodeServiceCatalog.SERVICE_PROCESS_CONTROL)), int(record.get("security_level", 0)))
	definition.vulnerabilities.assign(record.get("vulnerabilities", []))
	definition.tags.assign(record.get("tags", []))
	definition.capability_types = record.get("capability_types", []).duplicate()
	definition.bypass_operations.assign(record.get("bypass_operations", []))
	var authored_operations: Array = record.get("supported_operations", [])
	if not authored_operations.is_empty():
		definition.supported_operations.clear()
		for operation: Variant in authored_operations:
			var normalized := PlayerOperationCatalog.normalize(operation)
			if PlayerOperationCatalog.is_supported(normalized) and not definition.supported_operations.has(normalized): definition.supported_operations.append(normalized)
	var known_fields := [&"id", &"display_name", &"service_type", &"security_level", &"vulnerabilities", &"tags", &"capability_types", &"bypass_operations", &"supported_operations"]
	for key: Variant in record:
		if not known_fields.has(StringName(key)): definition.metadata[key] = record[key]
	service_definitions.append(definition)
	services.append(definition.to_record())

func get_services_by_type(service_type: StringName) -> Array[NodeServiceDefinition]:
	var normalized := NodeServiceCatalog.normalize(service_type)
	return service_definitions.filter(func(service: NodeServiceDefinition): return service.service_type == normalized)

func report_security_event(event: Dictionary) -> void:
	var report := event.duplicate(true)
	report["source_node"] = id
	report["node_id"] = id
	security_event_reported.emit(report)

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
