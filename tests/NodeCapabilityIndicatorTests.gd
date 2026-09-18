extends SceneTree

const CATALOG := preload("res://cyberspace/display/node_capability_catalog.tres")
const VISUAL_CONFIG := preload("res://cyberspace/display/cyberspace_visualization_config.tres")
const SOCKET_SCRIPT := preload("res://cyberspace/display/NodeCapabilitySocket.gd")

var failures := 0
var assertions := 0

func _init() -> void:
	_test_catalog_derivation()
	_test_knowledge_gating()
	_test_uncertain_contents()
	_test_capability_aggregation()
	_test_visual_uses_sanitized_capabilities()
	print("%s: %d node capability indicator assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _test_catalog_derivation() -> void:
	var camera: Array[Dictionary] = [{"tags": [&"VIDEO", &"SECURITY"]}]
	var camera_types := CATALOG.derive_from_services(camera)
	_expect(camera_types.has(NodeCapabilityType.Value.FEED), "camera service derives FEED")
	_expect(camera_types.has(NodeCapabilityType.Value.MEATSPACE), "camera service derives MEATSPACE")
	_expect(camera_types.has(NodeCapabilityType.Value.CONTROL_SYSTEM), "camera service derives CONTROL_SYSTEM")
	_expect(camera_types.has(NodeCapabilityType.Value.SECURITY), "camera service derives SECURITY")
	var communications: Array[Dictionary] = [{"tags": [&"COMMS"]}]
	var communications_types := CATALOG.derive_from_services(communications)
	_expect(communications_types.has(NodeCapabilityType.Value.IO) and communications_types.has(NodeCapabilityType.Value.COMMUNICATIONS), "communications relay derives IO and COMMUNICATIONS")
	var database: Array[Dictionary] = [{"capability_types": [&"DATABASE", &"DATASTORE", &"CREDENTIALS"]}]
	var database_types := CATALOG.derive_from_services(database)
	_expect(database_types == [NodeCapabilityType.Value.DATABASE, NodeCapabilityType.Value.DATASTORE, NodeCapabilityType.Value.CREDENTIALS], "explicit broad capabilities remain ordered by catalog priority")
	_expect(CATALOG.definitions.size() == NodeCapabilityType.Value.size(), "vector icon catalog covers every capability type")
	var theme: Resource = VISUAL_CONFIG.capability_icon_theme
	_expect(theme.color_for(CATALOG.definition_for(NodeCapabilityType.Value.IO).palette_role) == theme.color_for(CATALOG.definition_for(NodeCapabilityType.Value.DATABASE).palette_role), "standard icons share the common palette instead of arbitrary per-icon colors")
	_expect(theme.color_for(CATALOG.definition_for(NodeCapabilityType.Value.ICE).palette_role) == theme.hostile_color, "hostile ICE uses the shared hostile palette role")

func _test_knowledge_gating() -> void:
	var node := NetworkNodeDefinition.new(&"CAM_CTL", "Camera Control", NetworkNodeDefinition.NodeType.SYSTEM, 2)
	node.add_service(&"CAMERA_MATRIX", "Camera Matrix", 2, [], [&"VIDEO", &"SECURITY"])
	var knowledge := PlayerKnowledge.new()
	knowledge.discover_node(node)
	_expect(knowledge.get_known_node_capabilities(node.id).is_empty(), "merely seeing a node does not reveal hosted capabilities")
	knowledge.reveal_node_level(node, &"INTELLIGENCE")
	_expect(knowledge.get_known_node_capabilities(node.id).is_empty(), "knowing security level does not reveal contents")
	knowledge.reveal_node_contents(node)
	_expect(knowledge.get_known_node_capabilities(node.id).has(NodeCapabilityType.Value.FEED), "known contents expose derived broad capabilities")
	knowledge.reveal_node_capability(node.id, NodeCapabilityType.Value.SYSTEM_ACCESS_NODE, &"SAN_OBSERVATION")
	_expect(knowledge.get_known_node_capabilities(node.id).has(NodeCapabilityType.Value.SYSTEM_ACCESS_NODE), "hosted entities can reveal an individual capability generically")

func _test_uncertain_contents() -> void:
	var node := NetworkNodeDefinition.new(&"NODE_12", "Node 12", NetworkNodeDefinition.NodeType.SYSTEM, 3)
	var service_a := {"id": &"SERVICE_A", "display_name": "Unknown A", "security_level": 2, "tags": [&"DATABASE"]}
	var service_b := {"id": &"SERVICE_B", "display_name": "Unknown B", "security_level": 1, "tags": [&"COMMS"]}
	node.services.assign([service_a, service_b])
	var knowledge := PlayerKnowledge.new()
	knowledge.reveal_uncertain_node_contents(node.id, 2, &"INTERCEPTED_COUNT")
	_expect(knowledge.get_unknown_node_content_count(node.id) == 2, "intelligence can reveal a count without revealing categories")
	_expect(knowledge.get_known_node_capabilities(node.id).is_empty(), "uncertain content does not leak actual capability icons")
	var graph := NetworkGraph.new()
	graph.add_node(node)
	var position := PlayerNetworkPosition.new(node.id)
	var ice := IceController.new(graph, position, knowledge)
	var scan_discoveries: Array[Dictionary] = [{"entity_kind": &"NODE_CONTENT_COUNT", "entity_id": node.id, "count": 3}]
	knowledge.commit_scan(ScanResult.new(true, &"NODE", node.id, 1, 1, 0, "", scan_discoveries), graph, ice)
	_expect(knowledge.get_unknown_node_content_count(node.id) == 3, "structured scan discoveries use the same uncertain-content knowledge record")
	knowledge.reveal_uncertain_node_contents(node.id, 2, &"INTERCEPTED_COUNT")
	knowledge.reveal_service(service_a, node.id, KnowledgeLevel.Value.IDENTIFIED)
	_expect(knowledge.get_unknown_node_content_count(node.id) == 2, "identifying one hosted service resolves one uncertain item")
	_expect(knowledge.get_known_node_capabilities(node.id) == [NodeCapabilityType.Value.DATABASE], "identified service replaces uncertainty with only its derived capability")
	knowledge.reveal_node_contents(node, &"SCAN")
	_expect(knowledge.get_unknown_node_content_count(node.id) == 0, "revealing full node contents clears aggregate uncertainty")

func _test_capability_aggregation() -> void:
	var node := NetworkNodeDefinition.new(&"FEED_HUB", "Feed Hub", NetworkNodeDefinition.NodeType.SYSTEM, 2)
	for index in 4:
		node.add_service(StringName("FEED_%d" % index), "Feed %d" % index, 1, [], [&"VIDEO"])
	var knowledge := PlayerKnowledge.new()
	knowledge.reveal_uncertain_node_contents(node.id, 4)
	knowledge.reveal_service(node.services[0], node.id, KnowledgeLevel.Value.IDENTIFIED)
	knowledge.reveal_service(node.services[1], node.id, KnowledgeLevel.Value.IDENTIFIED)
	var partial_counts := knowledge.get_known_node_capability_counts(node.id)
	_expect(partial_counts.get(NodeCapabilityType.Value.FEED, 0) == 2, "two discovered feeds aggregate to FEED x2")
	_expect(knowledge.get_unknown_node_content_count(node.id) == 2, "undiscovered feeds remain uncertain rather than inflating the known count")
	knowledge.reveal_service(node.services[0], node.id, KnowledgeLevel.Value.SCANNED)
	_expect(knowledge.get_known_node_capability_counts(node.id).get(NodeCapabilityType.Value.FEED, 0) == 2, "rescanning one service does not double-count its category")
	knowledge.reveal_node_contents(node)
	_expect(knowledge.get_known_node_capability_counts(node.id).get(NodeCapabilityType.Value.FEED, 0) == 4, "full contents knowledge aggregates all four feeds into one category count")

func _test_visual_uses_sanitized_capabilities() -> void:
	var visual := NodeVisual.new()
	visual.apply_visualization_config(VISUAL_CONFIG)
	visual.configure_view({"id": &"COMMS", "display_name": "Comms", "identity_known": true, "capability_types": [NodeCapabilityType.Value.IO, NodeCapabilityType.Value.COMMUNICATIONS]}, false, true, false)
	var definitions := visual.capability_definitions()
	_expect(definitions.size() == 2 and definitions.any(func(definition): return definition.glyph == "IO") and definitions.any(func(definition): return definition.glyph == "CM"), "node visual renders catalog definitions supplied by PlayerKnowledge")
	var socket_assignments := visual.capability_socket_assignments()
	_expect(socket_assignments.size() == 2 and socket_assignments[0].socket == 6 and socket_assignments[1].socket == 10, "capabilities use their fixed preferred sockets rather than count-based offsets")
	_expect(socket_assignments == visual.capability_socket_assignments(), "socket assignment is deterministic across renders")
	visual.capability_counts = {NodeCapabilityType.Value.COMMUNICATIONS: 3, NodeCapabilityType.Value.IO: 3}
	visual.configure_view({"id": &"COMMS", "display_name": "Comms", "identity_known": true, "capability_types": [NodeCapabilityType.Value.IO, NodeCapabilityType.Value.COMMUNICATIONS], "capability_counts": {NodeCapabilityType.Value.IO: 3, NodeCapabilityType.Value.COMMUNICATIONS: 3}}, false, true, false)
	var counted_assignments := visual.capability_socket_assignments()
	_expect(counted_assignments.size() == 2 and counted_assignments.all(func(assignment): return assignment.count == 3), "renderer emits one socket per category with its known aggregate count")
	var socket_controls := visual.get_children().filter(func(child): return child.get_script() == SOCKET_SCRIPT)
	_expect(socket_controls.size() == 2, "each occupied icon socket receives one lightweight interactive hit target")
	var comms_socket: Control = socket_controls.filter(func(child): return child.capability_type == NodeCapabilityType.Value.COMMUNICATIONS)[0]
	_expect(comms_socket.tooltip_text.contains("COMMUNICATIONS") and comms_socket.tooltip_text.contains("×3"), "capability tooltip explains the known aggregate without listing hidden services")
	var activated := [false]
	visual.capability_selected.connect(func(selected_node: StringName, capability: int) -> void: activated[0] = selected_node == &"COMMS" and capability == NodeCapabilityType.Value.COMMUNICATIONS)
	comms_socket.activated.emit(NodeCapabilityType.Value.COMMUNICATIONS)
	_expect(activated[0], "icon activation routes through the node capability selection interface")
	var center := Vector2(140, 100)
	var radius: float = VISUAL_CONFIG.radius(false)
	for assignment: Dictionary in socket_assignments:
		var badge_center: Vector2 = visual.capability_socket_position(assignment.socket, center, radius)
		_expect(badge_center.distance_to(center) - VISUAL_CONFIG.capability_indicator_radius > radius * 0.8, "socket badge remains beyond its hex edge")
	var all_capabilities: Array[int] = []
	for value: int in NodeCapabilityType.Value.values(): all_capabilities.append(value)
	visual.capability_types = all_capabilities
	var crowded := visual.capability_socket_assignments()
	_expect(crowded.size() == 12, "node renders at most twelve occupied sockets")
	_expect(crowded[0].capability_type == NodeCapabilityType.Value.SYSTEM_ACCESS_NODE and crowded[1].capability_type == NodeCapabilityType.Value.OBJECTIVE, "crowded sockets honor stable capability priority")
	_expect(not crowded.any(func(assignment): return assignment.capability_type == NodeCapabilityType.Value.CREDENTIALS or assignment.capability_type == NodeCapabilityType.Value.ACTIVE_PROCESS), "lowest-priority capabilities yield when all twelve sockets are occupied")
	visual.configure_view({"id": &"UNKNOWN_CONTENTS", "display_name": "Host", "identity_known": true}, false, true, false)
	_expect(visual.capability_definitions().is_empty(), "node visual does not derive or leak authoritative contents")
	visual.configure_view({"id": &"UNCERTAIN", "display_name": "Host", "identity_known": true, "unknown_content_count": 2}, false, true, false)
	var uncertain_assignments := visual.capability_socket_assignments()
	_expect(uncertain_assignments.size() == 1 and uncertain_assignments[0].kind == &"UNKNOWN_CONTENT" and uncertain_assignments[0].count == 2, "two unidentified items render as one aggregate uncertain socket")
	visual.free()

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
