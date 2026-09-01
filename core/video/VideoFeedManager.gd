class_name VideoFeedManager
extends Node

signal feeds_changed
signal action_resolved(result: VideoFeedActionResult)
signal feed_observed(feed_id: StringName)
signal video_event_seen(feed_id: StringName, event: Dictionary)

var definitions: Dictionary = {}
var sessions: Dictionary = {}
var open_feed_id: StringName
var action_definitions: Dictionary = {}
var total_security_suspicion := 0
var _process_manager: RealtimeProcessManager
var _knowledge: PlayerKnowledge
var _position: PlayerNetworkPosition
var evidence_archive: EvidenceArchive


func bind_evidence_archive(archive: EvidenceArchive) -> void:
	evidence_archive = archive


func configure(process_manager: RealtimeProcessManager, knowledge: PlayerKnowledge, position: PlayerNetworkPosition = null) -> void:
	_process_manager = process_manager
	_knowledge = knowledge
	_position = position
	if action_definitions.is_empty():
		_create_default_actions()
	if not _process_manager.processes_updated.is_connected(_on_realtime_updated):
		_process_manager.processes_updated.connect(_on_realtime_updated)
	if not _knowledge.knowledge_changed.is_connected(_on_knowledge_changed):
		_knowledge.knowledge_changed.connect(_on_knowledge_changed)


func add_feed(definition: VideoFeedDefinition, process_id: StringName) -> bool:
	if definition == null or definition.id == &"" or definitions.has(definition.id) or _process_manager.get_process(process_id) == null:
		return false
	definitions[definition.id] = definition
	sessions[definition.id] = VideoFeedSession.new(definition, process_id)
	(sessions[definition.id] as VideoFeedSession).authored_event_occurred.connect(_on_authored_event_occurred)
	feeds_changed.emit()
	return true


func get_discovered_feeds() -> Array[VideoFeedSession]:
	var result: Array[VideoFeedSession] = []
	for value: Variant in sessions.values():
		var session := value as VideoFeedSession
		if _knowledge.knows_realtime_process(session.realtime_process_id):
			result.append(session)
	result.sort_custom(func(a: VideoFeedSession, b: VideoFeedSession) -> bool: return String(a.definition.id) < String(b.definition.id))
	return result


func open_feed(feed_id: StringName) -> VideoFeedSession:
	var session := sessions.get(feed_id) as VideoFeedSession
	if session == null or not session.definition.player_access or not _knowledge.knows_realtime_process(session.realtime_process_id):
		return null
	open_feed_id = feed_id
	feed_observed.emit(feed_id)
	feeds_changed.emit()
	return session


func close_monitor() -> void:
	open_feed_id = &""
	feeds_changed.emit()


func get_open_session() -> VideoFeedSession:
	return sessions.get(open_feed_id)


func get_action_definition(command: VideoFeedActionDefinition.Command) -> VideoFeedActionDefinition:
	return action_definitions.get(command)


func validate_action(feed_id: StringName, command: VideoFeedActionDefinition.Command) -> VideoFeedActionResult:
	var result := VideoFeedActionResult.new(false, command, feed_id)
	var session := sessions.get(feed_id) as VideoFeedSession
	var action := get_action_definition(command)
	if session == null or action == null or not _knowledge.knows_realtime_process(session.realtime_process_id):
		result.reason = "Video feed is not accessible."
		return result
	if _position != null:
		if _position.authority_level < action.authority_requirement:
			result.reason = "Authority %d required." % action.authority_requirement
			return result
		if action.capability_requirement != &"" and not _position.has_capability(action.capability_requirement):
			result.reason = "%s capability required." % action.capability_requirement
			return result
	if command == VideoFeedActionDefinition.Command.DISABLE and not session.definition.can_disable:
		result.reason = "Feed cannot be disabled."
		return result
	if command == VideoFeedActionDefinition.Command.RECORD and not session.definition.can_record:
		result.reason = "Feed cannot be recorded."
		return result
	if command == VideoFeedActionDefinition.Command.LOOP and not session.definition.can_replay:
		result.reason = "Feed cannot replay captured material."
		return result
	result.success = true
	result.reason = "Command validated."
	result.cyber_cost = action.cyber_cost
	return result


