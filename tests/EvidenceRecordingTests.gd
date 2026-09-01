extends SceneTree

const ClockScript := preload("res://core/RealtimeWorldClock.gd")
const ArchiveScript := preload("res://core/evidence/EvidenceArchive.gd")
const RecordScript := preload("res://core/evidence/EvidenceRecord.gd")
const CyberClockScript := preload("res://core/CyberspaceClock.gd")

var failures := 0
var assertions := 0


func _init() -> void:
	_test_record_and_evidence_workflow()
	print("%s: %d evidence recording assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)


func _test_record_and_evidence_workflow() -> void:
	var clock = ClockScript.new()
	var archive = ArchiveScript.new()
	archive.configure(clock)
	clock.restore(5.0, false)
	var captured: Array[Dictionary] = []
	var record = archive.begin_recording(RecordScript.SourceType.COMMS, &"SECURITY_CALL_07", {"channel_id": &"SECURITY"}, [&"SECURITY"], func() -> Array[Dictionary]: return captured)
	_expect(record.recording_start == 5.0 and record.recording_end < 0.0, "recording preserves its realtime start and remains active")

	captured.append({"time": 7.0, "speaker_id": &"DISPATCH", "text": "Team two is checking the east stairwell."})
	clock.restore(9.0, false)
	_expect(record.content_reference.events.size() == 1, "placeholder recording preserves timed stream events")

	var cyber = CyberClockScript.new()
	var request := ActionRequest.new(&"PLAYER", ActionRequest.ActionType.WAIT, null, 100)
	cyber.resolve_action(request, _always_valid, _always_applies)
	_expect(cyber.current_tick == 100 and record.recording_start == 5.0, "cyber ticks do not alter evidence recording time")

	archive.stop_recording(record.id)
	_expect(record.recording_end == 9.0, "stopping capture stores the realtime end")
	var analysis: Dictionary = archive.analyze(record.id, [{"phrase": "east stairwell", "story_hook_id": &"STAIRWELL_HOOK", "story_tags": [&"PATROL"]}])
	_expect(analysis.matches.size() == 1 and analysis.matches[0].story_hook_id == &"STAIRWELL_HOOK", "analysis can reveal an authored phrase-to-StoryHook match")
	_expect(archive.review(record.id) and archive.mark_important(record.id), "evidence can be reviewed and marked important")
	_expect(archive.share(record.id, &"CONTACT_ZERO") and archive.use_as_story_evidence(record.id, &"STAIRWELL_HOOK"), "evidence can be shared and used for story resolution")
	archive.free()
	clock.free()


func _always_valid(_request: ActionRequest) -> Dictionary:
	return {"success": true, "reason": "", "events": []}


func _always_applies(_request: ActionRequest) -> Dictionary:
	return {"success": true, "reason": "Applied.", "events": []}


func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
