class_name DockableMonitorWidget
extends PanelContainer

signal dock_requested(widget: DockableMonitorWidget, slot: DockSlot)
signal pin_changed(widget: DockableMonitorWidget, pinned: bool)

enum DockSlot { LEFT, RIGHT, BOTTOM }

var monitor_title: String = "MONITOR"
var dock_slot: DockSlot = DockSlot.RIGHT
var pinned: bool = true
var minimized: bool = false
var content: Control

var _body: MarginContainer
var _pin_button: Button
var _minimize_button: Button
var _dock_button: Button


func configure(title: String, monitor_content: Control, initial_slot: DockSlot, start_minimized: bool) -> void:
	monitor_title = title
	dock_slot = initial_slot
	content = monitor_content
	_build_ui()
	set_minimized(start_minimized)


func _build_ui() -> void:
	custom_minimum_size = Vector2(240.0 if dock_slot == DockSlot.BOTTOM else 280.0, 0.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.008, 0.025, 0.045, 0.96)
	panel_style.border_color = Color(0.22, 0.76, 0.73, 0.82)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(3)
	add_theme_stylebox_override("panel", panel_style)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	add_child(rows)

	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 32.0
	header.add_theme_constant_override("separation", 4)
	rows.add_child(header)

	var title_label := Label.new()
	title_label.text = "  ● %s" % monitor_title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_color_override("font_color", Color(0.38, 0.94, 0.83))
	title_label.tooltip_text = "Live realtime monitor. It continues updating when minimized."
	header.add_child(title_label)

	_pin_button = Button.new()
	_pin_button.flat = true
	_pin_button.focus_mode = Control.FOCUS_NONE
	_pin_button.pressed.connect(_toggle_pin)
	header.add_child(_pin_button)

	_dock_button = Button.new()
	_dock_button.flat = true
	_dock_button.focus_mode = Control.FOCUS_NONE
	_dock_button.tooltip_text = "Move to the next dock zone"
	_dock_button.pressed.connect(_request_next_dock)
	header.add_child(_dock_button)

	_minimize_button = Button.new()
	_minimize_button.flat = true
	_minimize_button.focus_mode = Control.FOCUS_NONE
	_minimize_button.tooltip_text = "Minimize without stopping this monitor"
	_minimize_button.pressed.connect(func() -> void: set_minimized(not minimized))
	header.add_child(_minimize_button)

	_body = MarginContainer.new()
	_body.add_theme_constant_override("margin_left", 4)
	_body.add_theme_constant_override("margin_right", 4)
	_body.add_theme_constant_override("margin_bottom", 4)
	rows.add_child(_body)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body.add_child(content)
	_refresh_header()


func set_minimized(value: bool) -> void:
	minimized = value
	if _body != null:
		# Visibility is presentation-only. The monitor remains in the tree and keeps processing.
		_body.visible = not minimized
	_refresh_header()


func set_pinned(value: bool) -> void:
	pinned = value
	_refresh_header()
	pin_changed.emit(self, pinned)


func set_dock_slot(value: DockSlot) -> void:
	dock_slot = value
	_refresh_header()


func _toggle_pin() -> void:
	set_pinned(not pinned)


func _request_next_dock() -> void:
	var next_slot: DockSlot = (int(dock_slot) + 1) % 3
	dock_requested.emit(self, next_slot)


func _refresh_header() -> void:
	if _pin_button != null:
		_pin_button.text = "PINNED" if pinned else "PIN"
		_pin_button.tooltip_text = "Unpin this monitor" if pinned else "Keep this monitor in the workspace"
	if _dock_button != null:
		_dock_button.text = ["LEFT", "RIGHT", "BOTTOM"][int(dock_slot)]
	if _minimize_button != null:
		_minimize_button.text = "+" if minimized else "−"
