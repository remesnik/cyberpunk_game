class_name SuspendedIntrusionAdvancer
extends RefCounted


func advance_suspended_intrusion(session: IntrusionSession, policy: DoorstopSuspensionPolicy, elapsed_seconds: float, context: Dictionary) -> Dictionary:
	if session == null or session.lifecycle != IntrusionSession.Lifecycle.SUSPENDED_AT_DOORSTOP:
		return _failure("Intrusion is not suspended at Doorstop.")
	if policy == null or elapsed_seconds < 0.0:
		return _failure("Suspension policy or elapsed time is invalid.")
	var events: Array[Dictionary] = []
	var trace := int(context.get("trace", session.resume_state.get("trace", 0)))
	if not policy.preserve_trace:
		trace = 0
	if policy.trace_increase_per_second > 0.0:
		var increase := int(floor(elapsed_seconds * policy.trace_increase_per_second))
		trace += increase
		if increase > 0:
			events.append({"type": &"SUSPENDED_TRACE_INCREASED", "amount": increase, "trace": trace})
	if not policy.alarms_remain_active:
		var alarm_manager: Variant = context.get("alarm_manager")
		if alarm_manager != null:
			for alarm: PhysicalAlarmInstance in alarm_manager.instances.values():
				alarm.apply_command(PhysicalAlarmDefinition.Command.RESTORE)
		events.append({"type": &"SUSPENDED_ALARMS_RESET"})
	var ice_events: Array[Dictionary] = []
	if policy.ice_may_reposition:
		var ice_controller: IceController = context.get("ice_controller") as IceController
		if ice_controller != null:
			var step_seconds := maxf(policy.ice_step_seconds, 0.001)
			var steps := mini(policy.maximum_ice_steps_per_advance, int(floor(elapsed_seconds / step_seconds)))
			if steps > 0:
				ice_events = ice_controller.update(steps, ActionRequest.new(&"SUSPENSION", ActionRequest.ActionType.WAIT, null, steps, {"suspended": true}))
				events.append({"type": &"SUSPENDED_ICE_ADVANCED", "steps": steps})
	if policy.replacement_ice_may_spawn:
		var spawn_count := mini(policy.maximum_replacement_ice_per_advance, int(floor(elapsed_seconds / maxf(policy.replacement_ice_interval_seconds, 0.001))))
		var spawn_callback: Callable = context.get("spawn_replacement_ice", Callable())
		if spawn_callback.is_valid():
			for index in spawn_count:
				spawn_callback.call(index)
		else:
			spawn_count = 0
		if spawn_count > 0:
			events.append({"type": &"SUSPENDED_REPLACEMENT_ICE", "count": spawn_count})
	var security_level := int(context.get("security_level", 0))
	if policy.security_may_escalate:
		var escalations := int(floor(elapsed_seconds / maxf(policy.security_escalation_interval_seconds, 0.001)))
		security_level = mini(policy.maximum_security_level, security_level + escalations)
		if escalations > 0:
			events.append({"type": &"SUSPENDED_SECURITY_ESCALATED", "security_level": security_level})
	var temporary_effects: Array[Dictionary] = []
	for source_effect: Dictionary in context.get("temporary_effects", []):
		var effect := source_effect.duplicate(true)
		if policy.temporary_effects_may_expire and bool(effect.get("expires_while_suspended", true)) and not bool(effect.get("permanent", false)):
			effect["remaining_seconds"] = maxf(0.0, float(effect.get("remaining_seconds", 0.0)) - elapsed_seconds)
			if effect.remaining_seconds <= 0.0:
				events.append({"type": &"SUSPENDED_EFFECT_EXPIRED", "effect_id": effect.get("id", &"")})
				continue
		temporary_effects.append(effect)
	if policy.node_local_processes_continue:
		var process_callback: Callable = context.get("advance_node_processes", Callable())
		if process_callback.is_valid():
			process_callback.call(elapsed_seconds, session.resume_state.get("current_node_id", &""))
			events.append({"type": &"SUSPENDED_NODE_PROCESSES_ADVANCED", "seconds": elapsed_seconds})
	session.record_suspended_security_time(elapsed_seconds)
	return {
		"success": true,
		"reason": "Suspended intrusion advanced by policy.",
		"elapsed_seconds": elapsed_seconds,
		"trace": trace,
		"security_level": security_level,
		"temporary_effects": temporary_effects,
		"events": events,
		"ice_events": ice_events,
	}


func _failure(reason: String) -> Dictionary:
	return {"success": false, "reason": reason, "events": [], "ice_events": []}
