extends Node

var failures := 0
var assertions := 0
@onready var game: Node = get_node("/root/Game")

func _ready() -> void:
	_test_defense_behaviors()
	await _test_game_and_inspection_ui()
	print("%s: %d SAN defense assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _test_defense_behaviors() -> void:
	var san := SystemAccessNode.new(&"SAN_TEST", &"OWNER", &"RUN", &"DECK", &"ENTRY")
	var controller := SANDefenseController.new()
	var defaults := SANDefenseCatalog.create_defaults()
	for definition in defaults: _expect(controller.install(san, definition).success, "%s installs as a reusable defense instance" % definition.id)
	_expect(san.defensive_systems.size() == 3 and san.defensive_systems.all(func(instance): return instance is SANDefenseInstance and instance.is_operational()), "SAN owns independent runtime defense instances")
	_expect(controller.access_resistance(san, &"ICE") == 5 and controller.access_resistance(san, &"HOSTILE_HACKER") == 4, "ICE Wall applies actor-specific SAN access resistance")
	var owner_interaction := controller.interact(san, &"OWNER", &"INSPECT")
	var hostile_interaction := controller.interact(san, &"INTRUDER", &"BREACH", &"HOSTILE_HACKER")
	_expect(owner_interaction.events.is_empty() and hostile_interaction.events.any(func(event): return event.type == &"SAN_WATCHDOG_ALERT"), "Watchdog alerts only when another actor interacts with the SAN")
	var deck_damage := controller.mitigate_deck_damage(san, 10)
	_expect(deck_damage.reduction == 3 and deck_damage.delivered_damage == 7, "Link Shield reduces physical deck damage delivered through the SAN")
	var integrity_damage := controller.apply_integrity_damage(san, 10, &"ICE")
	_expect(integrity_damage.reduction == 3 and integrity_damage.delivered_damage == 7 and san.integrity == 93, "defense hooks mitigate SAN integrity damage from ICE")
	var paid := SANDefenseDefinition.new(&"PAID", "Paid Module"); paid.resource_costs = {&"COMPUTE": 2}
	var resources := {&"COMPUTE": 2}
	_expect(controller.install(san, paid, 0.0, resources).success and resources[&"COMPUTE"] == 0, "defense installation can consume an available generic deck resource pool")
	_expect(not controller.install(san, paid, 0.0, resources).success, "installation rejects insufficient resources without inventing a separate economy")
	var view := controller.inspection_view(san)
	_expect(view.defenses.size() == 4 and view.defenses[0].has("state"), "inspection view exposes safe runtime defense state")

func _test_game_and_inspection_ui() -> void:
	game.start_session()
	_expect(game.player_system_access_node.defensive_systems.size() == 3, "Jack In installs the three initial player SAN defenses")
	var display := (load("res://cyberspace/display/NetworkDisplay.tscn") as PackedScene).instantiate()
	add_child(display); await get_tree().process_frame
	var san_id: StringName = game.player_system_access_node.id
	_expect(display.target_views.has(san_id), "normal cyberspace entity inspection lists the locally hosted SAN")
	display._select_target(san_id)
	_expect("ICE WALL" in display.target_details.text.to_upper() and "WATCHDOG" in display.target_details.text.to_upper() and "LINK SHIELD" in display.target_details.text.to_upper(), "SAN inspector presents installed defense names and states")
	game.san_defense_controller.interact(game.player_system_access_node, &"RIVAL", &"PROBE")
	_expect("WATCHDOG" in display.event_feed.text and "RIVAL" in display.event_feed.text, "Watchdog alert reaches the owning player's normal event feed")
	display.queue_free(); game.end_session()

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition: failures += 1; printerr("FAILED: %s" % description)
