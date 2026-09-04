class_name TestNetworkFactory
extends RefCounted

const PUBLIC_GATEWAY := &"PUBLIC_GATEWAY"
const ROUTER_A := &"ROUTER_A"
const WORKSTATION_01 := &"WORKSTATION_01"
const WORKSTATION_02 := &"WORKSTATION_02"
const AUTH_SERVER := &"AUTH_SERVER"
const FILE_SERVER := &"FILE_SERVER"
const SECURITY_SERVER := &"SECURITY_SERVER"

static func create_graph() -> NetworkGraph:
	var graph := NetworkGraph.new()
	graph.add_node(NetworkNodeDefinition.new(PUBLIC_GATEWAY, "Public Gateway", NetworkNodeDefinition.NodeType.GATEWAY, 0, true, &"PUBLIC"))
	graph.add_node(NetworkNodeDefinition.new(ROUTER_A, "Router A", NetworkNodeDefinition.NodeType.ROUTER, 1, true, &"CORP"))
	graph.add_node(NetworkNodeDefinition.new(WORKSTATION_01, "Workstation 01", NetworkNodeDefinition.NodeType.WORKSTATION, 1, true, &"CORP"))
	graph.add_node(NetworkNodeDefinition.new(WORKSTATION_02, "Workstation 02", NetworkNodeDefinition.NodeType.WORKSTATION, 1, true, &"CORP"))
	graph.add_node(NetworkNodeDefinition.new(AUTH_SERVER, "Authentication Server", NetworkNodeDefinition.NodeType.AUTH_SERVER, 3, true, &"CORP"))
	graph.add_node(NetworkNodeDefinition.new(FILE_SERVER, "File Server", NetworkNodeDefinition.NodeType.FILE_SERVER, 2, true, &"CORP"))
	graph.add_node(NetworkNodeDefinition.new(SECURITY_SERVER, "Security Server", NetworkNodeDefinition.NodeType.SECURITY_SERVER, 4, false, &"SECURITY"))
	graph.get_node(PUBLIC_GATEWAY).add_service(&"PUBLIC_RELAY", "Public Relay", 0)
	graph.get_node(AUTH_SERVER).add_service(&"AUTH_DAEMON", "Authentication Daemon", 3, [&"LEGACY_TOKEN"])
	graph.get_node(FILE_SERVER).add_service(&"FILE_INDEX", "File Index", 2, [&"STALE_ACL"])
	graph.get_node(SECURITY_SERVER).add_service(&"ICE_ORCHESTRATOR", "ICE Orchestrator", 4)
	graph.get_node(SECURITY_SERVER).recommended_capabilities.append(CapabilityCatalog.TRACE_SCRAMBLER)
	graph.add_link(NetworkLinkDefinition.new(&"GATEWAY_ROUTER", PUBLIC_GATEWAY, ROUTER_A, false, false, false, false, true, 1))
	graph.add_link(NetworkLinkDefinition.new(&"ROUTER_WS01", ROUTER_A, WORKSTATION_01, false, false, false, false, true, 1))
	graph.add_link(NetworkLinkDefinition.new(&"ROUTER_WS02", ROUTER_A, WORKSTATION_02, false, false, false, false, true, 2))
	graph.add_link(NetworkLinkDefinition.new(&"ROUTER_AUTH", ROUTER_A, AUTH_SERVER, false, false, true, false, true, 2, 2))
	graph.add_link(NetworkLinkDefinition.new(&"WS01_FILES", WORKSTATION_01, FILE_SERVER, true, false, false, false, true, 2))
	graph.add_link(NetworkLinkDefinition.new(&"WS02_FILES", WORKSTATION_02, FILE_SERVER, false, false, false, true, true, 1))
	graph.add_link(NetworkLinkDefinition.new(&"AUTH_SECURITY", AUTH_SERVER, SECURITY_SERVER, false, true, false, false, false, 3, 3, CapabilityCatalog.LEGACY_PROTOCOL))
	return graph

static func create_player(starting_points := 10) -> PlayerNetworkPosition:
	return PlayerNetworkPosition.new(PUBLIC_GATEWAY, starting_points)

static func create_player_knowledge(graph: NetworkGraph) -> PlayerKnowledge:
	var knowledge := PlayerKnowledge.new()
	knowledge.reveal_node(graph.get_node(PUBLIC_GATEWAY), KnowledgeLevel.Value.SCANNED)
	knowledge.mark_node_visited(graph.get_node(PUBLIC_GATEWAY), &"INITIAL_POSITION")
	knowledge.reveal_node(graph.get_node(ROUTER_A), KnowledgeLevel.Value.IDENTIFIED)
	knowledge.reveal_link(graph.get_link(&"GATEWAY_ROUTER"), KnowledgeLevel.Value.SCANNED)
	# Prior intelligence detects several contacts without exposing their identities.
	knowledge.detect_link(graph.get_link(&"ROUTER_WS01"))
	knowledge.detect_link(graph.get_link(&"ROUTER_WS02"))
	knowledge.detect_link(graph.get_link(&"ROUTER_AUTH"))
	return knowledge
