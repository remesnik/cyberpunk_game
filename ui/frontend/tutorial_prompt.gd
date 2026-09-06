class_name FrontendTutorialPrompt
extends Control

signal decision_made(run_introduction: bool)
signal back_requested
signal audio_cue_requested(cue: StringName)

@onready var yes_button: Button = %RunIntroduction
@onready var no_button: Button = %BeginImmediately
@onready var back_button: Button = %Back

func _ready() -> void:
	_bind(yes_button, func(): decision_made.emit(true))
	_bind(no_button, func(): decision_made.emit(false))
	_bind(back_button, back_requested.emit)
	yes_button.focus_neighbor_bottom = yes_button.get_path_to(no_button)
	no_button.focus_neighbor_top = no_button.get_path_to(yes_button)
	no_button.focus_neighbor_bottom = no_button.get_path_to(back_button)
	back_button.focus_neighbor_top = back_button.get_path_to(no_button)

func _bind(button: Button, action: Callable) -> void:
	if button.has_signal("audio_cue_requested"): button.audio_cue_requested.connect(audio_cue_requested.emit)
	if button.has_signal("transmitted"): button.transmitted.connect(action)
	else: button.pressed.connect(action)

func focus_default() -> void:
	if is_visible_in_tree(): yes_button.grab_focus()

func set_navigation_enabled(enabled: bool) -> void:
	for button: Button in [yes_button, no_button, back_button]:
		button.disabled = not enabled
		button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE

func apply_accessibility(config: FrontendAccessibilityConfig) -> void:
	for button: Button in [yes_button, no_button, back_button]:
		if button.has_method("set_feedback"): button.set_feedback(not config.reduced_animation and config.glitch_effects_enabled, 0.0 if config.reduced_animation else 1.0)
		if button.has_method("set_high_contrast_focus"): button.set_high_contrast_focus(config.high_contrast_focus)

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed(&"ui_cancel"): return
	get_viewport().set_input_as_handled()
	audio_cue_requested.emit(&"BACK")
	back_requested.emit()

