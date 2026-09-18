extends SceneTree

const Validator := preload("res://addons/cyberspace_authoring/validators/AuthoringValidator.gd")
var failures := 0
var assertions := 0

func _init() -> void:
	var state := PersistentGameState.new(); StoryModeNewGameInitializer.initialize(state); var story := StoryState.new(state)
	var target := MeatspaceTarget3D.new(); target.configure({"id": &"COMPUTER", "visible_if": {"scope": "flag", "id": "DECK_SELECTED", "value": true}, "visual_state": {"open": {"scope": "flag", "id": "TOOLBOX_OPEN", "value": true}}}, Vector3.ONE)
	var lid := Node3D.new(); target.add_child(lid); target.bind_visual(lid, &"visible", &"open", false, true)
	target.apply_state(state); _expect(not target.visible, "object visibility responds to authored story flag")
	story.set_flag(&"DECK_SELECTED", true); story.set_flag(&"TOOLBOX_OPEN", true); target.apply_state(state); _expect(target.visible and lid.visible, "visual state responds to authored flag")
	var restored := PersistentGameState.from_save_data(state.to_save_data()); target.apply_state(restored); _expect(target.visible and lid.visible, "object state persists across room re-entry/save restoration")
	var events := StoryEventSystem.new(); events.configure(restored); events.add_event(StoryEventDefinition.from_dict({"event_id": "time", "trigger": "test", "actions": [{"type": "set_story_time", "value": "DAWN"}]})); events.publish(&"test")
	_expect(restored.world_state.time_of_day == &"DAWN", "story time action changes Meatspace presentation state")

	var document := CyberspaceContentDocument.new(); document.story_variables = [{"id": &"KNOWN_FLAG"}]; document.room_bindings = [{"id": &"BROKEN", "scene_node_path": "", "visible_if": {"scope": &"flag", "id": &"MISSING_FLAG"}}]; document.authored_story_events = [{"id": &"BAD_EVENT", "event_id": &"DUP", "trigger": &"x", "actions": [{"type": &"unlock_contact", "id": &"MISSING_CONTACT"}]}, {"id": &"BAD_EVENT_2", "event_id": &"DUP", "trigger": &"x", "actions": []}]
	var issues := Validator.new().validate(document); _expect(issues.any(func(issue: Dictionary) -> bool: return issue.category == "ROOM BINDINGS") and issues.any(func(issue: Dictionary) -> bool: return "Duplicate event" in issue.message) and issues.any(func(issue: Dictionary) -> bool: return "missing contact" in String(issue.message).to_lower()), "authoring validation catches broken and unreachable references")

	var mission_events := StoryEventSystem.new(); mission_events.configure(restored); var missions := StoryMissionSystem.new(); missions.configure(restored, mission_events)
	_expect(missions.load_file("res://data/story_missions.json").is_empty() and missions.definitions.has(&"PROJECT_GLASSHOUSE"), "authored mission loads correctly")
	var comms := RealtimeCommsService.new(); var contacts := StoryContactSystem.new(); contacts.configure(restored, missions, comms)
	_expect(contacts.load_file("res://data/story_contacts.json").is_empty() and contacts.definitions.has(&"latch"), "authored contact loads correctly")
	var fired := StoryEventSystem.new(); fired.configure(restored); fired.register_action_handler(&"start_comms", contacts.start_comms_action); _expect(fired.load_file("res://data/story_events.json").is_empty(), "authored event catalog loads")
	fired.publish(&"clean_room_entered"); _expect(StoryState.new(restored).get_flag(&"latch_contacted"), "authored event fires correctly")
	var bedroom: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/meatspace/bedroom.json")); var box: Dictionary = bedroom.objects.STARTER_DECK_BOX; var computer: Dictionary = bedroom.objects.JACK_IN_INTERFACE
	_expect(not StoryBindingEvaluator.visible(box, restored) and StoryBindingEvaluator.visible(computer, restored), "bedroom box disappears and computer appears after deck selection")
	var legacy := PersistentGameState.from_save_data({"schema_version": 1}); _expect(legacy.world_state.get("time_of_day", "NIGHT") == "NIGHT" and legacy.campaign_state.has("room_object_states"), "old save/default state loads safely")
	target.free(); print("%s: %d Story Meatspace authoring assertions" % ["PASS" if failures == 0 else "FAIL", assertions]); quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition: failures += 1; printerr("FAILED: %s" % description)