func execute_action(feed_id: StringName, command: VideoFeedActionDefinition.Command) -> VideoFeedActionResult:
	var result := validate_action(feed_id, command)
	if not result.success:
		action_resolved.emit(result)
		return result
	var session := sessions[feed_id] as VideoFeedSession
	var action := get_action_definition(command)
	match command:
		VideoFeedActionDefinition.Command.MONITOR:
			open_feed(feed_id)
		VideoFeedActionDefinition.Command.RECORD:
			result.success = session.begin_recording()
			if result.success and evidence_archive != null:
				evidence_archive.begin_recording(EvidenceRecord.SourceType.VIDEO, feed_id, {"physical_location_id": session.definition.physical_location_id, "camera_type": session.definition.camera_type}, session.definition.story_tags, func() -> Array[Dictionary]: return session.recorded_events)
		VideoFeedActionDefinition.Command.DISABLE:
			result.success = session.apply_signal_state(VideoFeedState.Value.OFFLINE)
		VideoFeedActionDefinition.Command.RESTORE:
			result.success = session.apply_signal_state(VideoFeedState.Value.LIVE)
		VideoFeedActionDefinition.Command.FREEZE:
			result.success = session.apply_signal_state(VideoFeedState.Value.FROZEN)
		VideoFeedActionDefinition.Command.LOOP:
			result.success = session.apply_signal_state(VideoFeedState.Value.LOOPED)
		VideoFeedActionDefinition.Command.SPOOF:
			result.success = session.apply_signal_state(VideoFeedState.Value.SPOOFED, action.payload)
	result.resulting_state = session.feed_state
	result.trace_generated = action.trace_generated
	result.security_suspicion = action.security_suspicion
	result.story_events = action.story_events.duplicate(true)
	total_security_suspicion = maxi(0, total_security_suspicion + result.security_suspicion)
	result.reason = "%s applied." % action.command_label()
	action_resolved.emit(result)
	feeds_changed.emit()
	return result


func _on_realtime_updated(_session_time: float) -> void:
	for value: Variant in sessions.values():
		var session := value as VideoFeedSession
		var process := _process_manager.get_process(session.realtime_process_id)
		if process != null:
			session.advance_to(process.elapsed_time)
	feeds_changed.emit()


func _on_knowledge_changed() -> void:
	feeds_changed.emit()


func _on_authored_event_occurred(feed_id: StringName, event: Dictionary) -> void:
	if open_feed_id == feed_id:
		video_event_seen.emit(feed_id, event.duplicate(true))


func _create_default_actions() -> void:
	_register_action(VideoFeedActionDefinition.Command.MONITOR, 0, 0, 0, [])
	_register_action(VideoFeedActionDefinition.Command.RECORD, 1, 1, 0, [])
	_register_action(VideoFeedActionDefinition.Command.DISABLE, 2, 3, 20, [{"type": &"CAMERA_OFFLINE", "player_visible": true}])
	_register_action(VideoFeedActionDefinition.Command.RESTORE, 1, 1, -5, [{"type": &"CAMERA_RESTORED", "player_visible": true}])
	_register_action(VideoFeedActionDefinition.Command.FREEZE, 2, 2, 15, [{"type": &"CAMERA_FROZEN", "player_visible": true}])
	_register_action(VideoFeedActionDefinition.Command.LOOP, 3, 3, 25, [{"type": &"CAMERA_LOOPED", "player_visible": true}])
	var spoof := _register_action(VideoFeedActionDefinition.Command.SPOOF, 4, 5, 40, [{"type": &"CAMERA_SPOOFED", "player_visible": true}])
	spoof.capability_requirement = CapabilityCatalog.ROOTKIT
	spoof.payload = {"profile_id": &"ALL_CLEAR"}


func _register_action(command: VideoFeedActionDefinition.Command, cyber_cost: int, trace: int, suspicion: int, events: Array[Dictionary]) -> VideoFeedActionDefinition:
	var action := VideoFeedActionDefinition.new(command, cyber_cost)
	action.trace_generated = maxi(0, trace)
	action.security_suspicion = suspicion
	action.story_events = events.duplicate(true)
	action_definitions[command] = action
	return action
