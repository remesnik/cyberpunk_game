class_name OutboundCommsManager
extends Node

signal targets_changed
signal action_started(action: OutboundCommsAction, session_id: StringName)
signal action_rejected(action: OutboundCommsAction, reason: String)

var targets: Dictionary = {}
var story_hooks: Dictionary = {}
var flags: Dictionary = {}
var _process_manager: RealtimeProcessManager
var _comms_manager: CommsInterceptionManager
var _knowledge: PlayerKnowledge
var _position: PlayerNetworkPosition
var _clock: RealtimeWorldClock
var _serial := 0


func configure(process_manager: RealtimeProcessManager, comms_manager: CommsInterceptionManager, knowledge: PlayerKnowledge, position: PlayerNetworkPosition, clock: RealtimeWorldClock) -> void:
	_process_manager = process_manager
	_comms_manager = comms_manager
	_knowledge = knowledge
	_position = position
	_clock = clock
	if not _knowledge.knowledge_changed.is_connected(_on_knowledge_changed):
		_knowledge.knowledge_changed.connect(_on_knowledge_changed)


func add_target(target: OutboundCommsTargetDefinition) -> bool:
	if target == null or target.id == &"" or targets.has(target.id):
		return false
	targets[target.id] = target
	targets_changed.emit()
	return true


func add_story_hook(hook: StoryHook) -> bool:
	if hook == null or hook.id == &"" or story_hooks.has(hook.id):
		return false
	story_hooks[hook.id] = hook
	return true


func get_available_targets() -> Array[OutboundCommsTargetDefinition]:
	var result: Array[OutboundCommsTargetDefinition] = []
	var context := _base_context()
	for value: Variant in targets.values():
		var target := value as OutboundCommsTargetDefinition
		if target.is_available(context):
			result.append(target)
	result.sort_custom(func(a: OutboundCommsTargetDefinition, b: OutboundCommsTargetDefinition) -> bool: return String(a.id) < String(b.id))
	return result


func submit(action: OutboundCommsAction) -> Dictionary:
	action.requested_realtime = _clock.elapsed_seconds
	var target := targets.get(action.target_id) as OutboundCommsTargetDefinition
	if target == null or not target.is_available(_base_context()):
		return _reject(action, "Outbound target is unavailable.")
	if target.target_type != action.target_type:
		return _reject(action, "Outbound target type mismatch.")
	if not _choice_exists(target, action.choice_id):
		return _reject(action, "Authored response choice is invalid.")
	var context := _base_context()
	context.merge({"action_type": action.action_type, "target_id": action.target_id, "choice_id": action.choice_id}, true)
	var hook := _find_hook(context)
	if hook == null:
		return _reject(action, "No authored response is available.")
	_serial += 1
	var suffix := "%s_%03d" % [String(target.id), _serial]
	var process_id := StringName("OUTBOUND_PROCESS_%s" % suffix)
	var channel_id := StringName("OUTBOUND_CHANNEL_%s" % suffix)
	var session_id := StringName("OUTBOUND_SESSION_%s" % suffix)
	var duration := _response_duration(hook)
	var process := RealtimeProcess.new(process_id, RealtimeProcess.ProcessType.VOICE_CALL, "Outbound: %s" % target.display_name, target.id, duration)
	process.discovered = true
	process.accessible = true
	_process_manager.add_process(process, true)
	var channel := CommsChannelDefinition.new(channel_id, target.display_name, target.channel_type, target.endpoint_id)
	channel.participant_ids.assign([&"PLAYER", target.participant_id])
	_comms_manager.add_channel(channel)
	var session := CommsSession.new(session_id, channel_id, process_id)
	session.participants.assign(channel.participant_ids)
	session.duration = duration
	session.story_tags.assign(hook.story_tags)
	for line: Dictionary in hook.response_timeline:
		session.add_transcript_line(line.time, line.speaker_id, line.text)
	_comms_manager.add_session(session)
	# The player initiated this fictional channel, so it is known without scanning.
	_knowledge.realtime_process_records[process_id] = {"id": process_id, "display_name": process.display_name, "process_type": process.process_type, "endpoint_id": target.endpoint_id}
	session.listen()
	_comms_manager.active_session_id = session_id
	for effect: Dictionary in hook.effects:
		if effect.get("type", &"") == &"SET_FLAG":
			flags[effect.get("key", &"")] = effect.get("value", true)
	_knowledge.knowledge_changed.emit()
	action_started.emit(action, session_id)
	return {"success": true, "reason": "Outbound interaction started.", "session_id": session_id, "realtime": action.requested_realtime}


func _base_context() -> Dictionary:
	return {"knowledge": _knowledge, "position": _position, "flags": flags}


func _find_hook(context: Dictionary) -> StoryHook:
	for value: Variant in story_hooks.values():
		var hook := value as StoryHook
		if hook.trigger == &"OUTBOUND_COMMS" and hook.matches(context):
			return hook
	return null


func _choice_exists(target: OutboundCommsTargetDefinition, choice_id: StringName) -> bool:
	for choice: Dictionary in target.choices:
		if choice.get("id", &"") == choice_id:
			return true
	return false


func _response_duration(hook: StoryHook) -> float:
	if hook.response_timeline.is_empty():
		return 1.0
	return float(hook.response_timeline.back().get("time", 0.0)) + 3.0


func _reject(action: OutboundCommsAction, reason: String) -> Dictionary:
	action_rejected.emit(action, reason)
	return {"success": false, "reason": reason, "session_id": &"", "realtime": action.requested_realtime}


func _on_knowledge_changed() -> void:
	targets_changed.emit()
