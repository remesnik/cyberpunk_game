extends Node

const DeckHardwareStateScript := preload("res://core/intrusion/DeckHardwareState.gd")

var failures := 0
var assertions := 0

func _ready() -> void:
	_test_ice_attack_tiers()
	_test_authored_attack_data_and_disconnect()
	print("%s: %d ICE SAN attack assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _test_ice_attack_tiers() -> void:
	var fixture := _fixture()
	var ordinary := IceInstance.new(&"ORDINARY", IceDefinition.new(&"ORDINARY_DEF", "Ordinary ICE"), &"SAN_HOST", IceState.Value.SEARCH)
	fixture.controller.add_ice(ordinary)
	var events: Array[Dictionary] = fixture.controller.update(1, ActionRequest.new(&"PLAYER", ActionRequest.ActionType.WAIT))
	_expect(fixture.san.integrity == 100 and fixture.deck.integrity == 100 and not _has(events, &"ICE_SAN_INTEGRITY_ATTACK"), "ordinary ICE cannot attack SAN integrity or physical hardware")
	ordinary.operational = false

	var san_definition := IceDefinition.new(&"SAN_ATTACKER", "SAN Attacker")
	san_definition.san_attack.san_attack_enabled = true
	san_definition.san_attack.integrity_damage = 10
	var san_attacker := IceInstance.new(&"SAN_ATTACKER", san_definition, &"SAN_HOST", IceState.Value.SEARCH)
	fixture.controller.add_ice(san_attacker)
	events = fixture.controller.update(1, ActionRequest.new(&"PLAYER", ActionRequest.ActionType.WAIT))
	_expect(fixture.san.integrity == 93 and fixture.deck.integrity == 100, "SAN-attacking ICE damages SAN integrity after defenses but cannot damage the deck")
	_expect(_has(events, &"ICE_SAN_INTEGRITY_ATTACK") and not _has(events, &"ICE_DECK_LINK_ATTACK"), "SAN-only attack reports no physical deck attack")
	san_attacker.operational = false

	var physical_definition := IceDefinition.new(&"BLACK_ICE", "Physical Deck Attacker")
	physical_definition.san_attack.san_attack_enabled = true
	physical_definition.san_attack.deck_attack_enabled = true
	physical_definition.san_attack.integrity_damage = 10
	physical_definition.san_attack.deck_breach_power = 20
	physical_definition.san_attack.deck_breach_integrity_threshold = 100
	physical_definition.san_attack.physical_deck_damage = 15
	physical_definition.san_attack.component_degradation = 2
	physical_definition.san_attack.temporary_disable_id = &"I_O_BUS_FAULT"
	physical_definition.san_attack.temporary_disable_duration = 5.0
	physical_definition.san_attack.program_corruption_count = 1
	var physical := IceInstance.new(&"BLACK_ICE", physical_definition, &"SAN_HOST", IceState.Value.SEARCH)
	fixture.controller.add_ice(physical)
	events = fixture.controller.update(1, ActionRequest.new(&"PLAYER", ActionRequest.ActionType.WAIT))
	_expect(fixture.deck.integrity == 88, "physical deck-attacking ICE delivers configured damage after Link Shield mitigation")
	_expect(fixture.deck.component_degradation.DECK_LINK == 2 and fixture.deck.temporary_faults.size() == 1 and fixture.deck.corrupted_program_ids == [&"DECK_PROGRAM"], "physical attack uses hardware degradation, disable, and corruption hooks")
	_expect(_has(events, &"ICE_DECK_LINK_ATTACK"), "physical deck damage produces a player-visible structured event")

func _test_authored_attack_data_and_disconnect() -> void:
	var authored := AuthoredIceFactory.create_definition({"id": &"KILLER", "san_attack": {"enabled": true, "deck_attack_enabled": true, "integrity_damage": 4, "deck_breach_power": 9, "deck_breach_integrity_threshold": 80, "physical_deck_damage": 30, "force_disconnect_integrity_threshold": 20}})
	_expect(authored.san_attack.deck_attack_enabled and authored.san_attack.physical_deck_damage == 30 and authored.san_attack.deck_breach_integrity_threshold == 80, "ICE SAN/deck attacks are authored data rather than controller constants")
	var fixture := _fixture(false, 20)
	authored.san_attack.deck_breach_power = 20; authored.san_attack.deck_breach_integrity_threshold = 100
	fixture.controller.add_ice(IceInstance.new(&"KILLER", authored, &"SAN_HOST", IceState.Value.SEARCH))
	var events: Array[Dictionary] = fixture.controller.update(1, ActionRequest.new(&"PLAYER", ActionRequest.ActionType.WAIT))
	_expect(fixture.intrusion.lifecycle == IntrusionSession.Lifecycle.ABORTED and not fixture.san.active and _has(events, &"ICE_FORCED_DISCONNECT"), "configured lethal deck damage aborts the intrusion and destroys the SAN")

func _fixture(with_defenses := true, deck_integrity := 100) -> Dictionary:
	var graph := NetworkGraph.new(); graph.add_node(NetworkNodeDefinition.new(&"SAN_HOST", "SAN Host", NetworkNodeDefinition.NodeType.ROUTER)); graph.add_node(NetworkNodeDefinition.new(&"PLAYER_NODE", "Player Node", NetworkNodeDefinition.NodeType.ROUTER)); graph.add_link(NetworkLinkDefinition.new(&"LINK", &"SAN_HOST", &"PLAYER_NODE"))
	var manager := SystemAccessNodeManager.new(); var san: SystemAccessNode = manager.create_san(&"PLAYER", &"RUN", &"DECK", &"SAN_HOST").san
	var defenses := SANDefenseController.new()
	if with_defenses:
		for definition in SANDefenseCatalog.create_defaults(): defenses.install(san, definition)
	san.deck_accessible_storage.add_entry(DeckStorageEntry.new(&"DECK_PROGRAM", DeckStorageEntry.Kind.PROGRAM, "Deck Program"))
	var deck: RefCounted = DeckHardwareStateScript.new(&"DECK", deck_integrity)
	var intrusion := IntrusionSession.new(&"RUN"); intrusion.register_system_access_node(san)
	var controller := IceController.new(graph, PlayerNetworkPosition.new(&"PLAYER_NODE"), PlayerKnowledge.new())
	controller.configure_trails(null, &"RUN", &"PLAYER", manager); controller.configure_san_attacks(defenses); controller.register_san_attack_target(san, deck, intrusion)
	return {"controller": controller, "san": san, "deck": deck, "intrusion": intrusion}

func _has(events: Array[Dictionary], type: StringName) -> bool:
	return events.any(func(event): return event.type == type)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition: failures += 1; printerr("FAILED: %s" % description)
