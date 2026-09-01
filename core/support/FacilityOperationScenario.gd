class_name FacilityOperationScenario
extends Node

enum Outcome { ACTIVE, TEAM_ENGAGED, FAILED, SUCCEEDED }

signal timeline_changed
signal outcome_changed(outcome: Outcome, reason: String)

var outcome: Outcome = Outcome.ACTIVE
var outcome_reason: String = "OPERATION ACTIVE"
var cyberspace_events: Array[Dictionary] = []
var meatspace_events: Array[Dictionary] = []
var team_manager: PhysicalTeamManager
var video_manager: VideoFeedManager
var alarm_manager: PhysicalAlarmManager
var support_encounter: TeamSupportEncounter
var story_router: RealtimeStoryRouter
var _clock: RealtimeWorldClock
var _action_clock: ActionClock


func configure(team: PhysicalTeamManager, video: VideoFeedManager, alarms: PhysicalAlarmManager, support: TeamSupportEncounter, stories: RealtimeStoryRouter, clock: RealtimeWorldClock, action_clock: ActionClock) -> void:
	team_manager = team
	video_manager = video
	alarm_manager = alarms
	support_encounter = support
	story_router = stories
	_clock = clock
	_action_clock = action_clock
	team.team_moved.connect(_on_team_moved)
	team.team_state_changed.connect(_on_team_state_changed)
	support.support_event.connect(_on_support_event)
	stories.structured_event_received.connect(_on_story_event)
	action_clock.action_resolved.connect(_on_cyber_action)
	_log_meat(&"OPERATION_STARTED", {"team_id": &"TEAM_ALPHA", "location": &"STREET"})


func _on_cyber_action(request: ActionRequest, result: ActionResult) -> void:
	cyberspace_events.append({"tick": _action_clock.current_tick, "type": StringName("CYBER_%s" % request.get_action_name()), "success": result.success, "target": request.target, "cost": result.time_spent})
	_trim_and_emit()


func _on_story_event(event: StoryEvent) -> void:
	_log_meat(event.type_name(), {"source_id": event.source_id, "payload": event.payload})


func _on_support_event(event: Dictionary) -> void:
	_log_meat(event.get("type", &"TEAM_SUPPORT"), event)


func _on_team_moved(team_id: StringName, previous: StringName, current: StringName) -> void:
	if team_id != &"TEAM_ALPHA" or outcome not in [Outcome.ACTIVE, Outcome.TEAM_ENGAGED]:
		return
	_log_meat(&"TEAM_REACHED_LOCATION", {"team_id": team_id, "previous": previous, "location": current})
	if current == &"LOADING_DOCK" and not _loading_dock_camera_safe():
		_set_outcome(Outcome.TEAM_ENGAGED, "TEAM_ALPHA exposed at loading dock; camera feed remained live.")
		var team: PhysicalTeamInstance = team_manager.instances.get(team_id)
		team.set_operational_state(PhysicalTeamInstance.State.ENGAGED, "SECURITY CONTACT AT LOADING_DOCK")
	elif current == &"SERVER_ROOM":
		if not _server_alarm_bypassed():
			_set_outcome(Outcome.FAILED, "Server-room alarm detected Team Alpha.")
			var team: PhysicalTeamInstance = team_manager.instances.get(team_id)
			team.set_operational_state(PhysicalTeamInstance.State.LOST, "SECURITY RESPONSE AT SERVER_ROOM")
		else:
			_set_outcome(Outcome.SUCCEEDED, "Team Alpha reached SERVER_ROOM with access and alarm support.")


func _on_team_state_changed(team_id: StringName, _previous: int, current: int) -> void:
	if team_id == &"TEAM_ALPHA" and current == PhysicalTeamInstance.State.LOST and outcome != Outcome.FAILED:
		_set_outcome(Outcome.FAILED, "Team Alpha was lost before reaching the objective.")


func _loading_dock_camera_safe() -> bool:
	var session: VideoFeedSession = video_manager.sessions.get(&"CAM_LOADING_DOCK")
	return session != null and session.feed_state in [VideoFeedState.Value.LOOPED, VideoFeedState.Value.OFFLINE, VideoFeedState.Value.SPOOFED]


func _server_alarm_bypassed() -> bool:
	var alarm: PhysicalAlarmInstance = alarm_manager.instances.get(&"ALARM_ZONE_SERVER")
	return alarm != null and alarm.state == PhysicalAlarmInstance.State.BYPASSED


func _set_outcome(next: Outcome, reason: String) -> void:
	outcome = next
	outcome_reason = reason
	_log_meat(&"OPERATION_OUTCOME", {"outcome": Outcome.keys()[outcome], "reason": reason})
	outcome_changed.emit(outcome, reason)


func _log_meat(type: StringName, payload: Dictionary) -> void:
	meatspace_events.append({"realtime": _clock.elapsed_seconds if _clock != null else 0.0, "type": type, "payload": payload.duplicate(true)})
	_trim_and_emit()


func _trim_and_emit() -> void:
	while cyberspace_events.size() > 16: cyberspace_events.pop_front()
	while meatspace_events.size() > 16: meatspace_events.pop_front()
	timeline_changed.emit()
