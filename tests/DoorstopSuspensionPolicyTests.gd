extends SceneTree

class FakeAlarmManager:
	var instances: Dictionary = {}

var failures := 0
var assertions := 0
var spawned := 0
var node_process_seconds := 0.0


func _init() -> void:
	_test_forgiving_defaults_preserve_persistent_state()
	_test_reactive_policy_applies_only_enabled_consequences()
	print("%s: %d Doorstop suspension policy assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)


func _test_forgiving_defaults_preserve_persistent_state() -> void:
	var fixture := _suspended_fixture()
	var alarm_manager := FakeAlarmManager.new()
	var alarm := PhysicalAlarmInstance.new(PhysicalAlarmDefinition.new(&"ALARM_1", "Test Alarm"))
	alarm.state = PhysicalAlarmInstance.State.TRIGGERED
	alarm_manager.instances[&"ALARM_1"] = alarm
	var effects: Array[Dictionary] = [{"id": &"TEMP", "remaining_seconds": 20.0}, {"id": &"PERMANENT", "permanent": true, "remaining_seconds": 1.0}]
	var result := SuspendedIntrusionAdvancer.new().advance_suspended_intrusion(fixture.session, DoorstopSuspensionPolicy.forgiving(), 5.0, {"trace": 42, "alarm_manager": alarm_manager, "security_level": 2, "temporary_effects": effects})
	_expect(result.success and result.trace == 42, "forgiving default preserves trace without adding trace")
	_expect(alarm.state == PhysicalAlarmInstance.State.TRIGGERED, "default policy leaves active alarms unchanged")
	_expect(result.security_level == 2, "default policy does not escalate security")
	_expect(result.temporary_effects[0].remaining_seconds == 15.0 and result.temporary_effects[1].remaining_seconds == 1.0, "temporary effects expire by their rules while permanent effects remain")
	_expect(fixture.session.resume_state.objective_complete and fixture.session.resume_state.loot == 7 and fixture.session.resume_state.compromised, "completed objectives, loot, and compromised state remain untouched")


func _test_reactive_policy_applies_only_enabled_consequences() -> void:
	var fixture := _suspended_fixture()
	var policy := DoorstopSuspensionPolicy.new()
	policy.trace_increase_per_second = 0.5
	policy.alarms_remain_active = false
	policy.security_may_escalate = true
	policy.security_escalation_interval_seconds = 4.0
	policy.maximum_security_level = 5
	policy.replacement_ice_may_spawn = true
	policy.replacement_ice_interval_seconds = 5.0
	policy.maximum_replacement_ice_per_advance = 2
	policy.node_local_processes_continue = true
	var alarm_manager := FakeAlarmManager.new()
	var alarm := PhysicalAlarmInstance.new(PhysicalAlarmDefinition.new(&"ALARM_1", "Test Alarm"))
	alarm.state = PhysicalAlarmInstance.State.TRIGGERED
	alarm.detection_enabled = true
	alarm_manager.instances[&"ALARM_1"] = alarm
	var result := SuspendedIntrusionAdvancer.new().advance_suspended_intrusion(fixture.session, policy, 12.0, {
		"trace": 10,
		"alarm_manager": alarm_manager,
		"security_level": 1,
		"temporary_effects": [{"id": &"SHORT_BUFF", "remaining_seconds": 3.0}],
		"spawn_replacement_ice": Callable(self, "_spawn_replacement"),
		"advance_node_processes": Callable(self, "_advance_node_process"),
	})
	_expect(result.trace == 16, "reactive policy adds configured trace over elapsed realtime")
	_expect(alarm.state == PhysicalAlarmInstance.State.NORMAL, "a policy may explicitly reset alarms")
	_expect(result.security_level == 4, "security escalates at the configured interval and cap")
	_expect(result.temporary_effects.is_empty(), "expired temporary effects are removed")
	_expect(spawned == 2, "replacement ICE hook is invoked only when enabled and capped")
	_expect(node_process_seconds == 12.0, "node-local process hook receives suspended elapsed time")


func _suspended_fixture() -> Dictionary:
	var anchor := DoorstopAnchor.new(&"BURNED_INSTANCE", &"RUN_POLICY", &"NODE_A", 0.0)
	var session := IntrusionSession.new(&"RUN_POLICY")
	session.suspend_at_doorstop(anchor, 0.0, {"objective_complete": true, "loot": 7, "compromised": true, "current_node_id": &"NODE_A"})
	return {"anchor": anchor, "session": session}


func _spawn_replacement(_index: int) -> void:
	spawned += 1


func _advance_node_process(seconds: float, _node_id: StringName) -> void:
	node_process_seconds += seconds


func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
