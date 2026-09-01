class_name ActionClock
extends RefCounted

signal tick_advanced(previous_tick: int, current_tick: int, amount: int)
signal action_resolved(request: ActionRequest, result: ActionResult)

var current_tick := 0
var last_action: ActionRequest
var last_result: ActionResult
var _ice_updaters: Array[Callable] = []
var _trace_updaters: Array[Callable] = []
var _network_updaters: Array[Callable] = []
var _resolving := false

func register_ice_updater(updater: Callable) -> void:
	_register_once(_ice_updaters, updater)

func register_trace_updater(updater: Callable) -> void:
	_register_once(_trace_updaters, updater)

func register_network_updater(updater: Callable) -> void:
	_register_once(_network_updaters, updater)

func resolve_action(request: ActionRequest, validator: Callable, applier: Callable) -> ActionResult:
	if _resolving:
		return _finish(request, ActionResult.new(false, 0, "Another action is resolving."))
	if request.cost < 0:
		return _finish(request, ActionResult.new(false, 0, "Action cost cannot be negative."))
	_resolving = true
	var events: Array[Dictionary] = []
	var validation: Dictionary = validator.call(request)
	_append_events(events, validation.get("events", []))
	if not validation.get("success", false):
		_resolving = false
		return _finish(request, ActionResult.new(false, 0, validation.get("reason", "Action rejected."), events))

	var application: Dictionary = applier.call(request)
	_append_events(events, application.get("events", []))
	if not application.get("success", false):
		_resolving = false
		return _finish(request, ActionResult.new(false, 0, application.get("reason", "Action failed."), events))

	var previous_tick := current_tick
	current_tick += request.cost
	tick_advanced.emit(previous_tick, current_tick, request.cost)
	_run_phase(&"ICE_UPDATE", _ice_updaters, request, events)
	_run_phase(&"TRACE_UPDATE", _trace_updaters, request, events)
	_run_phase(&"NETWORK_UPDATE", _network_updaters, request, events)
	events.append({"type": &"EVENTS_RESOLVED", "tick": current_tick})
	_resolving = false
	return _finish(request, ActionResult.new(true, request.cost, application.get("reason", "Action resolved."), events))

func _run_phase(phase: StringName, updaters: Array[Callable], request: ActionRequest, events: Array[Dictionary]) -> void:
	events.append({"type": phase, "tick": current_tick})
	for updater in updaters:
		var produced: Variant = updater.call(current_tick, request)
		if produced is Array:
			_append_events(events, produced)

func _append_events(destination: Array[Dictionary], source: Array) -> void:
	for event in source:
		if event is Dictionary:
			destination.append((event as Dictionary).duplicate(true))

func _finish(request: ActionRequest, result: ActionResult) -> ActionResult:
	last_action = request
	last_result = result
	action_resolved.emit(request, result)
	return result

func _register_once(collection: Array[Callable], updater: Callable) -> void:
	if updater.is_valid() and not collection.has(updater):
		collection.append(updater)
