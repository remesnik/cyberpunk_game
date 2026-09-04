class_name NodeVisual
extends Control

enum DetailLevel { CLOSE, MEDIUM, FAR }

signal selected(node_id: StringName)
signal scan_requested(contact_id: StringName)
signal capability_selected(node_id: StringName, capability_type: int)

const DEFAULT_VISUALIZATION_CONFIG := preload("res://cyberspace/display/cyberspace_visualization_config.tres")
const CAPABILITY_SOCKET := preload("res://cyberspace/display/NodeCapabilitySocket.gd")

var node_id: StringName = &""
var title := "UNKNOWN"
var concise_status := ""
var is_current := false
var is_unknown := false
var is_destination := false
var is_security_visible := false
var is_selectable := false
var security_level := 0
var level_known := false
var capability_types: Array[int] = []
var capability_counts: Dictionary = {}
var unknown_content_count := 0
var stale_ice_count := 0
var local_san_present := false
var _san_arrival_strength := 0.0
var _hovered := false
var _pulse := 0.0
var _animation_time := 0.0
var _reduced_animation := false
var _scan_resolution_elapsed := -1.0
var _scan_revealed_capabilities: Array[int] = []
var _scan_resolves_level := false
var _scan_resolves_identity := false
var _scan_resolves_status := false
var _scan_previous_title := "???"
var _scan_previous_status := ""
var _focused_capability_socket := -1
var visualization_config: Resource = DEFAULT_VISUALIZATION_CONFIG
var detail_level := DetailLevel.CLOSE
var view_zoom := 1.0

func apply_visualization_config(config: Resource) -> void:
	visualization_config = config
	if visualization_config != null:
		custom_minimum_size = visualization_config.visual_size()
		size = custom_minimum_size
	queue_redraw()
	_rebuild_capability_socket_controls()

func set_reduced_animation(enabled: bool) -> void:
	_reduced_animation = enabled
	if enabled:
		_scan_resolution_elapsed = -1.0
	queue_redraw()

func set_view_context(zoom: float, visible_node_count: int) -> void:
	view_zoom = clampf(zoom, 0.2, 1.5)
	var next_level: int = visualization_config.detail_level_for(view_zoom, visible_node_count)
	if next_level == detail_level:
		return
	detail_level = next_level
	_rebuild_capability_socket_controls()
	queue_redraw()

func displayed_capability_types() -> Array[int]:
	var result: Array[int] = []
	for capability: int in capability_types:
		var definition: Resource = visualization_config.capability_catalog.definition_for(capability) if visualization_config != null and visualization_config.capability_catalog != null else null
		if detail_level == DetailLevel.CLOSE:
			result.append(capability)
		elif detail_level == DetailLevel.MEDIUM and definition != null and int(definition.get("priority")) <= int(visualization_config.medium_capability_priority_limit):
			result.append(capability)
		elif detail_level == DetailLevel.FAR and visualization_config.far_capability_types.has(capability):
			result.append(capability)
	return result

func shows_node_label() -> bool:
	return detail_level != DetailLevel.FAR

func shows_status_text() -> bool:
	return detail_level == DetailLevel.CLOSE

func shows_capability_counts() -> bool:
	return detail_level == DetailLevel.CLOSE

func play_knowledge_resolution(previous_view: Dictionary) -> void:
	var previous_capabilities: Array[int] = []
	previous_capabilities.assign(previous_view.get("capability_types", []))
	_scan_revealed_capabilities.clear()
	var stable_capabilities: Array[int] = capability_types.duplicate()
	if visualization_config != null and visualization_config.capability_catalog != null:
		stable_capabilities = visualization_config.capability_catalog.sort_capabilities(stable_capabilities)
	for capability: int in stable_capabilities:
		if not previous_capabilities.has(capability):
			_scan_revealed_capabilities.append(capability)
	_scan_resolves_level = level_known and not bool(previous_view.get("level_known", false))
	var previous_level := int(previous_view.get("level", KnowledgeLevel.Value.DETECTED))
	var previous_identity_known := bool(previous_view.get("identity_known", previous_level >= KnowledgeLevel.Value.IDENTIFIED))
	_scan_previous_title = _short_node_label(previous_view, previous_identity_known)
	_scan_previous_status = String(previous_view.get("concise_status", "")).to_upper()
	_scan_resolves_identity = _scan_previous_title != title
	_scan_resolves_status = _scan_previous_status != concise_status
	if _reduced_animation or (not _scan_resolves_level and not _scan_resolves_identity and not _scan_resolves_status and _scan_revealed_capabilities.is_empty()):
		_scan_resolution_elapsed = -1.0
	else:
		_scan_resolution_elapsed = 0.0
	queue_redraw()

