class_name CyberspaceSpatialBackdrop
extends Control

var camera_offset := Vector2.ZERO

func set_camera_offset(value: Vector2) -> void:
	camera_offset = value
	queue_redraw()

func _draw() -> void:
	var horizon := size.y * 0.31
	draw_rect(Rect2(Vector2.ZERO, size), Color("020815"))
	# A single interpolated atmospheric wash implies depth without visible floor
	# geometry, helper lines, or banding.
	var haze_points := PackedVector2Array([
		Vector2(0, horizon), Vector2(size.x, horizon),
		Vector2(size.x, size.y), Vector2(0, size.y),
	])
	var haze_colors := PackedColorArray([
		Color(0.01, 0.05, 0.10, 0.20), Color(0.01, 0.05, 0.10, 0.20),
		Color(0.02, 0.15, 0.23, 0.34), Color(0.02, 0.15, 0.23, 0.34),
	])
	draw_polygon(haze_points, haze_colors)
