class_name AuthoredNetworkRuntimeBuilder
extends RefCounted

static func build_graph(document: CyberspaceContentDocument, is_available: Callable = Callable()) -> NetworkGraph:
	var graph := NetworkGraph.new()
	for data: Dictionary in document.network_nodes:
		if not _entry_available(data, is_available): continue
		var node := NetworkNodeDefinition.new(
			StringName(data.get("id", &"")),
			String(data.get("display_name", "Unnamed Node")),
			_node_type(StringName(data.get("node_type", &"SYSTEM"))),
			int(data.get("security_level", 0)),
			false,
			StringName(data.get("owner", data.get("faction", &""))),
			StringName(data.get("sphere_id", &""))
		)
		for service_id: StringName in _string_names(data.get("services", [])):
			var service := document.find_entry(service_id)
			if not service.is_empty() and _entry_available(service, is_available):
				node.add_service(service_id, String(service.get("display_name", service_id)), int(service.get("security_level", 0)), _string_names(service.get("vulnerabilities", [])), _string_names(service.get("tags", [])))
		graph.add_node(node)
	for data: Dictionary in document.network_links:
		if not _entry_available(data, is_available): continue
		if not graph.nodes.has(StringName(data.get("source", &""))) or not graph.nodes.has(StringName(data.get("destination", &""))): continue
		graph.add_link(NetworkLinkDefinition.new(
			StringName(data.get("id", &"")), StringName(data.get("source", &"")), StringName(data.get("destination", &"")),
			bool(data.get("one_way", false)), bool(data.get("hidden", false)), bool(data.get("locked", false)), bool(data.get("disabled", false)),
			false, int(data.get("traversal_cost", 1)), int(data.get("authority_requirement", 0)), StringName(data.get("capability_requirement", &""))
		))
	return graph

static func build_player(document: CyberspaceContentDocument, graph: NetworkGraph = null) -> PlayerNetworkPosition:
	var entry := entry_node_id(document)
	if graph != null and not graph.nodes.has(entry):
		entry = StringName(graph.nodes.keys()[0]) if not graph.nodes.is_empty() else &""
	return PlayerNetworkPosition.new(entry, 30)

static func build_knowledge(document: CyberspaceContentDocument, graph: NetworkGraph) -> PlayerKnowledge:
	var knowledge := PlayerKnowledge.new()
	for data: Dictionary in document.network_nodes:
		if not graph.nodes.has(StringName(data.id)): continue
		var level := _knowledge_level(StringName(data.get("starting_discovery_state", &"UNKNOWN")))
		if level > KnowledgeLevel.Value.UNKNOWN:
			knowledge.reveal_node(graph.get_node(StringName(data.id)), level)
	var entry := entry_node_id(document)
	if graph.nodes.has(entry): knowledge.mark_node_visited(graph.get_node(entry), &"CONTENT_ENTRY")
	for data: Dictionary in document.network_links:
		if graph.links.has(StringName(data.id)) and not bool(data.get("hidden", false)) and StringName(data.get("source", &"")) == entry:
			knowledge.reveal_link(graph.get_link(StringName(data.id)), KnowledgeLevel.Value.DETECTED)
	return knowledge

static func populate_ice(document: CyberspaceContentDocument, controller: IceController, is_available: Callable = Callable()) -> void:
	var definitions := {}
	for data: Dictionary in document.ice_definitions:
		if not _entry_available(data, is_available): continue
		var definition := IceDefinition.new(StringName(data.id), String(data.get("display_name", data.id)), int(data.get("detection_capability", 1)), int(data.get("movement_cost", 1)), int(data.get("scan_capability", 1)), _string_names(data.get("patrol_route", [])), int(data.get("maximum_integrity", 6)), int(data.get("defense", 1)))
		definitions[definition.id] = definition
	for data: Dictionary in document.ice_instances:
		if not _entry_available(data, is_available): continue
		var definition: IceDefinition = definitions.get(StringName(data.get("definition_id", &"")))
		if definition != null:
			controller.add_ice(IceInstance.new(StringName(data.id), definition, StringName(data.get("initial_node_id", &"")), _ice_state(StringName(data.get("initial_state", &"DORMANT")))))

