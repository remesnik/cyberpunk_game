class_name FrontendTransitionLayer
extends Control

enum Type { FADE, DIGITAL_CORRUPTION, SIGNAL_LOSS, SIGNAL_ACQUISITION }

var progress := 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()
var transition_type := Type.FADE

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()

func cover(type: Type, duration: float) -> void:
	transition_type = type
	show(); mouse_filter = Control.MOUSE_FILTER_STOP; progress = 0.0
	if duration <= 0.0:
		progress = 1.0; return
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "progress", 1.0, duration * 0.5)
	await tween.finished

func reveal(duration: float) -> void:
	if duration <= 0.0:
		progress = 0.0; hide(); mouse_filter = Control.MOUSE_FILTER_IGNORE; return
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "progress", 0.0, duration * 0.5)
	await tween.finished
	hide(); mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if progress <= 0.0: return
	match transition_type:
		Type.FADE:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.005, 0.009, 0.012, progress))
		Type.DIGITAL_CORRUPTION:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.005, 0.009, 0.012, progress * 0.94))
			for index in ceili(progress * 12.0):
				var y := fmod(float(index * 83 + 17), maxf(size.y, 1.0))
				var width := size.x * (0.2 + fmod(float(index * 37), 70.0) / 100.0)
				draw_rect(Rect2(fmod(float(index * 113), maxf(size.x, 1.0)), y, width, 2.0 + index % 4), Color(0.42, 0.55, 0.46, progress * 0.22))
		Type.SIGNAL_LOSS:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.005, 0.009, 0.012, progress))
			var aperture := size.y * (1.0 - progress)
			draw_rect(Rect2(0.0, size.y * 0.5 - aperture * 0.5, size.x, aperture), Color(0.42, 0.52, 0.45, 0.06))
		Type.SIGNAL_ACQUISITION:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.005, 0.009, 0.012, progress))
			var line_y := size.y * (1.0 - progress)
			draw_line(Vector2(0.0, line_y), Vector2(size.x, line_y), Color(0.72, 0.7, 0.42, progress * 0.55), 2.0)
