class_name PhysicalAlarmInstance
extends RefCounted

enum State { NORMAL, PREALARM, TRIGGERED, ACKNOWLEDGED, SILENCED, BYPASSED, FAULT }

signal state_changed(alarm_id: StringName, previous_state: State, current_state: State)
signal detection_occurred(alarm_id: StringName, event: Dictionary)

var definition: PhysicalAlarmDefinition
var state: State = State.NORMAL
var elapsed_time := 0.0
var state_changed_at := 0.0
var detection_enabled := true
var alert_presenting := false
var underlying_condition_active := false
var detection_count := 0
var last_detection: Dictionary = {}
var event_history: Array[Dictionary] = []
var _last_elapsed := -0.000001


func _init(alarm_definition: PhysicalAlarmDefinition = null) -> void:
	definition = alarm_definition


func advance_to(process_elapsed: float) -> void:
	var next_elapsed := maxf(_last_elapsed, process_elapsed)
	for event: Dictionary in definition.authored_timeline:
		var timestamp := float(event.get("time", 0.0))
		if timestamp <= _last_elapsed or timestamp > next_elapsed:
			continue
		elapsed_time = timestamp
		_apply_timeline_event(event)
	_last_elapsed = next_elapsed
	elapsed_time = next_elapsed


func detect(event: Dictionary = {}) -> bool:
	detection_count += 1
	last_detection = event.duplicate(true)
	last_detection["time"] = elapsed_time
	event_history.append({"type": &"DETECTION", "time": elapsed_time, "data": last_detection.duplicate(true)})
	detection_occurred.emit(definition.id, last_detection)
	if not detection_enabled or state == State.BYPASSED:
		return false
	underlying_condition_active = true
	if state != State.SILENCED:
		_set_state(State.TRIGGERED)
		alert_presenting = true
	return true


func apply_command(command: PhysicalAlarmDefinition.Command) -> bool:
	match command:
		PhysicalAlarmDefinition.Command.MONITOR:
			return true
		PhysicalAlarmDefinition.Command.ACKNOWLEDGE:
			if state not in [State.TRIGGERED, State.PREALARM, State.SILENCED]:
				return false
			_set_state(State.ACKNOWLEDGED)
			alert_presenting = false
		PhysicalAlarmDefinition.Command.SILENCE:
			if state not in [State.TRIGGERED, State.PREALARM, State.ACKNOWLEDGED]:
				return false
			_set_state(State.SILENCED)
			alert_presenting = false
			# Detection deliberately remains enabled.
		PhysicalAlarmDefinition.Command.BYPASS:
			detection_enabled = false
			alert_presenting = false
			_set_state(State.BYPASSED)
		PhysicalAlarmDefinition.Command.RESTORE:
			detection_enabled = true
			alert_presenting = false
			underlying_condition_active = false
			_set_state(State.NORMAL)
		PhysicalAlarmDefinition.Command.TRIGGER:
			return detect({"source": &"PLAYER_COMMAND"})
	return true


func reaction_view() -> Dictionary:
	return {
		"alarm_id": definition.id,
		"alarm_type": definition.alarm_type,
		"location_id": definition.physical_location_id,
		"state": state,
		"detection_enabled": detection_enabled,
		"alert_presenting": alert_presenting,
		"underlying_condition_active": underlying_condition_active,
		"detection_count": detection_count,
		"last_detection": last_detection.duplicate(true),
		"elapsed_time": elapsed_time,
	}


func state_label() -> String:
	return State.keys()[state]


func _apply_timeline_event(event: Dictionary) -> void:
	match StringName(event.get("type", &"DETECT")):
		&"PREALARM":
			if detection_enabled and state not in [State.BYPASSED, State.SILENCED]:
				underlying_condition_active = true
				alert_presenting = true
				_set_state(State.PREALARM)
		&"DETECT", &"TRIGGER":
			detect(event)
		&"CLEAR":
			underlying_condition_active = false
			if state not in [State.BYPASSED, State.FAULT]:
				alert_presenting = false
				_set_state(State.NORMAL)
		&"FAULT":
			alert_presenting = true
			_set_state(State.FAULT)
	event_history.append(event.duplicate(true))


func _set_state(next_state: State) -> void:
	if state == next_state:
		return
	var previous := state
	state = next_state
	state_changed_at = elapsed_time
	state_changed.emit(definition.id, previous, state)
