extends Node

const SCREEN := preload("res://ui/story_prologue/StoryPrologueScreen.tscn")
const CompactLocation := preload("res://ui/meatspace/locations/CompactMeatspaceLocation.gd")
var failures := 0
var assertions := 0

func _ready() -> void:
	Game.create_new_game(GameMode.Value.STORY)
	Game.start_session()
	var state := Game.persistent_game_state
	state.player_state.inventory.append({"item_id": &"TRAVEL_TEST_ITEM", "quantity": 1})
	var credits_before := int(state.player_state.credits)
	var tutorial_before: Dictionary = state.world_state.tutorial_state.duplicate(true)
	var screen := SCREEN.instantiate() as StoryPrologueScreen
	add_child(screen)
	await get_tree().process_frame

	var door := screen.bedroom.objects[&"DOOR"] as MeatspaceTarget3D
	door.activate()
	var labels := screen.travel_buttons.map(func(button: Button) -> String: return button.text)
	_expect(screen.travel_selector_open and labels == ["CHINATOWN", "LITTLE TANZANIA", "CBD", "HACKER CLUB"], "bedroom door opens all four data-driven destinations without HOME")
	_expect(not screen.bedroom.location_definition.has("destinations"), "bedroom door contains no hard-coded destination list")
	for id: StringName in [&"CHINATOWN", &"LITTLE_TANZANIA", &"CBD", &"HACKER_CLUB"]:
		_expect(load(String(screen.physical_interactions.get_location_definition(id).scene_path)) is PackedScene, "%s has a packaged authored scene" % id)
	screen._on_semantic_action(&"back_action")
	_expect(screen.physical_interactions.current_meatspace_location() == &"HOME" and not screen.travel_selector_open, "controller Back cancellation leaves location unchanged")

	door.activate()
	var initial_focus := get_viewport().gui_get_focus_owner()
	Input.action_press(&"focus_down"); screen._process(0.016); Input.action_release(&"focus_down")
	_expect(get_viewport().gui_get_focus_owner() != initial_focus, "controller stick navigation moves destination focus")
	await _input_action(&"ui_accept")
	_expect(screen.loaded_location_id == &"LITTLE_TANZANIA", "controller A/Cross activates the focused destination")
	(screen.current_location_view.objects[&"TRAVEL_EXIT"] as MeatspaceTarget3D).activate()
	(screen.travel_buttons[0] as Button).pressed.emit()
	await get_tree().process_frame

	door.activate()
	(screen.travel_buttons[0] as Button).pressed.emit()
	await get_tree().process_frame
	_expect(screen.loaded_location_id == &"CHINATOWN" and is_instance_of(screen.current_location_view, CompactLocation), "mouse destination activation loads the compact Chinatown scene")
	_expect(state.world_state.current_meatspace_location == &"CHINATOWN" and state.world_state.current_meatspace_location_id == &"CHINATOWN", "travel updates explicit persistent location state")
	_expect(int(state.player_state.credits) == credits_before and state.player_state.inventory.any(func(item: Dictionary) -> bool: return item.get("item_id") == &"TRAVEL_TEST_ITEM") and state.world_state.tutorial_state == tutorial_before, "travel preserves credits, inventory, and tutorial state")
	var restored := PersistentGameState.from_save_data(state.to_save_data())
	var restored_travel := MeatspaceInteractionController.new(); restored_travel.configure(screen.bedroom.location_definition, restored)
	_expect(restored_travel.current_meatspace_location() == &"CHINATOWN" and int(restored.player_state.credits) == credits_before, "save/load restores physical location without resetting global state")

	var exit := screen.current_location_view.objects[&"TRAVEL_EXIT"] as MeatspaceTarget3D
	exit.activate()
	_expect(screen.travel_buttons.size() == 1 and screen.travel_buttons[0].text == "HOME", "destination exit offers Return Home")
	(screen.travel_buttons[0] as Button).pressed.emit()
	await get_tree().process_frame
	_expect(screen.loaded_location_id == &"HOME" and screen.current_location_view == screen.bedroom and screen.bedroom.visible, "Return Home restores the persistent bedroom scene")
	_expect(state.world_state.current_meatspace_location == &"HOME", "Return Home persists HOME as the physical location")

	screen.queue_free(); Game.end_session(); await get_tree().process_frame
	print("%s: %d Meatspace travel assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)

func _input_action(action: StringName) -> void:
	var event := InputEventAction.new(); event.action = action; event.pressed = true
	Input.parse_input_event(event); await get_tree().process_frame
	event = InputEventAction.new(); event.action = action; event.pressed = false
	Input.parse_input_event(event); await get_tree().process_frame
