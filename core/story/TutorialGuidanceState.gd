class_name TutorialGuidanceState
extends RefCounted

## Stateful, authored guidance. This class reports recovery advice but never
## mutates graph, security, intrusion, or objective state itself.
var rules: Array[Dictionary] = []
var event_counts: Dictionary = {}
var hint_indices: Dictionary = {}
var completed_rules: Dictionary = {}


func configure(authored_rules: Array[Dictionary]) -> void:
	rules = authored_rules.duplicate(true)
	event_counts.clear()
	hint_indices.clear()
	completed_rules.clear()


func observe(event: Dictionary) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for rule: Dictionary in rules:
		if _matches(rule, event) and not completed_rules.has(StringName(rule.get("id", &""))): candidates.append(rule)
	if candidates.is_empty(): return {"handled": false}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("priority", 0)) > int(b.get("priority", 0)))
	var rule: Dictionary = candidates[0]
	var rule_id: StringName = rule.get("id", &"")
	event_counts[rule_id] = int(event_counts.get(rule_id, 0)) + 1
	var response := {"handled": true, "rule_id": rule_id, "actor_id": StringName(rule.get("actor_id", &"LATCH")), "severity": StringName(rule.get("severity", &"GUIDANCE")), "recoverable": bool(rule.get("recoverable", true)), "hard_fail": bool(rule.get("hard_fail", false)), "recovery_policy": StringName(rule.get("recovery_policy", &"KEEP_OBJECTIVE_ACTIVE")), "context": event.duplicate(true), "commands": (rule.get("recovery_commands", []) as Array).duplicate(true), "lines": []}
	if int(event_counts[rule_id]) < int(rule.get("respond_after", 1)): return response
	var hints: Array = rule.get("hints", [])
	var index := int(hint_indices.get(rule_id, 0))
	if index < hints.size():
		response.lines = _normalize_lines(hints[index], response.actor_id)
		hint_indices[rule_id] = index + 1
	if bool(rule.get("once", false)) or (bool(rule.get("complete_after_final_hint", true)) and int(hint_indices.get(rule_id, 0)) >= hints.size()): completed_rules[rule_id] = true
	return response


func reset_rule(rule_id: StringName) -> void:
	event_counts.erase(rule_id)
	hint_indices.erase(rule_id)
	completed_rules.erase(rule_id)


func get_hint_index(rule_id: StringName) -> int: return int(hint_indices.get(rule_id, 0))


func _matches(rule: Dictionary, event: Dictionary) -> bool:
	if StringName(rule.get("event_type", &"")) != StringName(event.get("type", &"")): return false
	for key: String in ["objective_id", "node_id", "program_id", "encounter_id"]:
		if rule.has(key) and StringName(rule[key]) != StringName(event.get(key, &"")): return false
	if rule.has("minimum_trace") and int(event.get("trace", 0)) < int(rule.minimum_trace): return false
	if rule.has("maximum_trace") and int(event.get("trace", 0)) > int(rule.maximum_trace): return false
	return true


func _normalize_lines(value: Variant, actor_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var values: Array = value if value is Array else [value]
	for line: Variant in values:
		if line is Dictionary:
			var copy: Dictionary = (line as Dictionary).duplicate(true)
			if not copy.has("speaker_id"): copy.speaker_id = actor_id
			if not copy.has("time"): copy.time = 0.0
			result.append(copy)
		else: result.append({"time": 0.0, "speaker_id": actor_id, "text": String(line)})
	return result
