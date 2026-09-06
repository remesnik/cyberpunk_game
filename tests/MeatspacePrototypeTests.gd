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
	_expect(screen.action_panel.object_id == &"WINDOW" and screen.action_panel.verbs.get_child_count() == 2, "3D target presents only authored contextual verbs")
	screen._physical_action(&"WINDOW", &"OPEN")
	_expect(exterior.window_open and exterior.lowpass.cutoff_hz > 10000, "opening window updates audio portal")
	_expect(controller.actions_for(&"WINDOW").any(func(a: Dictionary) -> bool: return a.id == "CLOSE") and not controller.execute(&"WINDOW", &"OPEN").success, "window offers close and rejects stale open action")
	var open_volume := exterior.city_audio.volume_db
	screen._physical_action(&"WINDOW", &"CLOSE")
	_expect(not exterior.window_open and exterior.city_audio.volume_db < open_volume and exterior.lowpass.cutoff_hz < 1000, "closed window muffles and attenuates exterior")
	for time in ["DAY", "DUSK", "NIGHT", "DAWN"]:
		controller.set_time_of_day(time)
		var profile: Dictionary = room.location_definition.environment.profiles[time]
		_expect(exterior.current_time == time and exterior.environment.background_color == Color(profile.sky), "%s selects authored sky" % time)
		_expect(exterior.neon.visible == profile.neon and is_equal_approx(exterior.city_audio.volume_db, float(profile.city_db) - 9), "%s selects neon and ambience mix" % time)
	state.player_state.fatigue = 80
	_expect(controller.execute(&"BED", &"SLEEP").success and state.player_state.fatigue == 20, "sleep reduces persistent fatigue")
	controller.execute(&"BED", &"SLEEP")
	_expect(state.player_state.fatigue == 0, "rest clamps fatigue at zero")
	controller.execute(&"STARTER_DECK_BOX", &"TAKE")
	_expect(state.player_state.inventory.size() == 2 and not controller.execute(&"STARTER_DECK_BOX", &"TAKE").success, "authored contents are taken once")
	_expect(not room.objects[&"STARTER_DECK_BOX"].get_node("Contents").visible, "taking contents empties the physical box")
	_expect(room.display_anchors.all(func(anchor: MeatspaceDisplayAnchor3D) -> bool: return anchor.get_child_count() == 0), "display table starts empty")
	state.world_state.physical_displays = {"BEDROOM": {"DISPLAY_TABLE/LEFT": {"id": "TEST_NOTES", "visual": "BOOK"}}}
	state.emit_changed()
	_expect(room.display_anchors[0].get_child_count() == 1, "generic display anchor restores authored world item")
	exterior.events.enter()
	exterior.events.advance(19.99)
	_expect(not exterior.train.visible, "train waits twenty seconds after entry")
	exterior.events.advance(0.01)
	_expect(exterior.train.visible and exterior.train_audio.playing, "train and sound start together at twenty seconds")
	exterior.events.advance(3.5)
	_expect(exterior.train.position.x > -1, "train moves through exterior")
	if "--capture" in OS.get_cmdline_user_args():
		for time in ["DAY", "DUSK", "NIGHT", "DAWN"]:
			controller.set_time_of_day(time)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://.godot/meatspace-%s.png" % time.to_lower())
	exterior.events.advance(3.5)
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
	const PATH := "res://.godot/meatspace-prototype-save.json"
	_expect(state.save_to_file(PATH) == OK, "physical state persists to disk")
	var restored := PersistentGameState.load_from_file(PATH).state as PersistentGameState
	DirAccess.remove_absolute(PATH)
	var returned := (load("res://ui/story_prologue/PlayerBedroom.tscn") as PackedScene).instantiate() as PlayerBedroom
	add_child(returned)
	returned.bind_state(restored)
	_expect(returned.exterior.window_open and returned.display_anchors[0].get_child_count() == 1, "window and display placements restore on reload")
	_expect(returned.exterior.events.elapsed == 0, "entry event uses new relative time after reload")
	returned.queue_free()
	screen.queue_free()
	monitor.queue_free()
	Game.end_session()
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	_expect(AudioServer.bus_count == bus_count - 1, "room unload removes owned audio bus")
	print("%s: %d Meatspace prototype assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
