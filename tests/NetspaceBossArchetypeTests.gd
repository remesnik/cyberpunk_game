extends Node

var failures := 0
var assertions := 0

func _ready() -> void:
	var graph := _graph()
	_test_warden(graph)
	_test_hunter(graph)
	_test_vault(graph)
	_test_architect(graph)
	_test_hydra(graph)
	_test_swarm(graph)
	_test_auditor(graph)
	_test_ghost(graph)
	_test_mirror(graph)
	_test_root(graph)
	print("%s: %d Netspace boss archetype assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _test_warden(graph: NetworkGraph) -> void:
	var boss := NetspaceBossEncounter.create(NetspaceBossEncounter.Archetype.WARDEN, &"WARDEN_TEST", &"B", graph)
	_expect(boss.phase == &"PROTECTED" and boss.defense_multiplier() > 1.0 and boss.trace_multiplier() > 1.0, "Warden starts protected by active support services")
	_expect(boss.disable_service(&"AUTHENTICATION") and boss.defense_multiplier() == 1.0 and boss.phase == &"ALERT", "authentication removal visibly reduces defense and advances service-driven phase")
	boss.disable_service(&"TRACE"); _expect(boss.trace_multiplier() == 1.0 and boss.phase == &"ISOLATED", "trace removal reduces pressure and isolates Warden")
	boss.disable_service(&"ALARM"); _expect(not boss.reinforcement_enabled(), "alarm removal prevents Warden reinforcements")
	_expect(not bool(boss.objective.accessible), "Warden objective remains protected while Warden is active")
	boss.disable_actor(&"WARDEN"); _expect(bool(boss.objective.accessible), "Warden objective unlocks after system supports and boss are neutralized")
	_expect(boss.target_views().size() == 5, "Warden exposes ICE, three services, and objective through ordinary local targets")

func _test_hunter(graph: NetworkGraph) -> void:
	var boss := NetspaceBossEncounter.create(NetspaceBossEncounter.Archetype.HUNTER, &"HUNTER_TEST", &"A", graph)
	var clock := ActionClock.new(); var clock_position := PlayerNetworkPosition.new(&"D", 20); boss.bind_action_clock(clock, clock_position)
	var clock_request := ActionRequest.new(&"PLAYER", ActionRequest.ActionType.WAIT)
	clock.resolve_action(clock_request, func(_request: ActionRequest) -> Dictionary: return {"success": true}, func(_request: ActionRequest) -> Dictionary: return {"success": true})
	_expect((boss.actors.HUNTER as Dictionary).node_id == &"B", "Hunter advances from the existing action-clock network phase")
	(boss.actors.HUNTER as Dictionary).node_id = &"A"
	var topology := _topology(graph); var event := boss.tick(&"D")[0]
	_expect((boss.actors.HUNTER as Dictionary).node_id == &"B" and event.from == &"A" and event.to == &"B", "Hunter moves one valid connection toward player")
	boss.tick(&"A"); _expect((boss.actors.HUNTER as Dictionary).node_id == &"A", "Hunter recalculates when player changes branch")
	(boss.actors.HUNTER as Dictionary).node_id = &"A"; var contact := boss.tick(&"A")
	_expect(not contact.is_empty() and contact[0].type == &"HUNTER_CONTACT" and int(boss.encounter_state.contact_pressure) > 0, "Hunter contact creates pressure without instant kill")
	_expect(_topology(graph) == topology, "Hunter pursuit never changes nodes or edge topology")
	var saved := boss.snapshot(); var restored := NetspaceBossEncounter.create(NetspaceBossEncounter.Archetype.HUNTER, &"RESTORE", &"D", graph); restored.restore(saved)
	_expect(restored.snapshot() == saved, "boss identity, node, phase, and encounter state survive persistence roundtrip")
	boss.cleanup(); _expect(clock._network_updaters.is_empty(), "boss cleanup unregisters its action-clock updater")

func _test_vault(graph: NetworkGraph) -> void:
	var boss := NetspaceBossEncounter.create(NetspaceBossEncounter.Archetype.VAULT, &"VAULT_TEST", &"B", graph)
	_expect(not bool(boss.objective.accessible) and boss.trace_multiplier() > 1.0, "Vault objective begins gated while Audit adds trace pressure")
	boss.disable_service(&"AUDIT"); boss.disable_service(&"ENCRYPTION"); _expect(not bool(boss.objective.accessible), "authentication still gates a partially compromised Vault")
	boss.set_authenticated(true); _expect(not bool(boss.objective.accessible), "file store/control remains authoritative after authentication")
	boss.take_control(); _expect(bool(boss.objective.accessible) and &"DOWNLOAD" in _commands(boss.target_views()[boss.objective.id]), "Vault dependencies dynamically expose Download")
	var scan := boss.apply_command((boss.services.AUTHENTICATION as Dictionary).id, &"SCAN"); _expect(not (scan.details as Array).is_empty(), "Vault Scan exposes dependency information")

func _test_architect(graph: NetworkGraph) -> void:
	var topology := _topology(graph); var boss := NetspaceBossEncounter.create(NetspaceBossEncounter.Archetype.ARCHITECT, &"ARCH_TEST", &"B", graph); var link := graph.get_link(&"AB")
	_expect(boss.set_link_state(&"AB", &"BLOCKED") and link.locked, "Architect can block traversal without moving geometry")
	var visual := LinkVisual.new(); visual.set_runtime_state(&"BLOCKED"); _expect(visual.runtime_state == &"BLOCKED" and visual.default_color != LinkVisual.CYAN, "Architect edge presentation reflects authoritative runtime state"); visual.free()
	var position := PlayerNetworkPosition.new(&"A", 20); _expect(graph.validate_traversal(position, &"B").error == NetworkGraph.TraversalError.LOCKED_LINK, "blocked Architect edge cannot be traversed")
	boss.set_link_state(&"AB", &"ACTIVE"); _expect(graph.validate_traversal(position, &"B").error == NetworkGraph.TraversalError.OK, "reopened Architect edge becomes traversable")
	boss.set_link_state(&"AB", &"ONE_WAY"); position.current_node_id = &"B"; _expect(graph.validate_traversal(position, &"A").error == NetworkGraph.TraversalError.NOT_CONNECTED, "Architect one-way state is respected")
	_expect(_topology(graph) == topology, "Architect changes runtime edge state without changing endpoints")
	boss.cleanup(); _expect(not link.one_way and not link.locked and not link.disabled, "Architect cleanup restores encounter-local route modifiers")

func _test_hydra(graph: NetworkGraph) -> void:
	var boss := NetspaceBossEncounter.create(NetspaceBossEncounter.Archetype.HYDRA, &"HYDRA_TEST", &"B", graph)
	_expect((boss.actors.DEFENSE as Dictionary).role != (boss.actors.TRACE as Dictionary).role and boss.defense_multiplier() > 1.0, "Hydra heads share state but retain distinct roles")
	boss.disable_actor(&"DEFENSE"); _expect(boss.defense_multiplier() == 1.0 and int(boss.encounter_state.stability) == 2, "disabling a Hydra role updates shared behavior")
	boss.disable_actor(&"REGENERATION"); boss.disable_actor(&"TRACE"); _expect(boss.completed and boss.phase == &"CORE_EXPOSED", "Hydra victory follows shared stability condition")

func _test_swarm(graph: NetworkGraph) -> void:
	var boss := NetspaceBossEncounter.create(NetspaceBossEncounter.Archetype.SWARM, &"SWARM_TEST", &"B", graph)
	for index in 12: boss.tick()
	_expect(boss.actors.size() == int(boss.encounter_state.maximum_active), "Swarm spawning respects its active entity cap")
	boss.disable_service(&"SPAWN"); var count := boss.actors.size(); for index in 4: boss.tick()
	_expect(boss.actors.size() == count, "disabled spawn service stops creation while existing units persist")

func _test_auditor(graph: NetworkGraph) -> void:
	var boss := NetspaceBossEncounter.create(NetspaceBossEncounter.Archetype.AUDITOR, &"AUDITOR_TEST", &"B", graph)
	var base := boss.trace_multiplier(); boss.tick(&"B", &"SCAN"); boss.tick(&"B", &"SCAN"); boss.tick(&"B", &"SCAN")
	_expect(base > 1.0 and boss.phase == &"IDENTIFIED", "Auditor escalates readable trace phase for repeated actions")
	boss.disable_service(&"LOGGING"); boss.disable_service(&"TRACE"); _expect(boss.trace_multiplier() < base, "disabling Auditor support services reduces trace pressure")
	boss.cleanup(); _expect(boss.completed, "Auditor encounter cleanup contains its temporary modifiers")

func _test_ghost(graph: NetworkGraph) -> void:
	var boss := NetspaceBossEncounter.create(NetspaceBossEncounter.Archetype.GHOST, &"GHOST_TEST", &"B", graph); var ghost_id: StringName = (boss.actors.GHOST as Dictionary).id
	_expect(boss.phase == &"UNKNOWN" and not bool(boss.target_views()[ghost_id].attackable), "Ghost begins concealed and cannot be directly attacked")
	var decoy_count := boss.actors.size(); boss.identify_ghost(&"DECOY_A"); _expect(boss.actors.size() == decoy_count - 1, "scanned Ghost decoy cleans up differently from real target")
	for index in 3: boss.identify_ghost(&"GHOST")
	_expect(boss.phase == &"EXPOSED" and bool(boss.target_views()[ghost_id].attackable), "deterministic Scan/Probe progression exposes the real Ghost")

func _test_mirror(graph: NetworkGraph) -> void:
	var boss := NetspaceBossEncounter.create(NetspaceBossEncounter.Archetype.MIRROR, &"MIRROR_TEST", &"B", graph)
	_expect(boss.record_program(&"ICEBREAKER") == 1.0 and boss.record_program(&"ICEBREAKER") == 1.0 and boss.record_program(&"ICEBREAKER") < 1.0, "Mirror adapts only after configurable repeated program use")
	_expect(boss.record_program(&"CLOAK") == 1.0, "switching tactics avoids the learned signature penalty")
	for index in 5: boss.tick()
	_expect(not (boss.encounter_state.adaptations as Dictionary).has(&"ICEBREAKER"), "Mirror adaptation decays and stays encounter-local")

func _test_root(graph: NetworkGraph) -> void:
	var boss := NetspaceBossEncounter.create(NetspaceBossEncounter.Archetype.ROOT, &"ROOT_TEST", &"A", graph); var topology := _topology(graph)
	_expect(boss.phase == &"ACCESS" and not bool(boss.objective.accessible), "Root starts in Access with final objective protected")
	for role in [&"AUTHENTICATION", &"TRACE", &"CONTROL"]: boss.disable_service(role)
	_expect(boss.advance_root_phase() and boss.phase == &"CONTAINMENT", "Root phase condition advances from compromised support systems")
	_expect(boss.advance_root_phase() and boss.phase == &"PURSUIT" and boss.actors.has(&"HUNTER"), "Root sequentially launches persistent Hunter component")
	boss.tick(&"D"); _expect(_topology(graph) == topology, "Root pursuit preserves fixed network topology")
	boss.advance_root_phase(); for role in boss.actors.keys():
		if String(role).begins_with("COMPONENT_"): boss.disable_actor(StringName(role))
	_expect(boss.advance_root_phase() and boss.phase == &"FINAL_ACCESS" and bool(boss.objective.accessible), "Root distributed components gate final access")

func _commands(view: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	if not bool(view.get("scanned", false)): result.append(&"SCAN")
	if bool(view.get("downloadable", false)): result.append(&"DOWNLOAD")
	if bool(view.get("disableable", false)): result.append(&"DISABLE")
	if bool(view.get("attackable", false)): result.append(&"ATTACK")
	return result

func _graph() -> NetworkGraph:
	var graph := NetworkGraph.new()
	for id in [&"A", &"B", &"C", &"D"]: graph.add_node(NetworkNodeDefinition.new(id, String(id), NetworkNodeDefinition.NodeType.SYSTEM, 1))
	graph.add_link(NetworkLinkDefinition.new(&"AB", &"A", &"B")); graph.add_link(NetworkLinkDefinition.new(&"BC", &"B", &"C")); graph.add_link(NetworkLinkDefinition.new(&"CD", &"C", &"D"))
	return graph

func _topology(graph: NetworkGraph) -> Dictionary:
	var result := {}
	for link: NetworkLinkDefinition in graph.links.values(): result[link.id] = [link.source, link.destination]
	return result

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition: failures += 1; printerr("FAILED: %s" % description)
