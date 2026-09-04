class_name NodeCapabilityIconSwatch
extends Control

var capability_type := -1
var icon_theme: Resource
var palette_role := 0

func configure(capability: int, theme: Resource, role: int) -> void:
	capability_type = capability
	icon_theme = theme
	palette_role = role
	custom_minimum_size = Vector2(28, 24)
	queue_redraw()

func _draw() -> void:
	if icon_theme == null or capability_type < 0: return
	var center := size * 0.5
	var color: Color = icon_theme.color_for(palette_role)
	draw_circle(center, 10.0, icon_theme.background_color)
	draw_circle(center, 10.0, color, false, 1.2, true)
	NodeCapabilityIconRenderer.draw_icon(self, capability_type, center, 6.8, color, float(icon_theme.line_width))
