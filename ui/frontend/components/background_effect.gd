class_name FrontendBackgroundEffect
extends Control

@export var grid_spacing := 48.0
@export var drift_speed := 3.5
@export_range(1.0, 3.0, 0.1) var ambient_activity_multiplier := 1.55
var _offset := 0.0
var _time := 0.0
var _ambient_active := false
var _activity_blend := 0.0
var _animation_enabled := true
var _glitch_enabled := true
var _scanlines_enabled := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(delta: float) -> void:
	if not _animation_enabled: return
	_activity_blend = move_toward(_activity_blend, 1.0 if _ambient_active else 0.0, delta * 2.5)
	var activity := lerpf(1.0, ambient_activity_multiplier, _activity_blend)
	_offset = fmod(_offset + delta * drift_speed * activity, grid_spacing)
	_time += delta
	queue_redraw()

func set_ambient_active(active: bool) -> void:
	_ambient_active = active

func is_ambient_active() -> bool: return _ambient_active

func apply_accessibility(config: FrontendAccessibilityConfig) -> void:
	_animation_enabled = not config.reduced_animation
	_glitch_enabled = config.glitch_effects_enabled
	_scanlines_enabled = config.scanlines_enabled
	set_process(_animation_enabled); queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("050808"))
	var grid := Color(0.29, 0.39, 0.36, 0.075)
	var structural := Color(0.35, 0.46, 0.4, 0.13)
	var x := -grid_spacing + _offset
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), grid, 1.0); x += grid_spacing
	var y := -grid_spacing + _offset * 0.45
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), grid, 1.0); y += grid_spacing
	# Sparse topology echoes the in-game graph without becoming decoration-heavy.
	var nodes: Array[Vector2] = [Vector2(size.x * 0.08, size.y * 0.22), Vector2(size.x * 0.27, size.y * 0.34), Vector2(size.x * 0.52, size.y * 0.18), Vector2(size.x * 0.74, size.y * 0.38), Vector2(size.x * 0.91, size.y * 0.25), Vector2(size.x * 0.64, size.y * 0.72)]
	for index in nodes.size() - 1: draw_line(nodes[index], nodes[index + 1], structural, 1.0)
	for point in nodes:
		draw_rect(Rect2(point - Vector2(3, 3), Vector2(6, 6)), Color(0.42, 0.53, 0.45, 0.22), false, 1.0)
	# Packets move slowly along one route; there is no falling-character motif.
	var phase := fmod(_time * 0.08, 1.0)
	draw_circle(nodes[1].lerp(nodes[2], phase), 2.0, Color(0.65, 0.62, 0.4, 0.45))
	if _activity_blend > 0.01:
		var secondary_phase := fmod(_time * 0.055 + 0.35, 1.0)
		draw_circle(nodes[3].lerp(nodes[4], secondary_phase), 1.7, Color(0.45, 0.57, 0.49, 0.28 * _activity_blend))
		draw_circle(nodes[4].lerp(nodes[5], fmod(secondary_phase + 0.5, 1.0)), 1.4, Color(0.65, 0.58, 0.36, 0.2 * _activity_blend))
	# Sparse interference bands remain behind opaque content panels.
	if _scanlines_enabled:
		for scan_y in range(0, int(size.y), 6): draw_line(Vector2(0, scan_y), Vector2(size.x, scan_y), Color(0, 0, 0, 0.035), 1.0)
	if _glitch_enabled and _animation_enabled and fmod(_time, lerpf(11.0, 7.5, _activity_blend)) < 0.08:
		var interference_y := fmod(_time * 173.0, maxf(size.y, 1.0))
		draw_rect(Rect2(0, interference_y, size.x, 2), Color(0.42, 0.47, 0.38, 0.045))
