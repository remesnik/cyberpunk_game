extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void:
	var state := PersistentGameState.new(); StoryModeNewGameInitializer.initialize(state)
	var events := StoryEventSystem.new(); events.configure(state); events.load_file("res://data/story_events.json")
	var missions := StoryMissionSystem.new(); missions.configure(state, events); missions.load_file("res://data/story_missions.json")
	var realtime := RealtimeCommsService.new()
	var contacts := StoryContactSystem.new(); contacts.configure(state, missions, realtime); _expect(contacts.load_file("res://data/story_contacts.json").is_empty(), "authored contact and comms catalog validates")
	events.register_action_handler(&"start_comms", contacts.start_comms_action)
	var story := StoryState.new(state)
	_expect(not story.is_contact_unlocked(&"latch") and contacts.unlocked_contacts().is_empty(), "Latch starts locked")
	_expect(not contacts.select_contact(&"latch").success, "locked contacts cannot be selected")
	var call_count := [0]; realtime.call_started.connect(func(_call: Dictionary) -> void: call_count[0] += 1)
	events.publish(&"clean_room_entered", {"first_visit": true})
	_expect(story.is_contact_unlocked(&"latch"), "first Clean-Room StoryEvent unlocks Latch")
	_expect(contacts.unlocked_contacts().size() == 1 and contacts.unlocked_contacts()[0].display_name == "Latch", "unlocked Latch appears in the Allies view")
	events.publish(&"clean_room_entered", {"first_visit": false})
	_expect(call_count[0] == 1, "Latch first-contact call fires once")
	_expect(realtime.is_active() and not realtime.simulation_blocked, "real-time contact call does not pause simulation")
	realtime.advance(10.0)
	story.change_reputation(&"latch", 1)
	var actions := contacts.valid_interactions(&"latch")
	_expect(actions.any(func(item: Dictionary) -> bool: return item.interaction_id == &"request_info") and actions.any(func(item: Dictionary) -> bool: return item.interaction_id == &"ask_glasshouse"), "contact actions filter by reputation and mission availability")
	events.publish(&"mission_result", {"mission_id": &"glasshouse_01", "success": true, "alarm_state": false, "unknown_ice_scanned": false})
	_expect(story.get_reputation(&"latch") == 2.0 and realtime.is_active(), "mission result triggers Latch reputation and follow-up call")
	var restored := PersistentGameState.from_save_data(state.to_save_data()); var restored_story := StoryState.new(restored)
	_expect(restored_story.is_contact_unlocked(&"latch") and restored_story.get_reputation(&"latch") == 2.0, "save/load preserves contact unlock and reputation state")
	story.update_contact_state(&"latch", {"relationship_flags": [&"TRUSTED_WITH_GLASSHOUSE"], "available_messages": [&"GLASSHOUSE_NOTE"]})
	var contact := contacts.contact_view(&"latch")
	_expect(contact.available_messages.has(&"GLASSHOUSE_NOTE") and story.get_contact_state(&"latch").relationship_flags.has(&"TRUSTED_WITH_GLASSHOUSE"), "contact messages and relationship flags persist in contact state")

	print("%s: %d Story contact assertions" % ["PASS" if failures == 0 else "FAIL", assertions]); quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition: failures += 1; printerr("FAILED: %s" % description)
