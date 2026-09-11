extends Node
const FirstMeatspaceTutorial = preload("res://core/story/FirstMeatspaceTutorial.gd")
var failures := 0
var assertions := 0

func _ready() -> void:
	Game.create_new_game(GameMode.Value.STORY)
	var main := (load("res://Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().physics_frame
	var screen := main.get_node("StoryPrologueScreen") as StoryPrologueScreen
	var network := main.get_node("NetworkDisplay")
	var clean_room := main.get_node("CleanRoom")
	var room := screen.bedroom
	var controller := Game.prologue_controller
	_expect(Game.game_domain == Game.GameDomain.MEATSPACE and screen.visible, "fresh save opens the existing bedroom")
	_expect("25 ICs" in screen.phase_label.text and not room.objects[&"JACK_IN_INTERFACE"].visible, "25 ICs and no computer initially")
	_expect(not controller.connect_first_contact().success, "missing deck prevents connection")
	room.objects[&"POSTER_VIRUS"].activate()
	_expect(screen.choice_panel.visible and not Game.persistent_game_state.campaign_state.story_flags.CLAN_SELECTED, "poster opens confirmation without choosing")
	await _capture("class-confirmation")
	screen.get_node("ChoiceOverlay/ChoicePanel/DismissChoices").pressed.emit()
	_expect(not Game.persistent_game_state.campaign_state.story_flags.CLAN_SELECTED, "cancel leaves class unselected")
	room.objects[&"POSTER_VIRUS"].activate()
	screen.choice_list.get_child(0).pressed.emit()
	await get_tree().process_frame
	_expect(Game.persistent_game_state.player_state.player_class == "VIRUS" and room.objects[&"POSTER_VIRUS"].get_node("SelectedClass").visible, "class persists and selected poster is marked")
	_expect(not controller.choose(&"CLASS_WAREZ", &"CHOOSE").success, "class choice is locked")
	room.objects[&"STARTER_DECK_BOX"].activate()
	_expect(screen.choice_list.get_child_count() == 2 and screen.choice_list.get_child(0).text.begins_with("More Slots") and screen.choice_list.get_child(1).text.begins_with("More Storage"), "only two supplied starter decks")
	await _capture("deck-choice")
	screen.choice_list.get_child(0).pressed.emit()
	await get_tree().process_frame
	_expect(not room.objects[&"STARTER_DECK_BOX"].visible and room.objects[&"JACK_IN_INTERFACE"].visible, "deck selection reveals usable computer")
	room.objects[&"TOOLBOX"].activate()
	_expect(screen.choice_list.get_child_count() == 10 and not screen.choice_list.get_child(0).disabled and "ASSEMBLE DECK" in screen.choice_list.get_child(0).text, "canonical toolbox leads with required free assembly")
	for i in range(1, 10): _expect(screen.choice_list.get_child(i).disabled, "upgrade remains unavailable before assembly")
	await _capture("toolbox")
	screen.choice_list.get_child(0).pressed.emit()
	await get_tree().process_frame
	_expect(Game.persistent_game_state.player_state.credits == 25 and Game.persistent_game_state.campaign_state.story_flags.DECK_ASSEMBLED, "assembly completes the deck without charging ICs")
	await _capture("bedroom-ready")
	room.objects[&"JACK_IN_INTERFACE"].activate()
	await get_tree().process_frame
	_expect(Game.active_content_document != null and Game.active_content_document.document_id == &"FIRST_CONTACT", "computer starts existing FIRST_CONTACT resource")
	_expect(Game.game_domain == Game.GameDomain.CLEAN_ROOM and clean_room.visible and not network.visible and not screen.visible, "bedroom connection enters the Clean-Room first")
	_expect(bool(Game.persistent_game_state.campaign_state.story_flags.CLEAN_ROOM_LATCH_CONTACTED), "Latch initiates the authored first Clean-Room contact")
	_expect(FirstMeatspaceTutorial.get_step(Game.persistent_game_state) == FirstMeatspaceTutorial.Step.ENTER_CLEAN_ROOM and clean_room.tutorial_hint.visible and "CONTROLS" in clean_room.tutorial_hint.text and "RETURN HOME" in clean_room.tutorial_hint.text, "first Clean-Room visit presents the concise staging-area cue")
	clean_room.go_button.pressed.emit()
	await get_tree().process_frame
	_expect(Game.game_domain == Game.GameDomain.CYBERSPACE and network.visible and not clean_room.visible, "Clean-Room GO enters the Netspace run")
	_expect(FirstMeatspaceTutorial.get_step(Game.persistent_game_state) == FirstMeatspaceTutorial.Step.COMPLETE, "first successful Netspace transition completes Meatspace onboarding")
	_expect(network.get_node("BottomBar").visible, "live Netspace quickbar is visible after entering Netspace")
	_expect(network.get_node("BottomBar/Margin/Rows/Programs").get_child_count() == Game.program_loadout.capacity, "live quickbar renders deck capacity, including empty slots")
	network._select_target(Game.player_network_position.current_node_id)
	_expect(network.get_node("CommandOverlay/CommandDial").visible and network.get_node("CommandOverlay/CommandDial").get_child_count() > 0, "live command dial renders immediately for a focused target")
	_expect(network._selected_contextual_command == &"SCAN", "live current node supports Scan even with bootstrap knowledge")
	# Exercise the scene reached through the real bedroom/Clean-Room handoff.
	var saved_loadout = Game.program_loadout
	for capacity in [2, 3]:
		Game.program_loadout = ProgramLoadout.new(capacity)
		network._update_program_bar()
		await get_tree().process_frame
		var slots := network.get_node("BottomBar/Margin/Rows/Programs")
		_expect(slots.get_child_count() == capacity, "empty live HUD renders capacity %d" % capacity)
		for button in slots.get_children():
			_expect(button.is_visible_in_tree() and "EMPTY" in button.text and button.size.y > 0, "empty slot is visibly rendered")
		slots.get_child(capacity - 1).pressed.emit()
		_expect(network.selected_active_slot == capacity - 1, "capacity widget selects its actual slot")
	Game.program_loadout = saved_loadout
	network._update_program_bar()
	network._select_target(&"ACCESS_RELAY")
	await get_tree().process_frame
	var before: StringName = network.selected_command_id
	_expect(before == &"SCAN" and network.get_valid_commands().size() > 1, "live adjacent node offers Scan plus traversal")
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	_expect(network.selected_command_id != before, "real D-pad Right event rotates the live selector")
	var chosen: StringName = network.selected_command_id
	_expect(network.command_dial.get_node(String(chosen)).button_pressed, "rotated command has visible selected styling")
	await _capture("netspace-dpad-right")
	network._rebuild_neighborhood()
	_expect(network.selected_command_id == chosen, "HUD refresh preserves the user's command selection")
	await _pad(JOY_BUTTON_DPAD_LEFT)
	_expect(network.selected_command_id == before, "real D-pad Left event rotates back")
	await get_tree().process_frame
	var screen_rect: Rect2 = network.get_viewport_rect()
	for control in [network.get_node("BottomBar"), network.command_dial]:
		_expect(control.is_visible_in_tree() and screen_rect.encloses(control.get_global_rect()), "live HUD lies inside the viewport")
	await _capture("netspace-hud")
	_expect(Game.player_network_position.current_node_id == &"ENTRY" and Game.san_controller.get_san(Game.intrusion_run_id) != null, "real player, graph and SAN exist")
	_expect(Game.meatspace_management.hardware_levels.DECK_SENSORS == 1 and Game.sensor_topology.sensors_rating == 1, "basic deck runtime exposes Sensors 1")
	var sensor_view := Game.sensor_topology.current_view()
	_expect(sensor_view.depths.get(&"ACCESS_RELAY") == 1 and sensor_view.depths.get(&"ROUTER_A") == 2, "First Contact starts with one sensor layer beyond the adjacent relay")
	var sensor_unknown := Game.player_knowledge.get_node_view(&"ROUTER_A")
	_expect(Game.player_knowledge.get_node_level(&"ROUTER_A") == KnowledgeLevel.Value.DETECTED and not sensor_unknown.identity_known and not sensor_unknown.has("display_name"), "First Contact sensor node remains sanitized and unknown")
	_expect(network.node_visuals.has(&"ROUTER_A") and network.node_visuals[&"ROUTER_A"].is_unknown and not network.target_views.has(&"ROUTER_A"), "distant sensor topology renders dim and cannot be targeted")
	_expect("SENSORS 1" in network.resource_label.text, "cyberspace deck UI displays Sensors 1")
	var original_sensor_nodes: int = Game.sensor_topology.current_view().nodes.size()
	Game.meatspace_management.hardware_levels[&"DECK_SENSORS"] = 2
	Game.meatspace_management.hardware_changed.emit(&"DECK_SENSORS", 2)
	_expect(Game.sensor_topology.sensors_rating == 2 and Game.sensor_topology.current_view().nodes.size() == original_sensor_nodes, "Sensors 2 upgrade recalculates immediately with Sensors 1 range")
	Game.meatspace_management.hardware_levels[&"DECK_SENSORS"] = 3
	Game.meatspace_management.hardware_changed.emit(&"DECK_SENSORS", 3)
	_expect(Game.sensor_topology.sensors_rating == 3 and Game.sensor_topology.current_view().maximum_depth == 3, "Sensors 3 upgrade expands the live BFS depth immediately")
	Game.meatspace_management.hardware_levels[&"DECK_SENSORS"] = 1
	Game.meatspace_management.hardware_changed.emit(&"DECK_SENSORS", 1)
	_expect(Game.persistent_game_state.player_state.player_class == "VIRUS" and Game.meatspace_management.equipment_orders.credits == 25, "class and currency survive real handoff")
	_expect(Game.entry_guidance != null and Game.entry_guidance.objective.id == "INSPECT_CURRENT_NODE", "authored First Contact opening objective is active")
	Game.entry_guidance.advance(2.1)
	_expect("INSPECT YOUR CURRENT NODE" in network.objective_label.text, "real tutorial HUD shows authored objective")
	await _capture("first-contact")
	_expect(Game.request_scan({"kind": ScanSystem.CURRENT_NODE, "node_id": &"ENTRY"}).success, "player can perform real cyberspace scan")
	Game.entry_guidance.advance(0.1)
	Game.entry_guidance.advance(0.7)
	_expect(Game.entry_guidance.objective.get("id") == "MOVE_TO_ACCESS_RELAY", "real scan advances authored opening tutorial")
	_expect(not controller.connect_first_contact().success, "connection cannot launch twice")
	Game.end_session()
	main.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	for id in ["VIRUS", "PHREAKERS", "WAREZ"]:
		var state := PersistentGameState.new()
		StoryModeNewGameInitializer.initialize(state)
		var other := MeatspacePrologueController.new()
		other.configure(load("res://data/authoring/story_prologue.tres"), state)
		_expect(other.choose(&"DECK_CRATE", &"DECK_BALANCED").success, "More Storage starter is selectable")
		_expect(not other.connection_status().success and "hesitate" in other.connection_status().reason, "missing class gives contextual feedback")
		_expect(other.choose(StringName("CLASS_" + id), &"CHOOSE").success and state.player_state.player_class == id, "%s is selectable" % id)
		_expect(other.choose(&"TOOLBOX", &"ASSEMBLE_DECK").success and state.campaign_state.story_flags.DECK_ASSEMBLED, "toolbox assembly completes the restored deck setup")
		var restored := PersistentGameState.from_save_data(state.to_save_data())
		other.configure(load("res://data/authoring/story_prologue.tres"), restored)
		_expect(other.connection_status().success and restored.player_state.class_profile.affinities.size() == 1, "class and distinct profile survive restoration")
	print("%s: %d Story prologue integration assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	get_tree().quit(failures)

func _pad(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame

func _capture(id: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/bedroom-fix-%s.png" % id)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
