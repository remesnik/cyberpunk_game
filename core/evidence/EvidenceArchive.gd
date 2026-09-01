class_name EvidenceArchive
extends Node

signal evidence_added(record: EvidenceRecord)
signal evidence_updated(record: EvidenceRecord)
signal analysis_completed(record: EvidenceRecord, result: Dictionary)
signal evidence_shared(record: EvidenceRecord, recipient_id: StringName)
signal story_evidence_used(record: EvidenceRecord, story_hook_id: StringName)

var records: Dictionary = {}
var _active_by_source: Dictionary = {}
var _providers: Dictionary = {}
var _clock: RealtimeWorldClock
var _serial: int = 0


func configure(clock: RealtimeWorldClock) -> void:
	_clock = clock
	if not _clock.elapsed_time_changed.is_connected(_on_realtime_changed):
		_clock.elapsed_time_changed.connect(_on_realtime_changed)


func reset() -> void:
	records.clear()
	_active_by_source.clear()
	_providers.clear()
	_serial = 0


func begin_recording(source_type: EvidenceRecord.SourceType, source_id: StringName, metadata: Dictionary = {}, story_tags: Array[StringName] = [], provider: Callable = Callable(), author_notes: String = "") -> EvidenceRecord:
	var key := _source_key(source_type, source_id)
	if _active_by_source.has(key):
		return get_record(_active_by_source[key])
	_serial += 1
	var record := EvidenceRecord.new(StringName("EVIDENCE_%04d" % _serial), source_type, source_id)
	record.recording_start = _clock.elapsed_seconds
	record.metadata = metadata.duplicate(true)
	record.story_tags.assign(story_tags)
	record.author_notes = author_notes
	record.content_reference = {"format": "TIMED_EVENTS", "events": []}
	records[record.id] = record
	_active_by_source[key] = record.id
	if provider.is_valid():
		_providers[record.id] = provider
	_sync_record(record)
	evidence_added.emit(record)
	return record


func stop_recording(record_id: StringName) -> bool:
	var record := get_record(record_id)
	if record == null or not record.is_recording():
		return false
	_sync_record(record)
	record.recording_end = _clock.elapsed_seconds
	_active_by_source.erase(_source_key(record.source_type, record.source_id))
	_providers.erase(record.id)
	evidence_updated.emit(record)
	return true


func stop_source(source_type: EvidenceRecord.SourceType, source_id: StringName) -> bool:
	var record_id: StringName = _active_by_source.get(_source_key(source_type, source_id), &"")
	return record_id != &"" and stop_recording(record_id)


func get_record(record_id: StringName) -> EvidenceRecord:
	return records.get(record_id) as EvidenceRecord


func is_recording_source(source_type: EvidenceRecord.SourceType, source_id: StringName) -> bool:
	return _active_by_source.has(_source_key(source_type, source_id))


func get_records_for_source(source_type: EvidenceRecord.SourceType, source_id: StringName) -> Array[EvidenceRecord]:
	var result: Array[EvidenceRecord] = []
	for value: Variant in records.values():
		var record := value as EvidenceRecord
		if record.source_type == source_type and record.source_id == source_id:
			result.append(record)
	result.sort_custom(func(a: EvidenceRecord, b: EvidenceRecord) -> bool: return a.recording_start < b.recording_start)
	return result


func review(record_id: StringName) -> bool:
	var record := get_record(record_id)
	if record == null:
		return false
	record.reviewed = true
	evidence_updated.emit(record)
	return true


func mark_important(record_id: StringName, value: bool = true) -> bool:
	var record := get_record(record_id)
	if record == null:
		return false
	record.important = value
	evidence_updated.emit(record)
	return true


func analyze(record_id: StringName, rules: Array[Dictionary]) -> Dictionary:
	var record := get_record(record_id)
	if record == null:
		return {"success": false, "reason": "Evidence record not found.", "matches": []}
	_sync_record(record)
	var searchable := JSON.stringify(record.content_reference).to_lower()
	var matches: Array[Dictionary] = []
	for rule: Dictionary in rules:
		var phrase := String(rule.get("phrase", "")).to_lower()
		if not phrase.is_empty() and searchable.contains(phrase):
			matches.append({"phrase": rule.get("phrase", ""), "story_hook_id": rule.get("story_hook_id", &""), "story_tags": rule.get("story_tags", []).duplicate()})
	record.metadata["analysis_matches"] = matches.duplicate(true)
	record.metadata["analyzed"] = true
	var result := {"success": true, "record_id": record.id, "matches": matches}
	analysis_completed.emit(record, result)
	evidence_updated.emit(record)
	return result


func share(record_id: StringName, recipient_id: StringName) -> bool:
	var record := get_record(record_id)
	if record == null:
		return false
	var recipients: Array = record.metadata.get("shared_with", [])
	if not recipients.has(recipient_id):
		recipients.append(recipient_id)
	record.metadata["shared_with"] = recipients
	evidence_shared.emit(record, recipient_id)
	evidence_updated.emit(record)
	return true


func use_as_story_evidence(record_id: StringName, story_hook_id: StringName) -> bool:
	var record := get_record(record_id)
	if record == null:
		return false
	var hooks: Array = record.metadata.get("story_evidence_for", [])
	if not hooks.has(story_hook_id):
		hooks.append(story_hook_id)
	record.metadata["story_evidence_for"] = hooks
	story_evidence_used.emit(record, story_hook_id)
	evidence_updated.emit(record)
	return true


func _on_realtime_changed(_realtime_now: float) -> void:
	for record_id: StringName in _providers.keys():
		_sync_record(get_record(record_id))


func _sync_record(record: EvidenceRecord) -> void:
	if record == null or not _providers.has(record.id):
		return
	var provided: Variant = (_providers[record.id] as Callable).call()
	if provided is Array:
		record.content_reference["events"] = (provided as Array).duplicate(true)


func _source_key(source_type: EvidenceRecord.SourceType, source_id: StringName) -> String:
	return "%d:%s" % [source_type, source_id]
