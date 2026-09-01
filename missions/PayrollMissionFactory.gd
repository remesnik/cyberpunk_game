class_name PayrollMissionFactory
extends RefCounted

const PUBLIC_GATEWAY := &"PUBLIC_GATEWAY"
const DMZ_ROUTER := &"DMZ_ROUTER"
const EMPLOYEE_WS := &"EMPLOYEE_WS"
const ENGINEERING_WS := &"ENGINEERING_WS"
const AUTH_SERVER := &"AUTH_SERVER"
const HIDDEN_ROUTE := &"HIDDEN_ROUTE"
const FILE_SERVER := &"FILE_SERVER"
const PAYROLL_SERVER := &"PAYROLL_SERVER"
const SECURITY_SERVER := &"SECURITY_SERVER"
const ACCESS_CONTROL_SERVER := &"ACCESS_CONTROL_SERVER"

static func create_graph() -> NetworkGraph:
	var graph := NetworkGraph.new()
	graph.add_node(NetworkNodeDefinition.new(PUBLIC_GATEWAY, "Public Gateway", NetworkNodeDefinition.NodeType.GATEWAY, 0, true, &"PUBLIC"))
	graph.add_node(NetworkNodeDefinition.new(DMZ_ROUTER, "DMZ Router", NetworkNodeDefinition.NodeType.ROUTER, 1, true, &"HALCYON_PAYROLL"))
	graph.add_node(NetworkNodeDefinition.new(EMPLOYEE_WS, "Employee Workstation", NetworkNodeDefinition.NodeType.WORKSTATION, 1, true, &"HALCYON_PAYROLL"))
	graph.add_node(NetworkNodeDefinition.new(ENGINEERING_WS, "Engineering Workstation", NetworkNodeDefinition.NodeType.WORKSTATION, 2, true, &"HALCYON_PAYROLL"))
	graph.add_node(NetworkNodeDefinition.new(AUTH_SERVER, "Authentication Server", NetworkNodeDefinition.NodeType.AUTH_SERVER, 3, true, &"HALCYON_PAYROLL"))
	graph.add_node(NetworkNodeDefinition.new(HIDDEN_ROUTE, "Legacy Maintenance Route", NetworkNodeDefinition.NodeType.SYSTEM, 2, false, &"UNKNOWN"))
	graph.add_node(NetworkNodeDefinition.new(FILE_SERVER, "File Server", NetworkNodeDefinition.NodeType.FILE_SERVER, 3, true, &"HALCYON_PAYROLL"))
	graph.add_node(NetworkNodeDefinition.new(PAYROLL_SERVER, "Payroll Server", NetworkNodeDefinition.NodeType.FILE_SERVER, 4, true, &"HALCYON_PAYROLL"))
	graph.add_node(NetworkNodeDefinition.new(SECURITY_SERVER, "Security Server", NetworkNodeDefinition.NodeType.SECURITY_SERVER, 5, false, &"HALCYON_SECURITY"))
	graph.add_node(NetworkNodeDefinition.new(ACCESS_CONTROL_SERVER, "Access Control Server", NetworkNodeDefinition.NodeType.SYSTEM, 2, true, &"HALCYON_SECURITY"))

	graph.get_node(PUBLIC_GATEWAY).add_service(&"ANCHOR_RELAY", "Anchor Relay", 0)
	graph.get_node(DMZ_ROUTER).add_service(&"DMZ_CONTROL", "DMZ Routing Control", 1, [&"DEFAULT_ROUTE_TABLE"])
	graph.get_node(EMPLOYEE_WS).add_service(&"EMP_DIRECTORY", "Employee Directory Agent", 1, [&"CACHED_CREDENTIAL"])
	graph.get_node(ENGINEERING_WS).add_service(&"ENG_TOOLCHAIN", "Engineering Toolchain", 2, [&"UNSIGNED_PLUGIN"])
	graph.get_node(AUTH_SERVER).add_service(&"AUTH_DAEMON", "Authentication Daemon", 3, [&"TOKEN_DOWNGRADE"])
	graph.get_node(FILE_SERVER).add_service(&"FILE_INDEX", "File Index", 2, [&"STALE_ACL"])
	graph.get_node(PAYROLL_SERVER).add_service(&"PAYROLL_DB", "Payroll Database", 4, [&"BATCH_EXPORT"])
	graph.get_node(SECURITY_SERVER).add_service(&"ICE_ORCHESTRATOR", "ICE Orchestrator", 5)
	graph.get_node(ACCESS_CONTROL_SERVER).add_service(&"DOOR_CONTROL_DAEMON", "Door Control Daemon", 2, [&"STALE_BADGE_SESSION"])
	graph.get_node(SECURITY_SERVER).recommended_capabilities.append(CapabilityCatalog.TRACE_SCRAMBLER)

	graph.add_link(NetworkLinkDefinition.new(&"PUBLIC_DMZ", PUBLIC_GATEWAY, DMZ_ROUTER, false, false, false, false, true, 1))
	graph.add_link(NetworkLinkDefinition.new(&"DMZ_EMPLOYEE", DMZ_ROUTER, EMPLOYEE_WS, false, false, false, false, true, 1))
	graph.add_link(NetworkLinkDefinition.new(&"DMZ_ENGINEERING", DMZ_ROUTER, ENGINEERING_WS, false, false, false, false, true, 2))
	graph.add_link(NetworkLinkDefinition.new(&"EMPLOYEE_ENGINEERING_SHORTCUT", EMPLOYEE_WS, ENGINEERING_WS, false, false, true, true, true, 3))
	graph.add_link(NetworkLinkDefinition.new(&"EMPLOYEE_AUTH_LOCK", EMPLOYEE_WS, AUTH_SERVER, false, false, true, false, true, 2))
	graph.get_link(&"EMPLOYEE_AUTH_LOCK").accepted_credentials.append(&"EMPLOYEE_CREDENTIAL")
	graph.add_link(NetworkLinkDefinition.new(&"ENGINEERING_HIDDEN", ENGINEERING_WS, HIDDEN_ROUTE, false, true, false, false, false, 2))
	graph.get_link(&"ENGINEERING_HIDDEN").required_capabilities_all.append(CapabilityCatalog.LEGACY_PROTOCOL)
	graph.add_link(NetworkLinkDefinition.new(&"HIDDEN_AUTH", HIDDEN_ROUTE, AUTH_SERVER, false, false, false, false, true, 1))
	graph.add_link(NetworkLinkDefinition.new(&"AUTH_FILE_DECRYPT", AUTH_SERVER, FILE_SERVER, false, false, false, false, true, 2))
	graph.get_link(&"AUTH_FILE_DECRYPT").required_capabilities_all.append(CapabilityCatalog.DECRYPT)
	graph.add_link(NetworkLinkDefinition.new(&"FILE_PAYROLL", FILE_SERVER, PAYROLL_SERVER, false, false, false, false, true, 2))
	graph.add_link(NetworkLinkDefinition.new(&"PAYROLL_SECURITY", PAYROLL_SERVER, SECURITY_SERVER, false, false, false, false, true, 1))
	graph.add_link(NetworkLinkDefinition.new(&"ENGINEERING_ACCESS_CONTROL", ENGINEERING_WS, ACCESS_CONTROL_SERVER, false, false, false, false, true, 2))
	return graph

