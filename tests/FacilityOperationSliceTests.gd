extends SceneTree

const FactoryScript := preload("res://missions/FacilityOperationFactory.gd")
const ScenarioScript := preload("res://core/support/FacilityOperationScenario.gd")

var failures := 0
var assertions := 0


func _init() -> void:
	_test_network_and_outcome_gates()
	print("%s: %d facility operation assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)


func _test_network_and_outcome_gates() -> void:
	var graph: NetworkGraph = FactoryScript.create_graph()
	var expected: Array[StringName] = [&"PUBLIC_GATEWAY", &"CORP_ROUTER", &"SECURITY_NET", &"CAMERA_SERVER", &"ACCESS_CONTROL", &"PBX_SERVER", &"ALARM_CONTROLLER"]
	_expect(graph.nodes.keys() == expected, "facility cyberspace graph uses the authored seven-node chain")
	_expect(graph.find_link(&"PUBLIC_GATEWAY", &"CORP_ROUTER") != null and graph.find_link(&"PBX_SERVER", &"ALARM_CONTROLLER") != null, "discrete graph connects the operation endpoints")

	var team_manager := PhysicalTeamManager.new()
	var team_definition := PhysicalTeamDefinition.new(&"ALPHA", "Team Alpha")
	var team := PhysicalTeamInstance.new(&"TEAM_ALPHA", team_definition, &"STREET")
	team_manager.instances[team.id] = team
	var video_manager := VideoFeedManager.new()
	var feed_definition := VideoFeedDefinition.new(&"CAM_LOADING_DOCK", "Loading Dock")
	var feed := VideoFeedSession.new(feed_definition)
	video_manager.sessions[feed_definition.id] = feed
	var alarm_manager := PhysicalAlarmManager.new()
	var alarm_definition := PhysicalAlarmDefinition.new(&"ALARM_ZONE_SERVER", "Server Alarm", PhysicalAlarmDefinition.AlarmType.MOTION_SENSOR)
	var alarm := PhysicalAlarmInstance.new(alarm_definition)
	alarm_manager.instances[alarm_definition.id] = alarm
	var support := TeamSupportEncounter.new()
	var stories := RealtimeStoryRouter.new()
	var realtime := RealtimeWorldClock.new()
	var cyber := CyberspaceClock.new()
	var scenario = ScenarioScript.new()
	scenario.configure(team_manager, video_manager, alarm_manager, support, stories, realtime, cyber)

	team.current_location = &"LOADING_DOCK"
	team_manager.team_moved.emit(team.id, &"STREET", &"LOADING_DOCK")
	_expect(scenario.outcome == ScenarioScript.Outcome.TEAM_ENGAGED and team.state == PhysicalTeamInstance.State.ENGAGED, "live dock camera exposes a slow player to security")

	var safe_scenario = ScenarioScript.new()
	var safe_support := TeamSupportEncounter.new()
	var safe_team := PhysicalTeamInstance.new(&"TEAM_ALPHA", team_definition, &"STREET")
	var safe_team_manager := PhysicalTeamManager.new()
	safe_team_manager.instances[safe_team.id] = safe_team
	feed.feed_state = VideoFeedState.Value.LOOPED
	alarm.state = PhysicalAlarmInstance.State.BYPASSED
	safe_scenario.configure(safe_team_manager, video_manager, alarm_manager, safe_support, stories, realtime, cyber)
	safe_team.current_location = &"LOADING_DOCK"
	safe_team_manager.team_moved.emit(safe_team.id, &"STREET", &"LOADING_DOCK")
	safe_team.current_location = &"SERVER_ROOM"
	safe_team_manager.team_moved.emit(safe_team.id, &"SERVICE_HALL", &"SERVER_ROOM")
	_expect(safe_scenario.outcome == ScenarioScript.Outcome.SUCCEEDED, "camera manipulation and alarm bypass permit player-dependent success")
	_expect(safe_scenario.cyberspace_events.is_empty() and safe_scenario.meatspace_events.size() >= 3, "scenario keeps cyber and meatspace timeline channels separate")

	for object in [scenario, safe_scenario, team_manager, safe_team_manager, video_manager, alarm_manager, support, safe_support, stories, realtime]:
		object.free()


func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
