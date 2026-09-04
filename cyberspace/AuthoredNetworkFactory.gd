class_name AuthoredNetworkFactory
extends RefCounted

static func build(document: CyberspaceContentDocument, entry_node_id: StringName = &"ENTRY", traversal_points := 100) -> Dictionary:
	var graph := NetworkGraph.new()
	for data: Dictionary in document.spheres:
		var sphere_nodes: Array[StringName] = []
		sphere_nodes.assign(data.get("node_ids", []))
		var sphere := SphereDefinition.new(data.id, data.get("display_name", data.id), sphere_nodes, data.get("original_security_sleeve_id", &""))
		sphere.metadata = (data.get("metadata", {}) as Dictionary).duplicate(true)
		graph.add_sphere(sphere)
	var services: Dictionary = {}
	for service: Dictionary in document.services: services[service.get("id", &"")] = service
	for data: Dictionary in document.network_nodes:
		var node := NetworkNodeDefinition.new(data.id, data.get("display_name", data.id), _node_type(data.get("node_type", &"SYSTEM")), int(data.get("security_level", 0)), data.get("starting_discovery_state", &"UNKNOWN") != &"UNKNOWN", data.get("owner", data.get("faction", &"")), data.get("sphere_id", &""))
		for service_id: StringName in data.get("services", []):
			var definition: Dictionary = services.get(service_id, {})
			var vulnerabilities: Array[StringName] = []
			vulnerabilities.assign(definition.get("vulnerabilities", []))
			var tags: Array[StringName] = []
			tags.assign(definition.get("tags", []))
			node.add_service(service_id, definition.get("display_name", service_id), int(definition.get("security_level", data.get("security_level", 0))), vulnerabilities, tags, definition.get("capability_types", []))
		graph.add_node(node)
	for data: Dictionary in document.security_sleeves:
		var members: Array[StringName] = []
		members.assign(data.get("current_members", []))
		var sleeve := SecuritySleeve.new(data.id, data.get("display_name", data.id), members, _sleeve_state(data.get("state", &"INTACT")))
		sleeve.metadata = (data.get("metadata", {}) as Dictionary).duplicate(true)
		graph.add_security_sleeve(sleeve)
	for data: Dictionary in document.network_links:
		var link := NetworkLinkDefinition.new(data.id, data.source, data.destination, bool(data.get("one_way", false)), bool(data.get("hidden", false)), bool(data.get("locked", false)), bool(data.get("disabled", false)), bool(data.get("discovered", not bool(data.get("hidden", false)))), int(data.get("traversal_cost", 1)), int(data.get("authority_requirement", 0)), data.get("capability_requirement", &""))
		graph.add_link(link)
	var position := PlayerNetworkPosition.new(entry_node_id, traversal_points)
	var knowledge := PlayerKnowledge.new()
	for data: Dictionary in document.network_nodes:
		var level := _knowledge_level(data.get("starting_discovery_state", &"UNKNOWN"))
		if level > KnowledgeLevel.Value.UNKNOWN: knowledge.reveal_node(graph.get_node(data.id), level)
	knowledge.mark_node_visited(graph.get_node(entry_node_id), &"INITIAL_POSITION")
	return {"graph": graph, "position": position, "knowledge": knowledge}

static func _sleeve_state(value: StringName) -> SecuritySleeve.State:
	var normalized := StringName(String(value).to_upper())
	for state: int in SecuritySleeve.State.values():
		if StringName(SecuritySleeve.State.keys()[state]) == normalized: return state
	return SecuritySleeve.State.INTACT

static func _node_type(value: StringName) -> NetworkNodeDefinition.NodeType:
	var normalized := value
	if normalized in [&"CAMERA_SERVER", &"PBX", &"ACCESS_CONTROL", &"ALARM_CONTROLLER"]: normalized = &"SYSTEM"
	for index: int in NetworkNodeDefinition.NodeType.values():
		if StringName(NetworkNodeDefinition.NodeType.keys()[index]) == normalized: return index
	return NetworkNodeDefinition.NodeType.SYSTEM

static func _knowledge_level(value: StringName) -> KnowledgeLevel.Value:
	match value:
		&"DETECTED": return KnowledgeLevel.Value.DETECTED
		&"IDENTIFIED": return KnowledgeLevel.Value.IDENTIFIED
		&"SCANNED": return KnowledgeLevel.Value.SCANNED
		&"COMPROMISED": return KnowledgeLevel.Value.COMPROMISED
	return KnowledgeLevel.Value.UNKNOWN
