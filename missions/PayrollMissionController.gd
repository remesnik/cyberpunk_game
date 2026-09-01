class_name PayrollMissionController
extends RefCounted

const MISSION_NAME := "GHOST IN THE PAYROLL"
const OBJECTIVE_RESOURCE := &"EMPLOYEE_LEDGER"
const TRACE_FAILURE_THRESHOLD := 20

var graph: NetworkGraph
var position: PlayerNetworkPosition
var knowledge: PlayerKnowledge
var resources: PlayerResourceState
var shortcuts: ShortcutController
var exploited_services: Array[StringName] = []
var ledger_extracted := false
var mission_complete := false

func _init(p_graph: NetworkGraph, p_position: PlayerNetworkPosition, p_knowledge: PlayerKnowledge, p_resources: PlayerResourceState, p_shortcuts: ShortcutController) -> void:
	graph = p_graph
	position = p_position
	knowledge = p_knowledge
	resources = p_resources
	shortcuts = p_shortcuts

func objective_text() -> String:
	if mission_complete:
		return "COMPLETE // EMPLOYEE LEDGER SECURED"
	if int(resources.volatile_resources.get(OBJECTIVE_RESOURCE, 0)) > 0:
		return "RETURN EMPLOYEE_LEDGER TO PUBLIC_GATEWAY"
	return "RETRIEVE EMPLOYEE_LEDGER FROM PAYROLL_SERVER"

func validate_exploit(target: Dictionary) -> Dictionary:
	var service_id := knowledge.resolve_service_contact(target.get("contact_id", &""))
	var record: Dictionary = knowledge.service_records.get(service_id, {})
	if service_id == &"" or record.get("node_id", &"") != position.current_node_id:
		return {"success": false, "reason": "Service is not locally addressable."}
	if knowledge.get_service_level(service_id) < KnowledgeLevel.Value.SCANNED:
		return {"success": false, "reason": "Service must be scanned before exploitation."}
	if exploited_services.has(service_id):
		return {"success": false, "reason": "Service is already compromised."}
	return {"success": true, "reason": "", "service_id": service_id}

func exploit_cost(target: Dictionary) -> int:
	var service_id := knowledge.resolve_service_contact(target.get("contact_id", &""))
	return 1 + int(knowledge.service_records.get(service_id, {}).get("security_level", 1))

func execute_exploit(target: Dictionary) -> Dictionary:
	var validation := validate_exploit(target)
	if not validation.success:
		return {"success": false, "reason": validation.reason, "trace": 0, "events": []}
	var service_id: StringName = validation.service_id
	exploited_services.append(service_id)
	var events: Array[Dictionary] = [{"type": &"SERVICE_COMPROMISED", "service_id": service_id}]
	match service_id:
		&"DMZ_CONTROL":
			shortcuts.activate(&"EMPLOYEE_ENGINEERING_BRIDGE", position, knowledge)
			events.append({"type": &"SHORTCUT_ENABLED", "link_id": &"EMPLOYEE_ENGINEERING_SHORTCUT"})
		&"EMP_DIRECTORY":
			if not position.credentials.has(&"EMPLOYEE_CREDENTIAL"):
				position.credentials.append(&"EMPLOYEE_CREDENTIAL")
			var locked_link := graph.get_link(&"EMPLOYEE_AUTH_LOCK")
			locked_link.locked = false
			knowledge.reveal_link(locked_link, KnowledgeLevel.Value.SCANNED)
			events.append({"type": &"CREDENTIAL_STOLEN", "credential": &"EMPLOYEE_CREDENTIAL"})
		&"ENG_TOOLCHAIN":
			for capability in [CapabilityCatalog.LEGACY_PROTOCOL, CapabilityCatalog.DEEP_SCAN, CapabilityCatalog.TRACE_SCRAMBLER]:
				if position.grant_capability(capability):
					events.append({"type": &"CAPABILITY_ACQUIRED", "capability_id": capability})
		&"AUTH_DAEMON":
			position.grant_capability(CapabilityCatalog.DECRYPT)
			events.append({"type": &"CAPABILITY_ACQUIRED", "capability_id": CapabilityCatalog.DECRYPT})
		&"DOOR_CONTROL_DAEMON":
			events.append({"type": &"PHYSICAL_ACCESS_UNLOCKED", "access_point_id": &"DOOR_12", "service_id": service_id})
	var service_data := knowledge.service_records.get(service_id, {}) as Dictionary
	service_data["level"] = KnowledgeLevel.Value.COMPROMISED
	knowledge.service_records[service_id] = service_data
	knowledge.knowledge_changed.emit()
	return {"success": true, "reason": "Exploit succeeded.", "trace": maxi(1, exploit_cost(target) - 1), "events": events}

func validate_transfer(target: Dictionary) -> Dictionary:
	var service_id := knowledge.resolve_service_contact(target.get("contact_id", &""))
	if service_id != &"PAYROLL_DB" or position.current_node_id != PayrollMissionFactory.PAYROLL_SERVER:
		return {"success": false, "reason": "EMPLOYEE_LEDGER is not available at this target."}
	if knowledge.get_service_level(service_id) < KnowledgeLevel.Value.SCANNED:
		return {"success": false, "reason": "Payroll database must be scanned first."}
	return {"success": true, "reason": ""}

func execute_transfer(target: Dictionary) -> Dictionary:
	var validation := validate_transfer(target)
	if not validation.success:
		return {"success": false, "reason": validation.reason, "trace": 0, "events": []}
	resources.add_volatile(OBJECTIVE_RESOURCE, 1)
	ledger_extracted = true
	return {"success": true, "reason": "EMPLOYEE_LEDGER extracted.", "trace": 3, "events": [{"type": &"DATA_EXTRACTED", "resource_id": OBJECTIVE_RESOURCE}]}

func check_completion() -> Array[Dictionary]:
	if not mission_complete and position.current_node_id == PayrollMissionFactory.PUBLIC_GATEWAY and int(resources.volatile_resources.get(OBJECTIVE_RESOURCE, 0)) > 0:
		mission_complete = true
		return [{"type": &"MISSION_COMPLETE", "mission": MISSION_NAME}]
	return []
