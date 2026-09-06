extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://ui/frontend/frontend_root.tscn") as PackedScene
	var frontend: FrontendRoot = packed.instantiate()
	frontend.initial_screen = FrontendRoot.Screen.MAIN_MENU
	frontend.transition_duration = 0.0
	frontend.automatically_start_gameplay = false
	root.add_child(frontend)
	await process_frame
	frontend.main_menu.new_game_requested.emit()
	await process_frame; await process_frame; await process_frame
	var chooser: FrontendGameModeSelection = frontend.game_mode_selection
	_expect(frontend.current_screen == FrontendRoot.Screen.GAME_MODE_SELECTION and chooser.visible and not frontend.main_menu.visible, "NEW GAME routes through the central root to Game Mode Selection")
	_expect(chooser._activation_armed and chooser.selected_mode_id.is_empty(), "destination input is armed only after the entering input has been released")
	_expect(chooser.story_option.custom_minimum_size.x >= 300 and chooser.free_roam_option.custom_minimum_size.x >= 300, "Story and Free Roam use large selectable boxes")
	_expect(chooser.story_option.mode_title == "STORY MODE" and "authored campaign" in chooser.story_option.description and chooser.story_option.metadata == ["GUIDED PROGRESSION", "STORY EVENTS", "AUTHORED MISSIONS"], "Story box communicates authored narrative progression concisely")
	_expect(chooser.free_roam_option.mode_title == "FREE ROAM" and "network sandbox" in chooser.free_roam_option.description and chooser.free_roam_option.metadata == ["OPEN NETWORK", "SANDBOX PROGRESSION", "DYNAMIC JOBS"], "Free Roam box communicates open-ended progression concisely")
	_expect(chooser.story_option.preview_variant() == &"GUIDED_ROUTE" and chooser.free_roam_option.preview_variant() == &"OPEN_NETWORK", "each mode owns a distinct procedural network preview")
	_expect(not chooser.story_option.focus_neighbor_right.is_empty() and not chooser.free_roam_option.focus_neighbor_left.is_empty(), "keyboard/controller focus neighbors connect both options")
	var selected_modes: Array[StringName] = []
	frontend.game_mode_requested.connect(func(mode_id: StringName): selected_modes.append(mode_id))
	chooser.story_option.grab_focus()
	await process_frame
	_expect(chooser.story_option.has_focus() and chooser.story_option.preview_intensity() > 0.2 and selected_modes.is_empty(), "focus visibly selects and clarifies the Story preview without activating it")
	chooser.free_roam_option.grab_focus()
	await process_frame
	_expect(chooser.free_roam_option.has_focus() and selected_modes.is_empty(), "focus can move to Free Roam without activation")
	_expect(chooser.get_node("Margin/Content/SelectionStatus").text.ends_with("FREE ROAM") and chooser.free_roam_option.state_label.text.contains("CONFIRM"), "the focused mode has an explicit active state in addition to its border")
	chooser.free_roam_option.pressed.emit()
	_expect(chooser.confirmation.visible and chooser.confirmation_title.text == "FREE ROAM" and "open-ended" in chooser.confirmation_summary.text and selected_modes.is_empty(), "mode activation opens a concise summary without starting")
	chooser.start_button.transmitted.emit()
	await process_frame; await process_frame; await process_frame
	_expect(selected_modes.is_empty() and frontend.current_screen == FrontendRoot.Screen.TUTORIAL_PROMPT, "Free Roam confirmation opens the optional introduction prompt before startup")
	_expect(frontend.tutorial_prompt.yes_button.has_focus(), "tutorial prompt has visible keyboard/controller focus")
	frontend.tutorial_prompt.decision_made.emit(false)
	_expect(selected_modes == [&"FREE_ROAM"], "declining introduction begins Free Roam directly")

	# Return behavior is tested on a fresh chooser because mode activation is a
	# terminal handoff in production even when scene switching is disabled here.
	selected_modes.clear()
	frontend.show_game_mode_selection(); await process_frame; await process_frame; await process_frame
	chooser.back_requested.emit()
	await process_frame; await process_frame; await process_frame
	_expect(frontend.current_screen == FrontendRoot.Screen.MAIN_MENU and frontend.main_menu.visible, "BACK returns through frontend_root to Main Menu")
	frontend.main_menu.new_game_requested.emit()
	await process_frame; await process_frame; await process_frame
	chooser = frontend.game_mode_selection
	chooser.story_option.pressed.emit()
	_expect(chooser.confirmation.visible and chooser.confirmation_title.text == "STORY MODE" and "campaign" in chooser.confirmation_summary.text and selected_modes.is_empty(), "Story selection opens its campaign summary")
	chooser.start_button.transmitted.emit()
	_expect(selected_modes == [&"STORY_MODE"], "Story Mode also requires and responds to explicit activation")
	chooser.prepare(true); await process_frame; await process_frame; chooser.story_option.mode_activated.emit(&"STORY_MODE")
	_expect(chooser.overwrite_warning.visible, "confirmation warning derives from resumable-save availability")
	chooser.confirmation_back_button.transmitted.emit()
	_expect(not chooser.confirmation.visible and chooser.options.visible, "confirmation Back returns to mode cards")

	var accessible := FrontendAccessibilityConfig.new(); accessible.reduced_animation = true; accessible.glitch_effects_enabled = false; accessible.high_contrast_focus = true
	frontend.apply_accessibility(accessible)
	_expect(chooser.story_option._high_contrast_focus and not chooser.story_option.effects_enabled, "mode boxes preserve high-contrast focus when animation is reduced")
	chooser.size = Vector2(2560, 1080); chooser._update_responsive_layout()
	_expect(not chooser.options.vertical and chooser.story_option.custom_minimum_size.x == 410, "wide and ultrawide layouts retain two bounded horizontal option boxes")
	chooser.size = Vector2(800, 900); chooser._update_responsive_layout()
	_expect(chooser.options.vertical and chooser.story_option.custom_minimum_size.y <= 185, "narrow layouts stack and compact the option boxes without fixed-resolution offsets")
	frontend.queue_free()
	print("%s: %d game-mode selection assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		printerr("FAILED: %s" % description)