func is_resolving_knowledge() -> bool:
	return _scan_resolution_elapsed >= 0.0

func has_state_animation() -> bool:
	return is_current or local_san_present or capability_types.has(NodeCapabilityType.Value.FEED) or capability_types.has(NodeCapabilityType.Value.ACTIVE_PROCESS) or capability_types.has(NodeCapabilityType.Value.ICE) or capability_types.has(NodeCapabilityType.Value.OBJECTIVE)

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void: _hovered = true; queue_redraw())
	mouse_exited.connect(func() -> void: _hovered = false; queue_redraw())
	set_process(true)

func configure(node: NetworkNodeDefinition, current: bool, selectable: bool, security_visible: bool) -> void:
	configure_view({"id": node.id, "display_name": node.display_name, "node_type": node.node_type, "security_level": node.security_level, "level": KnowledgeLevel.Value.SCANNED}, current, selectable, security_visible)

func configure_view(record: Dictionary, current: bool, selectable: bool, security_visible: bool) -> void:
	node_id = record.get("id", &"")
	title = String(record.get("display_name", "UNKNOWN NODE")).to_upper()
	var level := int(record.get("level", KnowledgeLevel.Value.DETECTED))
	var identity_known := bool(record.get("identity_known", level >= KnowledgeLevel.Value.IDENTIFIED))
	title = _short_node_label(record, identity_known)
	level_known = bool(record.get("level_known", record.has("security_level")))
	concise_status = String(record.get("concise_status", "")).to_upper()
	is_current = current
	is_selectable = selectable
	is_security_visible = security_visible
	security_level = int(record.get("security_level", 0))
	capability_types.assign(record.get("capability_types", []))
	capability_counts = (record.get("capability_counts", {}) as Dictionary).duplicate()
	unknown_content_count = maxi(0, int(record.get("unknown_content_count", 0)))
	stale_ice_count = maxi(0, int(record.get("stale_ice_count", 0)))
	local_san_present = bool(record.get("local_san_present", false))
	is_unknown = false
	_rebuild_capability_socket_controls()
	queue_redraw()

func configure_unknown(contact_id: StringName = &"") -> void:
	node_id = contact_id
	title = "???"
	concise_status = ""
	is_unknown = true
	level_known = false
	capability_types.clear()
	capability_counts.clear()
	unknown_content_count = 0
	stale_ice_count = 0
	local_san_present = false
	_rebuild_capability_socket_controls()
	is_selectable = contact_id != &""
	queue_redraw()

func set_destination_emphasis(enabled: bool) -> void:
	is_destination = enabled
	queue_redraw()

func resolved_level_style() -> Resource:
	if visualization_config == null:
		return DEFAULT_VISUALIZATION_CONFIG.style_for_level(security_level, level_known and not is_unknown)
	var style: Resource = visualization_config.style_for_level(security_level, level_known and not is_unknown)
	return style if style != null else DEFAULT_VISUALIZATION_CONFIG.style_for_level(security_level, level_known and not is_unknown)

func level_glyph() -> String:
	var style := resolved_level_style()
	if not level_known or is_unknown:
		return String(style.get("label")) if style != null else "L?"
	var configured := String(style.get("label")) if style != null else ""
	return configured if not configured.is_empty() else "L%d" % security_level

func interior_lines() -> PackedStringArray:
	var lines := PackedStringArray([title])
	if level_known and not is_unknown: lines.append(level_glyph())
	if not concise_status.is_empty(): lines.append(concise_status)
	return lines

