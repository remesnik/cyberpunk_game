class_name PhysicalTeamManager
extends Node

signal teams_changed
signal team_moved(team_id: StringName, previous_location: StringName, current_location: StringName)
signal team_state_changed(team_id: StringName, previous_state: PhysicalTeamInstance.State, current_state: PhysicalTeamInstance.State)
signal team_route_blocked(team_id: StringName, access_point_id: StringName, location_id: StringName)

var location_graph: MeatspaceLocationGraph
var definitions: Dictionary = {}
var instances: Dictionary = {}
var _process_manager: RealtimeProcessManager
var _knowledge: PlayerKnowledge
var team_knowledge: PhysicalTeamKnowledge = PhysicalTeamKnowledge.new()
var access_point_validator: Callable


func configure(graph: MeatspaceLocationGraph, process_manager: RealtimeProcessManager, knowledge: PlayerKnowledge, partial_knowledge: PhysicalTeamKnowledge = null) -> void:
	location_graph = graph
	_process_manager = process_manager
	_knowledge = knowledge
	team_knowledge = partial_knowledge if partial_knowledge != null else PhysicalTeamKnowledge.new()
	if not _process_manager.processes_updated.is_connected(_on_realtime_updated):
		_process_manager.processes_updated.connect(_on_realtime_updated)
	if not _knowledge.knowledge_changed.is_connected(_on_knowledge_changed):
		_knowledge.knowledge_changed.connect(_on_knowledge_changed)


func add_team(instance: PhysicalTeamInstance) -> bool:
	if instance == null or instance.id == &"" or instances.has(instance.id) or _process_manager.get_process(instance.realtime_process_id) == null:
		return false
	instances[instance.id] = instance
	if instance.team_definition != null:
		definitions[instance.team_definition.id] = instance.team_definition
	instance.location_changed.connect(_on_team_moved)
	instance.state_changed.connect(_on_team_state_changed)
	instance.route_blocked.connect(_on_team_route_blocked)
	return true


func get_player_views(realtime_now: float) -> Array[Dictionary]:
	if team_knowledge == null: return []
	return team_knowledge.get_all_views(realtime_now)


func observe_team(team_id: StringName, source: PhysicalTeamKnowledge.Source, realtime_now: float, fields: Array[StringName] = [&"location", &"state", &"objective", &"comms_status"]) -> bool:
	var team := instances.get(team_id) as PhysicalTeamInstance
	if team == null:
		return false
	var observation: Dictionary = {}
	if fields.has(&"location"): observation["location"] = team.current_location
	if fields.has(&"state"): observation["state"] = team.state
	if fields.has(&"objective"): observation["objective"] = team.objective
	if fields.has(&"comms_status"): observation["comms_status"] = PhysicalTeamKnowledge.CommsStatus.ONLINE
	team_knowledge.commit_observation(team_id, observation, source, realtime_now)
	return true


func assign_route(team_id: StringName, route: Array[StringName], objective: StringName = &"") -> bool:
	var team := instances.get(team_id) as PhysicalTeamInstance
	return team != null and team.assign_route(route, location_graph, objective)


func get_team_status(team_id: StringName) -> Dictionary:
	var team := instances.get(team_id) as PhysicalTeamInstance
	if team == null:
		return {}
	return {
		"id": team.id,
		"definition_id": team.team_definition.id,
		"team_type": team.team_definition.team_type,
		"current_location": team.current_location,
		"objective": team.objective,
		"state": team.state,
		"known_status": team.known_status,
		"comms_channel": team.comms_channel,
		"equipment": team.equipment.duplicate(),
		"visibility_to_player": team.visibility_to_player,
		"start_time": team.start_time,
		"elapsed_time": team.elapsed_time,
		"segment_progress": team.segment_progress(),
	}


func _on_realtime_updated(_session_time: float) -> void:
	for value: Variant in instances.values():
		var team := value as PhysicalTeamInstance
		var process := _process_manager.get_process(team.realtime_process_id)
		if process != null:
			team.advance_to(process.elapsed_time, location_graph, access_point_validator)
	teams_changed.emit()


func _on_team_moved(team_id: StringName, previous: StringName, current: StringName) -> void:
	team_moved.emit(team_id, previous, current)
	teams_changed.emit()


func _on_team_state_changed(team_id: StringName, previous: PhysicalTeamInstance.State, current: PhysicalTeamInstance.State) -> void:
	team_state_changed.emit(team_id, previous, current)
	if current == PhysicalTeamInstance.State.ENGAGED: _publish_tactical_alert(&"TEAM_MEMBER_UNDER_ATTACK", team_id, "UNDER ATTACK", &"CRITICAL")
	elif current == PhysicalTeamInstance.State.LOST: _publish_tactical_alert(&"TEAM_MEMBER_DUMPED", team_id, "CONTACT LOST", &"CRITICAL")
	elif current == PhysicalTeamInstance.State.COMPLETE: _publish_tactical_alert(&"OBJECTIVE_COMPLETE", team_id, "OBJECTIVE COMPLETE", &"SUCCESS")
	teams_changed.emit()


func _on_team_route_blocked(team_id: StringName, access_point_id: StringName, location_id: StringName) -> void:
	team_route_blocked.emit(team_id, access_point_id, location_id)
	teams_changed.emit()


func _on_knowledge_changed() -> void:
	# Discovering a team-tracking process reveals that a team exists, but does not
	# leak its objective location or state.
	for value: Variant in instances.values():
		var team := value as PhysicalTeamInstance
		if _knowledge.knows_realtime_process(team.realtime_process_id) and not team_knowledge.records.has(team.id):
			team_knowledge.detect_team(team.id, team.elapsed_time, PhysicalTeamKnowledge.Source.TEAM_TELEMETRY)
			_publish_tactical_alert(&"TEAM_MEMBER_DETECTED", team.id, "SIGNAL DETECTED", &"INFO")
	teams_changed.emit()

func _publish_tactical_alert(type: StringName, subject_id: StringName, message: String, severity: StringName) -> void:
	if not is_inside_tree(): return
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null: event_bus.publish_tactical_status_alert(type, subject_id, message, severity)
