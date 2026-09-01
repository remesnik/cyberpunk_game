class_name CommsSession
extends RefCounted

signal transcript_line_available(session_id: StringName, line: Dictionary)
signal session_completed(session_id: StringName)

var id: StringName
var channel_id: StringName
var participants: Array[StringName] = []
var start_condition: StringName = &"SESSION_START"
var duration := -1.0
var scripted_audio_timeline: Array[Dictionary] = []
var transcript_timeline: Array[Dictionary] = []
var encryption_level := 0
var intercept_requirement: StringName
var recording_allowed := true
var story_tags: Array[StringName] = []
var realtime_process_id: StringName

var listening := false
var monitoring := false
var recording := false
var marked_important := false
var completed := false
var elapsed_time := 0.0
var listen_started_at := 0.0
var record_started_at := 0.0
var heard_lines: Array[Dictionary] = []
var recorded_lines: Array[Dictionary] = []
var important_lines: Array[Dictionary] = []
var _last_elapsed := -0.000001


func _init(session_id: StringName = &"", linked_channel_id: StringName = &"", process_id: StringName = &"") -> void:
	id = session_id
	channel_id = linked_channel_id
	realtime_process_id = process_id


func add_transcript_line(at_seconds: float, speaker_id: StringName, text: String, event_id: StringName = &"") -> void:
	transcript_timeline.append({"time": maxf(0.0, at_seconds), "speaker_id": speaker_id, "text": text, "event_id": event_id})
	transcript_timeline.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.time) < float(b.time))


func listen() -> void:
	if listening:
		return
	listening = true
	monitoring = true
	listen_started_at = elapsed_time


func stop_listening() -> void:
	listening = false


func monitor() -> void:
	monitoring = true


func stop_monitoring() -> void:
	monitoring = false
	listening = false


func start_recording() -> bool:
	if not recording_allowed:
		return false
	if not recording:
		record_started_at = elapsed_time
	recording = true
	return true


func mark_important() -> bool:
	marked_important = true
	if not heard_lines.is_empty():
		var line: Dictionary = heard_lines.back().duplicate(true)
		if not important_lines.has(line):
			important_lines.append(line)
	return true


func advance_to(process_elapsed_time: float) -> void:
	var next_elapsed := maxf(_last_elapsed, process_elapsed_time)
	for line: Dictionary in transcript_timeline:
		var timestamp := float(line.get("time", 0.0))
		if timestamp <= _last_elapsed or timestamp > next_elapsed:
			continue
		if recording:
			recorded_lines.append(line.duplicate(true))
		if listening:
			var heard := line.duplicate(true)
			heard_lines.append(heard)
			transcript_line_available.emit(id, heard)
	_last_elapsed = next_elapsed
	elapsed_time = next_elapsed
	if duration >= 0.0 and elapsed_time >= duration and not completed:
		completed = true
		listening = false
		recording = false
		session_completed.emit(id)


func transcript_for_monitor() -> Array[Dictionary]:
	if recorded_lines.is_empty():
		return heard_lines.duplicate(true)
	var combined := recorded_lines.duplicate(true)
	for line: Dictionary in heard_lines:
		if not combined.has(line):
			combined.append(line.duplicate(true))
	combined.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.time) < float(b.time))
	return combined
