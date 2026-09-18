extends Node

var failures := 0
var assertions := 0

func _ready() -> void:
	var game := get_node("/root/Game")
	game.create_new_game(&"FREE_ROAM")
	_expect(game.get_game_mode() == GameMode.Value.FREE_ROAM and game.is_free_roam_mode(), "Game exposes the selected explicit mode")
	var payload: Dictionary = game.serialize_persistent_state()
	game.create_new_game(&"STORY_MODE")
	game.restore_persistent_state(payload)
	_expect(game.is_free_roam_mode(), "Game-level save restoration preserves mode independently of mission state")
	game.restore_persistent_state({"schema_version": 1})
	_expect(game.is_story_mode(), "Game-level legacy restoration applies the documented migration")
	var frontend: FrontendRoot = (load("res://ui/frontend/frontend_root.tscn") as PackedScene).instantiate()
	frontend.automatically_start_gameplay = false
	add_child(frontend)
	await get_tree().process_frame
	frontend.game_mode_selection.mode_selected.emit(&"FREE_ROAM")
	await get_tree().process_frame; await get_tree().process_frame; await get_tree().process_frame
	_expect(frontend.current_screen == FrontendRoot.Screen.TUTORIAL_PROMPT, "Free Roam selection asks whether to run the optional introduction")
	frontend.tutorial_prompt.decision_made.emit(false)
	_expect(game.is_free_roam_mode(), "frontend mode confirmation writes Game state before gameplay handoff")
	frontend.queue_free()
	print("%s: %d Game autoload mode assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
