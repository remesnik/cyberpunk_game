extends Node

var failures := 0
var assertions := 0

func _ready() -> void:
	var game := get_node("/root/Game")
	game.create_new_game(GameMode.Value.STORY); game.start_session()
	var state: PersistentGameState = game.persistent_game_state
	var story := StoryState.new(state)
	_expect(int(state.player_state.credits) == 25, "new game starts with 25 IC")
	_expect(not story.get_flag(&"DECK_SELECTED"), "starter box is initially present")
	_expect(not StoryBindingEvaluator.matches({"scope": &"flag", "id": &"DECK_SELECTED", "operator": &"flag_true"}, state), "computer is initially hidden")

	var storage_state := PersistentGameState.new(); StoryModeNewGameInitializer.initialize(storage_state)
	var storage_controller := MeatspacePrologueController.new(); storage_controller.configure(load("res://data/authoring/story_prologue.tres"), storage_state); storage_controller.choose(&"DECK_CRATE", &"DECK_BALANCED")
	_expect(int(storage_state.player_state.active_slot_count) == 2, "More Storage grants two active slots")
	var slots_state := PersistentGameState.new(); StoryModeNewGameInitializer.initialize(slots_state)
	var slots_controller := MeatspacePrologueController.new(); slots_controller.configure(load("res://data/authoring/story_prologue.tres"), slots_state); slots_controller.choose(&"DECK_CRATE", &"DECK_SCOUT")
	_expect(int(slots_state.player_state.active_slot_count) == 3, "More Slots grants three active slots")
	game.prologue_controller.choose(&"DECK_CRATE", &"DECK_SCOUT")
	_expect(story.get_flag(&"DECK_SELECTED"), "box disappears after deck choice")
	_expect(StoryBindingEvaluator.matches({"scope": &"flag", "id": &"DECK_SELECTED", "operator": &"flag_true"}, state), "computer appears after deck choice")

	story.set_flag(&"DECK_ASSEMBLED", true); story.set_flag(&"CLAN_SELECTED", true); state.player_state["player_class"] = "VIRUS"
	var connected: Dictionary = game.prologue_controller.connect_first_contact()
	_expect(connected.success and game.game_domain == game.GameDomain.CLEAN_ROOM, "computer enters the Clean-Room")
	story = StoryState.new(game.persistent_game_state)
	_expect(story.has_completed_event(&"latch_first_contact"), "first Clean-Room visit fires Latch event")
	_expect(story.is_contact_unlocked(&"latch"), "Latch unlocks as a contact")
	var latch_count := story.get_event_count(&"latch_first_contact"); game.clean_room_controller.enter()
	_expect(story.get_event_count(&"latch_first_contact") == latch_count, "Latch first contact remains one-shot")
	_expect(game.story_mission_system.status(&"glasshouse_01") == StoryMissionSystem.AVAILABLE, "Glasshouse becomes available")
	_expect(not game.clean_room_controller.view().mission_briefing.is_empty(), "Clean-Room presents authored briefing")

	var entered: Dictionary = game.enter_netspace_from_clean_room()
	_expect(entered.success and game.story_mission_system.status(&"glasshouse_01") == StoryMissionSystem.ACTIVE, "GO starts Glasshouse")
	_expect(game.active_content_document != null and game.active_content_document.document_id == &"GLASSHOUSE_01", "GO loads authored Glasshouse network")
	_expect(game.network_graph.nodes.size() == 7 and game.network_graph.get_node(&"WARDEN") != null, "Glasshouse topology is compact and deterministic")
	_expect(game.active_boss_encounter != null and game.active_boss_encounter.phase == &"PROTECTED", "Warden starts protected")

	game.publish_story_trigger(&"target_scanned", {"target_id": &"UNKNOWN_ICE"})
	_expect(_objective_state(game, &"scan_unknown_ice") == ObjectiveDefinition.COMPLETED, "unknown ICE scan completes optional objective")
	game.publish_story_trigger(&"stream_intercepted", {"stream_id": &"EXECUTIVE_COMMS"})
	_expect(_objective_state(game, &"intercept_executive_comms") == ObjectiveDefinition.COMPLETED, "executive interception completes optional objective")
	game.publish_story_trigger(&"alarm_triggered", {"service_id": &"ALARM_SERVICE"})
	_expect(_objective_state(game, &"avoid_alarm") == ObjectiveDefinition.FAILED, "alarm deterministically fails avoidance objective")
	game.publish_story_trigger(&"file_downloaded", {"file_id": &"personnel.dat"})
	_expect(_objective_state(game, &"download_personnel_file") == ObjectiveDefinition.COMPLETED, "personnel download completes primary objective")
	game.active_boss_encounter.disable_service(&"AUTHENTICATION"); game.active_boss_encounter.disable_service(&"TRACE")
	_expect(game.active_boss_encounter.phase == &"ISOLATED" and game.active_boss_encounter.defense_multiplier() == 1.0, "support services weaken and isolate Warden")
	game.active_boss_encounter.disable_actor(&"WARDEN"); game.publish_story_trigger(&"boss_state_changed", game.active_boss_encounter.snapshot())
	_expect(bool(game.active_boss_encounter.objective.accessible), "Warden can be defeated or bypassed to expose objective")

	var credits_before := int(state.player_state.credits)
	game._maybe_complete_story_mission_on_exit(&"OBJECTIVE"); await get_tree().process_frame
	var result: MissionResult = game.story_mission_system.latest_result(&"glasshouse_01")
	_expect(result.success and result.primary_objective_completed and result.personnel_file_acquired, "RunResult records primary success")
	_expect(result.alarm_state and result.unknown_ice_scanned and result.executive_comms_intercepted, "RunResult records optional outcomes")
	_expect(result.warden_state == &"ISOLATED" and result.trace_result == &"CLEAR", "RunResult captures Warden and trace state")
	_expect(result.ic_earned == 60 and int(state.player_state.credits) == credits_before + 60, "authored base and optional rewards apply")
	_expect(story.get_flag(&"glasshouse_completed") and story.get_flag(&"chapter_02_available"), "result rules unlock persistent story progression")
	_expect(story.get_reputation(&"latch") == 0.0, "alarm result selects noisy-run branch without clean-run reputation")
	_expect(game.game_domain == game.GameDomain.CLEAN_ROOM and not game.clean_room_controller.view().mission_debrief.is_empty(), "escape returns to Clean-Room with persisted debrief")

	var home: Dictionary = game.return_home_from_clean_room()
	_expect(home.success and game.game_domain == game.GameDomain.MEATSPACE, "debrief can return player home")
	_expect(story.get_flag(&"glasshouse_file_acquired"), "mission reward drives bedroom display consequence")
	_expect(StringName(state.world_state.time_of_day) == &"NIGHT", "chapter result advances story time to night")
	var saved := PersistentGameState.from_save_data(state.to_save_data()); var saved_story := StoryState.new(saved)
	_expect(saved_story.get_flag(&"glasshouse_completed") and saved_story.is_contact_unlocked(&"latch") and int(saved.player_state.credits) == int(state.player_state.credits), "chapter state survives save/load")

	var retry_events := StoryEventSystem.new(); retry_events.configure(saved); retry_events.load_file("res://data/story_events.json")
	var retry := StoryMissionSystem.new(); retry.configure(saved, retry_events); retry.load_file("res://data/story_missions.json"); retry.story_state.set_mission_status(&"glasshouse_01", StoryMissionSystem.AVAILABLE); retry.start_mission(&"glasshouse_01"); retry.observe(&"file_downloaded", {"file_id": &"personnel.dat"}); var retry_result: Dictionary = retry.resolve_active_mission()
	_expect(retry_result.result.ic_earned == 0, "retry never duplicates claimed reward")
	retry.story_state.set_mission_status(&"glasshouse_01", StoryMissionSystem.AVAILABLE); retry.start_mission(&"glasshouse_01"); var abort: Dictionary = retry.fail_active_run(&"abort")
	_expect(not abort.result.success and abort.result.trace_result == &"ABORTED", "voluntary abort produces a safe failed result")
	retry.story_state.set_mission_status(&"glasshouse_01", StoryMissionSystem.AVAILABLE); retry.start_mission(&"glasshouse_01"); var traced: Dictionary = retry.fail_active_run(&"trace", {"trace": 20})
	_expect(not traced.result.success and traced.result.trace_result == &"TRACED", "trace completion produces a safe ejection result")

	game.end_session()
	print("%s: %d Chapter 1 vertical-slice assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _objective_state(game: Node, objective_id: StringName) -> StringName:
	return StringName((game.story_mission_system.active_run.get("objectives", {}).get(objective_id, {}) as Dictionary).get("state", &""))

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition: failures += 1; printerr("FAILED: %s" % description)
