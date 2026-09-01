class_name VideoFeedActionResult
extends RefCounted

var success := false
var command: VideoFeedActionDefinition.Command
var feed_id: StringName
var resulting_state: VideoFeedState.Value = VideoFeedState.Value.LIVE
var reason: String
var cyber_cost := 0
var trace_generated := 0
var security_suspicion := 0
var story_events: Array[Dictionary] = []


func _init(ok := false, action_command: VideoFeedActionDefinition.Command = VideoFeedActionDefinition.Command.MONITOR, target_feed_id: StringName = &"", message := "") -> void:
	success = ok
	command = action_command
	feed_id = target_feed_id
	reason = message


func to_events() -> Array[Dictionary]:
	var events := story_events.duplicate(true)
	events.push_front({
		"type": &"VIDEO_FEED_COMMAND",
		"feed_id": feed_id,
		"command": VideoFeedActionDefinition.Command.keys()[command],
		"state": VideoFeedState.label(resulting_state),
		"suspicion": security_suspicion,
		"player_visible": true,
	})
	return events
