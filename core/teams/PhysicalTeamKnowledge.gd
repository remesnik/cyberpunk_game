class_name PhysicalTeamKnowledge
extends RefCounted

enum Source { TEAM_RADIO, BODY_CAMERA, FACILITY_CAMERA, BADGE_READER, MOTION_SENSOR, TEAM_TELEMETRY, VERBAL_REPORT }
enum CommsStatus { UNKNOWN, ONLINE, DEGRADED, LOST }

signal knowledge_changed(team_id: StringName)

## Sanitized observations only. No PhysicalTeamInstance references are stored.
var records: Dictionary = {}


func detect_team(team_id: StringName, observed_at: float, source: Source = Source.MOTION_SENSOR) -> void:
	if team_id == &"":
		return
	var record: Dictionary = records.get(team_id, {})
	record.merge({
		"team_id": team_id,
		"last_contact": observed_at,
		"last_source": source,
		"comms_status": CommsStatus.UNKNOWN,
		"confidence_at_contact": 0.25,
	}, false)
	records[team_id] = record
	knowledge_changed.emit(team_id)


func commit_observation(team_id: StringName, observation: Dictionary, source: Source, observed_at: float) -> void:
	if team_id == &"":
		return
	var record: Dictionary = records.get(team_id, {"team_id": team_id})
	var confidence := _source_confidence(source)
	record["last_contact"] = maxf(float(record.get("last_contact", 0.0)), observed_at)
	record["last_source"] = source
	record["confidence_at_contact"] = confidence
	if observation.has("location"):
		record["last_known_location"] = observation.location
		record["location_confirmed_at"] = observed_at
	if observation.has("state"):
		record["team_state"] = observation.state
		record["state_confirmed_at"] = observed_at
	if observation.has("objective"):
		record["objective"] = observation.objective
	if observation.has("comms_status"):
		record["comms_status"] = observation.comms_status
	elif source in [Source.TEAM_RADIO, Source.TEAM_TELEMETRY, Source.BODY_CAMERA]:
		record["comms_status"] = CommsStatus.ONLINE
	records[team_id] = record
	knowledge_changed.emit(team_id)


func report_comms_lost(team_id: StringName, observed_at: float) -> void:
	var record: Dictionary = records.get(team_id, {"team_id": team_id, "confidence_at_contact": 0.0})
	record["last_contact"] = observed_at
	record["comms_status"] = CommsStatus.LOST
	record["last_source"] = Source.TEAM_RADIO
	records[team_id] = record
	knowledge_changed.emit(team_id)


func get_view(team_id: StringName, realtime_now: float) -> Dictionary:
	if not records.has(team_id):
		return {}
	var view := (records[team_id] as Dictionary).duplicate(true)
	var last_contact := float(view.get("last_contact", 0.0))
	var age := maxf(0.0, realtime_now - last_contact)
	var base_confidence := float(view.get("confidence_at_contact", 0.0))
	var decay_rate := 0.004 if int(view.get("last_source", Source.VERBAL_REPORT)) in [Source.BODY_CAMERA, Source.TEAM_TELEMETRY] else 0.012
	if int(view.get("comms_status", CommsStatus.UNKNOWN)) == CommsStatus.LOST:
		decay_rate *= 1.8
	view["contact_age"] = age
	view["confidence"] = clampf(base_confidence - age * decay_rate, 0.0, 1.0)
	view["stale"] = age > _stale_threshold(int(view.get("last_source", Source.VERBAL_REPORT)))
	return view


func get_all_views(realtime_now: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for team_id: StringName in records:
		result.append(get_view(team_id, realtime_now))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.team_id) < String(b.team_id))
	return result


static func source_label(source: Source) -> String:
	return Source.keys()[source].replace("_", " ")


static func comms_label(status: CommsStatus) -> String:
	return CommsStatus.keys()[status]


func _source_confidence(source: Source) -> float:
	match source:
		Source.BODY_CAMERA: return 1.0
		Source.TEAM_TELEMETRY: return 0.95
		Source.FACILITY_CAMERA: return 0.88
		Source.TEAM_RADIO: return 0.82
		Source.BADGE_READER: return 0.7
		Source.MOTION_SENSOR: return 0.55
		Source.VERBAL_REPORT: return 0.5
	return 0.25


func _stale_threshold(source: Source) -> float:
	return 8.0 if source in [Source.BODY_CAMERA, Source.TEAM_TELEMETRY] else 15.0
