class_name FacilityOperationFactory
extends RefCounted

const PUBLIC_GATEWAY := &"PUBLIC_GATEWAY"
const CORP_ROUTER := &"CORP_ROUTER"
const SECURITY_NET := &"SECURITY_NET"
const CAMERA_SERVER := &"CAMERA_SERVER"
const ACCESS_CONTROL := &"ACCESS_CONTROL"
const PBX_SERVER := &"PBX_SERVER"
const ALARM_CONTROLLER := &"ALARM_CONTROLLER"


static func create_graph() -> NetworkGraph:
	var graph := NetworkGraph.new()
	graph.add_node(NetworkNodeDefinition.new(PUBLIC_GATEWAY, "Public Gateway", NetworkNodeDefinition.NodeType.GATEWAY, 0, true, &"PUBLIC"))
	graph.add_node(NetworkNodeDefinition.new(CORP_ROUTER, "Corporate Router", NetworkNodeDefinition.NodeType.ROUTER, 1, true, &"NORTHSTAR_CORP"))
	graph.add_node(NetworkNodeDefinition.new(SECURITY_NET, "Security Network", NetworkNodeDefinition.NodeType.SECURITY_SERVER, 2, false, &"NORTHSTAR_SECURITY"))
	graph.add_node(NetworkNodeDefinition.new(CAMERA_SERVER, "Camera Server", NetworkNodeDefinition.NodeType.SYSTEM, 2, false, &"NORTHSTAR_SECURITY"))
	graph.add_node(NetworkNodeDefinition.new(ACCESS_CONTROL, "Access Control", NetworkNodeDefinition.NodeType.SYSTEM, 2, false, &"NORTHSTAR_SECURITY"))
	graph.add_node(NetworkNodeDefinition.new(PBX_SERVER, "PBX Server", NetworkNodeDefinition.NodeType.SYSTEM, 2, false, &"NORTHSTAR_CORP"))
	graph.add_node(NetworkNodeDefinition.new(ALARM_CONTROLLER, "Alarm Controller", NetworkNodeDefinition.NodeType.SYSTEM, 2, false, &"NORTHSTAR_SECURITY"))

	graph.get_node(PUBLIC_GATEWAY).add_service(&"ANCHOR_RELAY", "Anchor Relay", 0)
	graph.get_node(CORP_ROUTER).add_service(&"CORP_ROUTING", "Corporate Routing Fabric", 1, [&"ROUTE_ENUMERATION"])
	graph.get_node(SECURITY_NET).add_service(&"SECURITY_DIRECTORY", "Security Service Directory", 2, [&"STALE_INDEX"])
	graph.get_node(CAMERA_SERVER).add_service(&"CAMERA_CONTROL", "Camera Control Matrix", 2, [&"REPLAY_BUFFER"])
	graph.get_node(ACCESS_CONTROL).add_service(&"DOOR_CONTROL_DAEMON", "Door 12 Controller", 2, [&"STALE_BADGE_SESSION"])
	graph.get_node(PBX_SERVER).add_service(&"PBX_SWITCH", "Security PBX Switch", 2, [&"VOICE_MIRROR"])
	graph.get_node(ALARM_CONTROLLER).add_service(&"ALARM_ZONE_CONTROL", "Server Alarm Zone", 2, [&"MAINTENANCE_BYPASS"])

	var chain: Array[Dictionary] = [
		{"id": &"PUBLIC_CORP", "a": PUBLIC_GATEWAY, "b": CORP_ROUTER, "cost": 1},
		{"id": &"CORP_SECURITY", "a": CORP_ROUTER, "b": SECURITY_NET, "cost": 1},
		{"id": &"SECURITY_CAMERA", "a": SECURITY_NET, "b": CAMERA_SERVER, "cost": 2},
		{"id": &"CAMERA_ACCESS", "a": CAMERA_SERVER, "b": ACCESS_CONTROL, "cost": 2},
		{"id": &"ACCESS_PBX", "a": ACCESS_CONTROL, "b": PBX_SERVER, "cost": 1},
		{"id": &"PBX_ALARM", "a": PBX_SERVER, "b": ALARM_CONTROLLER, "cost": 2},
	]
	for item: Dictionary in chain:
		graph.add_link(NetworkLinkDefinition.new(item.id, item.a, item.b, false, false, false, false, true, item.cost))
	return graph


static func create_player() -> PlayerNetworkPosition:
	var player := PlayerNetworkPosition.new(PUBLIC_GATEWAY, 30)
	player.grant_capability(&"DECRYPT_VOICE")
	return player


static func create_knowledge(graph: NetworkGraph) -> PlayerKnowledge:
	var knowledge := PlayerKnowledge.new()
	knowledge.reveal_node(graph.get_node(PUBLIC_GATEWAY), KnowledgeLevel.Value.SCANNED)
	knowledge.reveal_node(graph.get_node(CORP_ROUTER), KnowledgeLevel.Value.IDENTIFIED)
	knowledge.reveal_link(graph.get_link(&"PUBLIC_CORP"), KnowledgeLevel.Value.SCANNED)
	return knowledge


static func populate_ice(controller: IceController) -> void:
	var route: Array[StringName] = [SECURITY_NET, CAMERA_SERVER, ACCESS_CONTROL, CAMERA_SERVER]
	var definition := IceDefinition.new(&"FACILITY_SENTINEL", "Facility Sentinel", 1, 2, 2, route, 10, 1)
	controller.add_ice(IceInstance.new(&"FACILITY_SENTINEL_01", definition, SECURITY_NET, IceState.Value.PATROL))
