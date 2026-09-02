extends SceneTree

var failures := 0
var assertions := 0


func _init() -> void:
	var level := load("res://data/authoring/first_contact.tres") as CyberspaceContentDocument
	var process_data: Dictionary = level.find_entry(&"GUARD_CAMERA_CALL_PROCESS")
	var session_data: Dictionary = level.find_entry(&"GUARD_CAMERA_FAULT_CALL")
	var channel_data: Dictionary = level.find_entry(&"FACILITIES_FAULT_CHANNEL")
	_expect(process_data.metadata.origin == &"MEATSPACE" and process_data.duration == 45.0, "guard call is authored as a finite objective meat-space process")
	_expect(process_data.start_trigger.target_id == &"CAM_LOBBY_01", "camera manipulation starts the call independently of COMM_NODE discovery")

	var process_manager := RealtimeProcessManager.new()
	var process := RealtimeProcess.new(process_data.id, RealtimeProcess.ProcessType.VOICE_CALL, process_data.display_name, process_data.source_id, process_data.duration)
	process_manager.add_process(process, true)
	var endpoint := RealtimeEndpointDefinition.new(&"COMM_NODE_ENDPOINT", RealtimeEndpointDefinition.EndpointType.COMMS, &"COMM_NODE", &"INTERNAL_COMMS", [&"GUARD_CAMERA_CALL_PROCESS"] as Array[StringName])
	process_manager.add_endpoint(endpoint)
	var knowledge := PlayerKnowledge.new()
	knowledge.realtime_endpoint_records[endpoint.id] = {"id": endpoint.id, "accessible": true}
	knowledge.realtime_process_records[process.id] = {"id": process.id, "endpoint_id": endpoint.id}
	var player := PlayerNetworkPosition.new(&"COMM_NODE")
	var manager := CommsInterceptionManager.new()
	manager.configure(process_manager, knowledge, player)
	var channel := CommsChannelDefinition.new(channel_data.id, channel_data.display_name, CommsChannelDefinition.ChannelType.PHONE_CALL, endpoint.id)
	channel.set_access_policy(CommsAccessResult.Operation.MONITOR)
	channel.set_access_policy(CommsAccessResult.Operation.INTERCEPT, 0, &"", &"", 1, false, 0.0)
	channel.set_access_policy(CommsAccessResult.Operation.RECORD)
	channel.set_access_policy(CommsAccessResult.Operation.INJECT, 1, &"SPOOF", &"VOICE_INJECTOR", 3, true, 0.35)
	manager.add_channel(channel)
	var session := CommsSession.new(session_data.id, channel.id, process.id)
	session.duration = session_data.duration
	for line: Dictionary in session_data.timeline:
		session.add_transcript_line(line.time, line.speaker_id, line.text, line.story_event_id)
	manager.add_session(session)

	_expect(manager.monitor(session.id).available and manager.listen(session.id), "discovered live call supports monitoring and interception")
	process_manager.advance_to_realtime(6.1)
	_expect(session.heard_lines.size() == 2 and session.heard_lines[0].event_id == &"CAMERA_FAULT_REPORTED", "live transcript follows real elapsed seconds")
	var elapsed_before_cyber := session.elapsed_time
	var cyber := ActionClock.new()
	cyber.resolve_action(ActionRequest.new(&"PLAYER", ActionRequest.ActionType.WAIT, null, 100), func(_request): return {"success": true, "events": []}, func(_request): return {"success": true, "events": []})
	_expect(cyber.current_tick == 100 and session.elapsed_time == elapsed_before_cyber and session.heard_lines.size() == 2, "one hundred cyber ticks neither advance nor flush the live call")
	process_manager.advance_to_realtime(14.1)
	_expect(session.heard_lines.size() == 3 and session.heard_lines[-1].event_id == &"GUARD_CHECKING_RELAY", "call continues when realtime advances while cyber actions remain available")
	var injection := manager.evaluate_access(session.id, CommsAccessResult.Operation.INJECT)
	_expect(not injection.available and injection.missing_requirements == [&"AUTHORITY_1", &"SPOOF", &"VOICE_INJECTOR"], "optional manipulation uses generic access results and explains unavailable requirements")
	var sequence: Dictionary = level.find_entry(&"FIRST_CONTACT_LIVE_COMMS")
	_expect(sequence.beats.size() == 5 and sequence.beats[1].objective.choices.any(func(choice): return choice.id == &"IGNORE_CALL"), "authored sequence permits listening, interception, or ignoring the call")
	manager.free(); process_manager.free()
	print("%s: %d First Contact comms assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)


func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
