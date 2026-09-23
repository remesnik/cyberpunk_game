class_name AuthoredNetworkRuntimeBuilder
extends RefCounted

static func build_graph(document: CyberspaceContentDocument, is_available: Callable = Callable()) -> NetworkGraph:
	var graph := NetworkGraph.new()
	for data: Dictionary in document.spheres:
		if not _entry_available(data, is_available): continue
		graph.add_sphere(SphereDefinition.new(StringName(data.get("id", &"")), String(data.get("display_name", data.get("name", "Sphere"))), [], StringName(data.get("original_security_sleeve_id", &""))))
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
		node.network_type = StringName(data.get("network_type", data.get("node_type", &"SYSTEM"))).to_upper()
		var family_name := StringName(data.get("security_family", &"VIRAL")).to_upper()
		var family_index := NetworkNodeDefinition.SecurityFamily.keys().find(String(family_name))
		node.security_family = (family_index as NetworkNodeDefinition.SecurityFamily) if family_index >= 0 else NetworkNodeDefinition.SecurityFamily.VIRAL
		node.difficulty_rating = maxi(0, int(data.get("difficulty_rating", data.get("security_level", 0))))
		var authored_position: Array = data.get("authored_position", [])
		if authored_position.size() >= 3:
			node.authored_position = Vector3(float(authored_position[0]), float(authored_position[1]), float(authored_position[2]))
			node.has_authored_position = true
		for service_id: StringName in _string_names(data.get("services", [])):
			var service := document.find_entry(service_id)
			if not service.is_empty() and _entry_available(service, is_available):
				node.add_service_record(service)
		for control_data: Dictionary in data.get("outbound_path_controls", data.get("path_controls", [])): node.add_path_control(NodePathControl.from_authored(control_data))
		graph.add_node(node)
	for data: Dictionary in document.security_sleeves:
		if not _entry_available(data, is_available): continue
		var state_name := StringName(String(data.get("state", &"INTACT")).to_upper()); var state_index := SecuritySleeve.State.keys().find(String(state_name))
		var sleeve := SecuritySleeve.new(StringName(data.get("id", &"")), String(data.get("display_name", "Security Sleeve")), _string_names(data.get("current_members", [])), state_index as SecuritySleeve.State if state_index >= 0 else SecuritySleeve.State.INTACT)
		sleeve.metadata = (data.get("metadata", {}) as Dictionary).duplicate(true); sleeve.security_count = int(data.get("security_count", sleeve.metadata.get("security_count", 0)))
		graph.add_security_sleeve(sleeve)
	for data: Dictionary in document.network_links:
		if not _entry_available(data, is_available): continue
		if not graph.nodes.has(StringName(data.get("source", &""))) or not graph.nodes.has(StringName(data.get("destination", &""))): continue
		var link := NetworkLinkDefinition.new(
			StringName(data.get("id", &"")), StringName(data.get("source", &"")), StringName(data.get("destination", &"")),
			bool(data.get("one_way", false)), bool(data.get("hidden", false)), bool(data.get("locked", false)) and (data.get("directions", []) as Array).is_empty(), bool(data.get("disabled", false)),
			false, int(data.get("traversal_cost", 1)), int(data.get("authority_requirement", 0)), StringName(data.get("capability_requirement", &""))
		)
		var gate_name := StringName(data.get("traversal_gate", data.get("gate", &"NONE"))).to_upper()
		var gate_index := NetworkLinkDefinition.TraversalGateType.keys().find(String(gate_name))
		if gate_index >= 0: link.traversal_gate_type = gate_index as NetworkLinkDefinition.TraversalGateType
		link.traversal_requirement = (data.get("traversal_requirement", data.get("requirement", {})) as Dictionary).duplicate(true)
		link.blocked_reason = String(data.get("blocked_reason", "ACCESS REQUIREMENT NOT MET"))
		if link.traversal_gate_type == NetworkLinkDefinition.TraversalGateType.ONE_WAY: link.one_way = true
		for direction_data: Dictionary in data.get("directions", []): link.configure_direction(direction_data.get("source", link.source), direction_data.get("destination", link.destination), direction_data)
		graph.add_link(link)
	_apply_path_security_overrides(document, graph)
	return graph

