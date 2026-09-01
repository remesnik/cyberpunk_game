class_name OutboundCommsAction
extends RefCounted

enum ActionType { CALL, SEND_MESSAGE, TRANSMIT, JOIN_CHANNEL }
enum TargetType { CONTACT, PHONE_NUMBER, RADIO_CHANNEL, INTERCOM, SECURITY_DESK, AUTOMATED_SYSTEM, CUSTOM }

var actor_id: StringName = &"PLAYER"
var action_type: ActionType
var target_type: TargetType
var target_id: StringName
var choice_id: StringName
var requested_realtime := 0.0
var metadata: Dictionary = {}


func _init(type: ActionType = ActionType.CALL, target_kind: TargetType = TargetType.CUSTOM, destination_id: StringName = &"", selected_choice_id: StringName = &"") -> void:
	action_type = type
	target_type = target_kind
	target_id = destination_id
	choice_id = selected_choice_id


func action_label() -> String:
	return ActionType.keys()[action_type].replace("_", " ")

