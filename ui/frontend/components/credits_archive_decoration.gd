class_name CreditsArchiveDecoration
extends Control

@export_range(0.0, 0.15, 0.005) var maximum_opacity := 0.075
var section_count := 0
var entry_index := 1
var entry_total := 1
var scroll_ratio := 0.0
var _activity_time := 0.0
var _animation_enabled := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(delta: float) -> void:
	_activity_time += delta
	queue_redraw()

func apply_accessibility(config: FrontendAccessibilityConfig) -> void:
	_animation_enabled = not config.reduced_animation
	set_process(_animation_enabled); queue_redraw()

func configure(p_section_count: int, p_entry_total: int) -> void:
	section_count = maxi(0, p_section_count); entry_total = maxi(1, p_entry_total); queue_redraw()

func set_archive_progress(ratio: float, current_entry: int) -> void:
	scroll_ratio = clampf(ratio, 0.0, 1.0); entry_index = clampi(current_entry, 1, entry_total); queue_redraw()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0: return
	var ink := Color(0.42, 0.52, 0.45, maximum_opacity)
	var pulse := 0.55 + (sin(_activity_time * 1.4) * 0.12 if _animation_enabled else 0.0)
	var active_ink := Color(0.63, 0.58, 0.36, maximum_opacity * pulse)
	var rail_x := size.x - 30.0
	draw_line(Vector2(rail_x, 72.0), Vector2(rail_x, size.y - 72.0), ink, 1.0)
	for index in section_count:
		var y := lerpf(92.0, size.y - 92.0, float(index) / maxf(float(section_count - 1), 1.0))
		draw_rect(Rect2(rail_x - 3.0, y - 3.0, 6.0, 6.0), active_ink if absf(scroll_ratio - float(index) / maxf(section_count - 1, 1)) < 0.12 else ink, false, 1.0)
	var font := get_theme_default_font()
	var font_size := 11
	draw_string(font, Vector2(22.0, 30.0), "CONTRIBUTOR DATABASE // RECORD ACCESS", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
	draw_string(font, Vector2(22.0, size.y - 24.0), "ARCHIVE NODE // AUTHORS", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
	var counter := "ENTRY %03d/%03d" % [entry_index, entry_total]
	draw_string(font, Vector2(size.x - 142.0, 30.0), counter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, active_ink)
	# A single slow packet traverses the archive rail; it never crosses the text column.
	var packet_y := lerpf(72.0, size.y - 72.0, fmod(_activity_time * 0.035, 1.0) if _animation_enabled else scroll_ratio)
	draw_rect(Rect2(rail_x - 2.0, packet_y - 2.0, 4.0, 4.0), active_ink)
