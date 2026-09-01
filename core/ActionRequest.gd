class_name ActionRequest
extends RefCounted

enum ActionType { MOVE, SCAN, PING, EXPLOIT, TRANSFER, WAIT, USE_PROGRAM, DISRUPT, HIDE, SPOOF, ATTACK_PROCESS, BREAK_LOCK, REDIRECT, TRACE_SCRAMBLE, RETREAT }

var actor: StringName
var action_type: ActionType
var target: Variant
var cost: int
var metadata: Dictionary

func _init(p_actor: StringName, p_action_type: ActionType, p_target: Variant = null, p_cost := 1, p_metadata: Dictionary = {}) -> void:
	actor = p_actor
	action_type = p_action_type
	target = p_target
	cost = p_cost
	metadata = p_metadata.duplicate(true)

func get_action_name() -> String:
	return ActionType.keys()[action_type]
