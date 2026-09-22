extends Node

var failures := 0
var assertions := 0
var save_path := "res://.test_first_contact_finale/autosave.json"


func _ready() -> void:
	var game := get_node("/root/Game")
	game.create_new_game(GameMode.Value.STORY)
	game.persistent_game_state.campaign_state["pending_entry_content_id"] = &"FIRST_CONTACT"
	game.persistent_game_state.campaign_state["current_content_id"] = &"FIRST_CONTACT"
	game.persistent_game_state.campaign_state.story_flags[&"FIRST_CONTACT_AVAILABLE"] = true
	game.persistent_game_state.campaign_state.story_flags[&"FIRST_CONTACT_STARTED"] = true
	game.autosave_service.autosave_path = save_path
	game.start_session()
	game.game_domain = game.GameDomain.CYBERSPACE
	_expect(game.active_content_document != null and game.active_content_document.document_id == &"FIRST_CONTACT", "test runs the authored First Contact network")
	var initial_credits := int(game.persistent_game_state.player_state.credits)
	game.publish_story_trigger(&"service_disabled", {"service_id": &"ACCESS_LOG"})
	_expect(bool(game.persistent_game_state.world_state.get("first_contact_cleanup_complete", false)), "disabling the authored access log completes the cleanup state")
	var result: Dictionary = game.complete_intrusion_and_return_to_meatspace({"exit_node": &"EXIT", "cleanup_service_id": &"ACCESS_LOG"})
	var flags: Dictionary = game.persistent_game_state.campaign_state.story_flags
	_expect(result.success and game.game_domain == game.GameDomain.MEATSPACE and game.intrusion_session.lifecycle == IntrusionSession.Lifecycle.COMPLETED, "proper exit completes the intrusion and returns to meatspace")
	_expect(bool(flags.get(&"FIRST_CONTACT_COMPLETE", false)) and game.story_mission_system.status(&"glasshouse_01") == StoryMissionSystem.AVAILABLE, "completion unlocks the next Story Mode mission")
	_expect(int(game.persistent_game_state.player_state.credits) == initial_credits + 10, "First Contact awards its small IC reward exactly once")
	_expect(game.persistent_game_state.save_metadata.get("autosave_reason", &"") == &"MISSION_COMPLETE", "final meatspace return uses the mission-complete autosave policy")
	game.end_session()
	_cleanup()
	print("%s: %d First Contact finale assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)


func _cleanup() -> void:
	var absolute := ProjectSettings.globalize_path(save_path)
	if FileAccess.file_exists(absolute): DirAccess.remove_absolute(absolute)
	var directory := absolute.get_base_dir()
	if DirAccess.dir_exists_absolute(directory): DirAccess.remove_absolute(directory)


func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