static func populate_hackers(document: CyberspaceContentDocument, manager: HackerNPCManager, is_available: Callable = Callable()) -> void:
	for data: Dictionary in document.hacker_npcs:
		if not _entry_available(data, is_available): continue
		var definition := HackerNPCDefinition.new(StringName(data.get("definition_id", data.id)), String(data.get("display_name", data.id)), String(data.get("callsign", data.get("display_name", data.id))))
		definition.faction = StringName(data.get("faction", &"INDEPENDENT"))
		definition.description = String(data.get("description", ""))
		definition.comms_channel_id = StringName(data.get("comms_channel_id", &""))
		definition.visual_signature = StringName(data.get("visual_signature", &"REMOTE_PROCESS"))
		definition.player_relationship = StringName(data.get("relationship", &"NEUTRAL"))
		definition.local_visibility_hops = int(data.get("local_visibility_hops", 1))
		definition.story_tags = _string_names(data.get("story_tags", []))
		definition.scripted_reactions.assign(document.hacker_reactions.filter(func(reaction: Dictionary) -> bool: return StringName(reaction.get("actor_id", &"")) == StringName(data.id)))
		var actor := HackerNPC.new(StringName(data.id), definition, StringName(data.get("initial_node_id", &"")))
		actor.state = _hacker_state(StringName(data.get("initial_state", &"HIDDEN")))
		actor.visible_signature = actor.state == HackerNPC.State.CONNECTED
		manager.add_actor(actor)
	manager.configure_tutorial_guidance(document.tutorial_guidance_rules)

static func _entry_available(data: Dictionary, is_available: Callable) -> bool:
	return not is_available.is_valid() or bool(is_available.call(StringName(data.get("id", &""))))

static func entry_node_id(document: CyberspaceContentDocument) -> StringName:
	for data: Dictionary in document.network_nodes:
		if &"ENTRY" in _string_names(data.get("tags", [])): return StringName(data.id)
	return StringName(document.network_nodes[0].id) if not document.network_nodes.is_empty() else &""

static func _node_type(id: StringName) -> NetworkNodeDefinition.NodeType:
	var key := String(id)
	if key in ["GATEWAY"]: return NetworkNodeDefinition.NodeType.GATEWAY
	if key in ["ROUTER"]: return NetworkNodeDefinition.NodeType.ROUTER
	if key in ["WORKSTATION"]: return NetworkNodeDefinition.NodeType.WORKSTATION
	if key in ["AUTH_SERVER"]: return NetworkNodeDefinition.NodeType.AUTH_SERVER
	if key in ["FILE_SERVER"]: return NetworkNodeDefinition.NodeType.FILE_SERVER
	if key in ["SECURITY", "SECURITY_SERVER"]: return NetworkNodeDefinition.NodeType.SECURITY_SERVER
	if key in ["SERVICE_CLUSTER"]: return NetworkNodeDefinition.NodeType.SERVICE_CLUSTER
	return NetworkNodeDefinition.NodeType.SYSTEM

static func _knowledge_level(id: StringName) -> KnowledgeLevel.Value:
	match id:
		&"SCANNED": return KnowledgeLevel.Value.SCANNED
		&"IDENTIFIED": return KnowledgeLevel.Value.IDENTIFIED
		&"DETECTED": return KnowledgeLevel.Value.DETECTED
		_: return KnowledgeLevel.Value.UNKNOWN

static func _ice_state(id: StringName) -> IceState.Value:
	var index := IceState.Value.keys().find(String(id))
	return index as IceState.Value if index >= 0 else IceState.Value.DORMANT

static func _hacker_state(id: StringName) -> HackerNPC.State:
	var index := HackerNPC.State.keys().find(String(id))
	return index as HackerNPC.State if index >= 0 else HackerNPC.State.HIDDEN

static func _string_names(values: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if values is Array:
		for value: Variant in values: result.append(StringName(value))
	return result
