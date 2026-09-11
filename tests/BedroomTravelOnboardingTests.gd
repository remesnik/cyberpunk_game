extends Node
const FirstMeatspaceTutorial = preload("res://core/story/FirstMeatspaceTutorial.gd")

var failures := 0
var assertions := 0

func _ready() -> void:
	Game.create_new_game(GameMode.Value.STORY)
	Game.start_session()
	var screen := (load("res://ui/story_prologue/StoryPrologueScreen.tscn") as PackedScene).instantiate() as StoryPrologueScreen
	add_child(screen)
	await get_tree().process_frame
	await get_tree().physics_frame
	var room := screen.bedroom
	var door := room.objects.get(&"DOOR") as MeatspaceTarget3D
	var chair := room.world.get_node("MustardWingChair") as Node3D
	_expect(door != null and door.position.x * chair.position.x < 0, "door is authored on the wall opposite the yellow chair")
	_expect(room.onboarding_prompt.visible and room.onboarding_emphasis.visible, "first bedroom visit shows guidance and gently emphasizes the deck box")
	GameplayBindings._set_device_mode(GameplayBindings.DeviceMode.GAMEPAD, 0)
	_expect("Right Stick or D-pad" in room.onboarding_prompt.text, "first-visit guidance adapts to controller input")
	GameplayBindings._set_device_mode(GameplayBindings.DeviceMode.MOUSE_KEYBOARD)
	_expect(screen.physical_interactions.get_available_meatspace_destinations().is_empty(), "travel query currently exposes no authored destinations")

	var door_screen := room.camera.unproject_position(door.global_position + Vector3(0, 1.1, 0))
	var hover := InputEventMouseMotion.new(); hover.position = door_screen
	room._gui_input(hover)
	_expect(room.focused_id == &"DOOR" and "Door" in room.hint.text, "hover ray-picking identifies the apartment door")
	_expect(room.onboarding_prompt.visible and "Click to interact" in room.onboarding_prompt.text and int(Game.persistent_game_state.world_state.tutorial_state.first_meatspace_step) == FirstMeatspaceTutorial.Step.INSPECT_OBJECT, "successful object focus advances persistent guidance without ending onboarding")

	var click := InputEventMouseButton.new(); click.position = door_screen; click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true
	room._gui_input(click)
	_expect("nowhere to go" in screen.result_label.text.to_lower(), "clicking the door invokes travel and reports the empty destination set")

	var returned := (load("res://ui/story_prologue/PlayerBedroom.tscn") as PackedScene).instantiate() as PlayerBedroom
	add_child(returned)
	returned.bind_state(Game.persistent_game_state)
	_expect(returned.onboarding_prompt.visible and returned.tutorial_step == FirstMeatspaceTutorial.Step.INSPECT_OBJECT and returned.objects.has(&"DOOR"), "returning mid-onboarding restores the exact step and keeps the door")

	returned.queue_free(); screen.queue_free(); Game.end_session()
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	print("%s: %d bedroom travel/onboarding assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
