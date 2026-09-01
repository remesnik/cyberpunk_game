class_name FacilityOperationMission
extends PayrollMissionController

const MISSION_NAME_SLICE := "BREACH WINDOW"


func _init(p_graph: NetworkGraph, p_position: PlayerNetworkPosition, p_knowledge: PlayerKnowledge, p_resources: PlayerResourceState, p_shortcuts: ShortcutController) -> void:
	super(p_graph, p_position, p_knowledge, p_resources, p_shortcuts)


func objective_text() -> String:
	return "SUPPORT TEAM_ALPHA // LOOP CAMERA // UNLOCK DOOR_12 // BYPASS ALARM"


func execute_exploit(target: Dictionary) -> Dictionary:
	var validation := validate_exploit(target)
	if not validation.success:
		return {"success": false, "reason": validation.reason, "trace": 0, "events": []}
	var service_id: StringName = validation.service_id
	exploited_services.append(service_id)
	var events: Array[Dictionary] = [{"type": &"SERVICE_COMPROMISED", "service_id": service_id}]
	match service_id:
		&"CAMERA_CONTROL":
			position.grant_capability(CapabilityCatalog.ROOTKIT)
			events.append({"type": &"CAPABILITY_ACQUIRED", "capability_id": CapabilityCatalog.ROOTKIT})
		&"DOOR_CONTROL_DAEMON":
			events.append({"type": &"PHYSICAL_ACCESS_UNLOCKED", "access_point_id": &"DOOR_12", "service_id": service_id})
		&"PBX_SWITCH":
			position.grant_capability(&"DECRYPT_VOICE")
			events.append({"type": &"COMMS_ACCESS_GRANTED", "channel_id": &"GUARD_PHONE_CALL"})
		&"ALARM_ZONE_CONTROL":
			position.authority_level = maxi(position.authority_level, 3)
			events.append({"type": &"ALARM_CONTROL_COMPROMISED", "alarm_id": &"ALARM_ZONE_SERVER"})
	var service_data := knowledge.service_records.get(service_id, {}) as Dictionary
	service_data["level"] = KnowledgeLevel.Value.COMPROMISED
	knowledge.service_records[service_id] = service_data
	knowledge.knowledge_changed.emit()
	return {"success": true, "reason": "Facility service compromised.", "trace": maxi(1, exploit_cost(target) - 1), "events": events}


func validate_transfer(_target: Dictionary) -> Dictionary:
	return {"success": false, "reason": "No transfer objective in this operation."}


func check_completion() -> Array[Dictionary]:
	return []