func _short_node_label(record: Dictionary, identity_known: bool) -> String:
	if not identity_known: return "???"
	var maximum: int = int(visualization_config.node_label_max_characters) if visualization_config != null else 14
	var label := String(record.get("short_id", record.get("display_name", node_id))).to_upper()
	if label.length() > maximum: label = String(record.get("id", node_id)).to_upper()
	if label.length() > maximum: label = label.left(maximum - 1) + "…"
	return label

func capability_definitions() -> Array[Resource]:
	var result: Array[Resource] = []
	if visualization_config == null or visualization_config.capability_catalog == null:
		return result
	for capability: int in capability_types:
		var definition: Resource = visualization_config.capability_catalog.definition_for(capability)
		if definition != null:
			result.append(definition)
	return result

func capability_socket_assignments() -> Array[Dictionary]:
	var assignments: Array[Dictionary] = []
	if visualization_config == null or visualization_config.capability_catalog == null:
		return assignments
	var sorted: Array[int] = visualization_config.capability_catalog.sort_capabilities(displayed_capability_types())
	var occupied: Array[bool] = []
	occupied.resize(12)
	occupied.fill(false)
	var show_uncertain := detail_level != DetailLevel.FAR
	var reserved := (1 if show_uncertain and unknown_content_count > 0 else 0) + (1 if show_uncertain and stale_ice_count > 0 else 0)
	var known_limit := 12 - reserved
	for capability: int in sorted:
		if assignments.size() >= known_limit:
			break
		var definition: Resource = visualization_config.capability_catalog.definition_for(capability)
		if definition == null:
			continue
		var preferred := clampi(int(definition.get("preferred_socket")), 0, 11)
		var socket := _next_available_socket(preferred, occupied)
		if socket < 0:
			break
		occupied[socket] = true
		assignments.append({"kind": &"CAPABILITY", "socket": socket, "capability_type": capability, "count": maxi(1, int(capability_counts.get(capability, 1))), "definition": definition})
	if show_uncertain and unknown_content_count > 0:
		var unknown_socket := _next_available_socket(int(visualization_config.unknown_content_preferred_socket), occupied)
		if unknown_socket >= 0:
			occupied[unknown_socket] = true
			assignments.append({"kind": &"UNKNOWN_CONTENT", "socket": unknown_socket, "count": unknown_content_count})
	if show_uncertain and stale_ice_count > 0:
		var stale_socket := _next_available_socket(3, occupied)
		if stale_socket >= 0:
			assignments.append({"kind": &"STALE_ICE", "socket": stale_socket, "count": stale_ice_count})
	return assignments

func capability_socket_position(socket: int, center: Vector2, radius: float) -> Vector2:
	var normalized_socket := posmod(socket, 12)
	var side: int = normalized_socket / 2
	var first_angle := -PI * 0.5 + TAU * float(side) / 6.0
	var second_angle := -PI * 0.5 + TAU * float(side + 1) / 6.0
	var first := center + Vector2(cos(first_angle), sin(first_angle)) * radius
	var second := center + Vector2(cos(second_angle), sin(second_angle)) * radius
	var along_side := 1.0 / 3.0 if normalized_socket % 2 == 0 else 2.0 / 3.0
	var edge_point := first.lerp(second, along_side)
	var outward := (edge_point - center).normalized()
	var clearance: float = float(visualization_config.capability_socket_border_gap) + float(visualization_config.capability_indicator_radius)
	return edge_point + outward * clearance

func _next_available_socket(preferred: int, occupied: Array[bool]) -> int:
	for offset in 12:
		var candidate := (preferred + offset) % 12
		if not occupied[candidate]:
			return candidate
	return -1

func _process(delta: float) -> void:
	_animation_time += delta
	_pulse = fmod(_pulse + delta * 2.5, TAU)
	_san_arrival_strength = maxf(0.0, _san_arrival_strength - delta * 1.5)
	if _scan_resolution_elapsed >= 0.0:
		_scan_resolution_elapsed += delta
		if _scan_resolution_elapsed >= float(visualization_config.scan_resolution_duration):
			_scan_resolution_elapsed = -1.0
	if (not _reduced_animation and has_state_animation()) or is_destination or _scan_resolution_elapsed >= 0.0 or _san_arrival_strength > 0.0:
		queue_redraw()

