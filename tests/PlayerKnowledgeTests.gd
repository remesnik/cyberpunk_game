extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void:
	_test_initial_view_is_sanitized()
	_test_scan_reveals_local_nodes()
	_test_hidden_destination_does_not_leak()
	print("%s: %d player knowledge assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _test_initial_view_is_sanitized() -> void:
	var graph := TestNetworkFactory.create_graph()
	var knowledge := TestNetworkFactory.create_player_knowledge(graph)
	var router_contacts := knowledge.get_local_contacts(TestNetworkFactory.ROUTER_A)
	_expect(router_contacts.size() == 4, "router exposes one known return route and three detected contacts")
	var unknown_count := 0
	for contact in router_contacts:
		if contact.kind == &"UNKNOWN_SIGNAL":
			unknown_count += 1
			_expect(not contact.has("node") and not contact.has("destination") and not contact.has("link"), "detected contact contains no objective topology")
	_expect(unknown_count == 3, "unscanned router destinations remain unknown")

func _test_scan_reveals_local_nodes() -> void:
	var graph := TestNetworkFactory.create_graph()
	var knowledge := TestNetworkFactory.create_player_knowledge(graph)
	var events := knowledge.scan_node(graph, TestNetworkFactory.ROUTER_A)
	_expect(knowledge.get_node_level(TestNetworkFactory.AUTH_SERVER) == KnowledgeLevel.Value.IDENTIFIED, "scan identifies auth server")
	_expect(knowledge.get_node_level(TestNetworkFactory.WORKSTATION_01) == KnowledgeLevel.Value.IDENTIFIED, "scan identifies workstation")
	_expect(knowledge.get_link_level(&"ROUTER_AUTH") == KnowledgeLevel.Value.SCANNED, "scan reveals route properties")
	_expect(not events.is_empty(), "scan produces knowledge events")

func _test_hidden_destination_does_not_leak() -> void:
	var graph := TestNetworkFactory.create_graph()
	var knowledge := TestNetworkFactory.create_player_knowledge(graph)
	knowledge.reveal_node(graph.get_node(TestNetworkFactory.AUTH_SERVER), KnowledgeLevel.Value.IDENTIFIED)
	knowledge.scan_node(graph, TestNetworkFactory.AUTH_SERVER)
	var contacts := knowledge.get_local_contacts(TestNetworkFactory.AUTH_SERVER)
	var found_unknown := false
	for contact in contacts:
		if contact.kind == &"UNKNOWN_SIGNAL":
			found_unknown = true
			_expect(not contact.has("destination") and not contact.has("node"), "hidden signal omits security-server identity")
	_expect(found_unknown, "hidden security route appears only as an unknown signal")
	_expect(knowledge.get_node_level(TestNetworkFactory.SECURITY_SERVER) == KnowledgeLevel.Value.UNKNOWN, "hidden destination remains unknown")

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
