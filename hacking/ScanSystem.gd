class_name ScanSystem
extends RefCounted

const CURRENT_NODE := &"CURRENT_NODE"
const NODE := &"NODE"
const LINK := &"LINK"
const SERVICE := &"SERVICE"
const ICE_SIGNAL := &"ICE_SIGNAL"
const PLAYER_SIGNAL := &"PLAYER_SIGNAL"

var graph: NetworkGraph
var position: PlayerNetworkPosition
var knowledge: PlayerKnowledge
var ice_controller: IceController
var realtime_endpoints: Dictionary
var realtime_processes: Dictionary

func _init(p_graph: NetworkGraph, p_position: PlayerNetworkPosition, p_knowledge: PlayerKnowledge, p_ice_controller: IceController, p_realtime_endpoints: Dictionary = {}, p_realtime_processes: Dictionary = {}) -> void:
	graph = p_graph
	position = p_position
	knowledge = p_knowledge
	ice_controller = p_ice_controller
	realtime_endpoints = p_realtime_endpoints
	realtime_processes = p_realtime_processes

func get_action_cost(target: Dictionary) -> int:
	var distance := _target_distance(target)
	return 1 + maxi(distance, 0)

func validate_target(target: Dictionary) -> Dictionary:
	var kind: StringName = target.get("kind", &"")
	if kind == CURRENT_NODE:
		return {"success": target.get("node_id", &"") == position.current_node_id, "reason": "Current-node target is invalid."}
	if kind == NODE:
		var node_id: StringName = target.get("node_id", &"")
		if not knowledge.knows_node(node_id):
			return {"success": false, "reason": "Node is not identified."}
		return {"success": _target_distance(target) == 1, "reason": "Node is not adjacent."}
	if kind == LINK:
		var link_id := knowledge.resolve_link_contact(target.get("contact_id", &""))
		return {"success": link_id != &"" and _link_touches_current(link_id), "reason": "Link signal is not locally detectable."}
	if kind == ICE_SIGNAL:
		var ice_id := knowledge.resolve_ice_contact(target.get("contact_id", &""))
		return {"success": ice_id != &"", "reason": "ICE signal is not detectable."}
	if kind == SERVICE:
		var service_id := knowledge.resolve_service_contact(target.get("contact_id", &""))
		var service_record: Dictionary = knowledge.service_records.get(service_id, {})
		return {"success": service_id != &"" and service_record.get("node_id", &"") == position.current_node_id, "reason": "Service is not locally detectable."}
	if kind == PLAYER_SIGNAL:
		return {"success": false, "reason": "Player-signal scanning is reserved for a later slice."}
	return {"success": false, "reason": "Unknown scan target type."}

func perform_scan(target: Dictionary, scanner_power: int) -> ScanResult:
	var validation := validate_target(target)
	if not validation.success:
		return ScanResult.new(false, target.get("kind", &""), &"", 0, 0, 0, validation.reason)
	var kind: StringName = target.kind
	var objective_id := _objective_id(target)
	var distance := _target_distance(target)
	var security := _target_security(kind, objective_id)
	var existing := _existing_level(kind, objective_id)
	var capability_bonus := 2 if position.has_capability(CapabilityCatalog.DEEP_SCAN) else 0
	var effective_power := maxi(scanner_power, 0) + position.scan_capability + capability_bonus + int(existing / 2) - maxi(distance, 0)
	var depth := clampi(effective_power - security + 1, 1, 4)
	var cost := get_action_cost(target)
	var trace := maxi(0, security + depth - scanner_power - position.scan_capability)
	var discoveries := _discover(kind, objective_id, depth)
	var events: Array[Dictionary] = [{"type": &"SCAN_PULSE", "target_kind": kind, "depth": depth, "player_visible": true}]
	return ScanResult.new(true, kind, objective_id, depth, cost, trace, "Scan complete.", discoveries, events)

func _discover(kind: StringName, objective_id: StringName, depth: int) -> Array[Dictionary]:
	var discoveries: Array[Dictionary] = []
	if kind in [CURRENT_NODE, NODE]:
		var node := graph.get_node(objective_id)
		var level := KnowledgeLevel.Value.IDENTIFIED if depth == 1 else KnowledgeLevel.Value.SCANNED
		discoveries.append({"entity_kind": &"NODE", "entity_id": node.id, "level": level, "identity": node.display_name, "node_type": node.node_type})
		if depth >= 2:
			discoveries.append({"entity_kind": &"NODE_DETAILS", "entity_id": node.id, "owner": node.owner_faction, "security_level": node.security_level})
		if depth >= 3:
			discoveries.append({"entity_kind": &"CONNECTIONS", "entity_id": node.id, "count": node.connected_links.size()})
			for link_id in node.connected_links:
				var link := graph.get_link(link_id)
				if link.hidden and not link.discovered:
					discoveries.append({"entity_kind": &"LINK", "entity_id": link.id, "level": KnowledgeLevel.Value.DETECTED})
				else:
					discoveries.append({"entity_kind": &"LINK", "entity_id": link.id, "level": KnowledgeLevel.Value.SCANNED})
		if depth >= 2:
			for service in node.services:
				discoveries.append({"entity_kind": &"SERVICE", "entity_id": service.id, "level": KnowledgeLevel.Value.IDENTIFIED})
			for ice_id in ice_controller.instances:
				var ice := ice_controller.get_ice(ice_id)
				if ice.current_node_id == node.id:
					discoveries.append({"entity_kind": &"ICE", "entity_id": ice.instance_id, "level": KnowledgeLevel.Value.DETECTED})
		_append_endpoint_discoveries(discoveries, node.id, &"", level)
	elif kind == LINK:
		var link := graph.get_link(objective_id)
		var link_level := KnowledgeLevel.Value.IDENTIFIED if depth == 1 else KnowledgeLevel.Value.SCANNED
		discoveries.append({"entity_kind": &"LINK", "entity_id": link.id, "level": link_level})
		if depth >= 2:
			var destination_id := link.destination_from(position.current_node_id)
			if destination_id != &"":
				discoveries.append({"entity_kind": &"NODE", "entity_id": destination_id, "level": KnowledgeLevel.Value.IDENTIFIED})
	elif kind == ICE_SIGNAL:
		var ice := ice_controller.get_ice(objective_id)
		var ice_level := KnowledgeLevel.Value.IDENTIFIED if depth < 3 else KnowledgeLevel.Value.SCANNED
		discoveries.append({"entity_kind": &"ICE", "entity_id": ice.instance_id, "level": ice_level, "node_id": ice.current_node_id, "state": ice.state})
	elif kind == SERVICE:
		var service_data := _find_service(objective_id)
		var service: Dictionary = service_data.service
		var service_level := KnowledgeLevel.Value.IDENTIFIED if depth == 1 else KnowledgeLevel.Value.SCANNED
		discoveries.append({"entity_kind": &"SERVICE", "entity_id": service.id, "level": service_level, "identity": service.display_name, "security_level": service.security_level})
		if depth >= 3:
			discoveries.append({"entity_kind": &"VULNERABILITIES", "entity_id": service.id, "items": service.vulnerabilities.duplicate()})
		_append_endpoint_discoveries(discoveries, service_data.node_id, service.id, service_level)
	return discoveries


