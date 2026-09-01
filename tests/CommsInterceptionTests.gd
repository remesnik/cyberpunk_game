extends SceneTree

const SessionScript := preload("res://core/comms/CommsSession.gd")
const CyberClockScript := preload("res://core/CyberspaceClock.gd")
const ManagerScript := preload("res://core/comms/CommsInterceptionManager.gd")
const ChannelScript := preload("res://core/comms/CommsChannelDefinition.gd")
const ProcessManagerScript := preload("res://core/RealtimeProcessManager.gd")
const ProcessScript := preload("res://core/RealtimeProcess.gd")
const EndpointScript := preload("res://core/RealtimeEndpointDefinition.gd")

var failures := 0
var assertions := 0


func _init() -> void:
	_test_realtime_transcript_and_cyber_isolation()
	_test_operation_specific_access_results()
	print("%s: %d comms interception assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)


func _test_realtime_transcript_and_cyber_isolation() -> void:
	var session = SessionScript.new(&"CALL", &"CHANNEL", &"PROCESS")
	session.duration = 30.0
	session.add_transcript_line(0.0, &"GUARD_1", "Loading dock is clear.")
	session.add_transcript_line(4.0, &"DISPATCH", "Copy.")
	session.add_transcript_line(10.0, &"GUARD_1", "Wait.")
	session.add_transcript_line(12.0, &"DISPATCH", "Report.")
	session.listen()
	session.advance_to(4.1)
	_expect(session.heard_lines.size() == 2, "lines appear according to realtime transcript timestamps")

	var before_cyber: float = session.elapsed_time
	var cyber = CyberClockScript.new()
	var result := cyber.resolve_action(ActionRequest.new(&"PLAYER", ActionRequest.ActionType.WAIT, null, 100), _valid, _applied)
	_expect(result.success and cyber.current_tick == 100, "cyberspace advances 100 ticks")
	_expect(is_equal_approx(session.elapsed_time, before_cyber) and session.heard_lines.size() == 2, "cyberspace ticks neither advance nor flush conversation")

	session.stop_listening()
	session.start_recording()
	session.advance_to(10.1)
	_expect(session.elapsed_time > before_cyber and session.heard_lines.size() == 2, "underlying call continues while not listening")
	_expect(session.recorded_lines.size() == 1 and session.recorded_lines[0].text == "Wait.", "recording captures lines while monitor is not listening")

	session.listen()
	session.advance_to(12.1)
	_expect(session.heard_lines.size() == 3 and session.heard_lines.back().text == "Report.", "reconnecting hears only remaining live lines")
	_expect(session.transcript_for_monitor().size() == 4, "recording preserves a line missed while disconnected")
	_expect(session.mark_important() and session.important_lines.size() == 1, "latest heard line can be marked important")


func _test_operation_specific_access_results() -> void:
	var process_manager = ProcessManagerScript.new()
	var process = ProcessScript.new(&"CALL_PROCESS", ProcessScript.ProcessType.VOICE_CALL, "Call")
	process_manager.add_process(process, true)
	var endpoint = EndpointScript.new(&"PBX_ENDPOINT", EndpointScript.EndpointType.COMMS, &"PBX", &"VOIP", [&"CALL_PROCESS"] as Array[StringName])
	process_manager.add_endpoint(endpoint)
	var knowledge := PlayerKnowledge.new()
	knowledge.realtime_endpoint_records[endpoint.id] = {"id": endpoint.id, "accessible": true}
	knowledge.realtime_process_records[process.id] = {"id": process.id, "endpoint_id": endpoint.id}
	var position := PlayerNetworkPosition.new(&"PBX")
	var manager = ManagerScript.new()
	manager.configure(process_manager, knowledge, position)
	var channel = ChannelScript.new(&"CHANNEL", "Test", ChannelScript.ChannelType.VOIP_CALL, endpoint.id)
	channel.set_access_policy(CommsAccessResult.Operation.MONITOR)
	channel.set_access_policy(CommsAccessResult.Operation.INTERCEPT, 0, &"DECRYPT_VOICE", &"", 2, false, 0.0)
	channel.set_access_policy(CommsAccessResult.Operation.RECORD)
	channel.set_access_policy(CommsAccessResult.Operation.INJECT, 0, &"PBX_ADMIN", &"VOICE_INJECTOR", 5, true, 0.65)
	manager.add_channel(channel)
	manager.add_session(SessionScript.new(&"SESSION", channel.id, process.id))

	var monitor_result: CommsAccessResult = manager.evaluate_access(&"SESSION", CommsAccessResult.Operation.MONITOR)
	var intercept_result: CommsAccessResult = manager.evaluate_access(&"SESSION", CommsAccessResult.Operation.INTERCEPT)
	var record_result: CommsAccessResult = manager.evaluate_access(&"SESSION", CommsAccessResult.Operation.RECORD)
	var inject_result: CommsAccessResult = manager.evaluate_access(&"SESSION", CommsAccessResult.Operation.INJECT)
	_expect(monitor_result.available and monitor_result.status_text() == "MONITOR AVAILABLE", "monitor has an independent available result")
	_expect(not intercept_result.available and intercept_result.status_text() == "INTERCEPT REQUIRES: DECRYPT_VOICE", "intercept explains its missing capability")
	_expect(intercept_result.trace_cost == 2 and not intercept_result.detection_possible, "interception trace does not imply detection")
	_expect(record_result.available and record_result.status_text() == "RECORD AVAILABLE", "record has an independent available result")
	_expect(not inject_result.available and inject_result.missing_requirements == [&"PBX_ADMIN", &"VOICE_INJECTOR"], "inject reports capability and program separately")
	_expect(inject_result.detection_possible and is_equal_approx(inject_result.detection_risk, 0.65), "endpoint policy explicitly enables injection detection risk")
	position.grant_capability(&"DECRYPT_VOICE")
	_expect(manager.evaluate_access(&"SESSION", CommsAccessResult.Operation.INTERCEPT).available, "granting the required capability enables only interception")
	manager.free()
	process_manager.free()


func _valid(_request: ActionRequest) -> Dictionary:
	return {"success": true, "reason": "", "events": []}


func _applied(_request: ActionRequest) -> Dictionary:
	return {"success": true, "reason": "", "events": []}


func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
