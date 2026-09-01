class_name VideoFeedActionDefinition
extends RefCounted

enum Command { MONITOR, RECORD, DISABLE, RESTORE, FREEZE, LOOP, SPOOF }

var command: Command
var cyber_cost := 1
var authority_requirement := 0
var capability_requirement: StringName
var trace_generated := 0
var security_suspicion := 0
var story_events: Array[Dictionary] = []
var payload: Dictionary = {}


func _init(action_command: Command = Command.MONITOR, cost := 1) -> void:
	command = action_command
	cyber_cost = maxi(0, cost)


func command_label() -> String:
	return Command.keys()[command]