func play_san_arrival() -> void:
	_san_arrival_strength = 1.0
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if is_selectable and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			selected.emit(node_id)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			scan_requested.emit(node_id)
			accept_event()

func _draw() -> void:
	var center := size * 0.5
	var radius: float = visualization_config.radius_for_lod(is_current, detail_level) if visualization_config != null else (54.0 if is_current else 42.0)
	var style := resolved_level_style()
	if style == null:
		return
	var fill_color: Color = style.get("fill_color")
	var border_color: Color = style.get("border_color")
	var resolve_progress := _knowledge_resolution_progress()
	if _scan_resolves_level and resolve_progress < 1.0:
		var unknown_style: Resource = visualization_config.style_for_level(0, false)
		fill_color = (unknown_style.get("fill_color") as Color).lerp(fill_color, resolve_progress)
		border_color = (unknown_style.get("border_color") as Color).lerp(border_color, resolve_progress)
	var intensity := float(style.get("intensity"))
	var pulse_amount := float(style.get("pulse_amount"))
	var current_pulse := 0.5
	if not _reduced_animation and is_current:
		current_pulse = (sin(_animation_time * TAU * float(visualization_config.current_pulse_speed)) + 1.0) * 0.5
	var glow_alpha := (0.07 + current_pulse * (0.05 + pulse_amount * 0.08)) * intensity
	draw_circle(center, radius + 12.0, Color(border_color, glow_alpha))
	var points := PackedVector2Array()
	for index in 6:
		var angle := -PI * 0.5 + TAU * float(index) / 6.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, fill_color)
	points.append(points[0])
	draw_polyline(points, border_color, 2.5, true)
	if _hovered and is_selectable:
		_draw_hex_outline(center, radius + 5.0, visualization_config.hover_color, 1.5)
	if is_destination:
		_draw_hex_outline(center, radius + 9.0, visualization_config.selection_color, 2.5)
	if is_current:
		var current_angle := -PI * 0.75 if _reduced_animation else _animation_time * float(visualization_config.current_pulse_speed)
		draw_arc(center, radius + 14.0, current_angle, current_angle + PI * 1.35, 28, Color(visualization_config.current_marker_color, 0.72 + current_pulse * 0.28), 2.0, true)
		var marker := PackedVector2Array([center + Vector2(0, -17), center + Vector2(-10, 4), center + Vector2(10, 4), center + Vector2(0, -17)])
		draw_colored_polygon(marker, visualization_config.current_marker_color)
	if is_resolving_knowledge():
		_draw_scan_acquisition(center, radius, resolve_progress)
	var font := ThemeDB.fallback_font
	var title_size: int = visualization_config.title_font_size if visualization_config != null else 14
	var displayed_title := _scan_previous_title if _scan_resolves_identity and resolve_progress < 0.48 else title
	var title_width := font.get_string_size(displayed_title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	var title_baseline := center.y - 7.0
	if detail_level != DetailLevel.FAR:
		draw_string(font, Vector2(center.x - title_width * 0.5, title_baseline), displayed_title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, border_color)
	var next_baseline := center.y + 13.0
	if detail_level == DetailLevel.FAR: next_baseline = center.y + 4.0
	if level_known and not is_unknown and (not _scan_resolves_level or resolve_progress >= 0.48):
		var glyph := level_glyph()
		var level_size: int = visualization_config.level_font_size
		var glyph_width := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, level_size).x
		draw_string(font, Vector2(center.x - glyph_width * 0.5, next_baseline), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, level_size, Color(border_color, 0.88))
		next_baseline += 14.0
	var displayed_status := _scan_previous_status if _scan_resolves_status and resolve_progress < 0.58 else concise_status
	if detail_level == DetailLevel.CLOSE and not displayed_status.is_empty():
		var status_size: int = visualization_config.status_font_size
		var status_width := font.get_string_size(displayed_status, HORIZONTAL_ALIGNMENT_LEFT, -1, status_size).x
		draw_string(font, Vector2(center.x - status_width * 0.5, next_baseline), displayed_status, HORIZONTAL_ALIGNMENT_LEFT, -1, status_size, Color(border_color, 0.68))
	_draw_capability_indicators(center, radius)
	if is_resolving_knowledge() and resolve_progress > 0.62:
		var highlight_alpha := sin((resolve_progress - 0.62) / 0.38 * PI) * 0.72
		_draw_hex_outline(center, radius + 7.0, Color(visualization_config.scan_discovery_highlight_color, highlight_alpha), 1.8)

