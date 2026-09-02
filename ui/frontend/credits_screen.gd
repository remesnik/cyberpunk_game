class_name CreditsScreen
extends Control

signal back_requested
signal audio_cue_requested(cue: StringName)

@export var credits_data: Resource
@export_group("Automatic Scroll")
@export var automatic_scroll_enabled := true
@export_range(2.0, 20.0, 0.5) var automatic_scroll_delay := 5.0
@export_range(4.0, 80.0, 1.0) var automatic_scroll_speed := 14.0
@export_range(0.5, 10.0, 0.5) var manual_scroll_multiplier := 3.0

@onready var frame: PanelContainer = %Frame
@onready var scroll: ScrollContainer = %CreditsScroll
@onready var records: VBoxContainer = %Records
@onready var title_label: Label = %Title
@onready var record_label: Label = %RecordLabel
@onready var archive_decoration: Control = %ArchiveDecoration
var _since_manual_input := 0.0
var _scroll_accumulator := 0.0
var entry_total := 0
var _end_event_started := false
var _end_event_complete := false
var _end_event_elapsed := 0.0
var _end_event_index := 0
var _end_event_container: VBoxContainer
var _configured_auto_scroll_enabled := true

func _ready() -> void:
	_configured_auto_scroll_enabled = automatic_scroll_enabled
	if %Back.has_signal("transmitted"): %Back.transmitted.connect(back_requested.emit)
	else: %Back.pressed.connect(back_requested.emit)
	if %Back.has_signal("audio_cue_requested"): %Back.audio_cue_requested.connect(audio_cue_requested.emit)
	resized.connect(_update_layout)
	scroll.get_v_scroll_bar().value_changed.connect(func(_value): _update_archive_progress())
	_build_records(); _update_layout(); set_process(true)

func focus_default() -> void:
	_since_manual_input = 0.0
	%Back.grab_focus()

func apply_accessibility(config: FrontendAccessibilityConfig) -> void:
	automatic_scroll_enabled = _configured_auto_scroll_enabled and not config.reduced_animation
	if archive_decoration.has_method("apply_accessibility"): archive_decoration.apply_accessibility(config)
	if %Background.has_method("apply_accessibility"): %Background.apply_accessibility(config)
	if %Back.has_method("set_feedback"): %Back.set_feedback(not config.reduced_animation and config.glitch_effects_enabled, 0.0 if config.reduced_animation else 1.0)
	if %Back.has_method("set_high_contrast_focus"): %Back.set_high_contrast_focus(config.high_contrast_focus)

func _process(delta: float) -> void:
	if not visible: return
	var axis := Input.get_axis("ui_up", "ui_down")
	if absf(axis) > 0.15:
		_manual_scroll(axis * automatic_scroll_speed * manual_scroll_multiplier * delta); _check_end_event_start(); _advance_end_event(delta); return
	_since_manual_input += delta
	if automatic_scroll_enabled and _since_manual_input >= automatic_scroll_delay: _automatic_scroll(delta)
	_check_end_event_start()
	_advance_end_event(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled(); audio_cue_requested.emit(&"BACK"); back_requested.emit()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]: _since_manual_input = 0.0
	elif event is InputEventJoypadMotion or event is InputEventScreenDrag or event is InputEventPanGesture: _since_manual_input = 0.0

func _build_records() -> void:
	for child in records.get_children(): child.queue_free()
	if credits_data == null: return
	title_label.text = credits_data.get("display_title")
	record_label.text = "%s // %s" % [credits_data.get("record_id"), credits_data.get("revision")]
	entry_total = 0
	_end_event_started = false; _end_event_complete = false; _end_event_elapsed = 0.0; _end_event_index = 0
	for section_value: Variant in credits_data.get("sections"):
		if not section_value is Resource and not section_value is Dictionary: continue
		var heading := String(_record_value(section_value, "heading", _record_value(section_value, "title", "RECORD")))
		var header := Label.new(); header.theme_type_variation = &"CreditsHeaderLabel"; header.text = "[ %s ]" % heading; records.add_child(header)
		records.add_child(HSeparator.new())
		for entry_value: Variant in _record_value(section_value, "entries", []):
			entry_total += 1
			var row := VBoxContainer.new(); records.add_child(row)
			var fallback_name: String = String(entry_value) if entry_value is String else ""
			var entry_name := String(_record_value(entry_value, "name", fallback_name))
			var role := String(_record_value(entry_value, "role", _record_value(entry_value, "detail", "")))
			var url := String(_record_value(entry_value, "optional_url", ""))
			var note := String(_record_value(entry_value, "optional_note", ""))
			if url.is_empty():
				var name := Label.new(); name.theme_type_variation = &"CreditsBodyLabel"; name.text = entry_name; name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; row.add_child(name)
			else:
				var link := LinkButton.new(); link.text = entry_name; link.uri = url; link.tooltip_text = url; link.theme_type_variation = &"CreditsLinkButton"; row.add_child(link)
			if not role.is_empty():
				var role_label := Label.new(); role_label.theme_type_variation = &"SystemLabel"; role_label.text = "  %s" % role; role_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; row.add_child(role_label)
			if not note.is_empty():
				var note_label := Label.new(); note_label.theme_type_variation = &"SystemLabel"; note_label.text = "  // %s" % note; note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; row.add_child(note_label)
		var gap := Control.new(); gap.custom_minimum_size.y = 24.0; records.add_child(gap)
	_end_event_container = VBoxContainer.new(); _end_event_container.name = "EndEvent"; _end_event_container.add_theme_constant_override("separation", 14); records.add_child(_end_event_container)
	archive_decoration.configure(credits_data.get("sections").size(), entry_total)
	_update_archive_progress()

