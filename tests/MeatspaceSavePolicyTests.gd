extends Node

const AutosaveService := preload("res://core/save/MeatspaceAutosaveService.gd")

var failures := 0
var assertions := 0
var save_dir := "user://meatspace_save_policy_test"
var save_path := save_dir.path_join("autosave.json")

func _ready() -> void:
	var game := get_node("/root/Game")
	_cleanup()
	game.autosave_service.autosave_path = save_path
	game.autosave_service.request_count = 0
	game.autosave_service.successful_save_count = 0

	game.create_new_game(GameMode.Value.FREE_ROAM)
	game.start_session()
	_expect(game.enter_free_roam_network().success, "test intrusion enters cyberspace")
	_expect(game.enter_netspace_from_clean_room().success, "Clean-Room GO begins the test intrusion")
	var initial_requests: int = game.autosave_service.request_count
	var wait: ActionResult = game.request_action(ActionRequest.new(&"PLAYER", ActionRequest.ActionType.WAIT, &"", 3))
	_expect(wait.success and game.action_clock.current_tick == 3, "cyberspace action advances the cyber clock")
	_expect(game.autosave_service.request_count == initial_requests and not FileAccess.file_exists(save_path), "cyberspace actions and ticks create no autosave")
	_expect(game.save_persistent_state(save_dir.path_join("manual.json")) == ERR_UNAUTHORIZED, "manual normal save is rejected during cyberspace")

	var doorstop_id := &"FREEROAM_DOORSTOP_001"
	_expect(game.program_loadout.install(doorstop_id, game.program_inventory), "Doorstop is installed for save-policy integration")
	var deployment: ActionResult = game.request_doorstop_deployment(doorstop_id)
	_expect(deployment.success and game.autosave_service.request_count == initial_requests, "program execution and Doorstop deployment do not save while still in cyberspace")
	var exit: Dictionary = game.jack_out_through_doorstop()
	_expect(exit.success and game.autosave_service.successful_save_count == 1 and FileAccess.file_exists(save_path), "Doorstop exit creates exactly one meat-space autosave")
	var loaded: Dictionary = PersistentGameState.load_from_file(save_path)
	_expect(loaded.error == OK and loaded.state.is_free_roam_mode(), "autosave preserves explicit game mode")
	var saved: PersistentGameState = loaded.state
	var saved_loadout := PackedStringArray(saved.player_state.installed_program_instance_ids.map(func(value: Variant) -> String: return String(value)))
	var runtime_loadout := PackedStringArray(game.program_loadout.installed_instance_ids.map(func(value: Variant) -> String: return String(value)))
	_expect(saved.player_state.owned_programs.size() == game.program_inventory.all_instances().size() and saved_loadout == runtime_loadout, "autosave captures inventory and current loadout after the consumed Doorstop")
	_expect(int(saved.player_state.hardware.DECK_CPU) == int(game.meatspace_management.hardware_levels.DECK_CPU) and int(saved.player_state.hardware.DECK_RAM) == int(game.meatspace_management.hardware_levels.DECK_RAM) and int(saved.player_state.credits) == game.equipment_order_manager.credits, "autosave captures deck hardware and credits")
	_expect(saved.world_state.has("network_knowledge") and saved.world_state.has("intrusion_snapshot") and saved.world_state.intrusion_snapshot.lifecycle == IntrusionSession.Lifecycle.SUSPENDED_AT_DOORSTOP, "autosave captures knowledge and suspended intrusion state")
	_expect(saved.save_metadata.autosave_reason == &"DOORSTOP_EXIT", "autosave records its centralized reason")
	game.end_session()

	# The other public cyberspace-to-meat-space routes use the same policy.
	_cleanup_file()
	game.autosave_service.successful_save_count = 0
	game.create_new_game(GameMode.Value.STORY)
	game.start_session()
	game.enter_netspace_from_clean_room()
	var normal: Dictionary = game.jack_out_normally()
	_expect(normal.success and game.intrusion_session.lifecycle == IntrusionSession.Lifecycle.ABORTED and game.game_domain == game.GameDomain.CLEAN_ROOM, "normal Jack Out returns to the Clean-Room")
	_expect(game.autosave_service.successful_save_count == 0, "Clean-Room return does not masquerade as a Meatspace autosave")
	game.end_session()

	_cleanup_file()
	game.autosave_service.successful_save_count = 0
	game.create_new_game(GameMode.Value.STORY)
	game.start_session()
	game.enter_netspace_from_clean_room()
	var completed: Dictionary = game.complete_intrusion_and_return_to_meatspace({&"objective_id": &"TEST_OBJECTIVE"})
	_expect(completed.success and game.intrusion_session.lifecycle == IntrusionSession.Lifecycle.COMPLETED and game.game_domain == game.GameDomain.CLEAN_ROOM, "mission completion returns to the Clean-Room")
	_expect(game.autosave_service.successful_save_count == 0, "mission Clean-Room return waits for an explicit home transition before saving")
	game.end_session()

	_cleanup()
	print("%s: %d meat-space save-policy assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _cleanup_file() -> void:
	var absolute := ProjectSettings.globalize_path(save_path)
	if FileAccess.file_exists(absolute): DirAccess.remove_absolute(absolute)

func _cleanup() -> void:
	_cleanup_file()
	var directory := ProjectSettings.globalize_path(save_dir)
	if DirAccess.dir_exists_absolute(directory): DirAccess.remove_absolute(directory)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
