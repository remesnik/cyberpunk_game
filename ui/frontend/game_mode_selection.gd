class_name FrontendGameModeSelection
extends Control

signal mode_selected(mode_id: StringName)
signal back_requested
signal audio_cue_requested(cue: StringName)

@export_range(640, 1400, 10) var compact_layout_threshold := 940
@onready var options: BoxContainer = %Options
@onready var story_option: FrontendGameModeOption = %StoryMode
@onready var free_roam_option: FrontendGameModeOption = %FreeRoam
@onready var back_button: Button = %Back
@onready var confirmation: VBoxContainer = %Confirmation
@onready var confirmation_title: Label = %ConfirmationTitle
@onready var confirmation_summary: Label = %ConfirmationSummary
@onready var overwrite_warning: Label = %OverwriteWarning
@onready var start_button: Button = %Start
@onready var confirmation_back_button: Button = %ConfirmationBack

var selected_mode_id: StringName = &""
var has_existing_save := false
var _last_focused_mode: StringName = &"STORY_MODE"
var _activation_armed := false
var _release_frames := 0

func _ready() -> void:
	story_option.mode_activated.connect(_select_mode)
	free_roam_option.mode_activated.connect(_select_mode)
	story_option.mode_focused.connect(_on_mode_focused)
	free_roam_option.mode_focused.connect(_on_mode_focused)
	story_option.audio_cue_requested.connect(audio_cue_requested.emit)
	free_roam_option.audio_cue_requested.connect(audio_cue_requested.emit)
	if back_button.has_signal("audio_cue_requested"): back_button.audio_cue_requested.connect(audio_cue_requested.emit)
	if back_button.has_signal("transmitted"): back_button.transmitted.connect(back_requested.emit)
	else: back_button.pressed.connect(back_requested.emit)
	if start_button.has_signal("audio_cue_requested"): start_button.audio_cue_requested.connect(audio_cue_requested.emit)
	if confirmation_back_button.has_signal("audio_cue_requested"): confirmation_back_button.audio_cue_requested.connect(audio_cue_requested.emit)
	if start_button.has_signal("transmitted"): start_button.transmitted.connect(_confirm_mode)
	else: start_button.pressed.connect(_confirm_mode)
	if confirmation_back_button.has_signal("transmitted"): confirmation_back_button.transmitted.connect(_close_confirmation)
	else: confirmation_back_button.pressed.connect(_close_confirmation)
	resized.connect(_update_responsive_layout)
	_update_responsive_layout()
	_rebuild_focus_neighbors()
	set_process(true)

