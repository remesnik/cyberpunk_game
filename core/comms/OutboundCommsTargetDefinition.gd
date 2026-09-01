class_name OutboundCommsTargetDefinition
extends RefCounted

var id: StringName
var target_type: OutboundCommsAction.TargetType
var display_name: String
var endpoint_id: StringName
var channel_type: CommsChannelDefinition.ChannelType = CommsChannelDefinition.ChannelType.PHONE_CALL
var participant_id: StringName
var conditions: Array[ConditionDefinition] = []
var choices: Array[Dictionary] = []
var tags: Array[StringName] = []


func _init(target_id: StringName = &"", type: OutboundCommsAction.TargetType = OutboundCommsAction.TargetType.CUSTOM, name: String = "", required_endpoint_id: StringName = &"") -> void:
	id = target_id
	target_type = type
	display_name = name
	endpoint_id = required_endpoint_id


func is_available(context: Dictionary) -> bool:
	for condition: ConditionDefinition in conditions:
		if not condition.evaluate(context):
			return false
	return true


func add_choice(choice_id: StringName, text: String) -> void:
	choices.append({"id": choice_id, "text": text})

