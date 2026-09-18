class_name SphereMinimapNode
extends Control

enum DetailLevel { CLOSE, MEDIUM, DENSE }

signal focus_requested(node_id: StringName)
signal inspection_hint_changed(node_id: StringName, text: String, visible: bool)

const DEFAULT_CONFIG := preload("res://cyberspace/display/cyberspace_visualization_config.tres")

var node_id: StringName = &""
var node_view: Dictionary = {}
var is_current := false
var has_san := false
var has_objective := false
var has_detected_ice := false
var stale_ice_count := 0
var has_current_dynamic_status := false
var has_stale_dynamic_status := false
var is_sphere_exit := false
var has_critical_alert := false
var visualization_config: Resource = DEFAULT_CONFIG
var detail_level := DetailLevel.CLOSE
var immediate_threat := false
var _hovered := false
var _keyboard_focused := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_on_pointer_entered)
	mouse_exited.connect(_on_pointer_exited)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)

func configure(p_node_id: StringName, view: Dictionary, current: bool, sphere_exit: bool, critical_alert := false, config: Resource = DEFAULT_CONFIG, p_detail_level := DetailLevel.CLOSE, p_immediate_threat := false) -> void:
	node_id = p_node_id
	node_view = view.duplicate(true)
	is_current = current
	visualization_config = config if config != null else DEFAULT_CONFIG
	detail_level = p_detail_level
	immediate_threat = p_immediate_threat
	var visual_size := Vector2(56, 44)
	if detail_level == DetailLevel.MEDIUM: visual_size = Vector2(44, 34)
	elif detail_level == DetailLevel.DENSE: visual_size = Vector2(34, 28)
	custom_minimum_size = visual_size
	size = visual_size
	var capabilities: Array = node_view.get("capability_types", [])
	has_san = bool(node_view.get("local_san_present", false)) or capabilities.has(NodeCapabilityType.Value.SYSTEM_ACCESS_NODE)
	has_objective = capabilities.has(NodeCapabilityType.Value.OBJECTIVE)
	has_detected_ice = capabilities.has(NodeCapabilityType.Value.ICE) and (detail_level != DetailLevel.DENSE or immediate_threat)
	stale_ice_count = int(node_view.get("stale_ice_count", 0)) if detail_level != DetailLevel.DENSE else 0
	has_current_dynamic_status = bool(node_view.get("has_current_dynamic_status", false))
	has_stale_dynamic_status = bool(node_view.get("has_stale_dynamic_status", false)) and detail_level != DetailLevel.DENSE
	is_sphere_exit = sphere_exit
	has_critical_alert = critical_alert or bool(node_view.get("critical_alert", false))
	tooltip_text = known_name_for_inspection()
	queue_redraw()

func known_name_for_inspection() -> String:
	var text := String(node_view.get("display_name", node_id)).to_upper() if bool(node_view.get("identity_known", false)) else "UNKNOWN NODE"
	var stale: Array = node_view.get("stale_ice_observations", [])
	if not stale.is_empty():
		var newest_age := 999999
		for observation: Dictionary in stale: newest_age = mini(newest_age, int(observation.get("age_ticks", 0)))
		text += "\nICE LAST KNOWN // %d TICKS AGO" % newest_age
	return text

func _gui_input(event: InputEvent) -> void:
	var activate: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	activate = activate or event.is_action_pressed(&"ui_accept")
	if not activate: return
	grab_focus()
	focus_requested.emit(node_id)
	accept_event()

func _on_pointer_entered() -> void:
	_hovered = true
	inspection_hint_changed.emit(node_id, known_name_for_inspection(), true)
	queue_redraw()

func _on_pointer_exited() -> void:
	_hovered = false
	if not _keyboard_focused: inspection_hint_changed.emit(node_id, "", false)
	queue_redraw()

func _on_focus_entered() -> void:
	_keyboard_focused = true
	inspection_hint_changed.emit(node_id, known_name_for_inspection(), true)
	queue_redraw()

func _on_focus_exited() -> void:
	_keyboard_focused = false
	if not _hovered: inspection_hint_changed.emit(node_id, "", false)
	queue_redraw()

func semantic_markers() -> Array[StringName]:
	var result: Array[StringName] = []
	if is_current: result.append(&"CURRENT")
	if has_san: result.append(&"SAN")
	if has_objective: result.append(&"OBJECTIVE")
	if has_detected_ice: result.append(&"ICE")
	if stale_ice_count > 0: result.append(&"ICE_STALE")
	if has_current_dynamic_status: result.append(&"DYNAMIC_CURRENT")
	if has_stale_dynamic_status: result.append(&"DYNAMIC_STALE")
	if is_sphere_exit: result.append(&"SPHERE_EXIT")
	if has_critical_alert: result.append(&"CRITICAL_ALERT")
	return result

