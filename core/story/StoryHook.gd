class_name StoryHook
extends RefCounted

var id: StringName
var trigger: StringName
var conditions: Array[ConditionDefinition] = []
var response_timeline: Array[Dictionary] = []
var story_tags: Array[StringName] = []
var effects: Array[Dictionary] = []


func _init(hook_id: StringName = &"", hook_trigger: StringName = &"") -> void:
	id = hook_id
	trigger = hook_trigger


func matches(context: Dictionary) -> bool:
	for condition: ConditionDefinition in conditions:
		if not condition.evaluate(context):
			return false
	return true


func add_response_line(delay_seconds: float, speaker_id: StringName, text: String) -> void:
	response_timeline.append({"time": maxf(0.0, delay_seconds), "speaker_id": speaker_id, "text": text})
	response_timeline.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.time) < float(b.time))

