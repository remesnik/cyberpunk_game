class_name StoryBindingEvaluator
extends RefCounted
## Shared authored-condition evaluator for Meatspace visibility, variants, and anchors.

static func matches(rule: Variant, state: PersistentGameState) -> bool:
	if rule == null or (rule is Dictionary and rule.is_empty()): return true
	if state == null or not rule is Dictionary: return false
	var data := rule as Dictionary
	if data.has("all"): return (data.all as Array).all(func(item: Variant) -> bool: return matches(item, state))
	if data.has("any"): return (data.any as Array).any(func(item: Variant) -> bool: return matches(item, state))
	var id := StringName(data.get("id", data.get("flag", &""))); var scope := StringName(data.get("scope", &"flag")); var actual: Variant
	match scope:
		&"flag": actual = StoryState.new(state).get_flag(id)
		&"value": actual = StoryState.new(state).get_value(id, null)
		&"story_state": actual = StoryState.new(state).get_state(id)
		&"contact_unlocked": actual = StoryState.new(state).is_contact_unlocked(id)
		&"contact_reputation": actual = StoryState.new(state).get_reputation(id)
		&"mission": actual = StoryState.new(state).get_mission_status(id)
		&"world": actual = state.world_state.get(id)
		&"player": actual = state.player_state.get(id)
		_: return false
	var expected: Variant = data.get("value", data.get("equals", true)); var operator := StringName(data.get("operator", &"equals"))
	match operator:
		&"flag_true": return bool(actual)
		&"flag_false": return not bool(actual)
		&"equals": return actual == expected
		&"not_equals": return actual != expected
		&"greater_than": return actual != null and actual > expected
		&"less_than": return actual != null and actual < expected
		&"greater_or_equal": return actual != null and actual >= expected
		&"less_or_equal": return actual != null and actual <= expected
	return false

static func visible(data: Dictionary, state: PersistentGameState) -> bool:
	var shown := true
	if data.has("visible_if"): shown = matches(data.visible_if, state)
	elif data.has("visibility"): shown = matches(data.visibility, state)
	if data.has("hidden_if") and matches(data.hidden_if, state): shown = false
	return shown

static func variant(data: Dictionary, state: PersistentGameState, fallback: StringName = &"") -> StringName:
	for mapping: Dictionary in data.get("state_variant_if", []):
		if matches(mapping.get("condition", {}), state): return StringName(mapping.get("variant", fallback))
	return fallback