func _record_value(record: Variant, property: StringName, fallback: Variant) -> Variant:
	if record is Dictionary: return record.get(property, fallback)
	if record is Resource:
		for descriptor: Dictionary in record.get_property_list():
			if descriptor.name == property: return record.get(property)
	return fallback

func _automatic_scroll(delta: float) -> void:
	var bar := scroll.get_v_scroll_bar()
	var maximum := maxf(0.0, bar.max_value - bar.page)
	if scroll.scroll_vertical >= int(maximum): return
	_scroll_accumulator += automatic_scroll_speed * delta
	var whole := int(_scroll_accumulator)
	if whole > 0: scroll.scroll_vertical = mini(scroll.scroll_vertical + whole, int(maximum)); _scroll_accumulator -= whole
	_update_archive_progress()

func _manual_scroll(amount: float) -> void:
	_since_manual_input = 0.0; scroll.scroll_vertical = maxi(0, scroll.scroll_vertical + int(amount)); _update_archive_progress()

func _update_archive_progress() -> void:
	if archive_decoration == null: return
	var bar := scroll.get_v_scroll_bar(); var maximum := maxf(0.0, bar.max_value - bar.page)
	var ratio := 0.0 if maximum <= 0.0 else float(scroll.scroll_vertical) / maximum
	var current := 1 + int(roundf(ratio * maxf(entry_total - 1, 0)))
	archive_decoration.set_archive_progress(ratio, current)

func _check_end_event_start() -> void:
	if _end_event_started or credits_data == null or not bool(credits_data.get("end_event_enabled")): return
	var bar := scroll.get_v_scroll_bar(); var maximum := maxf(0.0, bar.max_value - bar.page)
	if maximum > 0.0 and float(scroll.scroll_vertical) >= maximum - 2.0:
		_end_event_started = true; _end_event_elapsed = 0.0; _advance_end_event(0.0)

func _advance_end_event(delta: float) -> void:
	if not _end_event_started or _end_event_complete: return
	_end_event_elapsed += delta
	var lines: Array = credits_data.get("end_event_lines")
	while _end_event_index < lines.size() and _end_event_elapsed >= float(lines[_end_event_index].get("delay", 0.0)):
		_append_end_event_line(lines[_end_event_index]); _end_event_index += 1
	if _end_event_index >= lines.size():
		_end_event_complete = true
		var prompt := Label.new(); prompt.theme_type_variation = &"SystemLabel"; prompt.text = "\n[ %s ]" % credits_data.get("end_event_return_prompt"); prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _end_event_container.add_child(prompt)

func _append_end_event_line(line: Dictionary) -> void:
	var bar := scroll.get_v_scroll_bar()
	var was_following_bottom := float(scroll.scroll_vertical) >= maxf(0.0, bar.max_value - bar.page) - 2.0
	var label := Label.new(); label.text = String(line.get("text", "")); label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	match StringName(line.get("style", &"SYSTEM")):
		&"WARNING": label.theme_type_variation = &"WarningLabel"
		&"STATUS": label.theme_type_variation = &"StatusLabel"
		_: label.theme_type_variation = &"SystemLabel"
	_end_event_container.add_child(label)
	# New lines extend the scroll range; remain near the ending without locking it.
	if was_following_bottom: call_deferred("_follow_end_event")

func _follow_end_event() -> void:
	if _end_event_started: scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)

func is_end_event_started() -> bool: return _end_event_started
func is_end_event_complete() -> bool: return _end_event_complete

func _update_layout() -> void:
	if not is_node_ready(): return
	frame.custom_minimum_size = Vector2(minf(760.0, maxf(360.0, size.x - 64.0)), minf(820.0, maxf(420.0, size.y - 64.0)))
	# The scrolling body yields vertical space before headers, Back, or the
	# surrounding frame can be clipped in a short resized window.
	scroll.custom_minimum_size.y = clampf(size.y - 420.0, 120.0, 360.0)
