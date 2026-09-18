class_name RealtimeCommsService
extends RefCounted
## Advances authored calls independently of action ticks. It never pauses by default.

signal call_started(call: Dictionary)
signal subtitle_presented(line: Dictionary)
signal call_completed(call_id: StringName, completion_trigger: StringName)
signal call_interrupted(call_id: StringName)

var definitions: Dictionary = {}
var active_call: Dictionary = {}
var elapsed := 0.0
var next_line := 0
var simulation_blocked := false

func load_definitions(values: Array) -> Array[String]:
	var errors: Array[String] = []
	for value: Variant in values:
		if not value is Dictionary: errors.append("Comms catalog contains a non-object entry."); continue
		var call: Dictionary = (value as Dictionary).duplicate(true); var id := StringName(call.get("call_id", &""))
		if id.is_empty(): errors.append("Comms call has no call_id.")
		elif definitions.has(id): errors.append("Duplicate comms call '%s'." % id)
		else: definitions[id] = call
	return errors

func start_comms(call_id: StringName) -> Dictionary:
	if not definitions.has(call_id): return {"success": false, "reason": "Unknown comms call '%s'." % call_id}
	var incoming: Dictionary = (definitions[call_id] as Dictionary).duplicate(true)
	if not active_call.is_empty():
		if int(incoming.get("priority", 0)) <= int(active_call.get("priority", 0)): return {"success": false, "reason": "A higher-priority call is active."}
		if not bool(active_call.get("interruptible", true)): return {"success": false, "reason": "The active call cannot be interrupted."}
		call_interrupted.emit(StringName(active_call.call_id))
	active_call = incoming; elapsed = 0.0; next_line = 0; simulation_blocked = bool(active_call.get("blocks_simulation", false)); call_started.emit(active_call.duplicate(true)); advance(0.0)
	return {"success": true, "call": active_call.duplicate(true), "blocks_simulation": simulation_blocked}

func advance(delta: float) -> void:
	if active_call.is_empty(): return
	elapsed += maxf(0.0, delta); var lines: Array = active_call.get("lines", [])
	while next_line < lines.size() and float(lines[next_line].get("time", 0.0)) <= elapsed:
		var line: Dictionary = (lines[next_line] as Dictionary).duplicate(true); line["call_id"] = active_call.call_id; subtitle_presented.emit(line); next_line += 1
	var duration := float(active_call.get("duration", 0.0))
	if elapsed >= duration and next_line >= lines.size():
		var id := StringName(active_call.call_id); var trigger := StringName(active_call.get("completion_trigger", &"")); active_call = {}; simulation_blocked = false; call_completed.emit(id, trigger)

func is_active() -> bool: return not active_call.is_empty()
