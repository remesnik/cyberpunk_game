extends Node

var failures := 0
var assertions := 0

func _ready() -> void:
	Game.create_new_game(GameMode.Value.STORY)
	Game.start_session()
	_expect(Game.active_content_profile.get("kind", &"") == &"MEATSPACE_PROLOGUE", "Story Mode begins in the authored meat-space prologue")
	_expect(Game.game_domain == Game.GameDomain.MEATSPACE and Game.prologue_controller != null, "bedroom is playable before cyberspace entry")
	_expect(Game.san_controller.get_san(Game.intrusion_run_id) == null, "no SAN exists before the authored Jack In")
	var screen := (load("res://ui/story_prologue/StoryPrologueScreen.tscn") as PackedScene).instantiate() as StoryPrologueScreen
	add_child(screen)
	_expect(screen.visible and screen.interaction_list.get_child_count() == 1, "playable bedroom screen renders available authored objects")
	(screen.bedroom.objects[&"JACK_IN_INTERFACE"] as MeatspaceTarget3D).activate()
	screen._physical_action(&"JACK_IN_INTERFACE", &"STORY")
	_expect(Game.prologue_controller.selected_interaction_id == &"CLAN_TERMINAL" and screen.choice_panel.visible, "3D selection reaches authored Story Mode choice UI")
	var definition := load("res://data/authoring/story_prologue.tres") as MeatspacePrologueDefinition
	_expect(definition.validate().is_empty() and definition.interactions.size() == 6, "prologue interactions and choices are data-driven and valid")

	_choose(&"CLAN_TERMINAL", &"CLAN_GHOSTS")
	_expect(Game.persistent_game_state.player_state.clan_id == &"GHOSTS", "clan/play style persists through story flags and player state")
	_choose(&"DECK_CRATE", &"DECK_SCOUT")
	_expect(screen.bedroom.display_anchors[0].get_child_count() == 0, "deck choice leaves the display table empty")
	_expect(Game.persistent_game_state.player_state.deck_id == &"STARTER_SCOUT" and Game.persistent_game_state.player_state.hardware.DECK_RAM == 2, "starter deck choice changes persistent configuration")
	var credits_before := int(Game.persistent_game_state.player_state.credits)
	_choose(&"TOOLBOX", &"ADD_MEMORY")
	_expect(Game.persistent_game_state.player_state.hardware.DECK_RAM == 3 and Game.persistent_game_state.player_state.credits == credits_before - 75, "optional toolbox uses hardware and currency state")
	_choose(&"DECK_CHAIR", &"JACK_IN")
	_choose(&"BBS_DIALER", &"CONNECT_BBS")
	_choose(&"BBS_HELP_DESK", &"READ_BOARD")
	_expect(Game.prologue_controller != null and Game.persistent_game_state.campaign_state.story_flags.BBS_READ, "optional BBS interaction does not prematurely start the tutorial")
	_choose(&"BBS_HELP_DESK", &"ASK_FOR_GUIDE")
	_expect(Game.active_content_document != null and Game.active_content_document.document_id == &"FIRST_CONTACT", "asking for guidance hands off to FIRST_CONTACT")
	_expect(Game.player_network_position.current_node_id == &"ENTRY" and Game.san_controller.get_san(Game.intrusion_run_id) != null, "FIRST_CONTACT creates the real intrusion and SAN only after Jack In")
	_expect(Game.program_loadout.is_installed(&"STARTER_ROUTE_SNIFFER_001"), "selected prologue loadout is applied to the tutorial intrusion")
	_expect(Game.persistent_game_state.campaign_state.story_flags.PROLOGUE_COMPLETE and Game.persistent_game_state.campaign_state.story_flags.LATCH_CONTACTED, "prologue and Latch contact flags persist")
	_expect(not screen.visible, "bedroom screen yields cleanly when FIRST_CONTACT begins")
	screen.queue_free()
	Game.end_session()
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	print("%s: %d Story prologue integration assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _choose(interaction_id: StringName, choice_id: StringName) -> void:
	var result := Game.prologue_controller.choose(interaction_id, choice_id)
	_expect(bool(result.get("success", false)), "%s accepts authored choice %s" % [interaction_id, choice_id])

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)

