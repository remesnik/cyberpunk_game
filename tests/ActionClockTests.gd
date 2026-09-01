extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void:
	_test_non_unit_cost_and_phase_order()
	_test_failed_action_spends_no_time()
	_test_zero_cost_action()
	print("%s: %d action clock assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _test_non_unit_cost_and_phase_order() -> void:
	var clock := ActionClock.new()
	clock.register_ice_updater(func(tick: int, _request: ActionRequest) -> Array[Dictionary]: return [{"type": &"ICE_TEST", "tick": tick}])
	clock.register_trace_updater(func(tick: int, _request: ActionRequest) -> Array[Dictionary]: return [{"type": &"TRACE_TEST", "tick": tick}])
	clock.register_network_updater(func(tick: int, _request: ActionRequest) -> Array[Dictionary]: return [{"type": &"NETWORK_TEST", "tick": tick}])
	var request := ActionRequest.new(&"PLAYER", ActionRequest.ActionType.TRANSFER, &"FILE_SERVER", 3, {"bytes": 2048})
	var result := clock.resolve_action(request, _always_valid, _always_applies)
	_expect(result.success, "valid action succeeds")
	_expect(result.time_spent == 3 and clock.current_tick == 3, "non-unit action advances exact cost")
	_expect(request.metadata.bytes == 2048, "metadata is retained")
	var names := _event_names(result.events_produced)
	_expect(names == [&"PLAYER_ACTION_APPLIED", &"ICE_UPDATE", &"ICE_TEST", &"TRACE_UPDATE", &"TRACE_TEST", &"NETWORK_UPDATE", &"NETWORK_TEST", &"EVENTS_RESOLVED"], "phases and events resolve deterministically")

func _test_failed_action_spends_no_time() -> void:
	var clock := ActionClock.new()
	var request := ActionRequest.new(&"PLAYER", ActionRequest.ActionType.EXPLOIT, &"LOCKED", 5)
	var result := clock.resolve_action(request, func(_request: ActionRequest) -> Dictionary: return {"success": false, "reason": "Locked.", "events": []}, _always_applies)
	_expect(not result.success and result.reason == "Locked.", "validation failure is returned")
	_expect(clock.current_tick == 0 and result.time_spent == 0, "failed action spends no time")

func _test_zero_cost_action() -> void:
	var clock := ActionClock.new()
	var request := ActionRequest.new(&"PLAYER", ActionRequest.ActionType.PING, null, 0)
	var result := clock.resolve_action(request, _always_valid, _always_applies)
	_expect(result.success and clock.current_tick == 0, "valid zero-cost action is supported")

func _always_valid(_request: ActionRequest) -> Dictionary:
	return {"success": true, "reason": "", "events": []}

func _always_applies(_request: ActionRequest) -> Dictionary:
	return {"success": true, "reason": "Applied.", "events": [{"type": &"PLAYER_ACTION_APPLIED"}]}

func _event_names(events: Array[Dictionary]) -> Array[StringName]:
	var names: Array[StringName] = []
	for event in events:
		names.append(event.type)
	return names

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
