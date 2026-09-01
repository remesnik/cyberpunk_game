class_name RealtimeEventDefinition
extends RefCounted

enum TriggerType { AFTER_SECONDS, RELATIVE_OPERATION_TIME, PROCESS_STATE_CHANGED }
enum ActionType { START_COMMS, CHANGE_ALARM, MOVE_TEAM, START_VIDEO_EVENT, SET_STORY_FLAG, ACTIVATE_HOOK, CHANGE_PHYSICAL_STATE }

var id: StringName
var display_name: String
var trigger_type: TriggerType = TriggerType.AFTER_SECONDS
var delay_seconds := 0.0
var operation_id: StringName
var process_id: StringName
var expected_process_state: RealtimeProcess.State = RealtimeProcess.State.COMPLETED
var actions: Array[Dictionary] = []
var story_tags: Array[StringName] = []
var metadata: Dictionary = {}


func _init(event_id: StringName = &"", name: String = "", trigger: TriggerType = TriggerType.AFTER_SECONDS, delay := 0.0) -> void:
	id = event_id
	display_name = name
	trigger_type = trigger
	delay_seconds = maxf(0.0, delay)


func add_action(action_type: ActionType, payload: Dictionary = {}) -> void:
	actions.append({"type": action_type, "payload": payload.duplicate(true)})


func trigger_label() -> String:
	return TriggerType.keys()[trigger_type].replace("_", " ")

