class_name PhysicalTeamInstance
extends RefCounted

enum State { STAGING, MOVING, INFILTRATING, HOLDING, SEARCHING, WORKING, EXTRACTING, COMPROMISED, ENGAGED, LOST, COMPLETE }

signal location_changed(team_id: StringName, previous_location: StringName, current_location: StringName)
signal state_changed(team_id: StringName, previous_state: State, current_state: State)
signal route_blocked(team_id: StringName, access_point_id: StringName, location_id: StringName)

var id: StringName
var team_definition: PhysicalTeamDefinition
var current_location: StringName
var objective: StringName
var state: State = State.STAGING
## Objective operational status. Player-facing knowledge lives in PhysicalTeamKnowledge.
var known_status: String = "UNKNOWN"
var comms_channel: StringName
var equipment: Array[StringName] = []
## Authored visibility ceiling, not the player's current observation.
var visibility_to_player := KnowledgeLevel.Value.UNKNOWN
var start_time := 0.0
var elapsed_time := 0.0
var realtime_process_id: StringName

var planned_route: Array[StringName] = []
var route_index := 0
var segment_elapsed := 0.0
var segment_duration := 0.0
var _last_process_elapsed := 0.0
var blocked_at_access_point: StringName
var telemetry_history: Array[Dictionary] = []


func _init(instance_id: StringName = &"", definition: PhysicalTeamDefinition = null, starting_location: StringName = &"", process_id: StringName = &"") -> void:
	id = instance_id
	team_definition = definition
	current_location = starting_location
	realtime_process_id = process_id
	if definition != null:
		equipment.assign(definition.default_equipment)
	telemetry_history.append({"time": 0.0, "type": &"INITIAL", "location": current_location, "state": state})


func assign_route(route: Array[StringName], location_graph: MeatspaceLocationGraph, final_objective: StringName = &"") -> bool:
	if route.is_empty() or route[0] != current_location or not location_graph.is_valid_route(route):
		return false
	planned_route = route.duplicate()
	route_index = 0
	segment_elapsed = 0.0
	objective = final_objective
	_set_state(State.MOVING)
	_prepare_segment(location_graph)
	return true


func advance_to(process_elapsed: float, location_graph: MeatspaceLocationGraph, can_pass_access_point: Callable = Callable()) -> void:
	var delta := maxf(0.0, process_elapsed - _last_process_elapsed)
	_last_process_elapsed = maxf(_last_process_elapsed, process_elapsed)
	elapsed_time = _last_process_elapsed
	if state not in [State.MOVING, State.INFILTRATING, State.EXTRACTING] or planned_route.size() < 2:
		return
	while delta > 0.0 and route_index < planned_route.size() - 1:
		var remaining := segment_duration - segment_elapsed
		if delta < remaining:
			segment_elapsed += delta
			delta = 0.0
			break
		delta -= remaining
		segment_elapsed = 0.0
		var access_point_id := location_graph.access_point_for(planned_route[route_index], planned_route[route_index + 1])
		if access_point_id != &"" and can_pass_access_point.is_valid() and not bool(can_pass_access_point.call(id, access_point_id)):
			segment_elapsed = segment_duration
			blocked_at_access_point = access_point_id
			_set_state(State.HOLDING)
			known_status = "WAITING AT %s" % access_point_id
			route_blocked.emit(id, access_point_id, current_location)
			break
		var previous := current_location
		route_index += 1
		current_location = planned_route[route_index]
		telemetry_history.append({"time": elapsed_time - delta, "type": &"LOCATION", "previous": previous, "location": current_location, "state": state})
		location_changed.emit(id, previous, current_location)
		if state not in [State.MOVING, State.INFILTRATING, State.EXTRACTING]:
			break
		if route_index >= planned_route.size() - 1:
			_set_state(State.COMPLETE)
			known_status = "OBJECTIVE LOCATION REACHED"
			break
		_prepare_segment(location_graph)


func resume_route() -> bool:
	if state != State.HOLDING or blocked_at_access_point == &"":
		return false
	blocked_at_access_point = &""
	known_status = "ROUTE RESUMED"
	_set_state(State.MOVING)
	return true


func set_operational_state(next_state: State, status: String = "") -> void:
	if not status.is_empty():
		known_status = status
	_set_state(next_state)


func segment_progress() -> float:
	return 1.0 if segment_duration <= 0.0 else clampf(segment_elapsed / segment_duration, 0.0, 1.0)


func state_label() -> String:
	return State.keys()[state]


func _prepare_segment(location_graph: MeatspaceLocationGraph) -> void:
	if route_index >= planned_route.size() - 1:
		segment_duration = 0.0
		return
	var base_time := location_graph.travel_time(planned_route[route_index], planned_route[route_index + 1])
	var multiplier := maxf(0.01, team_definition.movement_speed_multiplier)
	segment_duration = base_time / multiplier


func _set_state(next_state: State) -> void:
	if state == next_state:
		return
	var previous := state
	state = next_state
	telemetry_history.append({"time": elapsed_time, "type": &"STATE", "previous": previous, "state": state, "location": current_location, "status": known_status})
	state_changed.emit(id, previous, state)