func _draw_scan_acquisition(center: Vector2, radius: float, progress: float) -> void:
	# Render-only acquisition sweep: it never changes layout or input bounds.
	var sweep_y := lerpf(center.y - radius * 0.72, center.y + radius * 0.72, smoothstep(0.0, 0.72, progress))
	var half_width := radius * 0.78 * (1.0 - absf(sweep_y - center.y) / maxf(radius, 1.0) * 0.45)
	var sweep_alpha := sin(minf(progress / 0.72, 1.0) * PI) * 0.72
	var sweep_color := Color(visualization_config.scan_sweep_color, sweep_alpha)
	draw_line(Vector2(center.x - half_width, sweep_y), Vector2(center.x + half_width, sweep_y), sweep_color, 2.0, true)
	var phase := int(floor(progress * 24.0))
	for index in 3:
		var direction := -1.0 if (phase + index) % 2 == 0 else 1.0
		var bar_y := sweep_y + float(index - 1) * 5.0
		draw_line(Vector2(center.x + direction * radius * 0.18, bar_y), Vector2(center.x + direction * radius * (0.32 + index * 0.11), bar_y), Color(sweep_color, sweep_alpha * 0.35), 1.0, true)

func _draw_capability_indicators(center: Vector2, radius: float) -> void:
	if (capability_types.is_empty() and unknown_content_count == 0 and stale_ice_count == 0) or visualization_config.capability_catalog == null or visualization_config.capability_icon_theme == null:
		return
	var assignments := capability_socket_assignments()
	if assignments.is_empty():
		return
	var badge_radius: float = visualization_config.capability_indicator_radius
	for assignment: Dictionary in assignments:
		var badge_center: Vector2 = capability_socket_position(int(assignment.socket), center, radius)
		var icon_theme: Resource = visualization_config.capability_icon_theme
		if assignment.kind == &"UNKNOWN_CONTENT":
			_draw_unknown_content_indicator(badge_center, badge_radius, int(assignment.count), icon_theme)
			if int(assignment.socket) == _focused_capability_socket: draw_circle(badge_center, badge_radius + 3.0, icon_theme.uncertainty_color, false, 1.5, true)
			continue
		if assignment.kind == &"STALE_ICE":
			_draw_stale_ice_indicator(badge_center, badge_radius, int(assignment.count), icon_theme)
			if int(assignment.socket) == _focused_capability_socket: draw_circle(badge_center, badge_radius + 3.0, icon_theme.uncertainty_color, false, 1.5, true)
			continue
		var definition: Resource = assignment.definition
		var color: Color = icon_theme.color_for(int(definition.get("palette_role")))
		var capability_type := int(definition.get("capability_type"))
		var reveal_alpha := _capability_reveal_alpha(capability_type)
		color.a *= reveal_alpha
		if reveal_alpha <= 0.01:
			continue
		var is_local_san := local_san_present and int(definition.get("capability_type")) == NodeCapabilityType.Value.SYSTEM_ACCESS_NODE
		if is_local_san:
			var san_wave := 0.5 if _reduced_animation else (sin(_animation_time * TAU * float(visualization_config.san_tether_pulse_speed)) + 1.0) * 0.5
			var pulse_alpha := (0.28 + san_wave * 0.24 + _san_arrival_strength * 0.35) * reveal_alpha
			draw_line(center, badge_center, Color(color, pulse_alpha), 1.25, true)
		draw_circle(badge_center, badge_radius, Color(icon_theme.background_color, icon_theme.background_color.a * reveal_alpha))
		draw_circle(badge_center, badge_radius, color, false, 1.5, true)
		NodeCapabilityIconRenderer.draw_icon(self, int(definition.get("capability_type")), badge_center, badge_radius * 0.68, color, float(icon_theme.line_width))
		if detail_level == DetailLevel.CLOSE and int(assignment.count) > 1:
			_draw_indicator_count(badge_center, badge_radius, int(assignment.count), color)
		if int(assignment.socket) == _focused_capability_socket:
			draw_circle(badge_center, badge_radius + 3.0, color, false, 1.5, true)
		var discovery_progress := _knowledge_resolution_progress()
		if is_resolving_knowledge() and _scan_revealed_capabilities.has(capability_type) and discovery_progress > 0.5:
			var discovery_alpha := sin((discovery_progress - 0.5) * 2.0 * PI) * 0.68
			draw_circle(badge_center, badge_radius + 3.5, Color(visualization_config.scan_discovery_highlight_color, maxf(0.0, discovery_alpha)), false, 1.4, true)
		if is_local_san:
			var san_angle := -PI * 0.5 if _reduced_animation else _animation_time * float(visualization_config.san_tether_pulse_speed)
			draw_arc(badge_center, badge_radius + 3.0 + _san_arrival_strength * 3.0, san_angle, san_angle + PI * 1.4, 18, Color(color, 0.8), 1.25, true)
			draw_circle(badge_center + Vector2(badge_radius * 0.72, -badge_radius * 0.72), 2.2, color)
		_draw_capability_state_effect(capability_type, badge_center, badge_radius, color, reveal_alpha)

