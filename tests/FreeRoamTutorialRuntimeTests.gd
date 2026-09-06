extends Node

var failures := 0
var assertions := 0

func _ready() -> void:
	var game := get_node("/root/Game")
	game.create_new_game(GameMode.Value.FREE_ROAM, {"run_introduction": true})
	_expect(game.is_content_available(&"FIRST_CONTACT_FREE_ROAM_TUTORIAL") and not game.is_content_available(&"FIRST_CONTACT"), "Free Roam receives only its optional tutorial wrapper")
	game.start_session()
	_expect(game.active_content_document != null and game.active_content_document.document_id == &"FIRST_CONTACT", "wrapper reuses the FIRST_CONTACT authored systems content")
	_expect(game.active_content_profile.tutorial_profile == &"FREE_ROAM_OPTIONAL", "runtime retains the Free Roam tutorial profile")
	_expect(not game.active_content_profile.campaign_progression_enabled and game.persistent_game_state.campaign_state.is_empty(), "tutorial cannot activate authored campaign progression")
	_expect(game.player_network_position.current_node_id == &"ENTRY" and game.hacker_npc_manager.get_actor(&"LATCH_REMOTE_ACTOR") != null, "optional introduction retains its graph and Latch guidance")
	_expect(game.action_clock != null and game.realtime_world_clock != null and game.san_controller != null, "optional tutorial uses production gameplay systems")
	var completion: Dictionary = game.complete_optional_tutorial()
	_expect(completion.success and completion.next_content_id == &"FREE_ROAM_HOME", "optional introduction returns to the normal Free Roam home flow")
	_expect(game.persistent_game_state.campaign_state.is_empty() and game.persistent_game_state.world_state.tutorial_state.introduction_completed, "tutorial completion remains outside campaign progression")
	game.end_session()
	print("%s: %d Free Roam tutorial assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
