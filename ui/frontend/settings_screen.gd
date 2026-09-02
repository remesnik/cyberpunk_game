class_name FrontendSettingsScreen
extends Control

signal back_requested
signal audio_cue_requested(cue: StringName)

@onready var back_button: Button = %Back
@onready var panel: PanelContainer = %Panel

func _ready() -> void:
	resized.connect(_update_layout); _update_layout()
	if back_button.has_signal("transmitted"): back_button.transmitted.connect(back_requested.emit)
	else: back_button.pressed.connect(back_requested.emit)
	if back_button.has_signal("audio_cue_requested"): back_button.audio_cue_requested.connect(audio_cue_requested.emit)

func focus_default() -> void: back_button.grab_focus()

func apply_accessibility(config: FrontendAccessibilityConfig) -> void:
	%CurrentSettings.text = "UI SCALE: %.0f%%\nANIMATION: %s\nGLITCH: %s\nSCANLINES: %s" % [config.ui_scale * 100.0, "REDUCED" if config.reduced_animation else "STANDARD", "ON" if config.glitch_effects_enabled else "OFF", "ON" if config.scanlines_enabled else "OFF"]
	if %Background.has_method("apply_accessibility"): %Background.apply_accessibility(config)
	if back_button.has_method("set_feedback"): back_button.set_feedback(not config.reduced_animation and config.glitch_effects_enabled, 0.0 if config.reduced_animation else 1.0)
	if back_button.has_method("set_high_contrast_focus"): back_button.set_high_contrast_focus(config.high_contrast_focus)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled(); audio_cue_requested.emit(&"BACK"); back_requested.emit()

func _update_layout() -> void:
	if not is_node_ready(): return
	panel.custom_minimum_size = Vector2(minf(620.0, maxf(360.0, size.x - 64.0)), minf(440.0, maxf(300.0, size.y - 64.0)))
