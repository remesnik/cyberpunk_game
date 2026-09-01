extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void:
	_test_current_node_scan_and_commit()
	_test_adjacent_node_scan()
	_test_detected_link_scan()
	_test_service_scan()
	_test_invalid_distant_target()
	print("%s: %d scan system assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _test_current_node_scan_and_commit() -> void:
	var fixture := _fixture(TestNetworkFactory.PUBLIC_GATEWAY)
	var system: ScanSystem = fixture.system
	var knowledge: PlayerKnowledge = fixture.knowledge
	var target := {"kind": ScanSystem.CURRENT_NODE, "node_id": TestNetworkFactory.PUBLIC_GATEWAY}
	var result := system.perform_scan(target, 1)
	_expect(result.success, "current node is a valid scan target")
	_expect(result.time_spent == 1 and result.scan_depth > 0, "scan returns structured time and depth")
	_expect(result.events_produced.size() == 1, "scan returns structured events")
	knowledge.commit_scan(result, fixture.graph, fixture.ice)
	_expect(knowledge.get_node_level(TestNetworkFactory.PUBLIC_GATEWAY) >= KnowledgeLevel.Value.SCANNED, "discoveries commit through PlayerKnowledge")

func _test_adjacent_node_scan() -> void:
	var fixture := _fixture(TestNetworkFactory.PUBLIC_GATEWAY)
	var target := {"kind": ScanSystem.NODE, "node_id": TestNetworkFactory.ROUTER_A}
	var result: ScanResult = fixture.system.perform_scan(target, 1)
	_expect(result.success and result.time_spent == 2, "adjacent scan includes topology distance in cost")

func _test_detected_link_scan() -> void:
	var fixture := _fixture(TestNetworkFactory.ROUTER_A)
	var knowledge: PlayerKnowledge = fixture.knowledge
	var contact: StringName = knowledge.link_records[&"ROUTER_AUTH"].contact_id
	var target := {"kind": ScanSystem.LINK, "contact_id": contact}
	var result: ScanResult = fixture.system.perform_scan(target, 2)
	_expect(result.success and result.target_id == &"ROUTER_AUTH", "detected link resolves internally for scanning")
	knowledge.commit_scan(result, fixture.graph, fixture.ice)
	_expect(knowledge.get_link_level(&"ROUTER_AUTH") >= KnowledgeLevel.Value.IDENTIFIED, "link discovery commits after scan")

func _test_service_scan() -> void:
	var fixture := _fixture(TestNetworkFactory.PUBLIC_GATEWAY)
	var knowledge: PlayerKnowledge = fixture.knowledge
	var local_target := {"kind": ScanSystem.CURRENT_NODE, "node_id": TestNetworkFactory.PUBLIC_GATEWAY}
	var local_result: ScanResult = fixture.system.perform_scan(local_target, 1)
	knowledge.commit_scan(local_result, fixture.graph, fixture.ice)
	var service_record: Dictionary = knowledge.service_records[&"PUBLIC_RELAY"]
	var service_target := {"kind": ScanSystem.SERVICE, "contact_id": service_record.contact_id}
	var service_result: ScanResult = fixture.system.perform_scan(service_target, 2)
	_expect(service_result.success and service_result.target_id == &"PUBLIC_RELAY", "detected local service is scan-selectable")
	_expect(service_result.trace_generated >= 0 and not service_result.discoveries.is_empty(), "service scan returns structured trace and discoveries")

func _test_invalid_distant_target() -> void:
	var fixture := _fixture(TestNetworkFactory.PUBLIC_GATEWAY)
	fixture.knowledge.reveal_node(fixture.graph.get_node(TestNetworkFactory.FILE_SERVER), KnowledgeLevel.Value.IDENTIFIED)
	var target := {"kind": ScanSystem.NODE, "node_id": TestNetworkFactory.FILE_SERVER}
	var result: ScanResult = fixture.system.perform_scan(target, 3)
	_expect(not result.success and result.time_spent == 0, "identified but distant node is not a valid target")

func _fixture(player_node: StringName) -> Dictionary:
	var graph := TestNetworkFactory.create_graph()
	var position := PlayerNetworkPosition.new(player_node, 20)
	var knowledge := TestNetworkFactory.create_player_knowledge(graph)
	var ice := IceController.new(graph, position, knowledge)
	TestIceFactory.populate(ice)
	return {"graph": graph, "knowledge": knowledge, "ice": ice, "system": ScanSystem.new(graph, position, knowledge, ice)}

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
