class_name FrontendLoadScreen
extends Control

signal back_requested
signal save_selected(save_id: StringName)
signal audio_cue_requested(cue: StringName)

@onready var session_list: VBoxContainer = %SessionList
@onready var empty_state: Label = %EmptyState
@onready var back_button: Button = %Back
@onready var panel: PanelContainer = %Panel

func _ready() -> void:
	resized.connect(_update_layout); _update_layout()
	if back_button.has_signal("transmitted"): back_button.transmitted.connect(back_requested.emit)
	else: back_button.pressed.connect(back_requested.emit)
	if back_button.has_signal("audio_cue_requested"): back_button.audio_cue_requested.connect(audio_cue_requested.emit)

func set_saves(summaries: Array[FrontendSaveSummary]) -> void:
	for child in session_list.get_children(): child.queue_free()
	empty_state.visible = summaries.is_empty()
	for summary in summaries:
		if summary == null or not summary.is_valid(): continue
		var button := Button.new()
		var context := summary.network_name if not summary.network_name.is_empty() else summary.location_name
		button.text = "%s\n%s\n%s\n%s" % [summary.save_id, summary.mode_label(), context, summary.playtime_display]
		button.tooltip_text = "%s // %s" % [summary.location_name, summary.display_timestamp]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(func(): save_selected.emit(summary.save_id))
		session_list.add_child(button)

func focus_default() -> void:
	var first := session_list.get_child(0) as Control if session_list.get_child_count() > 0 else back_button
	first.grab_focus()

func apply_accessibility(config: FrontendAccessibilityConfig) -> void:
	if %Background.has_method("apply_accessibility"): %Background.apply_accessibility(config)
	if back_button.has_method("set_feedback"): back_button.set_feedback(not config.reduced_animation and config.glitch_effects_enabled, 0.0 if config.reduced_animation else 1.0)
	if back_button.has_method("set_high_contrast_focus"): back_button.set_high_contrast_focus(config.high_contrast_focus)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled(); audio_cue_requested.emit(&"BACK"); back_requested.emit()

func _update_layout() -> void:
	if not is_node_ready(): return
	panel.custom_minimum_size = Vector2(minf(680.0, maxf(360.0, size.x - 64.0)), minf(500.0, maxf(320.0, size.y - 64.0)))
