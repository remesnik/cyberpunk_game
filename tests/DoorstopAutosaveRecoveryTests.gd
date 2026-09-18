extends Node

var failures := 0
var assertions := 0
var save_dir := "user://doorstop_autosave_recovery_test"
var save_path := save_dir.path_join("autosave.json")

func _ready() -> void:
	var game := get_node("/root/Game")
	_cleanup()
	game.autosave_service.autosave_path = save_path
	game.autosave_service.successful_save_count = 0
	game.create_new_game(GameMode.Value.FREE_ROAM)
	game.start_session()
	game.meatspace_management.start_programming(&"SAVED_DOORSTOP_TASK", game.doorstop_programming_definition)
	game.enter_free_roam_network()
	game.resource_state.add_volatile(&"SAVED_LOOT", 4)
	var source_id := &"FREEROAM_DOORSTOP_001"
	game.program_loadout.install(source_id, game.program_inventory)
	_expect(game.request_doorstop_deployment(source_id).success, "Doorstop deploys and relocates the single SAN")
	var anchor_node: StringName = game.player_network_position.current_node_id
	_expect(game.jack_out_through_doorstop().success and FileAccess.file_exists(save_path), "successful Doorstop meat-space entry creates the recovery autosave")
	var save_count: int = game.autosave_service.successful_save_count
	var saved: PersistentGameState = PersistentGameState.load_from_file(save_path).state
	_expect(not _saved_inventory_has(saved, source_id), "consumed Doorstop is absent from the Doorstop autosave")
	_expect(saved.world_state.intrusion_snapshot.lifecycle == IntrusionSession.Lifecycle.SUSPENDED_AT_DOORSTOP and saved.world_state.intrusion_snapshot.anchor.cyberspace_node_id == anchor_node, "autosave contains the suspended intrusion and exact return anchor")
	_expect(saved.world_state.programming_tasks.size() == 1, "programming task is captured once")

	_expect(game.jack_back_in_through_doorstop().success, "player re-enters through the live Doorstop")
	game.resource_state.add_volatile(&"SAVED_LOOT", 5)
	game.trace_level = 91
	var over: Dictionary = game.trigger_game_over("ICE DUMP")
	_expect(over.success and game.autosave_service.successful_save_count == save_count, "Game Over after re-entry does not replace the Doorstop autosave")
	var recovery: Dictionary = game.continue_from_game_over()
	_expect(recovery.success and recovery.from_autosave and game.game_domain == game.GameDomain.MEATSPACE, "Continue restores the Doorstop meat-space state")
	_expect(game.intrusion_session.lifecycle == IntrusionSession.Lifecycle.SUSPENDED_AT_DOORSTOP and game.intrusion_session.can_resume_through_doorstop(), "loaded intrusion is valid and suspended at Doorstop")
	_expect(game.doorstop_controller.anchors_by_run.size() == 1 and game.san_controller.sans_by_intrusion.size() == 1, "recovery creates exactly one anchor and one SAN")
	_expect(game.san_controller.get_san(game.intrusion_run_id).host_node_id == anchor_node and game.intrusion_session.suspended_anchor.cyberspace_node_id == anchor_node, "restored SAN and Doorstop agree on the saved host node")
	_expect(not game.program_inventory.has_instance(source_id), "recovery does not duplicate the burned Doorstop")
	_expect(game.resource_state.volatile_resources.get(&"SAVED_LOOT", 0) == 4, "loot rolls back to the saved amount without duplication")
	_expect(game.meatspace_management.programming_tasks.size() == 1 and game.meatspace_management.programming_tasks.has(&"SAVED_DOORSTOP_TASK"), "programming task restores exactly once")
	_expect(game.jack_back_in_through_doorstop().success and game.doorstop_controller.anchors_by_run.is_empty(), "restored Doorstop route can be consumed once without duplicating intrusion state")
	game.end_session()
	_cleanup()
	print("%s: %d Doorstop autosave recovery assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _saved_inventory_has(state: PersistentGameState, instance_id: StringName) -> bool:
	for record: Dictionary in state.player_state.get("owned_programs", []):
		if StringName(record.get("instance_id", &"")) == instance_id: return true
	return false

func _cleanup() -> void:
	var file := ProjectSettings.globalize_path(save_path)
	if FileAccess.file_exists(file): DirAccess.remove_absolute(file)
	var directory := ProjectSettings.globalize_path(save_dir)
	if DirAccess.dir_exists_absolute(directory): DirAccess.remove_absolute(directory)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition: failures += 1; printerr("FAILED: %s" % description)
