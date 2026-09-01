extends SceneTree

const ProcessScript := preload("res://core/RealtimeProcess.gd")
const ProcessManagerScript := preload("res://core/RealtimeProcessManager.gd")
const LocationGraphScript := preload("res://core/teams/MeatspaceLocationGraph.gd")
const TeamDefinitionScript := preload("res://core/teams/PhysicalTeamDefinition.gd")
const TeamInstanceScript := preload("res://core/teams/PhysicalTeamInstance.gd")
const TeamKnowledgeScript := preload("res://core/teams/PhysicalTeamKnowledge.gd")
const TeamManagerScript := preload("res://core/teams/PhysicalTeamManager.gd")
const CyberClockScript := preload("res://core/CyberspaceClock.gd")

var failures := 0
var assertions := 0


func _init() -> void:
	_test_realtime_movement_and_partial_knowledge()
	print("%s: %d physical team assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)


func _test_realtime_movement_and_partial_knowledge() -> void:
	var graph = LocationGraphScript.new()
	for location: StringName in [&"STREET", &"LOADING_DOCK", &"SERVICE_HALL", &"SECURITY_OFFICE", &"SERVER_ROOM", &"LAB"]:
		graph.add_location(location)
	graph.add_connection(&"STREET", &"LOADING_DOCK", 20.0)
	graph.add_connection(&"LOADING_DOCK", &"SERVICE_HALL", 15.0)
	graph.add_connection(&"SERVICE_HALL", &"SECURITY_OFFICE", 10.0)
	graph.add_connection(&"SERVICE_HALL", &"SERVER_ROOM", 12.0)
	graph.add_connection(&"SERVER_ROOM", &"LAB", 18.0)
	var process_manager = ProcessManagerScript.new()
	process_manager.add_process(ProcessScript.new(&"TEAM_ALPHA_PROCESS", ProcessScript.ProcessType.PENETRATION_TEAM, "Alpha"), true)
	process_manager.add_process(ProcessScript.new(&"SECURITY_PROCESS", ProcessScript.ProcessType.SECURITY_TEAM, "Security"), true)
	var player_knowledge := PlayerKnowledge.new()
	var partial = TeamKnowledgeScript.new()
	var manager = TeamManagerScript.new()
	manager.configure(graph, process_manager, player_knowledge, partial)
	var alpha_definition = TeamDefinitionScript.new(&"ALPHA_DEF", "Team Alpha", TeamDefinitionScript.TeamType.PLAYER_CONTRACTED)
	var alpha = TeamInstanceScript.new(&"TEAM_ALPHA", alpha_definition, &"STREET", &"TEAM_ALPHA_PROCESS")
	manager.add_team(alpha)
	manager.assign_route(alpha.id, [&"STREET", &"LOADING_DOCK", &"SERVICE_HALL", &"SERVER_ROOM", &"LAB"] as Array[StringName], &"REACH_LAB")
	var security_definition = TeamDefinitionScript.new(&"SECURITY_DEF", "Security", TeamDefinitionScript.TeamType.CORPORATE_SECURITY)
	var security = TeamInstanceScript.new(&"SECURITY", security_definition, &"SECURITY_OFFICE", &"SECURITY_PROCESS")
	manager.add_team(security)
	manager.assign_route(security.id, [&"SECURITY_OFFICE", &"SERVICE_HALL", &"LOADING_DOCK"] as Array[StringName], &"SECURE_DOCK")

	_expect(partial.get_view(alpha.id, 0.0).is_empty(), "true team instance does not automatically enter player knowledge")
	process_manager.advance_to_realtime(20.0)
	_expect(alpha.current_location == &"LOADING_DOCK" and security.current_location == &"SERVICE_HALL", "multiple teams move on weighted realtime graph")
	manager.observe_team(alpha.id, PhysicalTeamKnowledge.Source.VERBAL_REPORT, 20.0)
	process_manager.advance_to_realtime(39.0)
	var stale_view := partial.get_view(alpha.id, 39.0)
	_expect(alpha.current_location == &"SERVICE_HALL", "true Team Alpha reaches Service Hall")
	_expect(stale_view.last_known_location == &"LOADING_DOCK" and stale_view.contact_age == 19.0, "player sees loading dock confirmation from 19 seconds ago")
	_expect(stale_view.stale and stale_view.confidence < 0.5, "verbal report becomes stale and loses confidence")

	var before_cyber_location: StringName = alpha.current_location
	var cyber = CyberClockScript.new()
	cyber.resolve_action(ActionRequest.new(&"PLAYER", ActionRequest.ActionType.WAIT, null, 100), _valid, _applied)
	_expect(cyber.current_tick == 100 and alpha.current_location == before_cyber_location and alpha.elapsed_time == 39.0, "100 cyberspace ticks do not move physical teams")
	process_manager.advance_to_realtime(47.0)
	_expect(alpha.current_location == &"SERVER_ROOM", "Team Alpha crosses next route segment using realtime seconds")
	manager.observe_team(alpha.id, PhysicalTeamKnowledge.Source.BODY_CAMERA, 47.0)
	var bodycam_view := partial.get_view(alpha.id, 47.0)
	_expect(bodycam_view.last_known_location == &"SERVER_ROOM" and bodycam_view.confidence == 1.0 and not bodycam_view.stale, "bodycam supplies exact high-confidence visual status")
	partial.report_comms_lost(alpha.id, 48.0)
	process_manager.advance_to_realtime(65.0)
	var lost_view := partial.get_view(alpha.id, 65.0)
	_expect(alpha.current_location == &"LAB" and alpha.state == PhysicalTeamInstance.State.COMPLETE, "team completes full route in realtime")
	_expect(lost_view.last_known_location == &"SERVER_ROOM" and lost_view.comms_status == PhysicalTeamKnowledge.CommsStatus.LOST, "lost comms leave position stale instead of leaking true destination")
	_expect(manager.get_team_status(alpha.id).current_location == &"LAB", "objective status remains independently queryable by simulation")
	manager.free()
	process_manager.free()


func _valid(_request: ActionRequest) -> Dictionary:
	return {"success": true, "reason": "", "events": []}


func _applied(_request: ActionRequest) -> Dictionary:
	return {"success": true, "reason": "", "events": []}


func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
