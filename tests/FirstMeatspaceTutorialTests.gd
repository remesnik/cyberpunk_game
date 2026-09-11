extends Node

const Tutorial = preload("res://core/story/FirstMeatspaceTutorial.gd")
var failures := 0
var assertions := 0

func _ready() -> void:
	var state := PersistentGameState.new()
	StoryModeNewGameInitializer.initialize(state)
	var controller := MeatspacePrologueController.new()
	controller.configure(load("res://data/authoring/story_prologue.tres"), state)
	var room := (load("res://ui/story_prologue/PlayerBedroom.tscn") as PackedScene).instantiate() as PlayerBedroom
	add_child(room)
	room.bind_state(state)
	_expect(Tutorial.get_step(state) == Tutorial.Step.LOOK_AROUND and room.onboarding_prompt.visible, "new game starts at Look Around with one visible hint")
	room._advance_tutorial(Tutorial.Step.INSPECT_OBJECT)
	_expect(Tutorial.get_step(state) == Tutorial.Step.INSPECT_OBJECT and room.onboarding_emphasis.get_meta("target_id") == &"STARTER_DECK_BOX", "first focus advances to Inspect Object and emphasizes the box")
	room._on_prop_selected(&"BED")
	_expect(Tutorial.get_step(state) == Tutorial.Step.INSPECT_OBJECT, "unrelated interaction does not skip the required box step")
	room._on_prop_selected(&"STARTER_DECK_BOX")
	_expect(Tutorial.get_step(state) == Tutorial.Step.OPEN_BOX, "box interaction records Open Box")
	state.campaign_state.story_flags[&"BOX_OPEN"] = true
	_expect(Tutorial.reconcile(state) == Tutorial.Step.CHOOSE_DECK, "opened box recovers to Choose Deck")
	_expect(controller.choose(&"DECK_CRATE", &"DECK_SCOUT").success and Tutorial.get_step(state) == Tutorial.Step.USE_TOOLBOX, "More Slots advances to Use Toolbox")
	_expect(state.player_state.active_slot_count == 3, "More Slots preserves its three-slot gameplay effect")
	_expect(room.onboarding_emphasis.get_meta("target_id") == &"TOOLBOX", "toolbox becomes the only emphasized target")
	var credits: int = int(state.player_state.credits)
	_expect(controller.choose(&"TOOLBOX", &"ASSEMBLE_DECK").success and state.player_state.credits == credits, "required assembly costs zero ICs")
	_expect(Tutorial.get_step(state) == Tutorial.Step.USE_COMPUTER and room.onboarding_emphasis.get_meta("target_id") == &"JACK_IN_INTERFACE", "assembly advances to Use Computer and emphasizes it")
	Tutorial.advance_to(state, Tutorial.Step.ENTER_CLEAN_ROOM)
	_expect(not room.onboarding_prompt.visible and not room.onboarding_emphasis.visible, "bedroom hint and emphasis end in the Clean-Room step")
	var saved := state.to_save_data()
	var restored := PersistentGameState.from_save_data(saved)
	_expect(Tutorial.get_step(restored) == Tutorial.Step.ENTER_CLEAN_ROOM, "exact tutorial step survives serialization")
	Tutorial.advance_to(restored, Tutorial.Step.COMPLETE)
	Tutorial.advance_to(restored, Tutorial.Step.INSPECT_OBJECT)
	_expect(Tutorial.get_step(restored) == Tutorial.Step.COMPLETE, "completion is persistent and cannot regress")
	var completed_room := (load("res://ui/story_prologue/PlayerBedroom.tscn") as PackedScene).instantiate() as PlayerBedroom
	add_child(completed_room); completed_room.bind_state(restored)
	_expect(not completed_room.onboarding_prompt.visible and not completed_room.onboarding_emphasis.visible, "returning to the bedroom never restarts completed guidance")

	var storage := PersistentGameState.new()
	StoryModeNewGameInitializer.initialize(storage)
	var storage_controller := MeatspacePrologueController.new()
	storage_controller.configure(load("res://data/authoring/story_prologue.tres"), storage)
	_expect(storage_controller.choose(&"DECK_CRATE", &"DECK_BALANCED").success and storage.player_state.active_slot_count == 2 and storage.player_state.hardware.DECK_STORAGE == 2, "More Storage preserves two slots and its storage effect")

	var inconsistent := PersistentGameState.new()
	StoryModeNewGameInitializer.initialize(inconsistent)
	inconsistent.world_state.tutorial_state = {Tutorial.STATE_KEY: Tutorial.Step.OPEN_BOX}
	inconsistent.campaign_state.story_flags[&"DECK_SELECTED"] = true
	_expect(Tutorial.reconcile(inconsistent) == Tutorial.Step.USE_TOOLBOX, "out-of-sync saves recover forward from authoritative deck state")
	inconsistent.campaign_state.story_flags[&"DECK_ASSEMBLED"] = true
	_expect(Tutorial.reconcile(inconsistent) == Tutorial.Step.USE_COMPUTER, "assembled saves recover forward to computer use")
	room.queue_free(); completed_room.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	print("%s: %d first Meatspace tutorial assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
