class_name RealtimeEventInstance
extends RefCounted

enum State { PENDING, ACTIVE, COMPLETED, CANCELLED }

signal state_changed(instance_id: StringName, previous_state: State, current_state: State)

var id: StringName
var definition: RealtimeEventDefinition
var state: State = State.PENDING
var scheduled_at := -1.0
var activated_at := -1.0
var completed_at := -1.0
var cancelled_at := -1.0
var produced_actions: Array[Dictionary] = []


func _init(instance_id: StringName = &"", event_definition: RealtimeEventDefinition = null) -> void:
	id = instance_id
	definition = event_definition


func activate(realtime_now: float) -> bool:
	if state != State.PENDING:
		return false
	activated_at = realtime_now
	_set_state(State.ACTIVE)
	return true


func complete(realtime_now: float) -> bool:
	if state != State.ACTIVE:
		return false
	completed_at = realtime_now
	_set_state(State.COMPLETED)
	return true


func cancel(realtime_now: float) -> bool:
	if state not in [State.PENDING, State.ACTIVE]:
		return false
	cancelled_at = realtime_now
	_set_state(State.CANCELLED)
	return true


func state_label() -> String:
	return State.keys()[state]


func _set_state(next_state: State) -> void:
	if state == next_state:
		return
	var previous := state
	state = next_state
	state_changed.emit(id, previous, state)

