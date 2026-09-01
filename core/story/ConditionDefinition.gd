class_name ConditionDefinition
extends RefCounted

enum ConditionType { ALWAYS, FLAG_EQUALS, KNOWS_ENDPOINT, HAS_CAPABILITY, HAS_CREDENTIAL, ACTION_EQUALS, TARGET_EQUALS, CHOICE_EQUALS, STORY_EVENT_OCCURRED }

var id: StringName
var condition_type: ConditionType
var key: StringName
var expected: Variant = true
var negate := false
var description: String


func _init(condition_id: StringName = &"", type: ConditionType = ConditionType.ALWAYS, condition_key: StringName = &"", expected_value: Variant = true) -> void:
	id = condition_id
	condition_type = type
	key = condition_key
	expected = expected_value


func evaluate(context: Dictionary) -> bool:
	var matched := false
	match condition_type:
		ConditionType.ALWAYS:
			matched = true
		ConditionType.FLAG_EQUALS:
			matched = context.get("flags", {}).get(key) == expected
		ConditionType.KNOWS_ENDPOINT:
			var knowledge: PlayerKnowledge = context.get("knowledge")
			matched = knowledge != null and knowledge.knows_realtime_endpoint(key)
		ConditionType.HAS_CAPABILITY:
			var position: PlayerNetworkPosition = context.get("position")
			matched = position != null and position.has_capability(key)
		ConditionType.HAS_CREDENTIAL:
			var position: PlayerNetworkPosition = context.get("position")
			matched = position != null and position.has_credential(key)
		ConditionType.ACTION_EQUALS:
			matched = context.get("action_type", -1) == expected
		ConditionType.TARGET_EQUALS:
			matched = context.get("target_id", &"") == key
		ConditionType.CHOICE_EQUALS:
			matched = context.get("choice_id", &"") == key
		ConditionType.STORY_EVENT_OCCURRED:
			var filters: Dictionary = expected if expected is Dictionary else {}
			for story_event: StoryEvent in context.get("story_events", []):
				if story_event.type_name() != key:
					continue
				if filters.has("source_id") and story_event.source_id != StringName(filters.source_id):
					continue
				var payload_filters: Dictionary = filters.get("payload", {})
				var payload_matches := true
				for payload_key: Variant in payload_filters:
					if story_event.payload.get(payload_key) != payload_filters[payload_key]:
						payload_matches = false
						break
				if payload_matches:
					matched = true
					break
	return not matched if negate else matched
