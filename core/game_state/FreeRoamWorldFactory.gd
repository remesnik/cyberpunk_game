class_name FreeRoamWorldFactory
extends RefCounted

const HOME_UPLINK := &"HOME_UPLINK"
const PUBLIC_EXCHANGE := &"PUBLIC_EXCHANGE"
const JOB_BROKER := &"JOB_BROKER"
const SOFTWARE_BAZAAR := &"SOFTWARE_BAZAAR"
const INDUSTRIAL_GATE := &"INDUSTRIAL_GATE"
const LOGISTICS_RELAY := &"LOGISTICS_RELAY"
const SECURITY_HUB := &"SECURITY_HUB"
const ARCHIVE_NODE := &"ARCHIVE_NODE"

static func create_graph() -> NetworkGraph:
	var graph := NetworkGraph.new()
	graph.add_sphere(SphereDefinition.new(&"PUBLIC_MESH", "Public Mesh", [], &"PUBLIC_SLEEVE"))
	graph.add_sphere(SphereDefinition.new(&"INDUSTRIAL_MESH", "Industrial Mesh", [], &"INDUSTRIAL_SLEEVE"))
	_add_node(graph, HOME_UPLINK, "Home Uplink", NetworkNodeDefinition.NodeType.GATEWAY, 0, &"PUBLIC_MESH", &"LOCAL")
	_add_node(graph, PUBLIC_EXCHANGE, "Public Exchange", NetworkNodeDefinition.NodeType.ROUTER, 1, &"PUBLIC_MESH", &"OPEN_NET")
	_add_node(graph, JOB_BROKER, "Contract Broker", NetworkNodeDefinition.NodeType.SERVICE_CLUSTER, 1, &"PUBLIC_MESH", &"INDEPENDENT")
	_add_node(graph, SOFTWARE_BAZAAR, "Software Bazaar", NetworkNodeDefinition.NodeType.FILE_SERVER, 1, &"PUBLIC_MESH", &"INDEPENDENT")
	_add_node(graph, INDUSTRIAL_GATE, "Industrial Gateway", NetworkNodeDefinition.NodeType.GATEWAY, 2, &"INDUSTRIAL_MESH", &"CIVIC_LOGISTICS")
	_add_node(graph, LOGISTICS_RELAY, "Logistics Relay", NetworkNodeDefinition.NodeType.ROUTER, 2, &"INDUSTRIAL_MESH", &"CIVIC_LOGISTICS")
	_add_node(graph, SECURITY_HUB, "Security Hub", NetworkNodeDefinition.NodeType.SECURITY_SERVER, 3, &"INDUSTRIAL_MESH", &"PRIVATE_SECURITY")
	_add_node(graph, ARCHIVE_NODE, "Freight Archive", NetworkNodeDefinition.NodeType.FILE_SERVER, 2, &"INDUSTRIAL_MESH", &"CIVIC_LOGISTICS")
	graph.get_node(JOB_BROKER).add_service(&"PUBLIC_JOB_EXCHANGE", "Public Job Exchange", 0, [], [&"JOBS", &"SHARED"])
	graph.get_node(SOFTWARE_BAZAAR).add_service(&"PROGRAMMING_REPOSITORY", "Programming Repository", 1, [], [&"SOFTWARE", &"VENDOR"])
	graph.get_node(LOGISTICS_RELAY).add_service(&"FREIGHT_TELEMETRY", "Freight Telemetry", 2, [], [&"FEED", &"MEATSPACE"])
	graph.get_node(LOGISTICS_RELAY).add_service(&"WAREHOUSE_CONTROL", "Warehouse Control", 2, [], [&"CONTROL_SYSTEM", &"MEATSPACE"])
	graph.get_node(ARCHIVE_NODE).add_service(&"FREIGHT_DATASTORE", "Freight Datastore", 2, [], [&"DATASTORE"])
	graph.get_node(ARCHIVE_NODE).add_service(&"FREIGHT_DATABASE", "Freight Database", 2, [], [&"DATABASE"])
	_link(graph, &"HOME_EXCHANGE", HOME_UPLINK, PUBLIC_EXCHANGE, 1)
	_link(graph, &"EXCHANGE_BROKER", PUBLIC_EXCHANGE, JOB_BROKER, 1)
	_link(graph, &"EXCHANGE_BAZAAR", PUBLIC_EXCHANGE, SOFTWARE_BAZAAR, 1)
	_link(graph, &"EXCHANGE_INDUSTRIAL", PUBLIC_EXCHANGE, INDUSTRIAL_GATE, 2)
	_link(graph, &"INDUSTRIAL_LOGISTICS", INDUSTRIAL_GATE, LOGISTICS_RELAY, 1)
	_link(graph, &"LOGISTICS_SECURITY", LOGISTICS_RELAY, SECURITY_HUB, 2)
	_link(graph, &"LOGISTICS_ARCHIVE", LOGISTICS_RELAY, ARCHIVE_NODE, 1)
	graph.add_security_sleeve(SecuritySleeve.new(&"PUBLIC_SLEEVE", "Public Mesh Sleeve", [HOME_UPLINK, PUBLIC_EXCHANGE, JOB_BROKER, SOFTWARE_BAZAAR]))
	graph.add_security_sleeve(SecuritySleeve.new(&"INDUSTRIAL_SLEEVE", "Industrial Mesh Sleeve", [INDUSTRIAL_GATE, LOGISTICS_RELAY, SECURITY_HUB, ARCHIVE_NODE]))
	return graph

static func create_player() -> PlayerNetworkPosition:
	return PlayerNetworkPosition.new(HOME_UPLINK, 30)

static func create_knowledge(graph: NetworkGraph) -> PlayerKnowledge:
	var knowledge := PlayerKnowledge.new()
	knowledge.reveal_node(graph.get_node(HOME_UPLINK), KnowledgeLevel.Value.SCANNED)
	knowledge.mark_node_visited(graph.get_node(HOME_UPLINK), &"FREE_ROAM_HOME_UPLINK")
	knowledge.reveal_node(graph.get_node(PUBLIC_EXCHANGE), KnowledgeLevel.Value.IDENTIFIED)
	knowledge.reveal_link(graph.get_link(&"HOME_EXCHANGE"), KnowledgeLevel.Value.SCANNED)
	knowledge.reveal_sphere_identity(graph.get_sphere(&"PUBLIC_MESH"), &"STARTER_NETWORK_DIRECTORY")
	return knowledge

static func populate_ice(controller: IceController) -> void:
	var definition := IceDefinition.new(&"INDUSTRIAL_PATROL", "Industrial Patrol", 2, 2, 2, [SECURITY_HUB, LOGISTICS_RELAY, ARCHIVE_NODE], 8, 1)
	controller.add_ice(IceInstance.new(&"INDUSTRIAL_PATROL_01", definition, SECURITY_HUB, IceState.Value.PATROL))

static func _add_node(graph: NetworkGraph, id: StringName, name: String, type: NetworkNodeDefinition.NodeType, level: int, sphere: StringName, owner: StringName) -> void:
	graph.add_node(NetworkNodeDefinition.new(id, name, type, level, false, owner, sphere))

static func _link(graph: NetworkGraph, id: StringName, source: StringName, destination: StringName, cost: int) -> void:
	graph.add_link(NetworkLinkDefinition.new(id, source, destination, false, false, false, false, true, cost))
