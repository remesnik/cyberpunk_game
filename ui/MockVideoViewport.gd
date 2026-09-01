class_name MockVideoViewport
extends Control

var session: VideoFeedSession


func set_session(value: VideoFeedSession) -> void:
	session = value
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("061118"))
	for x in range(0, int(size.x) + 1, 32):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.2, 0.8, 0.68, 0.08), 1.0)
	for y in range(0, int(size.y) + 1, 24):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.2, 0.8, 0.68, 0.08), 1.0)
	# Loading dock geometry: bay, floor markings, and a fixed camera horizon.
	draw_line(Vector2(0, size.y * 0.68), Vector2(size.x, size.y * 0.68), Color("3e6f70"), 2.0)
	draw_rect(Rect2(size.x * 0.62, size.y * 0.2, size.x * 0.28, size.y * 0.48), Color(0.08, 0.16, 0.18), true)
	draw_rect(Rect2(size.x * 0.62, size.y * 0.2, size.x * 0.28, size.y * 0.48), Color("528b88"), false, 2.0)
	if session == null or not session.definition.online:
		var unavailable := session == null or not bool(session.get_observer_view().get("available", false))
		if not unavailable:
			pass
		else:
			draw_string(ThemeDB.fallback_font, Vector2(16, size.y * 0.5), "// SIGNAL LOST //", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("ff496c"))
			return
	var observer_view := session.get_observer_view()
	if not bool(observer_view.get("available", false)):
		draw_string(ThemeDB.fallback_font, Vector2(16, size.y * 0.5), "// SIGNAL LOST //", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("ff496c"))
		return
	for entity: Dictionary in observer_view.get("entities", []):
		var normalized: Vector2 = entity.position
		var point := Vector2(clampf(normalized.x, 0.04, 0.96) * size.x, clampf(normalized.y, 0.1, 0.9) * size.y)
		if entity.kind == &"VEHICLE":
			draw_rect(Rect2(point - Vector2(24, 10), Vector2(48, 20)), Color("ffc857"), false, 3.0)
		else:
			draw_circle(point, 7.0, Color("56e8ff"), false, 3.0)
			draw_line(point + Vector2(0, 7), point + Vector2(0, 28), Color("56e8ff"), 3.0)
		draw_string(ThemeDB.fallback_font, point + Vector2(10, -8), String(entity.id), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("a8fff0"))
