extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void:
	var story := PersistentGameState.new()
	_expect(story.get_game_mode() == GameMode.Value.STORY and story.is_story_mode() and not story.is_free_roam_mode(), "new persistent state defaults explicitly to Story mode")
	story.set_game_mode(GameMode.Value.FREE_ROAM)
	var payload := story.to_save_data()
	_expect(payload.schema_version == PersistentGameState.CURRENT_SCHEMA_VERSION and payload.game_mode == "FREE_ROAM", "save data contains an explicit versioned game mode")
	var restored := PersistentGameState.from_save_data(payload)
	_expect(restored.is_free_roam_mode() and restored.get_game_mode() == GameMode.Value.FREE_ROAM, "dictionary save/load preserves Free Roam mode")
	var migrated := PersistentGameState.from_save_data({"schema_version": 1, "story_flags": [&"OLD_DEVELOPMENT_SAVE"]})
	_expect(migrated.is_story_mode() and migrated.schema_version == PersistentGameState.CURRENT_SCHEMA_VERSION, "older development saves migrate safely to explicit Story mode")
	var invalid := PersistentGameState.from_save_data({"schema_version": 2, "game_mode": "NOT_A_MODE"})
	_expect(invalid.is_story_mode(), "unknown saved modes fail safely to Story mode")

	var path := "user://game_mode_persistence_test.json"
	_expect(story.save_to_file(path) == OK, "persistent state writes through its save boundary")
	var file_result := PersistentGameState.load_from_file(path)
	_expect(file_result.error == OK and (file_result.state as PersistentGameState).is_free_roam_mode(), "file save/load preserves selected mode")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	print("%s: %d game-mode persistence assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