func _append_endpoint_discoveries(discoveries: Array[Dictionary], node_id: StringName, service_id: StringName, scan_level: KnowledgeLevel.Value) -> void:
	for value: Variant in realtime_endpoints.values():
		var endpoint := value as RealtimeEndpointDefinition
		if endpoint.network_node_id != node_id or endpoint.service_id != service_id:
			continue
		if not endpoint.discovery_requirement_met(scan_level):
			continue
		var process_views: Array[Dictionary] = []
		for process_id: StringName in endpoint.associated_realtime_process_ids:
			var process: RealtimeProcess = realtime_processes.get(process_id)
			if process != null:
				process_views.append({"id": process.id, "display_name": process.display_name, "process_type": process.process_type})
		discoveries.append({
			"entity_kind": &"REALTIME_ENDPOINT",
			"entity_id": endpoint.id,
			"level": KnowledgeLevel.Value.IDENTIFIED,
			"endpoint_type": endpoint.endpoint_type,
			"network_node_id": endpoint.network_node_id,
			"service_id": endpoint.service_id,
			"description": endpoint.description,
			"tags": endpoint.tags.duplicate(),
			"associated_processes": process_views,
			"accessible": endpoint.access_requirements_met(position.authority_level, position.capabilities, position.credentials),
			"authority_requirement": endpoint.authority_requirement,
			"capability_requirement": endpoint.capability_requirement,
			"access_requirement": endpoint.access_requirement,
		})

func _objective_id(target: Dictionary) -> StringName:
	match StringName(target.get("kind", &"")):
		CURRENT_NODE, NODE:
			return target.get("node_id", &"")
		LINK:
			return knowledge.resolve_link_contact(target.get("contact_id", &""))
		ICE_SIGNAL:
			return knowledge.resolve_ice_contact(target.get("contact_id", &""))
		SERVICE:
			return knowledge.resolve_service_contact(target.get("contact_id", &""))
	return &""

func _target_distance(target: Dictionary) -> int:
	var kind: StringName = target.get("kind", &"")
	if kind == CURRENT_NODE:
		return 0
	if kind == NODE:
		var node_id: StringName = target.get("node_id", &"")
		return 1 if graph.find_link(position.current_node_id, node_id) != null else -1
	if kind in [LINK, SERVICE]:
		return 0
	if kind == ICE_SIGNAL:
		var ice_id := knowledge.resolve_ice_contact(target.get("contact_id", &""))
		var record: Dictionary = knowledge.ice_records.get(ice_id, {})
		return 0 if record.get("node_id", &"") == position.current_node_id else 1
	return -1

func _target_security(kind: StringName, objective_id: StringName) -> int:
	if kind in [CURRENT_NODE, NODE]:
		var node := graph.get_node(objective_id)
		return node.security_level if node != null else 0
	if kind == LINK:
		var link := graph.get_link(objective_id)
		if link != null:
			return maxi(graph.get_node(link.source).security_level, graph.get_node(link.destination).security_level)
	if kind == ICE_SIGNAL:
		var ice := ice_controller.get_ice(objective_id)
		return ice.detection_capability if ice != null else 0
	if kind == SERVICE:
		var service_data := _find_service(objective_id)
		return int(service_data.get("service", {}).get("security_level", 0))
	return 0

func _existing_level(kind: StringName, objective_id: StringName) -> int:
	if kind in [CURRENT_NODE, NODE]: return knowledge.get_node_level(objective_id)
	if kind == LINK: return knowledge.get_link_level(objective_id)
	if kind == ICE_SIGNAL: return knowledge.get_ice_level(objective_id)
	if kind == SERVICE: return knowledge.get_service_level(objective_id)
	return KnowledgeLevel.Value.UNKNOWN

func _link_touches_current(link_id: StringName) -> bool:
	var link := graph.get_link(link_id)
	return link != null and link.connects_from(position.current_node_id)

func _find_service(service_id: StringName) -> Dictionary:
	for node_id in graph.nodes:
		for service in graph.get_node(node_id).services:
			if service.get("id", &"") == service_id:
				return {"node_id": node_id, "service": service}
	return {}
