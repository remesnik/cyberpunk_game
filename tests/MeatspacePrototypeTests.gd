extends Node
var failures := 0
var assertions := 0

func _ready() -> void:
	var manager := PhysicalTeamManager.new()
	_expect(manager.get_player_views(0).is_empty(), "unconfigured team manager is safe for monitors")
	manager.free()
	Game.create_new_game(GameMode.Value.STORY)
	Game.start_session()
	var monitor := (load("res://ui/PhysicalTeamMonitor.tscn") as PackedScene).instantiate()
	add_child(monitor)
	var screen := (load("res://ui/story_prologue/StoryPrologueScreen.tscn") as PackedScene).instantiate() as StoryPrologueScreen
	add_child(screen)
	await get_tree().process_frame
	await get_tree().physics_frame
	var room := screen.bedroom
	var controller := screen.physical_interactions
	var state := Game.persistent_game_state
	var exterior := room.exterior
	var bus_count := AudioServer.bus_count
	exterior.events.set_process(false)
	_expect(room.size.x * room.size.y / (screen.size.x * screen.size.y) >= 0.7, "room occupies at least 70 percent of gameplay view")
	(room.objects[&"WINDOW"] as MeatspaceTarget3D).activate()
	_expect(not screen.action_panel.visible and exterior.window_open, "3D click toggles directly without verb menu")

	exterior.advance_portal(0.5)
	_expect(exterior.window_open and exterior.lowpass.cutoff_hz > 9000, "opening window updates audio portal")
	_expect(controller.actions_for(&"WINDOW").any(func(a: Dictionary) -> bool: return a.id == "CLOSE") and not controller.execute(&"WINDOW", &"OPEN").success, "window offers close and rejects stale open action")
	var open_volume := exterior.portal_gain
	screen._physical_action(&"WINDOW", &"CLOSE")
	exterior.advance_portal(0.5)
	_expect(not exterior.window_open and exterior.portal_gain < open_volume and exterior.lowpass.cutoff_hz < 1500, "closed window muffles and attenuates exterior")
	for time in ["DAY", "DUSK", "NIGHT", "DAWN"]:
		controller.set_time_of_day(time)
		var profile: Dictionary = room.location_definition.environment.profiles[time]
		_expect(exterior.sequencer.streams.size() == 6 and is_equal_approx(exterior.sequencer.interval_scale, float(profile.event_interval_scale)), "%s selects extra audio layers" % time)
		_expect(exterior.current_time == time and exterior.environment.background_color == Color(profile.sky), "%s selects authored sky" % time)
		_expect(exterior.neon.visible == profile.neon and is_equal_approx(exterior.city_audio.volume_db, float(profile.city_db)), "%s selects neon and ambience mix" % time)
	state.player_state.fatigue = 80
	_expect(controller.execute(&"BED", &"SLEEP").success and state.player_state.fatigue == 20, "sleep reduces persistent fatigue")
	controller.execute(&"BED", &"SLEEP")
	_expect(state.player_state.fatigue == 0, "rest clamps fatigue at zero")
	_expect("25 ICs" in screen.phase_label.text and not screen.time_selector.visible, "25 IC HUD and story-only time")
	_expect(not room.objects[&"JACK_IN_INTERFACE"].visible, "computer starts hidden")
	room.objects[&"STARTER_DECK_BOX"].activate()
	_expect(screen.choice_list.get_child_count() == 2 and screen.choice_list.get_child(0).text.begins_with("More Slots") and screen.choice_list.get_child(1).text.begins_with("More Storage"), "box directly presents exactly two deck options")
	_expect(not "ICs" in screen.choice_list.get_child(0).text and not "ICs" in screen.choice_list.get_child(1).text, "starter deck alternatives have no purchase pricing")
	_expect(Game.prologue_controller.choose(&"DECK_CRATE", &"DECK_SCOUT").success, "deck choice succeeds")
	_expect(state.player_state.credits == 25, "choosing the supplied starter deck preserves ICs")
	_expect(not room.objects[&"STARTER_DECK_BOX"].visible and room.objects[&"JACK_IN_INTERFACE"].visible, "choice removes box and reveals computer")
	_expect(not Game.prologue_controller.choose(&"DECK_CRATE", &"DECK_SCOUT").success, "deck choice cannot repeat")
	room.objects[&"TOOLBOX"].activate()
	_expect(screen.choice_list.get_child_count() == 9 and not screen.choice_list.get_child(0).disabled and "20 ICs" in screen.choice_list.get_child(0).text, "canonical catalog shows affordable running modification")
	for i in range(1, 9): _expect(screen.choice_list.get_child(i).disabled, "unaffordable or unwired choice stays visible")
	_expect(not Game.prologue_controller.choose(&"TOOLBOX", &"DECK_CPU").success and state.player_state.credits == 25, "controller rejects unaffordable upgrade")
	_expect(Game.prologue_controller.choose(&"TOOLBOX", &"RUNNING").success and state.player_state.credits == 5, "running modification costs 20 ICs")
	_expect(not Game.prologue_controller.choose(&"TOOLBOX", &"RUNNING").success, "running modification cannot be purchased twice")
	state.player_state.credits = 100
	state.emit_changed()
	room.objects[&"TOOLBOX"].activate()
	_expect(not screen.choice_list.get_child(1).disabled and screen.choice_list.get_child(0).disabled, "affordability and applied status refresh")
	_expect(Game.prologue_controller.choose(&"TOOLBOX", &"DECK_CPU").success and state.player_state.credits == 0, "100 IC upgrade applies")
	controller.primary(&"WINDOW_TABLE")
	_expect(exterior.window_open, "second window opens audio portal independently")
	controller.primary(&"WINDOW_TABLE")
	_expect(room.display_anchors.all(func(anchor: MeatspaceDisplayAnchor3D) -> bool: return anchor.get_child_count() == 0), "display table starts empty")
	state.world_state.physical_displays = {"BEDROOM": {"DISPLAY_TABLE/LEFT": {"id": "TEST_NOTES", "visual": "BOOK"}}}
	state.emit_changed()
	_expect(room.display_anchors[0].get_child_count() == 1, "generic display anchor restores authored world item")
	exterior.events.enter()
	exterior.events.advance(12)
	room.hide()
	exterior.events.advance(30)
	_expect(not exterior.train.visible and not exterior.train_audio.playing, "leaving before deadline cancels pending train")
	room.show()
	await get_tree().process_frame
	exterior.events.advance(19.99)
	_expect(not exterior.train.visible, "train waits twenty seconds after entry")
	exterior.events.advance(0.01)
	_expect(exterior.train.visible and exterior.train_audio.playing, "train and sound start together at twenty seconds")
	exterior.events.advance(float(room.location_definition.environment.events[0].duration) / 2.0)
	_expect(exterior.train.position.x > -1, "train moves through exterior")
	choice_cleanup(screen)
	if "--capture" in OS.get_cmdline_user_args():
		for time in ["DAY", "DUSK", "NIGHT", "DAWN"]:
			controller.set_time_of_day(time)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://.godot/meatspace-%s.png" % time.to_lower())
	exterior.events.advance(float(room.location_definition.environment.events[0].duration) / 2.0)
	_expect(not exterior.train.visible and not exterior.train_audio.playing and exterior.city_audio.playing, "train ends without interrupting ambience")
	room.hide()
	_expect(not exterior.events.active and not exterior.city_audio.playing, "leaving cancels events and ambience")
	room.show()
	_expect(exterior.events.active and exterior.events.elapsed == 0, "reentry restarts schedule")
	exterior.events.advance(20)
	_expect(exterior.train.visible, "train retriggers on reentry")
	room.hide()
	_expect(not exterior.train.visible and not exterior.train_audio.playing, "leaving mid-train cancels synchronized view and audio")
	controller.execute(&"WINDOW", &"OPEN")
	controller.primary(&"WINDOW_TABLE")
	const PATH := "res://.godot/meatspace-prototype-save.json"
	_expect(state.save_to_file(PATH) == OK, "physical state persists to disk")
	var restored := PersistentGameState.load_from_file(PATH).state as PersistentGameState
	DirAccess.remove_absolute(PATH)
	var returned := (load("res://ui/story_prologue/PlayerBedroom.tscn") as PackedScene).instantiate() as PlayerBedroom
	add_child(returned)
	returned.bind_state(restored)
	_expect(returned.exterior.window_open and returned.display_anchors[0].get_child_count() == 1 and not returned.objects[&"STARTER_DECK_BOX"].visible and returned.objects[&"JACK_IN_INTERFACE"].visible, "window and display placements restore on reload")
	_expect(restored.campaign_state.story_flags.WINDOW_TABLE_OPEN and returned.objects[&"WINDOW_TABLE"].get_node("Sash").rotation.x < 0, "second window state restores independently")
	_expect(returned.exterior.events.elapsed == 0, "entry event uses new relative time after reload")
	returned.queue_free()
	screen.queue_free()
	monitor.queue_free()
	Game.end_session()
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	_expect(AudioServer.bus_count == bus_count - 2, "room unload removes owned audio bus")
	var isolated := PersistentGameState.new()
	StoryModeNewGameInitializer.initialize(isolated)
	var authored := (load("res://data/authoring/story_prologue.tres") as MeatspacePrologueDefinition).duplicate(true) as MeatspacePrologueDefinition
	var deck: Dictionary = authored.interactions[0]
	deck.choices[1].cost_ics = 30
	var choices := MeatspacePrologueController.new()
	isolated.campaign_state.prologue.phase = &"CLAN_SELECTION"
	choices.configure(authored, isolated)
	_expect(choices.phase == &"DECK_SELECTION" and isolated.player_state.credits == 25, "legacy opening phase migrates without resetting player state")
	_expect(not choices.choose(&"DECK_CRATE", &"DECK_BALANCED").success and isolated.player_state.credits == 25, "costed deck rejects insufficient ICs")
	isolated.player_state.credits = 40
	_expect(choices.choose(&"DECK_CRATE", &"DECK_BALANCED").success and isolated.player_state.credits == 10 and isolated.player_state.hardware.DECK_STORAGE == 2, "More Storage supports authored cost and storage hardware")
	print("%s: %d Meatspace prototype assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)

func choice_cleanup(screen: StoryPrologueScreen) -> void:
	screen.choice_panel.get_parent().hide()
	screen.bedroom._set_focus(&"")
