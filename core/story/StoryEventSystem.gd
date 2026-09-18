class_name StoryEventSystem
extends RefCounted
## Extensible runtime for authored trigger/condition/action rules.

signal event_fired(event_id: StringName, trigger: StringName, context: Dictionary)
signal action_executed(event_id: StringName, index: int, action: Dictionary)
signal event_failed(event_id: StringName, reason: String)

var story_state: StoryState
var definitions: Dictionary = {}
var action_handlers: Dictionary = {}
var trigger_serial := 0

func configure(state: PersistentGameState) -> void: story_state = StoryState.new(state)

func load_file(path: String) -> Array[String]:
	if not FileAccess.file_exists(path): return ["Story event catalog not found: %s" % path]
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Array: return ["Story event catalog must contain an array: %s" % path]
	var errors: Array[String] = []
	for data: Variant in parsed:
		if not data is Dictionary: errors.append("Story event catalog contains a non-object entry."); continue
		var definition := StoryEventDefinition.from_dict(data)
		errors.append_array(add_event(definition))
	return errors

func add_event(definition: StoryEventDefinition) -> Array[String]:
	if definition == null: return ["Cannot register a null story event."]
	var errors := definition.validate()
	if definitions.has(definition.event_id): errors.append("Duplicate story event '%s'." % definition.event_id)
	if errors.is_empty(): definitions[definition.event_id] = definition
	return errors

func register_action_handler(type: StringName, handler: Callable) -> void:
	if handler.is_valid(): action_handlers[type] = handler

func publish(trigger: StringName, context: Dictionary = {}) -> Array[Dictionary]:
	trigger_serial += 1
	var candidates: Array[StoryEventDefinition] = []
	for value: Variant in definitions.values():
		var definition := value as StoryEventDefinition
		if definition.trigger == trigger and _repeat_allowed(definition) and _conditions_match(definition.conditions, context): candidates.append(definition)
	candidates.sort_custom(func(a: StoryEventDefinition, b: StoryEventDefinition) -> bool: return a.priority > b.priority if a.priority != b.priority else String(a.event_id) < String(b.event_id))
	var results: Array[Dictionary] = []
	for definition: StoryEventDefinition in candidates: results.append(_execute(definition, context))
	return results

func _execute(definition: StoryEventDefinition, context: Dictionary) -> Dictionary:
	var outputs: Array = []
	for index in definition.actions.size():
		var action: Dictionary = definition.actions[index].duplicate(true)
		var result := _execute_action(action, context)
		if not bool(result.get("success", false)):
			var reason := String(result.get("reason", "Story action failed."))
			event_failed.emit(definition.event_id, reason)
			return {"success": false, "event_id": definition.event_id, "failed_action_index": index, "reason": reason, "outputs": outputs}
		outputs.append(result)
		action_executed.emit(definition.event_id, index, action)
	story_state.mark_event_completed(definition.event_id, trigger_serial)
	event_fired.emit(definition.event_id, definition.trigger, context.duplicate(true))
	return {"success": true, "event_id": definition.event_id, "outputs": outputs}

