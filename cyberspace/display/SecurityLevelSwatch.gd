class_name SecurityLevelSwatch
extends Control

var level_style: Resource

func configure(style: Resource) -> void:
	level_style = style
	custom_minimum_size = Vector2(24, 18)
	queue_redraw()

func _draw() -> void:
	if level_style == null: return
	var center := size * 0.5
	var radius := minf(size.x * 0.34, size.y * 0.42)
	var points := PackedVector2Array()
	for index in 6:
		var angle := -PI * 0.5 + TAU * float(index) / 6.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, level_style.fill_color)
	points.append(points[0])
	draw_polyline(points, level_style.border_color, 1.5, true)
