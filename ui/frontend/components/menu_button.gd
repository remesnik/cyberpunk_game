class_name FrontendMenuButton
extends Button

signal transmitted
signal audio_cue_requested(cue: StringName)

@export_group("Interaction Feedback")
@export var effects_enabled := true
@export_range(0.0, 1.0, 0.05) var motion_scale := 1.0
@export_range(0.0, 0.2, 0.005) var transmission_duration := 0.065
@export var focus_tone: AudioStream
@export var activation_tone: AudioStream

var _focused := false
var _transmitting := false
var _feedback_time := 0.0
var _audio: AudioStreamPlayer
var _high_contrast_focus := false

func _ready() -> void:
	_audio = AudioStreamPlayer.new(); _audio.bus = &"Master"; add_child(_audio)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	pressed.connect(_begin_transmission)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	set_process(false)

func set_feedback(enabled: bool, intensity := 1.0) -> void:
	effects_enabled = enabled
	motion_scale = clampf(intensity, 0.0, 1.0)
	if not enabled: self_modulate = Color.WHITE
	queue_redraw()

func set_high_contrast_focus(enabled: bool) -> void:
	_high_contrast_focus = enabled
	add_theme_color_override(&"font_focus_color", Color("fff6b0") if enabled else Color("c8d4bd"))
	add_theme_color_override(&"font_hover_color", Color("fff6b0") if enabled else Color("d1d5b1"))
	queue_redraw()

func _process(delta: float) -> void:
	_feedback_time += delta
	if _focused or _transmitting: queue_redraw()

func _draw() -> void:
	if not effects_enabled or motion_scale <= 0.0 or (not _focused and not _transmitting): return
	var pulse: float = sin(_feedback_time * 18.0)
	var jitter: float = roundf(pulse) * motion_scale
	var cursor_color := Color("fff06a") if _high_contrast_focus else Color(0.73, 0.73, 0.52, 0.72 if _focused else 0.9)
	var center_y := size.y * 0.5
	draw_string(get_theme_default_font(), Vector2(12.0 + jitter, center_y + 5.0), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, get_theme_font_size(&"font_size"), cursor_color)
	if _high_contrast_focus:
		draw_rect(Rect2(Vector2(3.0, 3.0), size - Vector2(6.0, 6.0)), cursor_color, false, 2.0)
	# Two tiny packet marks imply transmission without moving the label or hitbox.
	if _transmitting:
		var packet_x := size.x - 22.0 - absf(pulse) * 6.0 * motion_scale
		draw_rect(Rect2(packet_x, center_y - 4.0, 3.0, 8.0), Color(0.7, 0.62, 0.38, 0.7))
		draw_rect(Rect2(packet_x + 6.0, center_y - 2.0, 2.0, 4.0), Color(0.48, 0.57, 0.49, 0.55))

func _on_focus_entered() -> void:
	_focused = true; _feedback_time = 0.0; set_process(effects_enabled and motion_scale > 0.0); queue_redraw()
	audio_cue_requested.emit(&"FOCUS"); _play_optional(focus_tone)

func _on_focus_exited() -> void:
	_focused = false
	if not _transmitting: set_process(false)
	queue_redraw()

func _begin_transmission() -> void:
	if _transmitting: return
	audio_cue_requested.emit(&"SELECT")
	if not effects_enabled or transmission_duration <= 0.0:
		transmitted.emit(); return
	_transmitting = true; _feedback_time = 0.0; set_process(true); _play_optional(activation_tone)
	var tween := create_tween()
	tween.tween_property(self, "self_modulate", Color(0.82, 0.9, 0.76, 1.0), transmission_duration * 0.45)
	tween.tween_property(self, "self_modulate", Color.WHITE, transmission_duration * 0.55)
	await tween.finished
	_transmitting = false
	if not _focused: set_process(false)
	queue_redraw(); transmitted.emit()

func _play_optional(stream: AudioStream) -> void:
	if stream == null or not effects_enabled: return
	_audio.stream = stream; _audio.play()
