extends SceneTree

const ClockScript := preload("res://core/RealtimeWorldClock.gd")
const ProcessScript := preload("res://core/RealtimeProcess.gd")
const ProcessManagerScript := preload("res://core/RealtimeProcessManager.gd")
const EventDefinitionScript := preload("res://core/realtime_events/RealtimeEventDefinition.gd")
const SchedulerScript := preload("res://core/realtime_events/RealtimeEventScheduler.gd")
const CyberClockScript := preload("res://core/CyberspaceClock.gd")

var failures := 0
var assertions := 0


func _init() -> void:
	_test_realtime_trigger_modes_and_isolation()
	print("%s: %d realtime event scheduler assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)


func _test_realtime_trigger_modes_and_isolation() -> void:
	var clock = ClockScript.new()
	var process_manager = ProcessManagerScript.new()
	var scheduler = SchedulerScript.new()
	scheduler.configure(clock, process_manager)
	var produced: Array[Dictionary] = []
	var transitions: Array[int] = []
	scheduler.register_action_handler(EventDefinitionScript.ActionType.SET_STORY_FLAG, func(payload: Dictionary, _instance: RealtimeEventInstance) -> void: produced.append(payload))

	var delayed = EventDefinitionScript.new(&"DELAYED", "Delayed event", EventDefinitionScript.TriggerType.AFTER_SECONDS, 10.0)
	delayed.add_action(EventDefinitionScript.ActionType.SET_STORY_FLAG, {"flag": &"DELAYED_FIRED"})
	scheduler.add_definition(delayed)
	var delayed_instance := scheduler.schedule(delayed.id)
	delayed_instance.state_changed.connect(func(_id: StringName, _previous: RealtimeEventInstance.State, current: RealtimeEventInstance.State) -> void: transitions.append(current))

	var cyber = CyberClockScript.new()
	cyber.resolve_action(ActionRequest.new(&"PLAYER", ActionRequest.ActionType.WAIT, null, 100), _valid, _applied)
	_expect(cyber.current_tick == 100 and delayed_instance.state == RealtimeEventInstance.State.PENDING, "100 cyber ticks do not activate realtime event")
	clock.restore(9.0, false)
	_expect(delayed_instance.state == RealtimeEventInstance.State.PENDING, "after-N-seconds event remains pending before deadline")
	clock.restore(10.0, false)
	_expect(delayed_instance.state == RealtimeEventInstance.State.COMPLETED and produced[0].flag == &"DELAYED_FIRED", "deadline activates action and completes event")
	_expect(transitions == [RealtimeEventInstance.State.ACTIVE, RealtimeEventInstance.State.COMPLETED], "event exposes ACTIVE before COMPLETED")

	var relative = EventDefinitionScript.new(&"RELATIVE", "Operation relative", EventDefinitionScript.TriggerType.RELATIVE_OPERATION_TIME, 5.0)
	relative.operation_id = &"OPERATION"
	relative.add_action(EventDefinitionScript.ActionType.SET_STORY_FLAG, {"flag": &"RELATIVE_FIRED"})
	scheduler.add_definition(relative)
	var relative_instance := scheduler.schedule(relative.id)
	_expect(relative_instance.scheduled_at < 0.0, "relative event waits for operation start")
	scheduler.register_operation_start(&"OPERATION", 20.0)
	clock.restore(24.9, false)
	_expect(relative_instance.state == RealtimeEventInstance.State.PENDING, "relative operation deadline uses registered origin")
	clock.restore(25.0, false)
	_expect(relative_instance.state == RealtimeEventInstance.State.COMPLETED, "relative operation event fires at offset")

	var process := ProcessScript.new(&"DELIVERY", ProcessScript.ProcessType.DELIVERY, "Delivery", &"VENDOR", 2.0)
	process_manager.add_process(process, true)
	var process_definition = EventDefinitionScript.new(&"PROCESS_DONE", "Process completed", EventDefinitionScript.TriggerType.PROCESS_STATE_CHANGED)
	process_definition.process_id = process.id
	process_definition.expected_process_state = RealtimeProcess.State.COMPLETED
	process_definition.add_action(EventDefinitionScript.ActionType.SET_STORY_FLAG, {"flag": &"PROCESS_FIRED"})
	scheduler.add_definition(process_definition)
	var process_instance := scheduler.schedule(process_definition.id)
	process_manager.advance_to_realtime(2.0)
	_expect(process_instance.state == RealtimeEventInstance.State.COMPLETED, "process-state transition activates authored event")

	var cancelled_definition = EventDefinitionScript.new(&"CANCEL_ME", "Cancelled", EventDefinitionScript.TriggerType.AFTER_SECONDS, 5.0)
	scheduler.add_definition(cancelled_definition)
	var cancelled := scheduler.schedule(cancelled_definition.id)
	_expect(scheduler.cancel(cancelled.id) and cancelled.state == RealtimeEventInstance.State.CANCELLED, "pending event can be cancelled")
	clock.restore(100.0, false)
	_expect(cancelled.state == RealtimeEventInstance.State.CANCELLED, "cancelled event never activates later")
	_expect(produced.size() == 3, "only non-cancelled authored actions are produced")
	scheduler.free()
	process_manager.free()
	clock.free()


func _valid(_request: ActionRequest) -> Dictionary:
	return {"success": true, "reason": "", "events": []}


func _applied(_request: ActionRequest) -> Dictionary:
	return {"success": true, "reason": "", "events": []}


func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