static func create_player() -> PlayerNetworkPosition:
	return PlayerNetworkPosition.new(PUBLIC_GATEWAY, 30)

static func create_knowledge(graph: NetworkGraph) -> PlayerKnowledge:
	var knowledge := PlayerKnowledge.new()
	knowledge.reveal_node(graph.get_node(PUBLIC_GATEWAY), KnowledgeLevel.Value.SCANNED)
	knowledge.reveal_node(graph.get_node(DMZ_ROUTER), KnowledgeLevel.Value.IDENTIFIED)
	knowledge.reveal_link(graph.get_link(&"PUBLIC_DMZ"), KnowledgeLevel.Value.SCANNED)
	return knowledge

static func populate_ice(controller: IceController) -> void:
	var auditor_route: Array[StringName] = [PAYROLL_SERVER, FILE_SERVER, AUTH_SERVER, FILE_SERVER]
	var auditor := IceDefinition.new(&"AUDITOR", "Auditor ICE", 1, 2, 2, auditor_route, 9, 1)
	controller.add_ice(IceInstance.new(&"AUDITOR_01", auditor, PAYROLL_SERVER, IceState.Value.PATROL))
	var sentinel_route: Array[StringName] = [SECURITY_SERVER, PAYROLL_SERVER, FILE_SERVER, PAYROLL_SERVER]
	var sentinel := IceDefinition.new(&"PAYROLL_SENTINEL", "Payroll Sentinel", 2, 3, 2, sentinel_route, 12, 2)
	controller.add_ice(IceInstance.new(&"SENTINEL_01", sentinel, SECURITY_SERVER, IceState.Value.DORMANT))
