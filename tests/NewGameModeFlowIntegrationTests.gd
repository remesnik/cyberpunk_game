extends Node

const AutosaveService := preload("res://core/save/MeatspaceAutosaveService.gd")

var failures := 0
var assertions := 0
var _new_game_emissions := 0
var _save_directory := "user://new_game_mode_flow_integration"

func _ready() -> void:
	await _run()
	print("%s: %d new-game mode flow integration assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _run() -> void:
	var game := get_node("/root/Game")
	var frontend := await _create_frontend()
	frontend.new_game_requested.connect(func() -> void: _new_game_emissions += 1)

	# Merely entering, focusing, backing out, and entering again must not create state.
	game.create_new_game(GameMode.Value.FREE_ROAM)
	var untouched_state: PersistentGameState = game.persistent_game_state
	frontend.main_menu.new_game_requested.emit()
	await _settle()
	frontend.game_mode_selection.story_option.grab_focus()
	await get_tree().process_frame
	frontend.game_mode_selection.free_roam_option.grab_focus()
	await get_tree().process_frame
	_expect(game.persistent_game_state == untouched_state and _new_game_emissions == 0, "switching card focus initializes neither mode")
	frontend.game_mode_selection.back_requested.emit()
	await _settle()
	frontend.main_menu.new_game_requested.emit()
	await _settle()
	_expect(game.persistent_game_state == untouched_state and _new_game_emissions == 0, "repeated New Game navigation does not duplicate game state")
	frontend.game_mode_selection.back_requested.emit()
	await _settle()
	_expect(frontend.current_screen == FrontendRoot.Screen.MAIN_MENU, "Back from mode selection returns to Main Menu")

	# MAIN MENU -> NEW GAME -> STORY MODE -> START.
	frontend.main_menu.new_game_requested.emit()
	await _settle()
	frontend.game_mode_selection.story_option.pressed.emit()
	_expect(frontend.game_mode_selection.confirmation.visible, "Story Mode requires its explicit summary/Start state")
	frontend.game_mode_selection.start_button.transmitted.emit()
	await get_tree().process_frame
	_expect(game.get_game_mode() == GameMode.Value.STORY, "Story flow stores STORY as the explicit game mode")
	_expect(game.persistent_game_state.campaign_state.get("campaign_id", &"") == &"MAIN_CAMPAIGN", "Story flow performs campaign initialization")
	_expect(game.persistent_game_state.campaign_state.get("pending_entry_content_id", &"") == &"STORY_PROLOGUE", "Story flow selects the authored bedroom prologue")
	_expect(game.is_content_available(&"FIRST_CONTACT") and not game.is_content_available(&"FREE_ROAM_HOME"), "Story content eligibility is active")
	var committed_story_state: PersistentGameState = game.persistent_game_state
	frontend.game_mode_selection.start_button.transmitted.emit()
	await get_tree().process_frame
	_expect(game.persistent_game_state == committed_story_state and _new_game_emissions == 1, "repeated Story Start input cannot create a duplicate game state")
	game.start_session()
	_expect(game.active_content_profile.get("kind", &"") == &"MEATSPACE_PROLOGUE" and game.prologue_controller != null, "Story runtime loads the playable prologue before FIRST_CONTACT")
	game.end_session()
	var story_payload: Dictionary = game.serialize_persistent_state()
	game.create_new_game(GameMode.Value.FREE_ROAM)
	game.restore_persistent_state(story_payload)
	_expect(game.is_story_mode() and game.persistent_game_state.campaign_state.get("campaign_id", &"") == &"MAIN_CAMPAIGN", "save/load preserves Story mode and campaign state")

	frontend.queue_free()
	await get_tree().process_frame
	frontend = await _create_frontend()
	frontend.new_game_requested.connect(func() -> void: _new_game_emissions += 1)

	# MAIN MENU -> NEW GAME -> FREE ROAM -> START -> decline optional intro.
	frontend.main_menu.new_game_requested.emit()
	await _settle()
	frontend.game_mode_selection.free_roam_option.pressed.emit()
	_expect(frontend.game_mode_selection.confirmation.visible, "Free Roam also requires explicit Start")
	frontend.game_mode_selection.start_button.transmitted.emit()
	await _settle()
	_expect(frontend.current_screen == FrontendRoot.Screen.TUTORIAL_PROMPT, "Free Roam Start routes through the optional introduction choice")
	frontend.tutorial_prompt.decision_made.emit(false)
	await get_tree().process_frame
	_expect(game.get_game_mode() == GameMode.Value.FREE_ROAM, "Free Roam flow stores FREE_ROAM explicitly")
	_expect(game.persistent_game_state.campaign_state.is_empty(), "Free Roam does not perform campaign initialization")
	_expect(game.persistent_game_state.world_state.get("pending_entry_content_id", &"") == &"FREE_ROAM_HOME" and game.persistent_game_state.world_state.get("available_dynamic_job_ids", []).size() == 5, "Free Roam bootstrap state loads")
	var committed_free_state: PersistentGameState = game.persistent_game_state
	frontend.tutorial_prompt.decision_made.emit(false)
	await get_tree().process_frame
	_expect(game.persistent_game_state == committed_free_state and _new_game_emissions == 2, "repeated Free Roam confirmation cannot create a duplicate game state")
	_prepare_save_directory()
	var save_path := _save_directory.path_join("free_roam.json")
	game.autosave_service.autosave_path = save_path
	game.start_session()
	_expect(game.free_roam_job_board != null and game.equipment_order_manager.vendors.size() > 0 and game.meatspace_management != null, "sandbox and shared job, vendor, programming, and management systems are available")
	_expect(game.mission == null and game.facility_scenario == null and not game.is_content_available(&"FIRST_CONTACT"), "Story-only mission chains do not automatically begin")
	_expect(game.request_meatspace_autosave(AutosaveService.Reason.RETURN_TO_MEATSPACE) == OK, "Free Roam state saves through the meat-space policy API")
	game.end_session()

	# Save/load and the real frontend Continue adapter must retain Free Roam.
	game.create_new_game(GameMode.Value.STORY)
	_expect(game.load_persistent_state(save_path) == OK and game.is_free_roam_mode(), "direct save/load preserves Free Roam mode")
	game.create_new_game(GameMode.Value.STORY)
	var provider := PersistentGameSaveProvider.new(_save_directory)
	provider.refresh()
	frontend.set_save_provider(provider)
	frontend.show_main_menu()
	await _settle()
	frontend.main_menu.continue_game_requested.emit()
	await get_tree().process_frame
	_expect(game.is_free_roam_mode() and game.persistent_game_state.campaign_state.is_empty(), "Continue restores the saved mode without running Story initialization")

	frontend.queue_free()
	_cleanup_save_directory()

func _create_frontend() -> FrontendRoot:
	var frontend := (load("res://ui/frontend/frontend_root.tscn") as PackedScene).instantiate() as FrontendRoot
	frontend.initial_screen = FrontendRoot.Screen.MAIN_MENU
	frontend.transition_duration = 0.0
	frontend.automatically_start_gameplay = false
	add_child(frontend)
	await get_tree().process_frame
	return frontend

func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

func _prepare_save_directory() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_save_directory))

func _cleanup_save_directory() -> void:
	var file_path := ProjectSettings.globalize_path(_save_directory.path_join("free_roam.json"))
	if FileAccess.file_exists(file_path): DirAccess.remove_absolute(file_path)
	var directory_path := ProjectSettings.globalize_path(_save_directory)
	if DirAccess.dir_exists_absolute(directory_path): DirAccess.remove_absolute(directory_path)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
