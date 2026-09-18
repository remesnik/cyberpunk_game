extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void:
	_test_state_persistence()
	_test_repeat_and_conditions()
	_test_order_and_invalid_actions()
	_test_latch_first_contact()
	print("%s: %d Story event assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _new_state() -> PersistentGameState:
	var state := PersistentGameState.new()
	StoryModeNewGameInitializer.initialize(state)
	return state

func _definition(id: StringName, repeat: String, conditions: Dictionary, actions: Array[Dictionary]) -> StoryEventDefinition:
	return StoryEventDefinition.from_dict({"event_id": id, "trigger": &"test_trigger", "repeat": repeat, "conditions": conditions, "actions": actions})

func _test_state_persistence() -> void:
	var state := _new_state()
	var story := StoryState.new(state)
	story.set_flag(&"test_flag", true)
	story.set_value(&"test_number", 4.5)
	var restored := PersistentGameState.from_save_data(state.to_save_data())
	var loaded_story := StoryState.new(restored)
	_expect(loaded_story.get_flag(&"test_flag"), "flags persist through the existing save format")
	_expect(is_equal_approx(float(loaded_story.get_value(&"test_number")), 4.5), "numeric values persist through the existing save format")

func _test_repeat_and_conditions() -> void:
	var state := _new_state()
	var system := StoryEventSystem.new(); system.configure(state)
	system.add_event(_definition(&"once_event", "once", {"all": [{"scope": "flag", "id": "gate", "operator": "flag_true"}]}, [{"type": "increment_value", "id": "once_count"}]))
	system.publish(&"test_trigger")
	_expect(int(system.story_state.get_value(&"once_count")) == 0, "false conditions prevent an event")
	system.story_state.set_flag(&"gate", true)
	system.publish(&"test_trigger"); system.publish(&"test_trigger")
	_expect(int(system.story_state.get_value(&"once_count")) == 1, "a one-shot event fires only once")
	system.add_event(_definition(&"always_event", "always", {"any": [{"scope": "value", "id": "once_count", "operator": "greater_or_equal", "value": 1}, {"scope": "flag", "id": "missing", "operator": "flag_true"}]}, [{"type": "increment_value", "id": "always_count"}]))
	system.publish(&"test_trigger"); system.publish(&"test_trigger")
	_expect(int(system.story_state.get_value(&"always_count")) == 2, "an always event can fire repeatedly and ANY numeric conditions work")

func _test_order_and_invalid_actions() -> void:
	var system := StoryEventSystem.new(); system.configure(_new_state())
	var order: Array[StringName] = []
	system.register_action_handler(&"record", func(action: Dictionary, _context: Dictionary) -> Dictionary: order.append(StringName(action.id)); return {"success": true})
	system.add_event(_definition(&"ordered", "once", {"all": []}, [{"type": "record", "id": "first"}, {"type": "record", "id": "second"}, {"type": "record", "id": "third"}]))
	var result := system.publish(&"test_trigger")
	_expect(result[0].success and order == [&"first", &"second", &"third"], "multiple authored actions execute in order")
	system.add_event(_definition(&"invalid_reference", "once", {"all": []}, [{"type": "start_dialogue", "id": "missing_dialogue"}]))
	var invalid := system.publish(&"test_trigger")
	var failed: Array = invalid.filter(func(item: Dictionary) -> bool: return item.event_id == &"invalid_reference")
	_expect(failed.size() == 1 and not failed[0].success and not system.story_state.has_completed_event(&"invalid_reference"), "invalid action references fail cleanly without completing the event")

func _test_latch_first_contact() -> void:
	var state := _new_state()
	var system := StoryEventSystem.new(); system.configure(state)
	var contacts: Array[StringName] = []
	system.register_action_handler(&"start_comms", func(action: Dictionary, _context: Dictionary) -> Dictionary: contacts.append(StringName(action.contact_id)); return {"success": true})
	_expect(system.load_file("res://data/story_events.json").is_empty(), "the authored story-event catalog validates")
	system.publish(&"clean_room_entered", {"first_visit": true})
	_expect(contacts == [&"latch"] and system.story_state.get_flag(&"latch_contacted") and system.story_state.is_contact_unlocked(&"latch"), "first Story Clean-Room entry contacts and unlocks Latch")
	system.publish(&"clean_room_entered", {"first_visit": false})
	_expect(contacts.size() == 1, "the Latch event does not repeat on re-entry")
	var restored := PersistentGameState.from_save_data(state.to_save_data())
	var loaded := StoryEventSystem.new(); loaded.configure(restored)
	loaded.register_action_handler(&"start_comms", func(action: Dictionary, _context: Dictionary) -> Dictionary: contacts.append(StringName(action.contact_id)); return {"success": true})
	loaded.load_file("res://data/story_events.json"); loaded.publish(&"clean_room_entered")
	_expect(contacts.size() == 1 and loaded.story_state.has_completed_event(&"latch_first_contact"), "save/load preserves one-shot event completion")

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
