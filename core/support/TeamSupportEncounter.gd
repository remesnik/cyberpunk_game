class_name TeamSupportEncounter
extends Node

enum TeamDecision { WAIT, FORCE_ENTRY, ABORT, ALTERNATE_ROUTE }
enum EncounterState { APPROACHING, WAITING_AT_DOOR, ROUTE_OPEN, FORCING_ENTRY, ABORTED, ALTERNATE_ROUTE, COMPLETE }

signal encounter_changed
signal support_event(event: Dictionary)

var team_id: StringName
var access_point: PhysicalAccessPointInstance
var team_manager: PhysicalTeamManager
var state: EncounterState = EncounterState.APPROACHING
var security_suspicion := 0
var event_history: Array[Dictionary] = []


func configure(target_team_id: StringName, target_access_point: PhysicalAccessPointInstance, manager: PhysicalTeamManager) -> void:
	if team_manager != null and team_manager.team_route_blocked.is_connected(_on_team_blocked):
		team_manager.team_route_blocked.disconnect(_on_team_blocked)
	if access_point != null and access_point.access_changed.is_connected(_on_access_changed):
		access_point.access_changed.disconnect(_on_access_changed)
	team_id = target_team_id
	access_point = target_access_point
	team_manager = manager
	team_manager.access_point_validator = _can_team_pass
	if not team_manager.team_route_blocked.is_connected(_on_team_blocked): team_manager.team_route_blocked.connect(_on_team_blocked)
	if not access_point.access_changed.is_connected(_on_access_changed): access_point.access_changed.connect(_on_access_changed)


func unlock_from_cyberspace(service_id: StringName) -> bool:
	if service_id != access_point.definition.control_service_id:
		return false
	access_point.unlock(&"CYBERSPACE_EXPLOIT")
	_record({"type": &"DOOR_UNLOCKED", "door_id": access_point.definition.id, "source": &"CYBERSPACE"})
	return true


func choose_team_decision(decision: TeamDecision) -> Dictionary:
	var team := team_manager.instances.get(team_id) as PhysicalTeamInstance
	if team == null or state != EncounterState.WAITING_AT_DOOR:
		return {"success": false, "reason": "Team is not awaiting a door decision."}
	match decision:
		TeamDecision.WAIT:
			team.known_status = "WAITING FOR CYBER SUPPORT"
			_record({"type": &"TEAM_WAITING", "team_id": team_id})
		TeamDecision.FORCE_ENTRY:
			state = EncounterState.FORCING_ENTRY
			security_suspicion += access_point.definition.force_entry_suspicion
			access_point.unlock(&"FORCED_ENTRY")
			_record({"type": &"DOOR_FORCED", "team_id": team_id, "suspicion": access_point.definition.force_entry_suspicion})
		TeamDecision.ABORT:
			state = EncounterState.ABORTED
			team.set_operational_state(PhysicalTeamInstance.State.LOST, "OPERATION ABORTED AT LOCKED DOOR")
			_record({"type": &"TEAM_ABORTED", "team_id": team_id})
		TeamDecision.ALTERNATE_ROUTE:
			var alternate: Array[StringName] = [&"LOADING_DOCK", &"SECURITY_OFFICE", &"SERVICE_HALL", &"SERVER_ROOM", &"LAB"]
			if not team_manager.assign_route(team_id, alternate, team.objective):
				return {"success": false, "reason": "No alternate physical route is available."}
			state = EncounterState.ALTERNATE_ROUTE
			_record({"type": &"TEAM_REROUTED", "team_id": team_id})
	encounter_changed.emit()
	return {"success": true, "reason": TeamDecision.keys()[decision].replace("_", " "), "state": state}


func status_text() -> String:
	return EncounterState.keys()[state].replace("_", " ")


func _can_team_pass(query_team_id: StringName, access_point_id: StringName) -> bool:
	if query_team_id != team_id or access_point_id != access_point.definition.id:
		return true
	return access_point.can_pass()


func _on_team_blocked(blocked_team_id: StringName, access_point_id: StringName, _location_id: StringName) -> void:
	if blocked_team_id != team_id or access_point_id != access_point.definition.id:
		return
	state = EncounterState.WAITING_AT_DOOR
	_record({"type": &"TEAM_BLOCKED", "team_id": team_id, "door_id": access_point_id})
	encounter_changed.emit()


func _on_access_changed(access_point_id: StringName, locked: bool, _source: StringName) -> void:
	if access_point_id != access_point.definition.id or locked:
		return
	var team := team_manager.instances.get(team_id) as PhysicalTeamInstance
	if team != null and team.blocked_at_access_point == access_point_id:
		team.resume_route()
	state = EncounterState.ROUTE_OPEN
	encounter_changed.emit()


func _record(event: Dictionary) -> void:
	event_history.append(event.duplicate(true))
	support_event.emit(event.duplicate(true))
