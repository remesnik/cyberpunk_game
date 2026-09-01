extends SceneTree

const ProcessScript := preload("res://core/RealtimeProcess.gd")
const ProcessManagerScript := preload("res://core/RealtimeProcessManager.gd")
const AlarmDefinitionScript := preload("res://core/alarms/PhysicalAlarmDefinition.gd")
const AlarmManagerScript := preload("res://core/alarms/PhysicalAlarmManager.gd")
const CyberClockScript := preload("res://core/CyberspaceClock.gd")

var failures := 0
var assertions := 0


func _init() -> void:
	_test_realtime_alarm_and_command_semantics()
	print("%s: %d physical alarm assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)


func _test_realtime_alarm_and_command_semantics() -> void:
	var process_manager = ProcessManagerScript.new()
	process_manager.add_process(ProcessScript.new(&"ALARM_PROCESS", ProcessScript.ProcessType.ALARM, "Test Alarm"), true)
	var knowledge := PlayerKnowledge.new()
	knowledge.realtime_process_records[&"ALARM_PROCESS"] = {"id": &"ALARM_PROCESS"}
	var position := PlayerNetworkPosition.new(&"SECURITY")
	var manager = AlarmManagerScript.new()
	manager.configure(process_manager, knowledge, position)
	var definition = AlarmDefinitionScript.new(&"ZONE_B", "Zone B", AlarmDefinitionScript.AlarmType.DOOR_FORCED, &"EAST_STAIR", &"ENDPOINT", &"ALARM_PROCESS")
	definition.set_action_policy(AlarmDefinitionScript.Command.MONITOR)
	definition.set_action_policy(AlarmDefinitionScript.Command.ACKNOWLEDGE)
	definition.set_action_policy(AlarmDefinitionScript.Command.SILENCE)
	definition.set_action_policy(AlarmDefinitionScript.Command.BYPASS, 0, &"ROOTKIT")
	definition.set_action_policy(AlarmDefinitionScript.Command.RESTORE)
	definition.set_action_policy(AlarmDefinitionScript.Command.TRIGGER)
	definition.add_timeline_event(5.0, &"PREALARM", {"description": "DOOR CONTACT UNSTABLE"})
	definition.add_timeline_event(10.0, &"TRIGGER", {"description": "DOOR FORCED"})
	manager.add_alarm(definition)
	var alarm: PhysicalAlarmInstance = manager.instances[definition.id]

	process_manager.advance_to_realtime(6.0)
	_expect(alarm.state == PhysicalAlarmInstance.State.PREALARM and alarm.alert_presenting, "prealarm occurs on realtime timeline")
	var cyber = CyberClockScript.new()
	cyber.resolve_action(ActionRequest.new(&"PLAYER", ActionRequest.ActionType.WAIT, null, 100), _valid, _applied)
	_expect(cyber.current_tick == 100 and alarm.elapsed_time == 6.0 and alarm.state == PhysicalAlarmInstance.State.PREALARM, "100 cyber ticks do not advance alarm")
	process_manager.advance_to_realtime(11.0)
	_expect(alarm.state == PhysicalAlarmInstance.State.TRIGGERED and alarm.detection_count == 1, "realtime sensor event triggers alarm")

	var silence: Dictionary = manager.execute_command(definition.id, AlarmDefinitionScript.Command.SILENCE)
	var detections_before := alarm.detection_count
	alarm.detect({"source": &"SECOND_MOTION"})
	_expect(silence.success and alarm.state == PhysicalAlarmInstance.State.SILENCED and alarm.detection_enabled, "silence stops presentation but preserves detection")
	_expect(not alarm.alert_presenting and alarm.detection_count == detections_before + 1, "silenced alarm continues counting physical detections")

	var denied_bypass: Dictionary = manager.execute_command(definition.id, AlarmDefinitionScript.Command.BYPASS)
	_expect(not denied_bypass.success and alarm.state == PhysicalAlarmInstance.State.SILENCED, "bypass respects authored capability requirement")
	position.grant_capability(&"ROOTKIT")
	manager.execute_command(definition.id, AlarmDefinitionScript.Command.BYPASS)
	var bypass_count := alarm.detection_count
	var created_alarm := alarm.detect({"source": &"BYPASSED_SENSOR"})
	_expect(alarm.state == PhysicalAlarmInstance.State.BYPASSED and not alarm.detection_enabled and not created_alarm, "bypass prevents sensor from creating an alarm")
	_expect(alarm.detection_count == bypass_count + 1 and not alarm.alert_presenting, "bypassed sensor can log activity without presenting alarm")
	manager.execute_command(definition.id, AlarmDefinitionScript.Command.RESTORE)
	_expect(alarm.state == PhysicalAlarmInstance.State.NORMAL and alarm.detection_enabled, "restore re-enables normal detection")
	var reaction := manager.get_reaction_view(definition.id)
	_expect(reaction.has("alert_presenting") and reaction.has("underlying_condition_active"), "physical actors receive a state-only reaction view")
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