func _knowledge_resolution_progress() -> float:
	if _scan_resolution_elapsed < 0.0 or _reduced_animation:
		return 1.0
	return clampf(_scan_resolution_elapsed / maxf(0.001, float(visualization_config.scan_resolution_duration)), 0.0, 1.0)

func _capability_reveal_alpha(capability_type: int) -> float:
	var reveal_index := _scan_revealed_capabilities.find(capability_type)
	if reveal_index < 0 or _scan_resolution_elapsed < 0.0 or _reduced_animation:
		return 1.0
	var start := float(reveal_index) * float(visualization_config.scan_icon_stagger)
	return clampf((_scan_resolution_elapsed - start) / 0.09, 0.0, 1.0)

func _draw_capability_state_effect(capability_type: int, center: Vector2, radius: float, color: Color, alpha: float) -> void:
	var phase := float(abs(hash(node_id))) * 0.00001
	match capability_type:
		NodeCapabilityType.Value.FEED:
			var wave := 0.45 if _reduced_animation else pow(maxf(0.0, sin((_animation_time + phase) * TAU / float(visualization_config.feed_signal_period))), 8.0)
			draw_arc(center, radius + 2.5, -PI * 0.78, -PI * 0.22, 7, Color(color, (0.18 + wave * 0.62) * alpha), 1.2, true)
		NodeCapabilityType.Value.ACTIVE_PROCESS:
			var flicker := 0.35 if _reduced_animation else pow(maxf(0.0, sin((_animation_time + phase) * TAU / float(visualization_config.active_process_flicker_period))), 14.0)
			draw_line(center + Vector2(-radius * 0.45, radius + 2.0), center + Vector2(radius * 0.45, radius + 2.0), Color(color, (0.2 + flicker * 0.7) * alpha), 1.4, true)
		NodeCapabilityType.Value.ICE:
			var hostile := 0.5 if _reduced_animation else (sin((_animation_time + phase) * TAU * float(visualization_config.ice_activity_speed)) + 1.0) * 0.5
			draw_arc(center, radius + 2.5, PI * 0.15, PI * 0.85, 8, Color(color, (0.3 + hostile * 0.45) * alpha), 1.4, true)
		NodeCapabilityType.Value.OBJECTIVE:
			var objective := 0.55 if _reduced_animation else (sin((_animation_time + phase) * TAU * float(visualization_config.objective_pulse_speed)) + 1.0) * 0.5
			draw_circle(center, radius + 3.0, Color(color, (0.38 + objective * 0.35) * alpha), false, 1.2, true)

