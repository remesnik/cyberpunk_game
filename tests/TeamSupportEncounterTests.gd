extends SceneTree

const ProcessScript := preload("res://core/RealtimeProcess.gd")
const ProcessManagerScript := preload("res://core/RealtimeProcessManager.gd")
const LocationGraphScript := preload("res://core/teams/MeatspaceLocationGraph.gd")
const TeamDefinitionScript := preload("res://core/teams/PhysicalTeamDefinition.gd")
const TeamInstanceScript := preload("res://core/teams/PhysicalTeamInstance.gd")
const TeamManagerScript := preload("res://core/teams/PhysicalTeamManager.gd")
const AccessDefinitionScript := preload("res://core/support/PhysicalAccessPointDefinition.gd")
const AccessInstanceScript := preload("res://core/support/PhysicalAccessPointInstance.gd")
const EncounterScript := preload("res://core/support/TeamSupportEncounter.gd")
const CyberClockScript := preload("res://core/CyberspaceClock.gd")

var failures := 0
var assertions := 0


func _init() -> void:
	_test_cyber_unlock_beats_realtime_door()
	_test_late_player_team_decisions()
	print("%s: %d team support assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)


func _test_cyber_unlock_beats_realtime_door() -> void:
	var fixture := _fixture()
	fixture.process_manager.advance_to_realtime(35.0)
	_expect(fixture.team.current_location == &"LOADING_DOCK" and fixture.team.state == PhysicalTeamInstance.State.HOLDING, "team reaches locked Door 12 after 35 realtime seconds")
	_expect(fixture.encounter.state == TeamSupportEncounter.EncounterState.WAITING_AT_DOOR, "encounter exposes late-player decision state")

	var cyber = CyberClockScript.new()
	cyber.resolve_action(ActionRequest.new(&"PLAYER", ActionRequest.ActionType.WAIT, null, 100), _valid, _applied)
	_expect(cyber.current_tick == 100 and fixture.team.elapsed_time == 35.0 and fixture.access.locked, "100 cyber ticks neither move team nor unlock door")
	_expect(not fixture.encounter.unlock_from_cyberspace(&"WRONG_SERVICE"), "unrelated compromised service cannot affect Door 12")
	_expect(fixture.encounter.unlock_from_cyberspace(&"DOOR_CONTROL_DAEMON") and not fixture.access.locked, "authored access-control service unlocks physical door")
	fixture.process_manager.advance_to_realtime(36.0)
	_expect(fixture.team.current_location == &"SERVICE_HALL" and fixture.team.state == PhysicalTeamInstance.State.MOVING, "team resumes realtime route after cyber support")
	_dispose_fixture(fixture)


func _test_late_player_team_decisions() -> void:
	var force_fixture := _fixture()
	force_fixture.process_manager.advance_to_realtime(35.0)
	var wait_result: Dictionary = force_fixture.encounter.choose_team_decision(TeamSupportEncounter.TeamDecision.WAIT)
	_expect(wait_result.success and force_fixture.team.state == PhysicalTeamInstance.State.HOLDING and force_fixture.access.locked, "WAIT preserves locked-door hold")
	var force_result: Dictionary = force_fixture.encounter.choose_team_decision(TeamSupportEncounter.TeamDecision.FORCE_ENTRY)
	_expect(force_result.success and not force_fixture.access.locked and force_fixture.encounter.security_suspicion == 35, "FORCE ENTRY opens door with physical suspicion consequence")
	_dispose_fixture(force_fixture)

	var alternate_fixture := _fixture()
	alternate_fixture.process_manager.advance_to_realtime(35.0)
	var alternate: Dictionary = alternate_fixture.encounter.choose_team_decision(TeamSupportEncounter.TeamDecision.ALTERNATE_ROUTE)
	_expect(alternate.success and alternate_fixture.team.planned_route[1] == &"SECURITY_OFFICE", "ALTERNATE ROUTE replaces blocked path")
	_dispose_fixture(alternate_fixture)

	var abort_fixture := _fixture()
	abort_fixture.process_manager.advance_to_realtime(35.0)
	var abort: Dictionary = abort_fixture.encounter.choose_team_decision(TeamSupportEncounter.TeamDecision.ABORT)
	_expect(abort.success and abort_fixture.team.state == PhysicalTeamInstance.State.LOST, "ABORT ends operation without changing door")
	_dispose_fixture(abort_fixture)


func _fixture() -> Dictionary:
	var graph = LocationGraphScript.new()
	for location: StringName in [&"STREET", &"LOADING_DOCK", &"SERVICE_HALL", &"SECURITY_OFFICE", &"SERVER_ROOM", &"LAB"]:
		graph.add_location(location)
	graph.add_connection(&"STREET", &"LOADING_DOCK", 20.0)
	graph.add_connection(&"LOADING_DOCK", &"SERVICE_HALL", 15.0, true, &"DOOR_12")
	graph.add_connection(&"LOADING_DOCK", &"SECURITY_OFFICE", 25.0)
	graph.add_connection(&"SECURITY_OFFICE", &"SERVICE_HALL", 10.0)
	graph.add_connection(&"SERVICE_HALL", &"SERVER_ROOM", 12.0)
	graph.add_connection(&"SERVER_ROOM", &"LAB", 18.0)
	var process_manager = ProcessManagerScript.new()
	process_manager.add_process(ProcessScript.new(&"TEAM_PROCESS", ProcessScript.ProcessType.PENETRATION_TEAM, "Alpha"), true)
	var manager = TeamManagerScript.new()
	manager.configure(graph, process_manager, PlayerKnowledge.new())
	var team = TeamInstanceScript.new(&"TEAM_ALPHA", TeamDefinitionScript.new(&"ALPHA", "Team Alpha", TeamDefinitionScript.TeamType.PLAYER_CONTRACTED), &"STREET", &"TEAM_PROCESS")
	manager.add_team(team)
	manager.assign_route(team.id, [&"STREET", &"LOADING_DOCK", &"SERVICE_HALL", &"SERVER_ROOM", &"LAB"] as Array[StringName], &"REACH_LAB")
	var access_definition = AccessDefinitionScript.new(&"DOOR_12", "Door 12", &"LOADING_DOCK", &"ACCESS_CONTROL_SERVER", &"DOOR_CONTROL_DAEMON")
	access_definition.force_entry_suspicion = 35
	var access = AccessInstanceScript.new(access_definition)
	var encounter = EncounterScript.new()
	encounter.configure(team.id, access, manager)
	return {"process_manager": process_manager, "manager": manager, "team": team, "access": access, "encounter": encounter}


func _dispose_fixture(fixture: Dictionary) -> void:
	fixture.encounter.free()
	fixture.manager.free()
	fixture.process_manager.free()


func _valid(_request: ActionRequest) -> Dictionary:
	return {"success": true, "reason": "", "events": []}


func _applied(_request: ActionRequest) -> Dictionary:
	return {"success": true, "reason": "", "events": []}


func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
