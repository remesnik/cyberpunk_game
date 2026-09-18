class_name FrontendMainMenu
extends Control

signal continue_game_requested
signal new_game_requested
signal load_game_requested
signal settings_requested
signal credits_requested
signal quit_requested
signal audio_cue_requested(cue: StringName)

@export var continue_save_available := false
@export var load_screen_available := false
@export var settings_screen_available := false
@export_range(640, 1400, 10) var compact_layout_threshold := 920
@export_group("Interaction Feedback")
@export var interaction_effects_enabled := true
@export_range(0.0, 1.0, 0.05) var interaction_motion_scale := 1.0
@export_group("Idle Ambient State")
@export var idle_ambient_enabled := true
@export_range(20.0, 40.0, 1.0) var idle_delay_seconds := 30.0
@export_range(2.0, 20.0, 0.5) var ambient_message_interval := 6.0
@export var ambient_messages: Array[String] = ["PASSIVE ROUTE SAMPLING...", "UNCLAIMED SIGNALS: 03", "PACKET WEATHER: QUIET", "LISTENING ON DARK FIBER..."]

@onready var layout: BoxContainer = %Layout
@onready var margin: MarginContainer = %Margin
@onready var quit_confirmation: ConfirmationDialog = %QuitConfirmation
@onready var continue_button: Button = %Continue
@onready var new_game_button: Button = %NewGame
@onready var load_button: Button = %LoadGame
@onready var settings_button: Button = %Settings
@onready var credits_button: Button = %Credits
@onready var quit_button: Button = %Quit
@onready var background: Control = %Background
@onready var ambient_message: Label = %AmbientMessage
var _idle_elapsed := 0.0
var _ambient_elapsed := 0.0
var _ambient_index := 0
var _idle_ambient_active := false

func _ready() -> void:
	_connect_activation(continue_button, continue_game_requested.emit)
	_connect_activation(new_game_button, new_game_requested.emit)
	_connect_activation(load_button, load_game_requested.emit)
	_connect_activation(settings_button, settings_requested.emit)
	_connect_activation(credits_button, credits_requested.emit)
	_connect_activation(quit_button, _request_quit)
	quit_confirmation.confirmed.connect(quit_requested.emit)
	resized.connect(_update_responsive_layout)
	apply_availability(continue_save_available, load_screen_available, settings_screen_available)
	_update_responsive_layout()
	apply_interaction_feedback(interaction_effects_enabled, interaction_motion_scale)
	set_process(true)
	focus_default()

func _process(delta: float) -> void:
	if not visible or not idle_ambient_enabled: return
	if not _idle_ambient_active:
		_idle_elapsed += delta
		if _idle_elapsed >= idle_delay_seconds: _set_idle_ambient(true)
	else:
		_ambient_elapsed += delta
		if _ambient_elapsed >= ambient_message_interval:
			_ambient_elapsed = 0.0; _ambient_index = (_ambient_index + 1) % maxi(ambient_messages.size(), 1); _show_ambient_message()

func _input(event: InputEvent) -> void:
	if visible and _is_user_input(event): _reset_idle_state()

func is_idle_ambient_active() -> bool: return _idle_ambient_active

func _is_user_input(event: InputEvent) -> bool:
	return event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventJoypadButton or event is InputEventJoypadMotion

func _set_idle_ambient(active: bool) -> void:
	_idle_ambient_active = active; _ambient_elapsed = 0.0
	if background.has_method("set_ambient_active"): background.set_ambient_active(active)
	ambient_message.visible = active and not ambient_messages.is_empty()
	if active: _show_ambient_message()

func _show_ambient_message() -> void:
	if ambient_messages.is_empty(): ambient_message.hide(); return
	ambient_message.text = "// %s" % ambient_messages[_ambient_index % ambient_messages.size()]

func _reset_idle_state() -> void:
	_idle_elapsed = 0.0; _ambient_index = 0
	if _idle_ambient_active: _set_idle_ambient(false)

func apply_interaction_feedback(enabled: bool, intensity := 1.0) -> void:
	interaction_effects_enabled = enabled; interaction_motion_scale = clampf(intensity, 0.0, 1.0)
	if not is_node_ready(): return
	for button: Button in [continue_button, new_game_button, load_button, settings_button, credits_button, quit_button]:
		if button.has_method("set_feedback"): button.set_feedback(enabled, interaction_motion_scale)

