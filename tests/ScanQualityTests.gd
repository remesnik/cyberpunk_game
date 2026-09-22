extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void:
	var graph := NetworkGraph.new()
	var node := NetworkNodeDefinition.new(&"COMMS", "Communications", NetworkNodeDefinition.NodeType.SYSTEM, 5)
	node.network_type = &"COMMUNICATIONS"
	node.security_family = NetworkNodeDefinition.SecurityFamily.PURPLE
	node.difficulty_rating = 5
	node.add_service_record({"id": &"VOICE", "display_name": "Voice", "service_type": &"VOICE_COMMS", "security_level": 3, "vulnerabilities": [&"LEGACY_CODEC"]})
	node.add_service_record({"id": &"MESSAGES", "display_name": "Messages", "service_type": &"MESSAGING", "security_level": 3})
	node.add_service_record({"id": &"LOGS", "display_name": "Logs", "service_type": &"LOGGING", "security_level": 4})
	var remote := NetworkNodeDefinition.new(&"REMOTE", "Remote Controller", NetworkNodeDefinition.NodeType.SECURITY_SERVER, 4)
	graph.add_node(node); graph.add_node(remote)
	var link := NetworkLinkDefinition.new(&"CONTROLLED_ROUTE", &"COMMS", &"REMOTE")
	link.configure_direction(&"COMMS", &"REMOTE", {"state": &"LOCKED", "controller_node_id": &"REMOTE", "remote_controller_node_id": &"REMOTE"})
	graph.add_link(link)
	var position := PlayerNetworkPosition.new(&"COMMS", 20)
	var knowledge := PlayerKnowledge.new()
	var ice := IceController.new(graph, position, knowledge)
	var warden := IceDefinition.new(&"WARDEN_3", "Warden", 3, 999999, 3, [], 10, 3)
	warden.binding_mode = IceDefinition.BindingMode.HOST_BOUND
	ice.add_ice(IceInstance.new(&"WARDEN_INSTANCE", warden, &"COMMS"))
	var scanner := ScanSystem.new(graph, position, knowledge, ice)

	var low := scanner.perform_scan({"kind": ScanSystem.CURRENT_NODE, "node_id": &"COMMS"}, 3)
	knowledge.commit_scan(low, graph, ice)
	var low_view := knowledge.get_node_view(&"COMMS")
	_expect(low.scan_depth == 1 and low.scan_quality == &"CONTACT", "weak scan produces explicit contact-quality result")
	_expect(low_view.network_type == &"COMMUNICATIONS" and not low_view.has("security_family") and not low_view.has("difficulty_rating"), "weak scan reveals network type without security or difficulty")
	_expect(low_view.ice_presence_known and low_view.ice_present and not knowledge.ice_records.has(&"WARDEN_INSTANCE"), "weak scan reveals ICE presence without identity")
	_expect(knowledge.get_services_at(&"COMMS").is_empty(), "weak scan does not reveal service inventory")

	var strong := scanner.perform_scan({"kind": ScanSystem.CURRENT_NODE, "node_id": &"COMMS"}, 8)
	knowledge.commit_scan(strong, graph, ice)
	var strong_view := knowledge.get_node_view(&"COMMS")
	var ice_view: Dictionary = knowledge.ice_records.get(&"WARDEN_INSTANCE", {})
	_expect(strong.scan_depth == 4 and strong.scan_quality == &"FORENSIC", "strong scan reaches extensible forensic quality")
	_expect(strong_view.security_family == &"PURPLE" and strong_view.difficulty_rating == 5, "strong scan reveals security family and difficulty")
	_expect(ice_view.ice_type == "Warden" and ice_view.ice_rating == 3, "strong scan reveals ICE type and rating")
	_expect(knowledge.get_services_at(&"COMMS").size() == 3, "strong scan reveals available services")
	_expect(strong_view.controlled_paths_known and strong_view.controlled_paths.any(func(path): return not path.get("remote_controller_relationships", []).is_empty()), "strong scan reveals controlled paths and remote controller relationships")
	_expect(strong_view.known_vulnerabilities.has(&"LEGACY_CODEC") and strong_view.affinity_hints.service_types.has(&"VOICE_COMMS"), "strong scan reveals vulnerability and affinity hints")

	print("%s: %d scan-quality assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
