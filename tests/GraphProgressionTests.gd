extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void:
	_test_metroidvania_route_loop()
	_test_spoof_or_credential_rule()
	print("%s: %d graph progression assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _test_metroidvania_route_loop() -> void:
	var fixture := ProgressionTestNetworkFactory.create_fixture()
	var graph: NetworkGraph = fixture.graph
	var player: PlayerNetworkPosition = fixture.player
	var progression: GraphProgressionController = fixture.progression
	var knowledge: PlayerKnowledge = fixture.knowledge
	graph.apply_traversal(player, ProgressionTestNetworkFactory.ENTRY_ROUTER)
	var blocked := graph.validate_traversal(player, ProgressionTestNetworkFactory.ENCRYPTED_ARCHIVE)
	_expect(blocked.error == NetworkGraph.TraversalError.CAPABILITY_REQUIRED, "early encrypted branch is inaccessible")
	_expect(graph.apply_traversal(player, ProgressionTestNetworkFactory.TOOL_REPOSITORY).error == NetworkGraph.TraversalError.OK, "alternate path remains usable")
	var acquisition_events := progression.on_node_entered(ProgressionTestNetworkFactory.TOOL_REPOSITORY)
	_expect(player.has_capability(CapabilityCatalog.DECRYPT), "alternate path grants DECRYPT")
	_expect(acquisition_events[0].type == &"CAPABILITY_ACQUIRED", "capability acquisition produces an event")
	graph.apply_traversal(player, ProgressionTestNetworkFactory.ENTRY_ROUTER)
	_expect(graph.apply_traversal(player, ProgressionTestNetworkFactory.ENCRYPTED_ARCHIVE).error == NetworkGraph.TraversalError.OK, "returning player can use encrypted branch")
	var reveal_events := progression.on_node_entered(ProgressionTestNetworkFactory.ENCRYPTED_ARCHIVE)
	_expect(reveal_events.any(func(event: Dictionary) -> bool: return event.type == &"SHORTCUT_REVEALED"), "archive reveals anchor shortcut")
	var contacts: Array[Dictionary] = knowledge.get_local_contacts(ProgressionTestNetworkFactory.ENCRYPTED_ARCHIVE)
	_expect(contacts.any(func(contact: Dictionary) -> bool: return contact.get("kind") == &"NODE" and contact.node.id == ProgressionTestNetworkFactory.ANCHOR), "shortcut appears in player knowledge")
	_expect(graph.apply_traversal(player, ProgressionTestNetworkFactory.ANCHOR).error == NetworkGraph.TraversalError.OK, "shortcut returns toward Anchor")

func _test_spoof_or_credential_rule() -> void:
	var fixture := ProgressionTestNetworkFactory.create_fixture()
	var graph: NetworkGraph = fixture.graph
	var player: PlayerNetworkPosition = fixture.player
	player.current_node_id = ProgressionTestNetworkFactory.ENCRYPTED_ARCHIVE
	player.grant_capability(CapabilityCatalog.DECRYPT)
	_expect(graph.validate_traversal(player, ProgressionTestNetworkFactory.IDENTITY_GATE).error == NetworkGraph.TraversalError.CAPABILITY_REQUIRED, "identity gate rejects an unqualified player")
	player.credentials.append(&"ARCHIVE_CREDENTIAL")
	_expect(graph.validate_traversal(player, ProgressionTestNetworkFactory.IDENTITY_GATE).error == NetworkGraph.TraversalError.OK, "valid credential satisfies SPOOF-or-credential rule")

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
