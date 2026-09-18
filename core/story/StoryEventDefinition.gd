class_name StoryEventDefinition
extends Resource
## Serializable authored rule: trigger + conditions -> ordered actions.

@export var event_id: StringName
@export var trigger: StringName
@export var conditions: Dictionary = {"all": []}
@export var actions: Array[Dictionary] = []
@export_enum("once", "always", "limited") var repeat_policy := "once"
@export var repeat_limit := 1
@export var priority := 0

static func from_dict(data: Dictionary) -> StoryEventDefinition:
	var definition := StoryEventDefinition.new()
	definition.event_id = StringName(data.get("event_id", data.get("id", &"")))
	definition.trigger = StringName(data.get("trigger", &""))
	definition.conditions = (data.get("conditions", {"all": []}) as Dictionary).duplicate(true)
	definition.actions.assign((data.get("actions", []) as Array).map(func(value: Variant) -> Dictionary: return (value as Dictionary).duplicate(true)))
	definition.repeat_policy = String(data.get("repeat", data.get("repeat_policy", "once"))).to_lower()
	definition.repeat_limit = maxi(1, int(data.get("repeat_limit", 1)))
	definition.priority = int(data.get("priority", 0))
	return definition

func validate() -> Array[String]:
	var errors: Array[String] = []
	if event_id.is_empty(): errors.append("Story event has no event_id.")
	if trigger.is_empty(): errors.append("Story event '%s' has no trigger." % event_id)
	if actions.is_empty(): errors.append("Story event '%s' has no actions." % event_id)
	if repeat_policy not in ["once", "always", "limited"]: errors.append("Story event '%s' has invalid repeat policy '%s'." % [event_id, repeat_policy])
	for action: Dictionary in actions:
		if StringName(action.get("type", &"")).is_empty(): errors.append("Story event '%s' contains an action without a type." % event_id)
	return errors
