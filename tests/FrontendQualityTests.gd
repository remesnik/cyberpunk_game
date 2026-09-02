extends SceneTree

var failures := 0
var assertions := 0

func _init() -> void: call_deferred("_run")

func _run() -> void:
	var frontend := (load("res://ui/frontend/frontend_root.tscn") as PackedScene).instantiate()
	frontend.transition_duration = 0.0
	frontend.automatically_start_gameplay = false
	root.add_child(frontend)
	await process_frame

	# Automatic boot and skip are separate production paths.
	frontend.splash._process(frontend.splash.total_duration() + 0.1)
	await process_frame; await process_frame; await process_frame
	_expect(frontend.current_screen == frontend.Screen.MAIN_MENU, "automatic splash completion reaches Main Menu")
	_expect(frontend.main_menu.new_game_button.has_focus(), "automatic arrival assigns stable keyboard/controller focus")
	frontend.show_splash(); await process_frame; await process_frame; await process_frame
	var skip := InputEventJoypadButton.new(); skip.button_index = JOY_BUTTON_A; skip.pressed = true
	frontend.splash._unhandled_input(skip)
	await process_frame; await process_frame; await process_frame
	_expect(frontend.current_screen == frontend.Screen.MAIN_MENU, "controller input skips splash")
	_expect(frontend.main_menu.new_game_button.has_focus(), "splash skip does not activate or lose destination focus")

	var resolutions := [Vector2(1920, 1080), Vector2(2560, 1440), Vector2(3440, 1440), Vector2(1280, 720), Vector2(960, 540)]
	for resolution: Vector2 in resolutions:
		frontend.size = resolution
		for screen: Control in [frontend.splash, frontend.main_menu, frontend.load_screen, frontend.settings_screen, frontend.credits]: screen.size = resolution; screen.show()
		frontend.main_menu._update_responsive_layout()
		frontend.credits._update_layout()
		frontend.load_screen._update_layout()
		frontend.settings_screen._update_layout()
		await process_frame; await process_frame
		_expect(_inside(frontend.main_menu.get_node("Margin/Layout/MenuFrame"), resolution), "main menu remains inside %s" % resolution)
		_expect(_inside(frontend.credits.frame, resolution), "credits remain inside %s" % resolution)
		_expect(_inside(frontend.load_screen.panel, resolution), "load browser remains inside %s" % resolution)
		_expect(_inside(frontend.settings_screen.panel, resolution), "settings remain inside %s" % resolution)
		for screen: Control in [frontend.splash, frontend.load_screen, frontend.settings_screen, frontend.credits]: screen.hide()
		frontend.main_menu.show()

	var buttons: Array[Button] = [frontend.main_menu.new_game_button, frontend.main_menu.load_button, frontend.main_menu.settings_button, frontend.main_menu.credits_button, frontend.main_menu.quit_button]
	_expect(buttons.all(func(button): return button.focus_mode == Control.FOCUS_ALL and not button.focus_neighbor_top.is_empty() and not button.focus_neighbor_bottom.is_empty()), "every enabled menu route participates in explicit controller focus navigation")
	_expect(InputMap.has_action("ui_accept") and InputMap.has_action("ui_cancel") and InputMap.has_action("ui_up") and InputMap.has_action("ui_down"), "keyboard/controller standard UI actions are available")

	var reduced := FrontendAccessibilityConfig.new()
	reduced.reduced_animation = true; reduced.glitch_effects_enabled = false; reduced.scanlines_enabled = false; reduced.high_contrast_focus = true
	frontend.apply_accessibility(reduced)
	frontend.show_credits(); await process_frame; await process_frame; await process_frame
	_expect(frontend.current_screen == frontend.Screen.CREDITS and not frontend._transitioning, "reduced-animation navigation completes without a stuck transition")
	_expect(not frontend.credits.automatic_scroll_enabled and frontend.credits.get_node("Center/Frame/Content/Back").effects_enabled == false, "reduced motion disables automatic credits and button animation")
	frontend.credits.back_requested.emit(); await process_frame; await process_frame; await process_frame
	_expect(frontend.current_screen == frontend.Screen.MAIN_MENU and frontend.main_menu.new_game_button.has_focus(), "Back consistently restores visible Main Menu focus")

	print("%s: %d frontend quality assertions" % ["PASS" if failures == 0 else "FAIL", assertions])
	frontend.queue_free(); quit(failures)

func _inside(control: Control, bounds: Vector2) -> bool:
	var rect := control.get_global_rect()
	return rect.position.x >= -1.0 and rect.position.y >= -1.0 and rect.end.x <= bounds.x + 1.0 and rect.end.y <= bounds.y + 1.0

func _expect(condition: bool, description: String) -> void:
	assertions += 1
	if not condition: failures += 1; printerr("FAILED: %s" % description)
