extends SceneTree

const OutboundManagerScript := preload("res://core/comms/OutboundCommsManager.gd")
const OutboundActionScript := preload("res://core/comms/OutboundCommsAction.gd")
const OutboundTargetScript := preload("res://core/comms/OutboundCommsTargetDefinition.gd")
const CommsManagerScript := preload("res://core/comms/CommsInterceptionManager.gd")
const ProcessManagerScript := preload("res://core/RealtimeProcessManager.gd")
const ClockScript := preload("res://core/RealtimeWorldClock.gd")
const ConditionScript := preload("res://core/story/ConditionDefinition.gd")
const StoryHookScript := preload("res://core/story/StoryHook.gd")
const CyberClockScript := preload("res://core/CyberspaceClock.gd")

var failures := 0
var assertions := 0


func _init() -> void:
	_test_authored_outbound_call_uses_realtime()
	print("%s: %d outbound comms assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)


func _test_authored_outbound_call_uses_realtime() -> void:
	var process_manager = ProcessManagerScript.new()
	var comms_manager = CommsManagerScript.new()
	var outbound = OutboundManagerScript.new()
	var clock = ClockScript.new()
	var knowledge := PlayerKnowledge.new()
	var position := PlayerNetworkPosition.new(&"PBX")
	var endpoint_id := &"PBX_ENDPOINT"
	knowledge.realtime_endpoint_records[endpoint_id] = {"id": endpoint_id}
	position.credentials.append(&"PBX_ACCESS")
	comms_manager.configure(process_manager, knowledge, position)
	outbound.configure(process_manager, comms_manager, knowledge, position, clock)

	var target = OutboundTargetScript.new(&"SECURITY", OutboundActionScript.TargetType.SECURITY_DESK, "Security", endpoint_id)
	target.conditions.append(ConditionScript.new(&"KNOW_PBX", ConditionScript.ConditionType.KNOWS_ENDPOINT, endpoint_id))
	target.conditions.append(ConditionScript.new(&"PBX_ACCESS", ConditionScript.ConditionType.HAS_CREDENTIAL, &"PBX_ACCESS"))
	target.add_choice(&"SMOKE_REPORT", "There's smoke on the third floor.")
	outbound.add_target(target)
	var hook = StoryHookScript.new(&"SECURITY_SMOKE", &"OUTBOUND_COMMS")
	hook.conditions.append(ConditionScript.new(&"TARGET", ConditionScript.ConditionType.TARGET_EQUALS, target.id))
	hook.conditions.append(ConditionScript.new(&"CHOICE", ConditionScript.ConditionType.CHOICE_EQUALS, &"SMOKE_REPORT"))
	hook.add_response_line(1.0, &"DISPATCH", "Redirecting the patrol.")
	hook.effects.append({"type": &"SET_FLAG", "key": &"PATROL_REDIRECTED", "value": true})
	outbound.add_story_hook(hook)

	_expect(outbound.get_available_targets().size() == 1, "StoryHook conditions expose an authored PBX target")
	var action = OutboundActionScript.new(OutboundActionScript.ActionType.CALL, OutboundActionScript.TargetType.SECURITY_DESK, target.id, &"SMOKE_REPORT")
	var result: Dictionary = outbound.submit(action)
	_expect(result.success and result.realtime == 0.0, "outbound action begins on realtime session timestamp")
	_expect(outbound.flags.get(&"PATROL_REDIRECTED", false), "authored StoryHook effect resolves")
	var session: CommsSession = comms_manager.sessions[result.session_id]

	var cyber = CyberClockScript.new()
	cyber.resolve_action(ActionRequest.new(&"PLAYER", ActionRequest.ActionType.WAIT, null, 100), _valid, _applied)
	_expect(cyber.current_tick == 100 and session.elapsed_time == 0.0 and session.heard_lines.is_empty(), "100 cyber ticks do not advance the outbound call")
	process_manager.advance_to_realtime(1.1)
	_expect(session.elapsed_time >= 1.0 and session.heard_lines.size() == 1, "authored response arrives from realtime progression")

	var invalid = OutboundActionScript.new(OutboundActionScript.ActionType.CALL, OutboundActionScript.TargetType.SECURITY_DESK, target.id, &"UNAUTHORED")
	_expect(not outbound.submit(invalid).success, "arbitrary unauthored dialogue choices are rejected")
	outbound.free()
	comms_manager.free()
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