static func _apply_path_security_overrides(document: CyberspaceContentDocument, graph: NetworkGraph) -> void:
	for data: Dictionary in document.path_security_overrides:
		var link := graph.get_link(StringName(data.get("link_id", &"")))
		if link == null: continue
		var direction := link.get_direction(StringName(data.get("source", &"")), StringName(data.get("destination", &"")))
		if direction != null: direction.apply_authored(data)

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
		if StringName(String(data.get("binding_mode", &"ROAMING")).to_upper()) == &"HOST_BOUND": definition.binding_mode = IceDefinition.BindingMode.HOST_BOUND
		definition.allowed_binding_node_ids.assign(data.get("allowed_binding_node_ids", []))
		definitions[definition.id] = definition
	for data: Dictionary in document.ice_instances:
		if not _entry_available(data, is_available): continue
		var definition: IceDefinition = definitions.get(StringName(data.get("definition_id", &"")))
		if definition != null:
			var instance := IceInstance.new(StringName(data.id), definition, StringName(data.get("initial_node_id", &"")), _ice_state(StringName(data.get("initial_state", &"DORMANT"))))
			instance.sphere_id = StringName(data.get("sphere_id", &""))
			instance.security_sleeve_id = StringName(data.get("security_sleeve_id", &""))
			instance.operational = bool(data.get("initially_active", true))
			instance.alert_level = clampi(int(data.get("initial_alert_level", 0)), 0, 100)
			controller.add_ice(instance)

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

static func populate_realtime(document: CyberspaceContentDocument, process_manager: RealtimeProcessManager, comms: CommsInterceptionManager, knowledge: PlayerKnowledge, position: PlayerNetworkPosition) -> void:
	for data: Dictionary in document.realtime_processes:
		var type_name := StringName(data.get("process_type", &"CUSTOM"))
		var type_index := RealtimeProcess.ProcessType.keys().find(String(type_name))
		var process := RealtimeProcess.new(data.id, type_index as RealtimeProcess.ProcessType if type_index >= 0 else RealtimeProcess.ProcessType.CUSTOM, data.get("display_name", data.id), data.get("source_id", &""), float(data.get("duration", -1.0)))
		process.metadata = (data.get("metadata", {}) as Dictionary).duplicate(true)
		process.tags.assign(data.get("tags", []))
		process_manager.add_process(process, bool(data.get("initially_active", true)))
	for data: Dictionary in document.realtime_endpoints:
		var type_name := StringName(data.get("endpoint_type", &"CUSTOM"))
		var type_index := RealtimeEndpointDefinition.EndpointType.keys().find(String(type_name))
		var process_ids: Array[StringName] = []; process_ids.assign(data.get("associated_realtime_process_ids", []))
		var endpoint := RealtimeEndpointDefinition.new(data.id, type_index as RealtimeEndpointDefinition.EndpointType if type_index >= 0 else RealtimeEndpointDefinition.EndpointType.CUSTOM, data.get("network_node_id", data.get("node_id", &"")), data.get("service_id", &""), process_ids)
		process_manager.add_endpoint(endpoint)
	comms.configure(process_manager, knowledge, position)
	for data: Dictionary in document.comms_channels:
		var type_name := StringName(data.get("channel_type", &"CUSTOM"))
		var type_index := CommsChannelDefinition.ChannelType.keys().find(String(type_name))
		var channel := CommsChannelDefinition.new(data.id, data.get("display_name", data.id), type_index as CommsChannelDefinition.ChannelType if type_index >= 0 else CommsChannelDefinition.ChannelType.CUSTOM, data.get("source_endpoint_id", &""))
		channel.participant_ids.assign(data.get("participant_ids", []))
		if bool(data.get("allow_monitor", true)): channel.set_access_policy(CommsAccessResult.Operation.MONITOR)
		if bool(data.get("allow_intercept", true)): channel.set_access_policy(CommsAccessResult.Operation.INTERCEPT)
		comms.add_channel(channel)
	for data: Dictionary in document.comms_sessions:
		var session := CommsSession.new(data.id, data.get("channel_id", &""), data.get("realtime_process_id", &""))
		session.duration = float(data.get("duration", -1.0)); session.story_tags.assign(data.get("tags", []))
		for line: Dictionary in data.get("timeline", []): session.add_transcript_line(float(line.get("time", 0.0)), line.get("speaker_id", &""), line.get("text", ""), line.get("story_event_id", &""))
		comms.add_session(session)

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
