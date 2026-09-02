class_name SoftwareProgrammingTask
extends RefCounted

enum State { PROGRAMMING, COMPLETED, COLLECTED }

var id: StringName
var program_definition: ProgramDefinition
var output_instance_id: StringName
var started_at: float
var duration: float
var state: State = State.PROGRAMMING


func _init(p_id: StringName, definition: ProgramDefinition, instance_id: StringName, start: float, seconds: float) -> void:
	id = p_id
	program_definition = definition
	output_instance_id = instance_id
	started_at = start
	duration = maxf(0.0, seconds)


func update(realtime_now: float) -> void:
	if state == State.PROGRAMMING and realtime_now - started_at >= duration:
		state = State.COMPLETED


func elapsed(realtime_now: float) -> float:
	return clampf(realtime_now - started_at, 0.0, duration)
