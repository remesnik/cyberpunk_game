class_name RealtimeEventScheduler
extends Node

signal timeline_changed
signal event_activated(instance: RealtimeEventInstance)
signal event_completed(instance: RealtimeEventInstance)
signal action_produced(instance_id: StringName, action: Dictionary)

var definitions: Dictionary = {}
var instances: Dictionary = {}
var operation_start_times: Dictionary = {}
var action_handlers: Dictionary = {}
var _clock: RealtimeWorldClock
var _process_manager: RealtimeProcessManager
var _serial := 0


func configure(clock: RealtimeWorldClock, process_manager: RealtimeProcessManager) -> void:
	_clock = clock
	_process_manager = process_manager
	if not _clock.elapsed_time_changed.is_connected(_on_realtime_changed):
		_clock.elapsed_time_changed.connect(_on_realtime_changed)
	if not _process_manager.process_state_changed.is_connected(_on_process_state_changed):
		_process_manager.process_state_changed.connect(_on_process_state_changed)


func add_definition(definition: RealtimeEventDefinition) -> bool:
	if definition == null or definition.id == &"" or definitions.has(definition.id):
		return false
	definitions[definition.id] = definition
	return true


func schedule(definition_id: StringName) -> RealtimeEventInstance:
	var definition := definitions.get(definition_id) as RealtimeEventDefinition
	if definition == null:
		return null
	_serial += 1
	var instance := RealtimeEventInstance.new(StringName("%s_%03d" % [definition.id, _serial]), definition)
	match definition.trigger_type:
		RealtimeEventDefinition.TriggerType.AFTER_SECONDS:
			instance.scheduled_at = _clock.elapsed_seconds + definition.delay_seconds
		RealtimeEventDefinition.TriggerType.RELATIVE_OPERATION_TIME:
			if operation_start_times.has(definition.operation_id):
				instance.scheduled_at = float(operation_start_times[definition.operation_id]) + definition.delay_seconds
		RealtimeEventDefinition.TriggerType.PROCESS_STATE_CHANGED:
			instance.scheduled_at = -1.0
	instances[instance.id] = instance
	instance.state_changed.connect(_on_instance_state_changed)
	timeline_changed.emit()
	return instance


func register_operation_start(operation_id: StringName, realtime_start := -1.0) -> void:
	var start := _clock.elapsed_seconds if realtime_start < 0.0 else realtime_start
	operation_start_times[operation_id] = start
	for value: Variant in instances.values():
		var instance := value as RealtimeEventInstance
		if instance.state == RealtimeEventInstance.State.PENDING and instance.definition.trigger_type == RealtimeEventDefinition.TriggerType.RELATIVE_OPERATION_TIME and instance.definition.operation_id == operation_id:
			instance.scheduled_at = start + instance.definition.delay_seconds
	timeline_changed.emit()


func register_action_handler(action_type: RealtimeEventDefinition.ActionType, handler: Callable) -> void:
	if handler.is_valid():
		action_handlers[action_type] = handler


func cancel(instance_id: StringName) -> bool:
	var instance := instances.get(instance_id) as RealtimeEventInstance
	var success := instance != null and instance.cancel(_clock.elapsed_seconds)
	if success:
		timeline_changed.emit()
	return success


func get_timeline() -> Array[RealtimeEventInstance]:
	var result: Array[RealtimeEventInstance] = []
	for value: Variant in instances.values():
		result.append(value as RealtimeEventInstance)
	result.sort_custom(func(a: RealtimeEventInstance, b: RealtimeEventInstance) -> bool:
		var a_time := INF if a.scheduled_at < 0.0 else a.scheduled_at
		var b_time := INF if b.scheduled_at < 0.0 else b.scheduled_at
		return a_time < b_time if a_time != b_time else String(a.id) < String(b.id)
	)
	return result


func _on_realtime_changed(realtime_now: float) -> void:
	for value: Variant in instances.values():
		var instance := value as RealtimeEventInstance
		if instance.state == RealtimeEventInstance.State.PENDING and instance.scheduled_at >= 0.0 and realtime_now >= instance.scheduled_at:
			_activate_and_resolve(instance, realtime_now)
	timeline_changed.emit()


func _on_process_state_changed(process_id: StringName, _previous: RealtimeProcess.State, current: RealtimeProcess.State) -> void:
	for value: Variant in instances.values():
		var instance := value as RealtimeEventInstance
		var definition := instance.definition
		if instance.state == RealtimeEventInstance.State.PENDING and definition.trigger_type == RealtimeEventDefinition.TriggerType.PROCESS_STATE_CHANGED and definition.process_id == process_id and definition.expected_process_state == current:
			_activate_and_resolve(instance, _clock.elapsed_seconds)


func _activate_and_resolve(instance: RealtimeEventInstance, realtime_now: float) -> void:
	if not instance.activate(realtime_now):
		return
	event_activated.emit(instance)
	for authored_action: Dictionary in instance.definition.actions:
		var action := authored_action.duplicate(true)
		action["event_definition_id"] = instance.definition.id
		action["realtime"] = realtime_now
		instance.produced_actions.append(action.duplicate(true))
		action_produced.emit(instance.id, action)
		var action_type: RealtimeEventDefinition.ActionType = int(action.get("type", -1))
		if action_handlers.has(action_type):
			action_handlers[action_type].call(action.get("payload", {}).duplicate(true), instance)
	instance.complete(realtime_now)
	event_completed.emit(instance)


func _on_instance_state_changed(_instance_id: StringName, _previous: RealtimeEventInstance.State, _current: RealtimeEventInstance.State) -> void:
	timeline_changed.emit()
