extends Node

var failures := 0
var assertions := 0
@onready var game: Node = get_node("/root/Game")

func _ready() -> void:
	_test_generic_registry()
	_test_player_jack_in_integration()
	print("%s: %d System Access Node assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _test_generic_registry() -> void:
	var manager := SystemAccessNodeManager.new()
	var created := manager.create_san(&"RIVAL_HACKER", &"RUN_ALPHA", &"RIVAL_DECK", &"ENTRY", 12.5, 80)
	_expect(created.success, "generic registry creates a hacker SAN")
	var san: SystemAccessNode = created.san
	_expect(san.owner_player_id == &"RIVAL_HACKER" and san.intrusion_id == &"RUN_ALPHA" and san.deck_id == &"RIVAL_DECK", "SAN associates actor, intrusion, and deck")
	_expect(san.host_node_id == &"ENTRY" and san.created_at == 12.5 and san.integrity == 80, "SAN records its host, creation marker, and integrity")
	var duplicate := manager.create_san(&"RIVAL_HACKER", &"RUN_ALPHA", &"OTHER_DECK", &"OTHER_NODE")
	_expect(not duplicate.success and manager.instances.size() == 1, "one actor cannot receive two SANs in the same intrusion")
	var allied := manager.create_san(&"ALLY_HACKER", &"RUN_ALPHA", &"ALLY_DECK", &"ENTRY")
	_expect(allied.success and manager.instances.size() == 2, "different hackers may own independent SANs in one intrusion")
	_expect(manager.relocate(san.id, &"RELAY").success and san.host_node_id == &"RELAY", "explicit relocation changes only the hosted node reference")
	_expect(san.apply_damage(25) == 25 and san.integrity == 55 and san.active, "SAN exposes integrity and defensive-system state for future ICE interactions")
	_expect(manager.destroy_san(san.id) and not san.active and san.deck_link_state == SystemAccessNode.DeckLinkState.SEVERED, "destroying a SAN severs its deck link")

func _test_player_jack_in_integration() -> void:
	game.start_session()
	var san: SystemAccessNode = game.player_system_access_node
	var entry_id: StringName = game.player_network_position.current_node_id
	var graph_node_count: int = game.network_graph.nodes.size()
	_expect(san != null and san.active, "Jack In creates the player SAN")
	_expect(san.owner_player_id == game.active_player_id and san.intrusion_id == game.intrusion_run_id and san.deck_id == game.active_deck_id, "player SAN uses live player, intrusion, and deck IDs")
	_expect(san.host_node_id == entry_id and game.network_graph.get_node(entry_id) != null, "player SAN is hosted inside the exact entry node")
	_expect(game.intrusion_session.get_system_access_node(game.active_player_id) == san, "intrusion session retains its SAN association")
	_expect(game.system_access_node_manager.get_for_connection(game.active_player_id, game.intrusion_run_id) == san, "registry resolves the one SAN for the player/intrusion pair")
	_expect(game.network_graph.nodes.size() == graph_node_count and not game.network_graph.nodes.has(san.id), "SAN is not inserted as a navigable graph node")
	var destination: StringName = game.network_graph.get_visible_connected_nodes(entry_id)[0]
	game.player_network_position.relocate(destination)
	_expect(game.player_network_position.current_node_id == destination and san.host_node_id == entry_id, "ordinary graph movement does not drag or recreate the hosted SAN")
	var duplicate: Dictionary = game.system_access_node_manager.create_san(game.active_player_id, game.intrusion_run_id, game.active_deck_id, entry_id)
	_expect(not duplicate.success, "active Jack-In state cannot create a duplicate player SAN")
	game.end_session()
	_expect(not san.active and san.deck_link_state == SystemAccessNode.DeckLinkState.SEVERED, "ending the intrusion retires its SAN")

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition: failures += 1; printerr("FAILED: %s" % description)
