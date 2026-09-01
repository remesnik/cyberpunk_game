class_name OperationPressureManager
extends Node

const OperationPressureInstanceScript := preload("res://core/operations/OperationPressureInstance.gd")

signal operation_added(instance: Variant)
signal operation_changed(instance: Variant)

var operations: Dictionary = {}
var _cyber_clock: ActionClock
var _realtime_clock: RealtimeWorldClock


func configure(cyber_clock: ActionClock, realtime_clock: RealtimeWorldClock) -> void:
	_cyber_clock = cyber_clock
	_realtime_clock = realtime_clock
	if not _realtime_clock.elapsed_time_changed.is_connected(_on_realtime_changed):
		_realtime_clock.elapsed_time_changed.connect(_on_realtime_changed)


func begin(definition: Resource) -> Variant:
	if definition == null or definition.id == &"" or operations.has(definition.id):
		return null
	var instance = OperationPressureInstanceScript.new(definition)
	operations[definition.id] = instance
	instance.start(_realtime_clock.elapsed_seconds, _cyber_clock.current_tick)
	operation_added.emit(instance)
	return instance


func record_cyber_action(request: ActionRequest, result: ActionResult) -> void:
	for value: Variant in operations.values():
		if value.record_cyber_action(request, result):
			operation_changed.emit(value)


func get_operation(operation_id: StringName) -> Variant:
	return operations.get(operation_id)


func _on_realtime_changed(realtime_now: float) -> void:
	for value: Variant in operations.values():
		var previous_state: int = value.state
		value.update_realtime(realtime_now)
		if value.state != previous_state:
			operation_changed.emit(value)
