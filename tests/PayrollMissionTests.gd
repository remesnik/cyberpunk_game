extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void:
	_test_mission_graph_rules()
	_test_hacking_extraction_and_return()
	_test_crash_cache_with_ledger()
	print("%s: %d payroll mission assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _test_mission_graph_rules() -> void:
	var fixture := _fixture()
	var graph: NetworkGraph = fixture.graph
	var player: PlayerNetworkPosition = fixture.player
	var knowledge: PlayerKnowledge = fixture.knowledge
	var shortcuts: ShortcutController = fixture.shortcuts
	player.relocate(PayrollMissionFactory.EMPLOYEE_WS)
	_expect(graph.validate_traversal(player, PayrollMissionFactory.AUTH_SERVER).error == NetworkGraph.TraversalError.LOCKED_LINK, "employee-auth route begins locked")
	player.relocate(PayrollMissionFactory.ENGINEERING_WS)
	_expect(graph.validate_traversal(player, PayrollMissionFactory.HIDDEN_ROUTE).error == NetworkGraph.TraversalError.HIDDEN_LINK, "legacy route begins hidden")
	player.relocate(PayrollMissionFactory.AUTH_SERVER)
	_expect(graph.validate_traversal(player, PayrollMissionFactory.FILE_SERVER).error == NetworkGraph.TraversalError.CAPABILITY_REQUIRED, "file route requires DECRYPT")
	var shortcut := graph.get_link(&"EMPLOYEE_ENGINEERING_SHORTCUT")
	_expect(shortcut.disabled and shortcut.locked, "cross-workstation shortcut begins unavailable")
	shortcuts.activate(&"EMPLOYEE_ENGINEERING_BRIDGE", player, knowledge)
	_expect(not shortcut.disabled and shortcut.traversal_cost == 1, "shortcut activation persistently enables a cheaper route")

func _test_hacking_extraction_and_return() -> void:
	var fixture := _fixture()
	var graph: NetworkGraph = fixture.graph
	var player: PlayerNetworkPosition = fixture.player
	var knowledge: PlayerKnowledge = fixture.knowledge
	var mission: PayrollMissionController = fixture.mission
	var scan: ScanSystem = fixture.scan
	graph.apply_traversal(player, PayrollMissionFactory.DMZ_ROUTER)
	_scan_node_and_service(scan, knowledge, fixture.ice, graph, PayrollMissionFactory.DMZ_ROUTER, &"DMZ_CONTROL")
	_expect(mission.execute_exploit(_service_target(knowledge, &"DMZ_CONTROL")).success, "DMZ exploit enables routing shortcut")
	graph.apply_traversal(player, PayrollMissionFactory.ENGINEERING_WS)
	_scan_node_and_service(scan, knowledge, fixture.ice, graph, PayrollMissionFactory.ENGINEERING_WS, &"ENG_TOOLCHAIN")
	mission.execute_exploit(_service_target(knowledge, &"ENG_TOOLCHAIN"))
	_expect(player.has_capability(CapabilityCatalog.DEEP_SCAN) and player.has_capability(CapabilityCatalog.TRACE_SCRAMBLER), "engineering exploit grants deep exploration tools")
	var deep_result := scan.perform_scan({"kind": ScanSystem.CURRENT_NODE, "node_id": player.current_node_id}, 1)
	knowledge.commit_scan(deep_result, graph, fixture.ice)
	var hidden_contact: StringName = knowledge.link_records[&"ENGINEERING_HIDDEN"].contact_id
	var hidden_scan := scan.perform_scan({"kind": ScanSystem.LINK, "contact_id": hidden_contact}, 1)
	knowledge.commit_scan(hidden_scan, graph, fixture.ice)
	_expect(knowledge.knows_node(PayrollMissionFactory.HIDDEN_ROUTE), "deep scan resolves hidden topology without leaking it early")
	_expect(graph.apply_traversal(player, PayrollMissionFactory.HIDDEN_ROUTE, knowledge.link_records.keys()).error == NetworkGraph.TraversalError.OK, "identified hidden route becomes traversable with LEGACY_PROTOCOL")
	player.relocate(PayrollMissionFactory.EMPLOYEE_WS)
	_scan_node_and_service(scan, knowledge, fixture.ice, graph, PayrollMissionFactory.EMPLOYEE_WS, &"EMP_DIRECTORY")
	mission.execute_exploit(_service_target(knowledge, &"EMP_DIRECTORY"))
	_expect(not graph.get_link(&"EMPLOYEE_AUTH_LOCK").locked, "employee exploit steals credential and opens identity route")
	graph.apply_traversal(player, PayrollMissionFactory.AUTH_SERVER)
	_scan_node_and_service(scan, knowledge, fixture.ice, graph, PayrollMissionFactory.AUTH_SERVER, &"AUTH_DAEMON")
	mission.execute_exploit(_service_target(knowledge, &"AUTH_DAEMON"))
	_expect(player.has_capability(CapabilityCatalog.DECRYPT), "auth exploit grants DECRYPT")
	_expect(graph.apply_traversal(player, PayrollMissionFactory.FILE_SERVER).error == NetworkGraph.TraversalError.OK, "capability-gated file route becomes usable")
	_scan_current(scan, knowledge, fixture.ice, graph)
	graph.apply_traversal(player, PayrollMissionFactory.PAYROLL_SERVER)
	_scan_node_and_service(scan, knowledge, fixture.ice, graph, PayrollMissionFactory.PAYROLL_SERVER, &"PAYROLL_DB")
	var transfer := mission.execute_transfer(_service_target(knowledge, &"PAYROLL_DB"))
	_expect(transfer.success and fixture.resources.volatile_resources.EMPLOYEE_LEDGER == 1, "payroll transfer extracts volatile EMPLOYEE_LEDGER")
	player.relocate(PayrollMissionFactory.PUBLIC_GATEWAY)
	_expect(mission.check_completion()[0].type == &"MISSION_COMPLETE", "returning ledger to Public Gateway completes mission")

func _test_crash_cache_with_ledger() -> void:
	var fixture := _fixture()
	var anchors := AnchorController.new(fixture.graph)
	anchors.register_anchor(AnchorDefinition.new(PayrollMissionFactory.PUBLIC_GATEWAY, "Public Gateway"))
	anchors.activate_anchor(PayrollMissionFactory.PUBLIC_GATEWAY)
	fixture.resources.add_volatile(PayrollMissionController.OBJECTIVE_RESOURCE, 1)
	fixture.player.relocate(PayrollMissionFactory.PAYROLL_SERVER)
	var failure := FailureRecoveryController.new(anchors, fixture.resources, fixture.player)
	failure.force_disconnect_at_current_node(18)
	_expect(failure.crash_cache.node_id == PayrollMissionFactory.PAYROLL_SERVER and fixture.player.current_node_id == PayrollMissionFactory.PUBLIC_GATEWAY, "failure leaves ledger cache at payroll and reconnects at Anchor")
	fixture.player.relocate(PayrollMissionFactory.PAYROLL_SERVER)
	var recovered := failure.recover_at(PayrollMissionFactory.PAYROLL_SERVER)
	_expect(recovered.EMPLOYEE_LEDGER == 1, "returning to payroll recovers cached ledger")

func _fixture() -> Dictionary:
	var graph := PayrollMissionFactory.create_graph()
	var player := PayrollMissionFactory.create_player()
	var knowledge := PayrollMissionFactory.create_knowledge(graph)
	var ice := IceController.new(graph, player, knowledge)
	PayrollMissionFactory.populate_ice(ice)
	var resources := PlayerResourceState.new()
	var shortcuts := ShortcutController.new(graph)
	shortcuts.register_shortcut(ShortcutDefinition.new(&"EMPLOYEE_ENGINEERING_BRIDGE", ShortcutDefinition.ShortcutType.COMPROMISED_ROUTER, &"EMPLOYEE_ENGINEERING_SHORTCUT", 1))
	return {"graph": graph, "player": player, "knowledge": knowledge, "ice": ice, "scan": ScanSystem.new(graph, player, knowledge, ice), "resources": resources, "shortcuts": shortcuts, "mission": PayrollMissionController.new(graph, player, knowledge, resources, shortcuts)}

func _scan_current(scan: ScanSystem, knowledge: PlayerKnowledge, ice: IceController, graph: NetworkGraph) -> void:
	var result := scan.perform_scan({"kind": ScanSystem.CURRENT_NODE, "node_id": scan.position.current_node_id}, 2)
	knowledge.commit_scan(result, graph, ice)

func _scan_node_and_service(scan: ScanSystem, knowledge: PlayerKnowledge, ice: IceController, graph: NetworkGraph, node_id: StringName, service_id: StringName) -> void:
	_scan_current(scan, knowledge, ice, graph)
	var target := _service_target(knowledge, service_id)
	var result := scan.perform_scan(target, 2)
	knowledge.commit_scan(result, graph, ice)

func _service_target(knowledge: PlayerKnowledge, service_id: StringName) -> Dictionary:
	return {"kind": ScanSystem.SERVICE, "contact_id": knowledge.service_records[service_id].contact_id}

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
