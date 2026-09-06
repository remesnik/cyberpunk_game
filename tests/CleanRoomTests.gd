extends Node

var failures := 0
var assertions := 0

func _ready() -> void:
	var game := get_node("/root/Game")
	game.create_new_game(GameMode.Value.FREE_ROAM)
	game.start_session()
	_expect(game.game_domain == game.GameDomain.MEATSPACE, "new Free Roam session begins at home")
	_expect(game.enter_free_roam_network().success and game.game_domain == game.GameDomain.CLEAN_ROOM, "Meatspace entry stops in the Clean-Room")
	var controller: CleanRoomController = game.clean_room_controller
	var initial := controller.view()
	var initial_credits := int(initial.credits)
	var cost := int(initial.next_link_cost)
	var initial_transfer := controller.adjusted_transfer_cost(3)
	_expect(controller.buy_link().success and game.equipment_order_manager.credits == initial_credits - cost, "buying a link deducts the displayed IC cost")
	_expect(controller.adjusted_transfer_cost(3) > initial_transfer and controller.trace_resolution_multiplier() > 1.0, "higher connection values slow transfer and trace resolution")
	game.equipment_order_manager.credits = 0
	_expect(not controller.can_buy_link() and not controller.buy_link().success, "unaffordable connection links are rejected")
	var deck := controller.view()
	var unloaded: Array = deck.owned_programs.filter(func(item: Dictionary): return not bool(item.installed))
	if not unloaded.is_empty():
		var instance_id := StringName(unloaded[0].instance_id)
		_expect(controller.install_program(instance_id).success and game.program_loadout.is_installed(instance_id), "Clean-Room active-slot loading uses the persistent deck loadout")
	_expect(controller.contact_ally(&"LATCH").success and not game.meatspace_management.story_interactions.is_empty(), "Clean-Room ally contact uses the Story interaction service")
	_expect(game.enter_netspace_from_clean_room().success and game.game_domain == game.GameDomain.CYBERSPACE, "GO enters Netspace")
	_expect(game.jack_out_normally().success and game.game_domain == game.GameDomain.CLEAN_ROOM, "leaving Netspace returns to the Clean-Room")
	_expect(game.return_home_from_clean_room().success and game.game_domain == game.GameDomain.MEATSPACE, "Return Home leaves the Clean-Room for Meatspace")
	game.end_session()

	game.create_new_game(GameMode.Value.STORY)
	game.persistent_game_state.campaign_state["pending_entry_content_id"] = &"FIRST_CONTACT"
	game.persistent_game_state.campaign_state["current_content_id"] = &"FIRST_CONTACT"
	game.start_session()
	var flags: Dictionary = game.persistent_game_state.campaign_state.get("story_flags", {})
	_expect(bool(flags.get(&"CLEAN_ROOM_LATCH_CONTACTED", false)), "Latch contacts the player on the first Story Clean-Room visit")
	var contacts_before: int = game.meatspace_management.story_interactions.size()
	game.clean_room_controller.enter()
	_expect(game.meatspace_management.story_interactions.size() == contacts_before, "automatic Latch first contact does not repeat")
	game.end_session()
	print("%s: %d Clean-Room assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
