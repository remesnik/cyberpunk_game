extends SceneTree

const GLASSHOUSE := &"glasshouse_01"
var failures := 0
var assertions := 0

func _init() -> void:
	var state := PersistentGameState.new(); StoryModeNewGameInitializer.initialize(state)
	StoryState.new(state).set_flag(&"FIRST_CONTACT_COMPLETE", true)
	var events := StoryEventSystem.new(); events.configure(state)
	var missions := StoryMissionSystem.new(); missions.configure(state, events)
	_expect(missions.load_file("res://data/story_missions.json").is_empty() and missions.status(GLASSHOUSE) == StoryMissionSystem.AVAILABLE, "mission becomes available from authored metadata")
	var briefing := missions.briefing(GLASSHOUSE)
	_expect(briefing.title == "PROJECT GLASSHOUSE" and briefing.primary_objectives[0].description == "Download personnel.dat" and int(briefing.reward.ics) == 40, "briefing reads authored mission data")
	var started := missions.start_mission(GLASSHOUSE)
	_expect(started.success and missions.status(GLASSHOUSE) == StoryMissionSystem.ACTIVE and started.entry_network == &"GLASSHOUSE_01", "mission starts with its authored entry network")

	var primary := missions.observe(&"file_downloaded", {"file_id": &"personnel.dat"})
	_expect(primary.size() == 1 and primary[0].state == ObjectiveDefinition.COMPLETED, "primary objective completes via gameplay event")
	var scan := missions.observe(&"target_scanned", {"target_id": &"UNKNOWN_ICE"})
	missions.observe(&"stream_intercepted", {"stream_id": &"EXECUTIVE_COMMS"})
	_expect(scan.size() == 1 and scan[0].state == ObjectiveDefinition.COMPLETED, "optional objective completes via gameplay event")
	var alarm := missions.observe(&"alarm_triggered", {"service_id": &"ALARM_SERVICE"})
	_expect(alarm.size() == 1 and alarm[0].state == ObjectiveDefinition.FAILED, "avoid-alarm objective fails when an alarm event occurs")

	var credits_before := int(state.player_state.credits)
	var resolved := missions.resolve_active_mission()
	var result: MissionResult = resolved.result
	_expect(result.success and missions.status(GLASSHOUSE) == StoryMissionSystem.SUCCESS, "mission succeeds when all primary objectives complete")
	_expect(result.success and result.optional_objectives.any(func(item: Dictionary) -> bool: return item.objective_id == &"avoid_alarm" and item.state == ObjectiveDefinition.FAILED), "optional failure does not automatically fail the mission")
	_expect(int(state.player_state.credits) == credits_before + 60 and result.ic_earned == 60, "authored IC reward applies on success")
	_expect(StoryState.new(state).get_flag(&"glasshouse_file_acquired") and StoryState.new(state).get_flag(&"glasshouse_unknown_ice_scanned") and StoryState.new(state).get_flag(&"glasshouse_exec_call_intercepted") and int(StoryState.new(state).get_value(&"corp_alert_level")) == 1, "mission result fires authored story consequences")
	var debrief := missions.debrief(GLASSHOUSE)
	_expect(debrief.success and debrief.primary_result == "Personnel.dat acquired" and debrief.optional_objectives.size() == 3 and debrief.ic_reward == 60, "debrief reads the persisted MissionResult")

	var restored := PersistentGameState.from_save_data(state.to_save_data())
	var restored_events := StoryEventSystem.new(); restored_events.configure(restored)
	var restored_missions := StoryMissionSystem.new(); restored_missions.configure(restored, restored_events); restored_missions.load_file("res://data/story_missions.json")
	var restored_result := restored_missions.latest_result(GLASSHOUSE)
	_expect(restored_result != null and restored_result.success and restored_result.files_extracted.has(&"personnel.dat"), "mission result persists through the existing save system")
	var rewarded_credits := int(restored.player_state.credits)
	restored_missions.story_state.set_mission_status(GLASSHOUSE, StoryMissionSystem.AVAILABLE)
	restored_missions.start_mission(GLASSHOUSE); restored_missions.observe(&"file_downloaded", {"file_id": &"personnel.dat"}); var second := restored_missions.resolve_active_mission()
	_expect(second.result.ic_earned == 0 and int(restored.player_state.credits) == rewarded_credits, "mission reward applies only once")
	_expect(restored_missions.acknowledge_debrief(GLASSHOUSE) and restored_missions.status(GLASSHOUSE) == StoryMissionSystem.COMPLETED, "successful mission can advance from result to permanent completion")

	print("%s: %d Story mission assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