func _execute_action(action: Dictionary, context: Dictionary) -> Dictionary:
	var type := StringName(action.get("type", &"")).to_lower()
	var id := StringName(action.get("id", action.get("contact_id", action.get("mission_id", &""))))
	match type:
		&"set_flag": story_state.set_flag(id, bool(action.get("value", true)))
		&"set_value":
			if not story_state.set_value(id, action.get("value")): return _failure("set_value requires a numeric value.")
		&"increment_value":
			if not story_state.increment_value(id, action.get("amount", 1)): return _failure("increment_value requires a numeric amount.")
		&"set_state": story_state.set_state(id, StringName(action.get("value", &"")))
		&"unlock_contact": story_state.unlock_contact(id)
		&"change_reputation": story_state.change_reputation(id, float(action.get("amount", 0.0)))
		&"unlock_mission": story_state.set_mission_status(id, StoryState.MISSION_UNLOCKED)
		&"add_objective": _set_objective(id, &"active", action)
		&"complete_objective": _set_objective(id, &"completed", action)
		&"fail_objective": _set_objective(id, &"failed", action)
		&"change_room_object_state": _set_room_object(id, action.get("value", action.get("state")))
		&"give_ics": _change_ics(int(action.get("amount", 0)))
		&"remove_ics": _change_ics(-int(action.get("amount", 0)))
		&"set_story_time": _set_story_time(StringName(action.get("value", &"NIGHT")))
		&"advance_story_time": _advance_story_time(int(action.get("amount", 1)))
		_:
			if not action_handlers.has(type): return _failure("No story action handler registered for '%s'." % type)
			var external: Variant = action_handlers[type].call(action.duplicate(true), context.duplicate(true))
			if external is Dictionary: return external
			return {"success": external != false}
	return {"success": true}

func _conditions_match(group: Dictionary, context: Dictionary) -> bool:
	if group.has("all"): return (group.all as Array).all(func(item: Variant) -> bool: return _condition_item(item, context))
	if group.has("any"): return (group.any as Array).any(func(item: Variant) -> bool: return _condition_item(item, context))
	return _leaf_matches(group, context)
func _condition_item(item: Variant, context: Dictionary) -> bool: return item is Dictionary and _conditions_match(item, context)
func _leaf_matches(condition: Dictionary, context: Dictionary) -> bool:
	var operator: StringName = StringName(StringName(condition.get("operator", &"equals")).to_lower())
	var actual: Variant = story_state.get_path(StringName(StringName(condition.get("scope", &"flag")).to_lower()), StringName(condition.get("id", &"")), context)
	var expected: Variant = condition.get("value", true)
	match operator:
		&"equals": return actual == expected
		&"not_equals": return actual != expected
		&"greater_than": return actual != null and actual > expected
		&"less_than": return actual != null and actual < expected
		&"greater_or_equal": return actual != null and actual >= expected
		&"less_or_equal": return actual != null and actual <= expected
		&"contains": return actual != null and expected in actual
		&"not_contains": return actual == null or expected not in actual
		&"flag_true": return bool(actual)
		&"flag_false": return not bool(actual)
	return false

func _repeat_allowed(definition: StoryEventDefinition) -> bool:
	match definition.repeat_policy:
		"always": return true
		"limited": return story_state.get_event_count(definition.event_id) < definition.repeat_limit
		_: return not story_state.has_completed_event(definition.event_id)
func _set_objective(id: StringName, status: StringName, action: Dictionary) -> void:
	var objectives: Dictionary = story_state.game_state.campaign_state.get_or_add("objectives", {})
	var record: Dictionary = (objectives.get(id, {}) as Dictionary).duplicate(true); record.merge(action, false); record["status"] = status; objectives[id] = record; story_state.game_state.emit_changed()
func _set_room_object(id: StringName, value: Variant) -> void: story_state.set_room_object_state(id, value)
func _change_ics(amount: int) -> void:
	story_state.game_state.player_state["credits"] = maxi(0, int(story_state.game_state.player_state.get("credits", 0)) + amount); story_state.game_state.emit_changed()
func _set_story_time(value: StringName) -> void:
	if value not in [&"DAWN", &"DAY", &"DUSK", &"NIGHT"]: return
	story_state.game_state.world_state["time_of_day"] = value; story_state.game_state.emit_changed()
func _advance_story_time(amount: int) -> void:
	var times := [&"DAWN", &"DAY", &"DUSK", &"NIGHT"]; var current := StringName(story_state.game_state.world_state.get("time_of_day", &"NIGHT")); _set_story_time(times[posmod(times.find(current) + amount, times.size())])
func _failure(reason: String) -> Dictionary: return {"success": false, "reason": reason}
