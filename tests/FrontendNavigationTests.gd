extends SceneTree

class MockSaveProvider extends FrontendSaveProvider:
	var summary := FrontendSaveSummary.new(&"SAVE_07", "HERMES INTERNAL", "SAFEHOUSE // DECK", "2097-04-03 22:14", true)
	var continued_id := &""
	func get_most_recent_resumable() -> FrontendSaveSummary: return summary
	func get_resumable_saves() -> Array[FrontendSaveSummary]: return [summary]
	func has_load_browser() -> bool: return true
	func continue_save(save_id: StringName) -> Error: continued_id = save_id; return OK
	func create_load_browser() -> Control:
		var browser := Control.new(); browser.name = "MockLoadBrowser"; return browser

var failures := 0
var assertions := 0

func _init() -> void: call_deferred("_run")

func _run() -> void:
	var packed := load("res://ui/frontend/frontend_root.tscn") as PackedScene
	var frontend = packed.instantiate()
	frontend.transition_duration = 0.0
	frontend.automatically_start_gameplay = false
	root.add_child(frontend)
	await process_frame
	_expect(frontend.frontend_audio != null and frontend.frontend_audio.profile is FrontendAudioProfile, "frontend root owns a configurable audio profile rather than screen asset paths")
	_expect(frontend.transition_layer is FrontendTransitionLayer and FrontendRoot.TransitionType.size() == 4, "one reusable transition layer exposes fade, corruption, signal-loss, and acquisition styles")
	_expect(frontend.frontend_audio.get_node("MenuAmbience") is AudioStreamPlayer and frontend.frontend_audio.get_node("CreditsAmbience") is AudioStreamPlayer and frontend.frontend_audio.get_node("UICues") is AudioStreamPlayer and frontend.frontend_audio.get_node("SplashCues") is AudioStreamPlayer, "dedicated placeholder players expose ambience, interface, and boot hooks")
	_expect(frontend.current_screen == frontend.Screen.SPLASH and frontend.splash.visible, "frontend begins at reusable splash screen")
	_expect(frontend.splash.total_duration() >= 3.0 and frontend.splash.total_duration() <= 6.0, "configured boot sequence remains within the three-to-six-second target")
	var frontend_theme: Theme = frontend.theme
	_expect(frontend_theme != null and frontend_theme.get_type_variation_base(&"FrontendHeadingLabel") == &"Label", "shared frontend theme defines heading typography")
	var accessible := FrontendAccessibilityConfig.new()
	accessible.ui_scale = 1.25; accessible.reduced_animation = true; accessible.glitch_effects_enabled = false
	accessible.scanlines_enabled = false; accessible.high_contrast_focus = true; accessible.master_volume = 0.8; accessible.menu_ui_volume = 0.6
	frontend.apply_accessibility(accessible)
	_expect(is_equal_approx(frontend.get_window().content_scale_factor, 1.25) and frontend.transition_duration == 0.0, "shared accessibility settings apply UI scale and reduced screen motion")
	_expect(not frontend.splash._glitch_effects_enabled and not frontend.splash.background._scanlines_enabled and not frontend.main_menu.background._animation_enabled and not frontend.credits.automatic_scroll_enabled, "glitch, scanline, ambient motion, and automatic credits scrolling observe accessibility switches")
	_expect(frontend.main_menu.new_game_button._high_contrast_focus and not frontend.main_menu.new_game_button.effects_enabled, "high-contrast focus remains available when animated feedback is disabled")
	_expect(is_equal_approx(frontend.frontend_audio._menu_ui_gain, 0.6), "frontend audio consumes the shared menu/UI volume setting")
	var defaults := FrontendAccessibilityConfig.new(); frontend.apply_accessibility(defaults)
	var menu_button: Button = frontend.main_menu.get_node("Margin/Layout/MenuFrame/Buttons/NewGame")
	var menu_panel: PanelContainer = frontend.main_menu.get_node("Margin/Layout/MenuFrame")
	_expect(menu_button.get_theme_stylebox(&"normal") != null and menu_panel.get_theme_stylebox(&"panel") != null, "shared frontend theme resolves menu states and panel borders")
	var skip := InputEventKey.new(); skip.pressed = true; skip.keycode = KEY_SPACE
	frontend.splash._unhandled_input(skip)
	_expect(frontend.main_menu.get_node("Margin/Layout/MenuFrame/Buttons/NewGame").disabled, "skip input cannot activate a menu option during handoff")
	await process_frame; await process_frame; await process_frame
	_expect(frontend.current_screen == frontend.Screen.MAIN_MENU and frontend.main_menu.visible and not frontend.splash.visible, "central root navigates splash to main menu")
	var menu = frontend.main_menu
	_expect(menu.get_node("Margin/Layout/MenuFrame/Buttons/Continue").disabled and not menu.get_node("Margin/Layout/MenuFrame/Buttons/LoadGame").disabled, "Continue is disabled without a save while the local save-browser route remains available")
	var save_provider := MockSaveProvider.new(); frontend.set_save_provider(save_provider)
	_expect(not menu.continue_button.disabled and not menu.load_button.disabled and "HERMES INTERNAL" in menu.get_node("Margin/Layout/MenuFrame/Buttons/SaveStatus").text, "a valid provider enables Continue and shows only its presentation-safe recent-save summary")
	menu.continue_game_requested.emit()
	_expect(save_provider.continued_id == &"SAVE_07", "Continue delegates the exact recent save ID to the save provider")
	menu.load_game_requested.emit()
	await process_frame; await process_frame; await process_frame
	_expect(frontend.current_screen == frontend.Screen.LOAD and frontend.load_screen.session_list.get_child_count() == 1, "Load routes to the central save browser populated by the provider")
	frontend.load_screen.back_requested.emit(); await process_frame; await process_frame; await process_frame
	_expect(frontend.current_screen == frontend.Screen.MAIN_MENU, "save-browser Back returns through the authoritative frontend root")
	frontend.set_save_provider(FrontendSaveProvider.new())
	_expect(menu.continue_button.disabled and not menu.load_button.disabled, "the null provider disables Continue while retaining the empty save browser")
	menu.apply_availability(true, true, true)
	_expect(not menu.get_node("Margin/Layout/MenuFrame/Buttons/Continue").disabled and not menu.get_node("Margin/Layout/MenuFrame/Buttons/LoadGame").disabled, "valid save availability enables continue and load")
	var new_button: Button = menu.get_node("Margin/Layout/MenuFrame/Buttons/NewGame")
	menu.new_game_requested.disconnect(frontend.show_game_mode_selection)
	var requested_cues: Array[StringName] = []
	menu.audio_cue_requested.connect(func(cue: StringName): requested_cues.append(cue))
	_expect(not new_button.focus_neighbor_top.is_empty() and not new_button.focus_neighbor_bottom.is_empty(), "keyboard and controller controls use explicit focus neighbors")
	var transmission_count := [0]
	new_button.transmitted.connect(func(): transmission_count[0] += 1)
	var hitbox_before := new_button.size
	new_button.grab_focus(); new_button.pressed.emit()
	await create_timer(0.09).timeout
	_expect(&"SELECT" in requested_cues, "menu activation requests a semantic selection cue")
	_expect(transmission_count[0] == 1 and new_button.size == hitbox_before, "brief activation feedback transmits once without changing the hitbox")
	menu.apply_interaction_feedback(false, 0.0)
	_expect(not new_button.effects_enabled and new_button.motion_scale == 0.0, "menu feedback supports a reduced-motion disabled mode")
	new_button.pressed.emit()
	_expect(transmission_count[0] == 2, "menu actions remain immediate and usable with all interaction animation disabled")
	menu.new_game_requested.connect(frontend.show_game_mode_selection)
	menu.idle_delay_seconds = 20.0
	menu._process(20.1)
	_expect(menu.is_idle_ambient_active() and menu.ambient_message.visible and menu.background.is_ambient_active(), "idle timeout enables lightweight messages and background activity")
	var activity := InputEventMouseMotion.new(); activity.relative = Vector2(1, 0)
	menu._input(activity)
	_expect(not menu.is_idle_ambient_active() and not menu.ambient_message.visible and not menu.background.is_ambient_active(), "any mouse input immediately restores the normal menu state")
	menu.idle_ambient_enabled = false; menu._process(40.0)
	_expect(not menu.is_idle_ambient_active(), "idle ambient behavior can be disabled without affecting the menu")
	menu.size = Vector2(700, 900); menu._update_responsive_layout()
	_expect(menu.layout.vertical, "main menu switches to compact vertical composition at narrow widths")
	menu.size = Vector2(1280, 720); menu._update_responsive_layout()
	_expect(not menu.layout.vertical, "main menu uses wide composition when space permits")
	var cancel := InputEventAction.new(); cancel.action = &"ui_cancel"; cancel.pressed = true
	menu._unhandled_input(cancel)
	_expect(menu.quit_confirmation.visible, "Escape or controller Back opens desktop quit confirmation")
	menu._unhandled_input(cancel)
	_expect(not menu.quit_confirmation.visible, "Back dismisses the open quit confirmation predictably")
	frontend.refresh_save_state()
	frontend.transition_duration = 0.1
	frontend.transition_to(frontend.Screen.CREDITS, frontend.TransitionType.DIGITAL_CORRUPTION)
	frontend.transition_to(frontend.Screen.MAIN_MENU, frontend.TransitionType.FADE)
	_expect(frontend._transitioning and frontend.transition_layer.mouse_filter == Control.MOUSE_FILTER_STOP, "transition layer captures input and rejects duplicate navigation while active")
	await create_timer(0.15).timeout; await process_frame; await process_frame
	frontend.transition_duration = 0.0
	_expect(frontend.current_screen == frontend.Screen.CREDITS and frontend.credits.visible, "central root navigates main menu to credits")
	_expect(frontend.frontend_audio.current_context == FrontendAudioController.Context.CREDITS, "credits navigation updates the persistent frontend ambience context")
	var credits_data: Resource = frontend.credits.credits_data
	_expect(credits_data is CreditsData and credits_data.sections.size() == 8, "credits load from a dedicated CreditsData resource")
	_expect(credits_data.sections.all(func(section): return section is CreditSection and section.entries.all(func(entry): return entry is CreditEntry)), "credit sections and entries are structured nested resources")
	_expect(credits_data.sections.any(func(section): return section.heading == "THIRD-PARTY SOFTWARE") and credits_data.sections.any(func(section): return section.heading == "LICENSES"), "third-party attribution and licenses remain independently editable sections")
	_expect(frontend.credits.records.get_child_count() > credits_data.sections.size(), "credits UI is populated dynamically from section data")
	_expect(frontend.credits.archive_decoration.maximum_opacity <= 0.1 and frontend.credits.archive_decoration.mouse_filter == Control.MOUSE_FILTER_IGNORE, "archive decoration remains faint and cannot intercept attribution input")
	_expect(frontend.credits.archive_decoration.entry_total == 9 and frontend.credits.entry_total == 9, "decorative entry counter derives from actual credit data")
	var credit_screen = frontend.credits
	_expect(credit_screen.credits_data.sections.size() == 8 and credit_screen.records.get_child_count() > 8, "credits sections and records are generated from data")
	credit_screen.automatic_scroll_delay = 0.0; credit_screen.automatic_scroll_speed = 80.0; credit_screen._process(1.0)
	_expect(credit_screen.scroll.scroll_vertical > 0, "optional automatic credits scrolling advances slowly through the record")
	_expect(credit_screen.archive_decoration.entry_index > 1, "archive activity follows credits scroll progress")
	credit_screen._manual_scroll(-10000.0)
	_expect(credit_screen.scroll.scroll_vertical == 0, "manual scrolling remains available while automatic scrolling is enabled")
	credit_screen.scroll.scroll_vertical = int(credit_screen.scroll.get_v_scroll_bar().max_value)
	credit_screen._process(0.0)
	_expect(credit_screen.is_end_event_started() and credit_screen._end_event_container.get_child_count() == 1, "configured end event begins only after reaching the credits bottom")
	credit_screen._process(3.1)
	_expect(credit_screen.is_end_event_complete() and credit_screen._end_event_container.get_child_count() == 4, "timed end event reveals configured lines and a clear return prompt")
	credit_screen.focus_default()
	_expect(credit_screen.get_node("Center/Frame/Content/Back").has_focus(), "Back remains reachable when credits are at the bottom")
	frontend.show_main_menu(); await process_frame; await process_frame; await process_frame
	_expect(frontend.current_screen == frontend.Screen.MAIN_MENU and not frontend.credits.visible, "credits returns through central root")
	frontend.show_settings(); await process_frame; await process_frame; await process_frame
	_expect(frontend.current_screen == frontend.Screen.SETTINGS and frontend.settings_screen.visible, "Settings routes to its frontend screen")
	frontend.settings_screen.back_requested.emit(); await process_frame; await process_frame; await process_frame
	_expect(frontend.current_screen == frontend.Screen.MAIN_MENU, "settings Back returns to main menu")
	var requests := [false]
	frontend.new_game_requested.connect(func(): requests[0] = true)
	frontend.main_menu.new_game_requested.emit()
	await process_frame; await process_frame; await process_frame
	_expect(frontend.current_screen == frontend.Screen.GAME_MODE_SELECTION and not requests[0], "NEW GAME routes to mode selection without starting gameplay")
	frontend.game_mode_selection.story_option.grab_focus()
	_expect(not requests[0], "focusing a game mode does not activate it")
	frontend.game_mode_selection.story_option.mode_activated.emit(&"STORY_MODE")
	_expect(frontend.game_mode_selection.confirmation.visible and not requests[0], "mode selection opens an inline confirmation summary")
	frontend.game_mode_selection.start_button.transmitted.emit()
	_expect(requests[0], "explicit game-mode activation exposes the compatible new-game signal")
	print("%s: %d frontend navigation assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	frontend.queue_free(); quit(failures)

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition: failures += 1; printerr("FAILED: %s" % description)
