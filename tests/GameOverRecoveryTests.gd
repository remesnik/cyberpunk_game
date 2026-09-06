extends Node

const AutosaveService := preload("res://core/save/MeatspaceAutosaveService.gd")

var failures := 0
var assertions := 0
var save_dir := "user://game_over_recovery_test"
var save_path := save_dir.path_join("autosave.json")

func _ready() -> void:
	var game := get_node("/root/Game")
	_cleanup()
	game.autosave_service.autosave_path = save_path
	game.autosave_service.successful_save_count = 0
	game.create_new_game(GameMode.Value.FREE_ROAM)
	game.start_session()
	game.meatspace_management.hardware_levels.DECK_RAM = 4
	game.equipment_order_manager.credits = 612
	game.persistent_game_state.world_state["current_meatspace_location_id"] = &"SAFEHOUSE_DECK_BAY"
	_expect(game.request_meatspace_autosave(AutosaveService.Reason.RETURN_TO_MEATSPACE) == OK, "meat-space recovery point is saved")
	var save_count: int = game.autosave_service.successful_save_count
	_expect(game.enter_free_roam_network().success, "player enters cyberspace after the save")
	game.trace_level = 77
	game.equipment_order_manager.credits = 3
	game.meatspace_management.hardware_levels.DECK_RAM = 9
	game.resource_state.add_volatile(&"UNSAVED_LOOT", 8)
	game.request_action(ActionRequest.new(&"PLAYER", ActionRequest.ActionType.WAIT, &"", 4))

	var screen: CanvasLayer = (load("res://ui/game_over/GameOverScreen.tscn") as PackedScene).instantiate()
	add_child(screen)
	await get_tree().process_frame
	var over: Dictionary = game.trigger_game_over("DECK LINK DESTROYED")
	await get_tree().process_frame
	_expect(over.success and not game.session_active and game.game_over_active, "Game Over terminates the failed runtime cleanly")
	_expect(screen.visible and screen.continue_button.visible and "AUTOSAVE AVAILABLE" in screen.status_label.text, "Game Over presents a usable Continue state")
	_expect(game.autosave_service.successful_save_count == save_count, "Game Over itself creates no autosave")
	screen.continue_button.pressed.emit()
	await get_tree().process_frame
	_expect(not game.game_over_active and game.session_active and not screen.visible, "Continue closes Game Over and starts recovered runtime")
	_expect(game.is_free_roam_mode() and game.game_domain == game.GameDomain.MEATSPACE, "Continue returns to the saved mode in meat space")
	_expect(game.equipment_order_manager.credits == 612 and game.meatspace_management.hardware_levels.DECK_RAM == 4, "unsaved dangerous-activity mutations are discarded")
	_expect(game.trace_level == 0 and game.resource_state.volatile_resources.get(&"UNSAVED_LOOT", 0) == 0, "recovery does not restore the last cyber tick, trace, or loot")
	game.end_session()
	screen.queue_free()

	# Missing autosave has a visible, deterministic mode-start fallback.
	_cleanup()
	game.create_new_game(GameMode.Value.STORY)
	game.start_session()
	var fallback_screen: CanvasLayer = (load("res://ui/game_over/GameOverScreen.tscn") as PackedScene).instantiate()
	add_child(fallback_screen)
	await get_tree().process_frame
	var no_save: Dictionary = game.trigger_game_over("NO CARRIER")
	await get_tree().process_frame
	_expect(no_save.success and not no_save.can_continue and "NO VALID" in fallback_screen.status_label.text, "missing autosave is explained rather than failing silently")
	fallback_screen.continue_button.pressed.emit()
	await get_tree().process_frame
	_expect(game.is_story_mode() and game.session_active and game.active_content_profile.get("kind", &"") == &"MEATSPACE_PROLOGUE", "missing-save Continue falls back to the Story prologue")
	game.end_session()
	fallback_screen.queue_free()
	_cleanup()
	print("%s: %d Game Over recovery assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _cleanup() -> void:
	var file := ProjectSettings.globalize_path(save_path)
	if FileAccess.file_exists(file): DirAccess.remove_absolute(file)
	var directory := ProjectSettings.globalize_path(save_dir)
	if DirAccess.dir_exists_absolute(directory): DirAccess.remove_absolute(directory)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition: failures += 1; printerr("FAILED: %s" % description)