func resolved_level_style() -> Resource:
	return visualization_config.style_for_level(int(node_view.get("security_level", 0)), bool(node_view.get("level_known", false)))

func hex_radius() -> float:
	if detail_level == DetailLevel.DENSE: return 6.5
	if detail_level == DetailLevel.MEDIUM: return 7.5
	return 8.0

func display_label() -> String:
	if detail_level == DetailLevel.DENSE: return ""
	if not bool(node_view.get("identity_known", false)): return "???"
	var label := String(node_view.get("short_id", node_view.get("display_name", node_id))).to_upper()
	var maximum := 7 if detail_level == DetailLevel.MEDIUM else 10
	return String(node_id).left(maximum) if label.length() > maximum else label

func node_center() -> Vector2:
	return Vector2(size.x * 0.5, minf(16.0, size.y * 0.44))

func marker_anchor(marker: StringName) -> Vector2:
	var center := node_center()
	return center + Vector2(0, -hex_radius() - 7.0) if marker == &"SAN" else center

func _draw() -> void:
	var center := node_center()
	var style := resolved_level_style()
	var radius := hex_radius()
	var vertices := PackedVector2Array()
	for index in 6:
		var angle := -PI * 0.5 + TAU * float(index) / 6.0
		vertices.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(vertices, style.fill_color)
	vertices.append(vertices[0]); draw_polyline(vertices, style.border_color, 1.4, true)
	if _hovered or _keyboard_focused:
		draw_circle(center, radius + 2.0, Color(0.70, 0.94, 0.98, 0.88), false, 1.1, true)
	if is_current:
		draw_circle(center, radius + 3.5, Color(1, 1, 1, 0.92), false, 1.5, true)
		var player_marker := PackedVector2Array([center + Vector2(0, -5), center + Vector2(4, 2), center + Vector2(1.5, 1), center + Vector2(1.5, 5), center + Vector2(-1.5, 5), center + Vector2(-1.5, 1), center + Vector2(-4, 2)])
		draw_colored_polygon(player_marker, Color.WHITE)
		player_marker.append(player_marker[0]); draw_polyline(player_marker, Color(0.02, 0.05, 0.08, 0.9), 0.8, true)
	if has_san:
		var san_center := marker_anchor(&"SAN")
		var san_color: Color = visualization_config.capability_icon_theme.local_link_color
		draw_line(center + Vector2(0, -radius), san_center + Vector2(0, 4), Color(san_color, 0.78), 1.25, true)
		NodeCapabilityIconRenderer.draw_icon(self, NodeCapabilityType.Value.SYSTEM_ACCESS_NODE, san_center, 4.5, san_color, 1.15)
	if has_objective:
		var objective := PackedVector2Array([center + Vector2(11, -2), center + Vector2(15, 2), center + Vector2(11, 6), center + Vector2(7, 2)])
		draw_colored_polygon(objective, Color("d4b766"))
	if has_detected_ice:
		var ice := PackedVector2Array([center + Vector2(-15, -5), center + Vector2(-10, 0), center + Vector2(-15, 5), center + Vector2(-15, -5)])
		draw_polyline(ice, Color("d05e69"), 1.5, true)
	elif stale_ice_count > 0:
		var stale_ice := PackedVector2Array([center + Vector2(-15, -5), center + Vector2(-10, 0), center + Vector2(-15, 5), center + Vector2(-15, -5)])
		draw_polyline(stale_ice, Color(visualization_config.minimap_stale_ice_color, 0.38), 1.1, true)
		draw_string(ThemeDB.fallback_font, center + Vector2(-10, -3), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(visualization_config.minimap_stale_ice_color, 0.48))
	if has_current_dynamic_status:
		draw_rect(Rect2(center + Vector2(-12, -12), Vector2(4, 4)), Color(visualization_config.minimap_dynamic_current_color, 0.72), true)
	elif has_stale_dynamic_status:
		draw_rect(Rect2(center + Vector2(-12, -12), Vector2(4, 4)), Color(visualization_config.minimap_stale_color, 0.34), false, 1.0)
	if is_sphere_exit:
		draw_line(center + Vector2(-3, 11), center + Vector2(0, 15), Color("d4b766"), 1.3, true)
		draw_line(center + Vector2(3, 11), center + Vector2(0, 15), Color("d4b766"), 1.3, true)
	if has_critical_alert:
		draw_circle(center + Vector2(13, -10), 4.0, Color("d05e69"))
		draw_string(ThemeDB.fallback_font, center + Vector2(11.2, -7.3), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("080b10"))
	var label := display_label()
	if not label.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(2, size.y - 3), label, HORIZONTAL_ALIGNMENT_CENTER, size.x - 4, 8 if detail_level == DetailLevel.CLOSE else 7, Color(0.72, 0.84, 0.87, 0.82))