func _rebuild_capability_socket_controls() -> void:
	for child in get_children():
		if child.get_script() == CAPABILITY_SOCKET: child.free()
	_focused_capability_socket = -1
	if visualization_config == null:
		return
	var center := size * 0.5
	var radius: float = visualization_config.radius_for_lod(is_current, detail_level)
	var hit_size: float = (float(visualization_config.capability_indicator_radius) + 4.0) * 2.0
	for assignment: Dictionary in capability_socket_assignments():
		var capability: int = int(assignment.get("capability_type", -1))
		var tooltip: String
		if assignment.kind == &"UNKNOWN_CONTENT": tooltip = _unknown_content_tooltip(int(assignment.count))
		elif assignment.kind == &"STALE_ICE":
			var stale_count := int(assignment.count)
			tooltip = "ICE SIGNAL // STALE\nLast-known position only%s" % (" ×%d" % stale_count if stale_count > 1 else "")
		else: tooltip = _capability_tooltip(assignment.definition, int(assignment.count))
		var socket_control: Control = CAPABILITY_SOCKET.new() as Control
		add_child(socket_control)
		socket_control.configure(int(assignment.socket), capability, tooltip, hit_size)
		socket_control.position = capability_socket_position(int(assignment.socket), center, radius) - socket_control.size * 0.5
		socket_control.activated.connect(_on_capability_socket_activated)
		socket_control.focus_changed.connect(_on_capability_socket_focus_changed)

func _capability_tooltip(definition: Resource, count: int) -> String:
	var heading := String(definition.get("display_name")).to_upper()
	var description := String(definition.get("tooltip_description"))
	if int(definition.get("capability_type")) == NodeCapabilityType.Value.FEED:
		description = "%d discovered feed%s" % [count, "" if count == 1 else "s"]
	elif count > 1:
		description = "%s ×%d" % [description, count]
	return "%s\n%s" % [heading, description]

func _unknown_content_tooltip(count: int) -> String:
	return "UNKNOWN CONTENT\n%d unidentified signal%s" % [count, "" if count == 1 else "s"]

func _on_capability_socket_activated(capability: int) -> void:
	if capability >= 0:
		capability_selected.emit(node_id, capability)

func _on_capability_socket_focus_changed(socket: int, focused: bool) -> void:
	_focused_capability_socket = socket if focused else -1
	queue_redraw()

func _draw_unknown_content_indicator(center: Vector2, radius: float, count: int, icon_theme: Resource) -> void:
	var color: Color = icon_theme.uncertainty_color
	draw_circle(center, radius, icon_theme.background_color)
	draw_circle(center, radius, color, false, 1.5, true)
	var font := ThemeDB.fallback_font
	var question_size := maxi(9, int(visualization_config.capability_indicator_font_size) + 2)
	var question_width := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, question_size).x
	draw_string(font, center + Vector2(-question_width * 0.5, question_size * 0.36), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, question_size, color)
	if count > 1:
		_draw_indicator_count(center, radius, count, color)

func _draw_stale_ice_indicator(center: Vector2, radius: float, count: int, icon_theme: Resource) -> void:
	var color: Color = icon_theme.uncertainty_color
	draw_circle(center, radius, icon_theme.background_color)
	draw_arc(center, radius, 0.15, PI * 0.8, 8, color, 1.5, true)
	draw_arc(center, radius, PI * 1.15, PI * 1.8, 8, color, 1.5, true)
	NodeCapabilityIconRenderer.draw_icon(self, NodeCapabilityType.Value.ICE, center, radius * 0.62, Color(color, 0.7), 1.2)
	draw_string(ThemeDB.fallback_font, center + Vector2(radius * 0.35, -radius * 0.2), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, color)
	if count > 1: _draw_indicator_count(center, radius, count, color)

func _draw_indicator_count(center: Vector2, radius: float, count: int, color: Color) -> void:
	var count_text := "×%d" % count
	draw_string(ThemeDB.fallback_font, center + Vector2(radius * 0.55, radius * 0.8), count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, color)

func _draw_hex_outline(center: Vector2, radius: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for index in 6:
		var angle := -PI * 0.5 + TAU * float(index) / 6.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	points.append(points[0])
	draw_polyline(points, color, width, true)
