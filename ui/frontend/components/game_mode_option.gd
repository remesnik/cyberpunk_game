class_name FrontendGameModeOption
extends Button

signal mode_activated(mode_id: StringName)
signal audio_cue_requested(cue: StringName)
signal mode_focused(mode_id: StringName)

@export var mode_id: StringName
@export var accent_color := Color("56e8ff")
@export var mode_title := "MODE"
@export_multiline var description := "Mode description."
@export var metadata: Array[String] = []
var effects_enabled := true
var _high_contrast_focus := false
var _visual_time := 0.0

@onready var title_label: Label = %ModeTitle
@onready var description_label: Label = %Description
@onready var metadata_label: Label = %Metadata
@onready var state_label: Label = %State

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pressed.connect(_activate)
	title_label.text = mode_title
	description_label.text = description
	metadata_label.text = "  //  ".join(metadata)
	state_label.text = "STANDBY"
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if effects_enabled and (has_focus() or is_hovered()):
		_visual_time += delta
		queue_redraw()

func _draw() -> void:
	var emphasized := has_focus() or is_hovered()
	var color := Color("fff6b0") if _high_contrast_focus and emphasized else accent_color
	var alpha := 0.95 if has_focus() else (0.62 if is_hovered() else 0.26)
	draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), Color(0.012, 0.025, 0.028, 0.96), true)
	_draw_mode_preview(color, 0.24 if has_focus() else (0.13 if is_hovered() else 0.055))
	if emphasized: draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), Color(color, 0.035), true)
	draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), Color(color, alpha), false, 2.0 if has_focus() else 1.0)
	if has_focus():
		draw_rect(Rect2(3, 3, 5, size.y - 6), Color(color, 0.9), true)
		draw_line(Vector2(10, 10), Vector2(34, 10), color, 2.0)
		draw_line(Vector2(10, 10), Vector2(10, 34), color, 2.0)
		draw_line(Vector2(size.x - 10, size.y - 10), Vector2(size.x - 34, size.y - 10), color, 2.0)
		draw_line(Vector2(size.x - 10, size.y - 10), Vector2(size.x - 10, size.y - 34), color, 2.0)
		if effects_enabled:
			var interference_y := 18.0 + fmod(_visual_time * 21.0, maxf(size.y - 36.0, 1.0))
			draw_line(Vector2(8, interference_y), Vector2(size.x - 8, interference_y), Color(color, 0.075), 1.0)

func set_feedback(enabled: bool, _intensity := 1.0) -> void:
	effects_enabled = enabled
	queue_redraw()

func set_high_contrast_focus(enabled: bool) -> void:
	_high_contrast_focus = enabled
	queue_redraw()

func preview_variant() -> StringName:
	return &"GUIDED_ROUTE" if mode_id == &"STORY_MODE" else &"OPEN_NETWORK"

func preview_intensity() -> float:
	return 0.24 if has_focus() else (0.13 if is_hovered() else 0.055)

func _on_focus_entered() -> void:
	audio_cue_requested.emit(&"FOCUS")
	state_label.text = "SELECTED // CONFIRM TO CONTINUE"
	mode_focused.emit(mode_id)
	queue_redraw()

func _on_focus_exited() -> void:
	if not is_hovered(): state_label.text = "STANDBY"
	queue_redraw()

func _on_mouse_entered() -> void:
	if not has_focus(): state_label.text = "POINTED // CLICK TO SELECT"
	mode_focused.emit(mode_id)
	queue_redraw()

func _on_mouse_exited() -> void:
	if not has_focus(): state_label.text = "STANDBY"
	queue_redraw()

func _activate() -> void:
	if disabled: return
	audio_cue_requested.emit(&"SELECT")
	mode_activated.emit(mode_id)

func _draw_mode_preview(color: Color, alpha: float) -> void:
	var area := Rect2(24.0, size.y * 0.50, size.x - 48.0, size.y * 0.31)
	if mode_id == &"STORY_MODE":
		var points := [Vector2(area.position.x, area.get_center().y), Vector2(area.position.x + area.size.x * 0.28, area.position.y + area.size.y * 0.30), Vector2(area.position.x + area.size.x * 0.58, area.position.y + area.size.y * 0.66), Vector2(area.end.x, area.position.y + area.size.y * 0.36)]
		for index in points.size() - 1: draw_line(points[index], points[index + 1], Color(color, alpha), 1.2)
		for index in points.size():
			draw_circle(points[index], 4.0 if index in [0, points.size() - 1] else 3.0, Color(color, alpha), false, 1.2)
	else:
		var center := area.get_center()
		var points := [center, center + Vector2(-area.size.x * 0.35, -area.size.y * 0.25), center + Vector2(area.size.x * 0.32, -area.size.y * 0.33), center + Vector2(-area.size.x * 0.28, area.size.y * 0.34), center + Vector2(area.size.x * 0.38, area.size.y * 0.23)]
		for index in range(1, points.size()): draw_line(center, points[index], Color(color, alpha), 1.0)
		draw_line(points[1], points[3], Color(color, alpha * 0.65), 1.0)
		draw_line(points[2], points[4], Color(color, alpha * 0.65), 1.0)
		for point in points: draw_circle(point, 3.2, Color(color, alpha), false, 1.1)
