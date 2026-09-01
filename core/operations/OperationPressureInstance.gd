class_name OperationPressureInstance
extends RefCounted

enum State { PENDING, ACTIVE, SUCCEEDED, DEADLINE_REACHED, CANCELLED }

signal changed
signal deadline_reached(operation_id: StringName)

var definition: Resource
var state: State = State.PENDING
var realtime_started_at: float = 0.0
var realtime_deadline_at: float = 0.0
var cyber_started_at_tick: int = 0
var completed_cyber_steps: int = 0


func _init(source_definition: Resource = null) -> void:
	definition = source_definition


func start(realtime_now: float, cyber_tick: int) -> void:
	realtime_started_at = realtime_now
	realtime_deadline_at = realtime_now + definition.realtime_deadline_seconds
	cyber_started_at_tick = cyber_tick
	state = State.ACTIVE
	changed.emit()


func update_realtime(realtime_now: float) -> void:
	if state == State.ACTIVE and realtime_now >= realtime_deadline_at:
		state = State.DEADLINE_REACHED
		changed.emit()
		deadline_reached.emit(definition.id)


func record_cyber_action(request: ActionRequest, result: ActionResult) -> bool:
	if state != State.ACTIVE or not result.success or completed_cyber_steps >= definition.cyber_plan.size():
		return false
	var step: Dictionary = definition.cyber_plan[completed_cyber_steps]
	if int(step.get("action_type", -1)) != request.action_type:
		return false
	var expected_target: StringName = step.get("target", &"")
	var actual_target: StringName = &""
	if request.target is Dictionary:
		actual_target = request.target.get("node_id", request.target.get("feed_id", request.target.get("service_id", &"")))
	elif request.target != null:
		actual_target = StringName(request.target)
	if expected_target != &"" and actual_target != expected_target:
		return false
	completed_cyber_steps += 1
	if completed_cyber_steps >= definition.cyber_plan.size():
		state = State.SUCCEEDED
	changed.emit()
	return true


func realtime_seconds_remaining(realtime_now: float) -> float:
	return maxf(0.0, realtime_deadline_at - realtime_now)


func remaining_cyber_cost() -> int:
	var total := 0
	for index in range(completed_cyber_steps, definition.cyber_plan.size()):
		total += int(definition.cyber_plan[index].get("cost", 0))
	return total


func current_step_label() -> String:
	if completed_cyber_steps >= definition.cyber_plan.size():
		return "PLAN COMPLETE"
	return String(definition.cyber_plan[completed_cyber_steps].get("label", "UNSPECIFIED ACTION"))


func state_label() -> String:
	return ["PENDING", "ACTIVE", "SUCCEEDED", "DEADLINE REACHED", "CANCELLED"][state]
