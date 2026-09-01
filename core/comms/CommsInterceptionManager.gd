class_name CommsInterceptionManager
extends Node

signal monitor_changed
signal transcript_received(session_id: StringName, line: Dictionary)
signal intercept_started(session_id: StringName)
signal recording_started(session_id: StringName)
signal comms_event_heard(session_id: StringName, event_id: StringName, line: Dictionary)

var channels: Dictionary = {}
var participants: Dictionary = {}
var sessions: Dictionary = {}
var active_session_id: StringName
var _process_manager: RealtimeProcessManager
var _knowledge: PlayerKnowledge
var _position: PlayerNetworkPosition
var loaded_programs: Array[StringName] = []
var evidence_archive: EvidenceArchive


func bind_evidence_archive(archive: EvidenceArchive) -> void:
	evidence_archive = archive


func configure(process_manager: RealtimeProcessManager, knowledge: PlayerKnowledge, position: PlayerNetworkPosition = null) -> void:
	_process_manager = process_manager
	_knowledge = knowledge
	_position = position
	if not _process_manager.processes_updated.is_connected(_on_realtime_updated):
		_process_manager.processes_updated.connect(_on_realtime_updated)
	if not _knowledge.knowledge_changed.is_connected(_on_knowledge_changed):
		_knowledge.knowledge_changed.connect(_on_knowledge_changed)


func add_participant(participant: CommsParticipantDefinition) -> bool:
	if participant == null or participant.id == &"" or participants.has(participant.id):
		return false
	participants[participant.id] = participant
	return true


func add_channel(channel: CommsChannelDefinition) -> bool:
	if channel == null or channel.id == &"" or channels.has(channel.id):
		return false
	channels[channel.id] = channel
	return true


func add_session(session: CommsSession) -> bool:
	if session == null or session.id == &"" or sessions.has(session.id) or not channels.has(session.channel_id):
		return false
	sessions[session.id] = session
	session.transcript_line_available.connect(_on_transcript_line)
	return true


func get_available_sessions() -> Array[CommsSession]:
	var result: Array[CommsSession] = []
	for value: Variant in sessions.values():
		var session := value as CommsSession
		if _knowledge != null and _knowledge.knows_realtime_process(session.realtime_process_id):
			result.append(session)
	result.sort_custom(func(a: CommsSession, b: CommsSession) -> bool: return String(a.id) < String(b.id))
	return result


func evaluate_access(session_id: StringName, operation: CommsAccessResult.Operation) -> CommsAccessResult:
	var result := CommsAccessResult.new(operation)
	var session := sessions.get(session_id) as CommsSession
	if session == null or _knowledge == null or not _knowledge.knows_realtime_process(session.realtime_process_id):
		result.reason = "Channel has not been discovered."
		return result
	var channel := channels.get(session.channel_id) as CommsChannelDefinition
	if channel == null:
		result.reason = "Channel definition is unavailable."
		return result
	var endpoint_record: Dictionary = _knowledge.realtime_endpoint_records.get(channel.source_endpoint_id, {})
	if endpoint_record.is_empty():
		result.reason = "Endpoint has not been discovered."
		return result
	if operation == CommsAccessResult.Operation.DISCOVER:
		result.available = true
		return result
	var policy := channel.get_access_policy(operation)
	result.authority_required = int(policy.get("authority", 0))
	result.capability_required = policy.get("capability", &"")
	result.program_required = policy.get("program", &"")
	result.trace_cost = int(policy.get("trace_cost", 0))
	result.detection_possible = bool(policy.get("detection_enabled", false))
	result.detection_risk = float(policy.get("detection_risk", 0.0)) if result.detection_possible else 0.0
	if operation == CommsAccessResult.Operation.INTERCEPT and result.capability_required == &"":
		result.capability_required = session.intercept_requirement if session.intercept_requirement != &"" else channel.intercept_requirement
	if operation == CommsAccessResult.Operation.RECORD and not session.recording_allowed:
		result.reason = "Recording prohibited by channel configuration."
		return result
	if _position == null:
		result.reason = "Player access state is unavailable."
		return result
	if _position.authority_level < result.authority_required:
		result.missing_requirements.append(StringName("AUTHORITY_%d" % result.authority_required))
	if result.capability_required != &"" and not _position.has_capability(result.capability_required) and not _position.has_credential(result.capability_required):
		result.missing_requirements.append(result.capability_required)
	if result.program_required != &"" and not loaded_programs.has(result.program_required):
		result.missing_requirements.append(result.program_required)
	result.available = result.missing_requirements.is_empty()
	return result