func _process(_delta: float) -> void:
	if _activation_armed or not visible: return
	if Input.is_action_pressed(&"ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_release_frames = 0
		return
	_release_frames += 1
	if _release_frames >= 2: _activation_armed = true

func focus_default() -> void:
	if not is_visible_in_tree(): return
	if confirmation.visible: start_button.grab_focus()
	else: story_option.grab_focus()

func prepare(existing_save: bool) -> void:
	has_existing_save = existing_save
	_activation_armed = false
	_release_frames = 0
	_last_focused_mode = &"STORY_MODE"
	_close_confirmation(false)

func set_navigation_enabled(enabled: bool) -> void:
	for control: Control in [story_option, free_roam_option, back_button, start_button, confirmation_back_button]:
		control.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
		control.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
		if control is BaseButton: control.disabled = not enabled
	if enabled: _rebuild_focus_neighbors()

func apply_accessibility(config: FrontendAccessibilityConfig) -> void:
	for option: FrontendGameModeOption in [story_option, free_roam_option]:
		option.set_feedback(not config.reduced_animation and config.glitch_effects_enabled, 0.0 if config.reduced_animation else 1.0)
		option.set_high_contrast_focus(config.high_contrast_focus)
	if back_button.has_method("set_feedback"): back_button.set_feedback(not config.reduced_animation and config.glitch_effects_enabled, 0.0 if config.reduced_animation else 1.0)
	if back_button.has_method("set_high_contrast_focus"): back_button.set_high_contrast_focus(config.high_contrast_focus)
	for button: Button in [start_button, confirmation_back_button]:
		if button.has_method("set_feedback"): button.set_feedback(not config.reduced_animation and config.glitch_effects_enabled, 0.0 if config.reduced_animation else 1.0)
		if button.has_method("set_high_contrast_focus"): button.set_high_contrast_focus(config.high_contrast_focus)

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed(&"ui_cancel"): return
	get_viewport().set_input_as_handled()
	audio_cue_requested.emit(&"BACK")
	if confirmation.visible: _close_confirmation()
	else: back_requested.emit()

func _select_mode(mode_id: StringName) -> void:
	if not _activation_armed: return
	selected_mode_id = mode_id
	_last_focused_mode = mode_id
	options.hide(); back_button.hide(); confirmation.show()
	var story := mode_id == &"STORY_MODE"
	confirmation_title.text = "STORY MODE" if story else "FREE ROAM"
	confirmation_summary.text = "Begin the authored campaign?" if story else "Begin an open-ended network sandbox?"
	overwrite_warning.visible = has_existing_save
	overwrite_warning.text = "WARNING // AN EXISTING RESUMABLE SESSION WAS DETECTED.\nStarting now creates a fresh game state; overwrite handling will follow the selected save slot." if has_existing_save else ""
	_rebuild_focus_neighbors()
	start_button.grab_focus()

func _confirm_mode() -> void:
	if selected_mode_id.is_empty(): return
	mode_selected.emit(selected_mode_id)

func _close_confirmation(refocus := true) -> void:
	selected_mode_id = &""
	confirmation.hide(); options.show(); back_button.show()
	_rebuild_focus_neighbors()
	if refocus and is_visible_in_tree():
		(story_option if _last_focused_mode == &"STORY_MODE" else free_roam_option).grab_focus()

func _on_mode_focused(mode_id: StringName) -> void:
	_last_focused_mode = mode_id
	%SelectionStatus.text = "SESSION TYPE // %s" % ("STORY MODE" if mode_id == &"STORY_MODE" else "FREE ROAM")

func _rebuild_focus_neighbors() -> void:
	if confirmation.visible:
		start_button.focus_neighbor_bottom = start_button.get_path_to(confirmation_back_button)
		confirmation_back_button.focus_neighbor_top = confirmation_back_button.get_path_to(start_button)
		return
	if options.vertical:
		story_option.focus_neighbor_bottom = story_option.get_path_to(free_roam_option)
		free_roam_option.focus_neighbor_top = free_roam_option.get_path_to(story_option)
		free_roam_option.focus_neighbor_bottom = free_roam_option.get_path_to(back_button)
		back_button.focus_neighbor_top = back_button.get_path_to(free_roam_option)
	else:
		story_option.focus_neighbor_right = story_option.get_path_to(free_roam_option)
		story_option.focus_neighbor_left = story_option.get_path_to(free_roam_option)
		story_option.focus_neighbor_bottom = story_option.get_path_to(back_button)
		free_roam_option.focus_neighbor_left = free_roam_option.get_path_to(story_option)
		free_roam_option.focus_neighbor_right = free_roam_option.get_path_to(story_option)
		free_roam_option.focus_neighbor_bottom = free_roam_option.get_path_to(back_button)
		back_button.focus_neighbor_top = back_button.get_path_to(story_option)

func _update_responsive_layout() -> void:
	if not is_node_ready(): return
	var compact := size.x < compact_layout_threshold or size.y < 700.0
	options.vertical = compact
	story_option.custom_minimum_size = Vector2(330, 185) if compact else Vector2(410, 310)
	free_roam_option.custom_minimum_size = Vector2(330, 185) if compact else Vector2(410, 310)
	_rebuild_focus_neighbors()