func apply_accessibility(config: FrontendAccessibilityConfig) -> void:
	apply_interaction_feedback(not config.reduced_animation and config.glitch_effects_enabled, 0.0 if config.reduced_animation else 1.0)
	if background.has_method("apply_accessibility"): background.apply_accessibility(config)
	for button: Button in [continue_button, new_game_button, load_button, settings_button, credits_button, quit_button]:
		if button.has_method("set_high_contrast_focus"): button.set_high_contrast_focus(config.high_contrast_focus)

func _connect_activation(button: Button, action: Callable) -> void:
	if button.has_signal("audio_cue_requested"):
		button.audio_cue_requested.connect(audio_cue_requested.emit)
	if button.has_signal("transmitted"): button.transmitted.connect(action)
	else: button.pressed.connect(action)

func focus_default() -> void:
	var target := continue_button if not continue_button.disabled else new_game_button
	if is_visible_in_tree(): target.grab_focus()

func apply_availability(has_continue_save: bool, can_load := false, has_settings_screen := false) -> void:
	continue_save_available = has_continue_save
	load_screen_available = can_load
	settings_screen_available = has_settings_screen
	if not is_node_ready(): return
	continue_button.disabled = not has_continue_save
	load_button.disabled = not can_load
	settings_button.disabled = not has_settings_screen
	%SaveStatus.text = "RECOVERABLE SESSION DETECTED" if has_continue_save else "NO RECOVERABLE SESSION"
	_rebuild_focus_neighbors()

func apply_save_state(summary: FrontendSaveSummary, can_browse_saves: bool, has_settings := true) -> void:
	var has_resume := summary != null and summary.is_valid()
	apply_availability(has_resume, can_browse_saves, has_settings)
	if not has_resume:
		%SaveStatus.text = "NO RECOVERABLE SESSION"
		continue_button.tooltip_text = "No valid resumable game was found."
	else:
		var details: PackedStringArray = ["LAST CONNECTION"]
		details.append("Mode: %s" % summary.mode_label())
		if not summary.network_name.is_empty(): details.append("Network: %s" % summary.network_name)
		if not summary.location_name.is_empty(): details.append("Location: %s" % summary.location_name)
		if not summary.display_timestamp.is_empty(): details.append("Timestamp: %s" % summary.display_timestamp)
		if not summary.playtime_display.is_empty(): details.append("Runtime: %s" % summary.playtime_display)
		%SaveStatus.text = "\n".join(details)
		continue_button.tooltip_text = "Resume %s." % (summary.network_name if not summary.network_name.is_empty() else "the latest valid session")
	load_button.tooltip_text = "Open saved sessions." if can_browse_saves else "No save browser is available."

func set_navigation_enabled(enabled: bool) -> void:
	new_game_button.disabled = not enabled
	credits_button.disabled = not enabled
	quit_button.disabled = not enabled
	continue_button.disabled = not enabled or not continue_save_available
	load_button.disabled = not enabled or not load_screen_available
	settings_button.disabled = not enabled or not settings_screen_available
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	if enabled: _rebuild_focus_neighbors()
	else: _reset_idle_state()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"): return
	get_viewport().set_input_as_handled()
	audio_cue_requested.emit(&"BACK")
	if quit_confirmation.visible: quit_confirmation.hide(); focus_default()
	else: _request_quit()

func _request_quit() -> void:
	if OS.has_feature("web"):
		quit_requested.emit(); return
	quit_confirmation.popup_centered(Vector2i(440, 190))
	quit_confirmation.get_ok_button().grab_focus()

func _rebuild_focus_neighbors() -> void:
	var available: Array[Button] = []
	for button: Button in [continue_button, new_game_button, load_button, settings_button, credits_button, quit_button]:
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
		if not button.disabled: available.append(button)
	for index in available.size():
		var button := available[index]
		button.focus_neighbor_top = button.get_path_to(available[posmod(index - 1, available.size())])
		button.focus_neighbor_bottom = button.get_path_to(available[(index + 1) % available.size()])

func _update_responsive_layout() -> void:
	if not is_node_ready(): return
	var compact := size.x < compact_layout_threshold
	layout.vertical = compact
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.offset_left = 24.0 if compact else 64.0
	margin.offset_right = -24.0 if compact else -64.0
	margin.offset_top = 24.0 if compact else 48.0
	margin.offset_bottom = -24.0 if compact else -48.0