func can_intercept(session_id: StringName) -> bool:
	return evaluate_access(session_id, CommsAccessResult.Operation.INTERCEPT).available


func monitor(session_id: StringName) -> CommsAccessResult:
	var result := evaluate_access(session_id, CommsAccessResult.Operation.MONITOR)
	if result.available:
		(sessions[session_id] as CommsSession).monitor()
		monitor_changed.emit()
	return result


func listen(session_id: StringName) -> bool:
	if not evaluate_access(session_id, CommsAccessResult.Operation.INTERCEPT).available:
		return false
	if active_session_id != &"" and sessions.has(active_session_id):
		(sessions[active_session_id] as CommsSession).stop_listening()
	active_session_id = session_id
	(sessions[session_id] as CommsSession).listen()
	intercept_started.emit(session_id)
	monitor_changed.emit()
	return true


func stop_listening() -> void:
	if active_session_id != &"" and sessions.has(active_session_id):
		(sessions[active_session_id] as CommsSession).stop_monitoring()
	monitor_changed.emit()


func record(session_id: StringName) -> bool:
	if not evaluate_access(session_id, CommsAccessResult.Operation.RECORD).available:
		return false
	var session := sessions[session_id] as CommsSession
	var success := session.start_recording()
	if success and evidence_archive != null:
		var channel := channels[session.channel_id] as CommsChannelDefinition
		var source_type := EvidenceRecord.SourceType.RADIO if channel.channel_type in [CommsChannelDefinition.ChannelType.SECURITY_RADIO, CommsChannelDefinition.ChannelType.PRIVATE_RADIO, CommsChannelDefinition.ChannelType.TACTICAL_COMMS] else EvidenceRecord.SourceType.COMMS
		evidence_archive.begin_recording(source_type, session.id, {"channel_id": session.channel_id, "participants": session.participants.duplicate(), "encryption_level": session.encryption_level}, session.story_tags, func() -> Array[Dictionary]: return session.recorded_lines)
	if success:
		recording_started.emit(session_id)
	monitor_changed.emit()
	return success


func mark_important(session_id: StringName) -> bool:
	if not evaluate_access(session_id, CommsAccessResult.Operation.MONITOR).available:
		return false
	var success := (sessions[session_id] as CommsSession).mark_important()
	monitor_changed.emit()
	return success


func inject(session_id: StringName) -> CommsAccessResult:
	# Injection behavior is intentionally reserved. This result is the complete
	# access explanation the future implementation will consume.
	return evaluate_access(session_id, CommsAccessResult.Operation.INJECT)


func _on_realtime_updated(_session_time: float) -> void:
	for value: Variant in sessions.values():
		var session := value as CommsSession
		var process := _process_manager.get_process(session.realtime_process_id)
		if process != null:
			session.advance_to(process.elapsed_time)
			if session.completed and evidence_archive != null:
				var channel := channels[session.channel_id] as CommsChannelDefinition
				var source_type := EvidenceRecord.SourceType.RADIO if channel.channel_type in [CommsChannelDefinition.ChannelType.SECURITY_RADIO, CommsChannelDefinition.ChannelType.PRIVATE_RADIO, CommsChannelDefinition.ChannelType.TACTICAL_COMMS] else EvidenceRecord.SourceType.COMMS
				evidence_archive.stop_source(source_type, session.id)
	monitor_changed.emit()


func _on_transcript_line(session_id: StringName, line: Dictionary) -> void:
	transcript_received.emit(session_id, line.duplicate(true))
	var event_id: StringName = line.get("event_id", &"")
	if event_id != &"":
		comms_event_heard.emit(session_id, event_id, line.duplicate(true))
	monitor_changed.emit()


func _on_knowledge_changed() -> void:
	monitor_changed.emit()
