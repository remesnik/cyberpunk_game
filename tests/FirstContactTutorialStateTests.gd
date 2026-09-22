extends Node

var failures := 0
var assertions := 0


func _ready() -> void:
	var document := load("res://data/authoring/first_contact_current.tres") as CyberspaceContentDocument
	var state := PersistentGameState.new()
	state.world_state = {}
	var first := AuthoredEntryGuidance.new()
	add_child(first)
	first.configure(document, state, &"SAN")
	_expect(first.debug_jump_to_stage(&"FC_FINAL_CLEANUP"), "debug stage jump accepts an authored stage")
	var saved: Dictionary = state.world_state.get(AuthoredEntryGuidance.PROGRESS_KEY, {})
	_expect(saved.current_beat_id == &"FC_FINAL_CLEANUP" and not saved.completed_beat_ids.has(&"FC_FINAL_CLEANUP"), "stage jump persists prerequisite completion without completing the target")
	first.queue_free()
	await get_tree().process_frame

	var restored := AuthoredEntryGuidance.new()
	add_child(restored)
	restored.configure(document, state, &"SAN")
	_expect(StringName(restored.beats[restored.index].id) == &"FC_FINAL_CLEANUP", "reload restores the exact active tutorial stage")
	Game.game_domain = Game.GameDomain.CYBERSPACE
	EventBus.publish_tutorial_gameplay_event(&"SERVICE_DISABLED", &"ACCESS_LOG")
	EventBus.publish_tutorial_gameplay_event(&"SERVICE_DISABLED", &"ACCESS_LOG")
	restored.advance(0.1)
	var after: Dictionary = state.world_state.get(AuthoredEntryGuidance.PROGRESS_KEY, {})
	_expect((after.completed_beat_ids as Array).count(&"FC_FINAL_CLEANUP") == 1, "repeated completion events complete an authored stage exactly once")
	_expect(StringName(after.current_beat_id) == &"FC_EXIT", "duplicate cleanup events cannot skip the following exit stage")
	restored.queue_free()
	print("%s: %d First Contact tutorial-state assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)


func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
