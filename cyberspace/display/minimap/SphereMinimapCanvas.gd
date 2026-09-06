class_name SphereMinimapCanvas
extends Control

signal node_focus_requested(node_id: StringName)
signal node_inspection_hint_changed(node_id: StringName, text: String, visible: bool)

const CONFIG := preload("res://cyberspace/display/cyberspace_visualization_config.tres")
const MINIMAP_NODE_SCENE := preload("res://cyberspace/display/minimap/SphereMinimapNode.tscn")

var graph: NetworkGraph
var position_model: PlayerNetworkPosition
var knowledge: PlayerKnowledge
var sphere_tracker: CurrentSphereTracker
var trail_system: HackerTrailSystem
var local_actor_id: StringName = &"PLAYER"
var intrusion_id: StringName = &""
var trail_tick_provider: Callable
var own_trail_visible := bool(CONFIG.minimap_show_own_trail)
var security_sleeves_visible := bool(CONFIG.minimap_show_security_sleeves)
var minimap_zoom := 1.0
var pan_offset := Vector2.ZERO
var _panning := false
var canonical_positions: Dictionary = {}
var current_sphere_id: StringName = &""
var node_visuals: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(_rebuild_node_visuals)

func set_models(p_graph: NetworkGraph, p_position: PlayerNetworkPosition, p_knowledge: PlayerKnowledge, p_tracker: CurrentSphereTracker = null) -> void:
	if knowledge != null and knowledge.knowledge_changed.is_connected(refresh): knowledge.knowledge_changed.disconnect(refresh)
	if position_model != null and position_model.position_changed.is_connected(_on_position_changed): position_model.position_changed.disconnect(_on_position_changed)
	graph = p_graph; position_model = p_position; knowledge = p_knowledge; sphere_tracker = p_tracker
	if knowledge != null: knowledge.knowledge_changed.connect(refresh)
	if position_model != null: position_model.position_changed.connect(_on_position_changed)
	refresh()

func set_trail_source(p_trail_system: HackerTrailSystem, p_actor_id: StringName, p_intrusion_id: StringName, p_tick_provider: Callable = Callable()) -> void:
	if trail_system != null and trail_system.trails_changed.is_connected(_on_trails_changed): trail_system.trails_changed.disconnect(_on_trails_changed)
	trail_system = p_trail_system
	local_actor_id = p_actor_id
	intrusion_id = p_intrusion_id
	trail_tick_provider = p_tick_provider
	if trail_system != null: trail_system.trails_changed.connect(_on_trails_changed)
	queue_redraw()

func set_own_trail_visible(visible: bool) -> void:
	own_trail_visible = visible
	queue_redraw()

func set_security_sleeves_visible(visible: bool) -> void:
	security_sleeves_visible = visible
	queue_redraw()

func _on_trails_changed() -> void:
	queue_redraw()

func _on_position_changed(_from: StringName, _to: StringName, _link: StringName) -> void:
	refresh()

func refresh() -> void:
	var previous_sphere_id := current_sphere_id
	current_sphere_id = &""
	if graph != null and position_model != null:
		var sphere := graph.get_sphere_for_node(position_model.current_node_id)
		if sphere != null: current_sphere_id = sphere.id
	if previous_sphere_id != &"" and previous_sphere_id != current_sphere_id:
		minimap_zoom = 1.0
		pan_offset = Vector2.ZERO
	canonical_positions = SphereMapLayout.positions_for_known(visible_node_ids())
	_rebuild_node_visuals()
	queue_redraw()

func visible_node_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	if graph == null or knowledge == null: return result
	for node_id in graph.get_nodes_in_sphere(current_sphere_id):
		if knowledge.player_knows_node_exists(node_id) or (position_model != null and position_model.current_node_id == node_id): result.append(node_id)
	result.sort()
	return result

func known_internal_links() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var visible := visible_node_ids()
	if knowledge == null: return result
	for record: Dictionary in knowledge.link_records.values():
		if int(record.get("level", KnowledgeLevel.Value.UNKNOWN)) < KnowledgeLevel.Value.IDENTIFIED: continue
		var source: StringName = record.get("source", &"")
		var destination: StringName = record.get("destination", &"")
		if visible.has(source) and visible.has(destination): result.append(record.duplicate(true))
	return result

func known_exit_links() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var visible := visible_node_ids()
	if knowledge == null: return result
	for record: Dictionary in knowledge.link_records.values():
		if int(record.get("level", KnowledgeLevel.Value.UNKNOWN)) < KnowledgeLevel.Value.IDENTIFIED: continue
		var source: StringName = record.get("source", &"")
		var destination: StringName = record.get("destination", &"")
		if visible.has(source) != visible.has(destination):
			var inside := source if visible.has(source) else destination
			if graph.get_sphere_for_node(inside) != null and graph.get_sphere_for_node(inside).id == current_sphere_id: result.append(record.duplicate(true))
	return result

func external_connection_markers() -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	var visible := visible_node_ids()
	for link: Dictionary in known_exit_links():
		var source: StringName = link.get("source", &"")
		var destination: StringName = link.get("destination", &"")
		var inside_node_id := source if visible.has(source) else destination
		var outside_node_id := destination if inside_node_id == source else source
		var outside_sphere := graph.get_sphere_for_node(outside_node_id)
		var sphere_known := outside_sphere != null and knowledge.knows_sphere_identity(outside_sphere.id)
		var sphere_view := knowledge.get_sphere_view(outside_sphere.id) if sphere_known else {}
		markers.append({
			"link_id": link.get("id", &""),
			"inside_node_id": inside_node_id,
			"destination_known": sphere_known,
			"destination_sphere_id": sphere_view.get("id", &"") if sphere_known else &"",
			"destination_label": String(sphere_view.get("display_name", outside_sphere.id)).to_upper() if sphere_known else "UNKNOWN NETWORK REGION",
		})
	markers.sort_custom(func(a: Dictionary, b: Dictionary):
		var host_order := String(a.inside_node_id).naturalnocasecmp_to(String(b.inside_node_id))
		return String(a.link_id) < String(b.link_id) if host_order == 0 else host_order < 0)
	var host_counts := {}
	for marker in markers: host_counts[marker.inside_node_id] = int(host_counts.get(marker.inside_node_id, 0)) + 1
	var host_indices := {}
	for marker in markers:
		marker["host_exit_index"] = int(host_indices.get(marker.inside_node_id, 0))
		marker["host_exit_count"] = int(host_counts[marker.inside_node_id])
		host_indices[marker.inside_node_id] = int(marker.host_exit_index) + 1
	return markers

func known_current_sleeve_groups() -> Dictionary:
	var result := {}
	if knowledge == null: return result
	var visible := visible_node_ids()
	for sleeve: Dictionary in knowledge.get_known_security_sleeves():
		if int(sleeve.get("state", SecuritySleeve.State.INTACT)) == SecuritySleeve.State.DISABLED: continue
		var members: Array[StringName] = []
		for node_id in sleeve.get("current_members", []):
			if visible.has(node_id): members.append(node_id)
		if not members.is_empty(): result[sleeve.get("id", &"")] = members
	return result

func security_sleeve_overlay_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	if not security_sleeves_visible: return records
	var visible := visible_node_ids()
	for sleeve: Dictionary in knowledge.get_known_security_sleeves():
		var state := int(sleeve.get("state", SecuritySleeve.State.INTACT))
		if state == SecuritySleeve.State.DISABLED: continue
		var sleeve_id: StringName = sleeve.get("id", &"")
		var members: Array[StringName] = []
		for node_id in sleeve.get("current_members", []):
			if visible.has(node_id): members.append(node_id)
		if members.is_empty(): continue
		var shared_links: Array[StringName] = []
		for link: Dictionary in known_internal_links():
			if members.has(link.source) and members.has(link.destination): shared_links.append(link.get("id", &""))
		records.append({"sleeve_id": sleeve_id, "state": state, "node_ids": members, "link_ids": shared_links})
	records.sort_custom(func(a: Dictionary, b: Dictionary): return String(a.sleeve_id) < String(b.sleeve_id))
	return records

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.004, 0.012, 0.024, 0.96))
	if graph == null or knowledge == null or current_sphere_id == &"": return
	var visible := visible_node_ids()
	var points := {}
	for node_id in visible: points[node_id] = _screen_position(canonical_positions.get(node_id, Vector2(0.5, 0.5)))
	for link: Dictionary in known_internal_links():
		var source: StringName = link.source; var destination: StringName = link.destination
		var sleeve_state := _known_shared_sleeve_state(source, destination)
		if security_sleeves_visible and sleeve_state >= 0:
			var sleeve_color := Color(CONFIG.minimap_sleeve_color, float(CONFIG.minimap_sleeve_edge_alpha) * _sleeve_state_alpha(sleeve_state))
			if sleeve_state == SecuritySleeve.State.INTACT:
				draw_line(points[source], points[destination], sleeve_color, float(CONFIG.minimap_sleeve_edge_width), true)
			else:
				draw_dashed_line(points[source], points[destination], sleeve_color, float(CONFIG.minimap_sleeve_edge_width), 4.0, true, true)
		draw_line(points[source], points[destination], Color(0.28, 0.78, 0.88, 0.46), 1.0, true)
		_draw_dynamic_link_information(link.get("id", &""), points[source], points[destination])
	_draw_visible_trails(points)
	for marker: Dictionary in external_connection_markers(): _draw_exit_marker(marker, points)
	if security_sleeves_visible:
		for node_id in visible:
			var sleeve_state := _known_node_sleeve_state(node_id)
			if sleeve_state >= 0:
				draw_arc(points[node_id], 11.0, -PI * 0.85, PI * 0.35, 12, Color(CONFIG.minimap_sleeve_color, float(CONFIG.minimap_sleeve_boundary_alpha) * _sleeve_state_alpha(sleeve_state)), float(CONFIG.minimap_sleeve_boundary_width), true)

func _screen_position(normalized: Vector2) -> Vector2:
	var base := _base_screen_position(normalized)
	return size * 0.5 + (base - size * 0.5) * minimap_zoom + pan_offset

func _base_screen_position(normalized: Vector2) -> Vector2:
	var padding := Vector2(24, 24)
	return padding + normalized * (size - padding * 2.0)

func detail_level_for_current_view() -> int:
	var count := visible_node_ids().size()
	if count <= int(CONFIG.minimap_close_node_limit) or minimap_zoom >= float(CONFIG.minimap_close_inspection_zoom): return SphereMinimapNode.DetailLevel.CLOSE
	if count <= int(CONFIG.minimap_medium_node_limit) or minimap_zoom >= float(CONFIG.minimap_medium_inspection_zoom): return SphereMinimapNode.DetailLevel.MEDIUM
	return SphereMinimapNode.DetailLevel.DENSE

func set_minimap_zoom(value: float) -> void:
	var next := clampf(value, float(CONFIG.minimap_min_zoom), float(CONFIG.minimap_max_zoom))
	if is_equal_approx(next, minimap_zoom): return
	minimap_zoom = next
	_rebuild_node_visuals()
	queue_redraw()

func center_on_node(node_id: StringName) -> bool:
	if not canonical_positions.has(node_id): return false
	var base := _base_screen_position(canonical_positions[node_id])
	pan_offset = -(base - size * 0.5) * minimap_zoom
	_rebuild_node_visuals()
	queue_redraw()
	return true

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			set_minimap_zoom(minimap_zoom + float(CONFIG.minimap_zoom_step)); accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			set_minimap_zoom(minimap_zoom - float(CONFIG.minimap_zoom_step)); accept_event()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed; accept_event()
	elif event is InputEventMouseMotion and _panning:
		pan_offset += event.relative
		_rebuild_node_visuals()
		queue_redraw()
		accept_event()

func _rebuild_node_visuals() -> void:
	for child in get_children():
		if child is SphereMinimapNode: child.free()
	node_visuals.clear()
	if graph == null or knowledge == null or size.x <= 1.0: return
	var exit_nodes: Array[StringName] = []
	var visible := visible_node_ids()
	var detail_level := detail_level_for_current_view()
	for link: Dictionary in known_exit_links():
		var source: StringName = link.source; var destination: StringName = link.destination
		var inside := source if visible.has(source) else destination
		if not exit_nodes.has(inside): exit_nodes.append(inside)
	for node_id in visible:
		var visual := MINIMAP_NODE_SCENE.instantiate() as SphereMinimapNode
		add_child(visual)
		var view := knowledge.get_node_view(node_id)
		visual.configure(node_id, view, position_model.current_node_id == node_id, exit_nodes.has(node_id), bool(view.get("critical_alert", false)), CONFIG, detail_level, _node_has_immediate_threat(node_id, view))
		visual.position = _screen_position(canonical_positions.get(node_id, Vector2(0.5, 0.5))) - visual.node_center()
		visual.focus_requested.connect(request_focus_node)
		visual.inspection_hint_changed.connect(_on_node_inspection_hint_changed)
		node_visuals[node_id] = visual

func minimap_node_for(node_id: StringName) -> SphereMinimapNode:
	return node_visuals.get(node_id) as SphereMinimapNode

func request_focus_node(node_id: StringName) -> bool:
	if knowledge == null or not visible_node_ids().has(node_id): return false
	node_focus_requested.emit(node_id)
	return true

func focus_current_player() -> bool:
	if position_model == null: return false
	center_on_node(position_model.current_node_id)
	return request_focus_node(position_model.current_node_id)

func _on_node_inspection_hint_changed(node_id: StringName, text: String, visible: bool) -> void:
	node_inspection_hint_changed.emit(node_id, text, visible)

func visible_trail_segments() -> Array[TrailSegment]:
	if trail_system == null or intrusion_id == &"": return []
	var tick := int(trail_tick_provider.call()) if trail_tick_provider.is_valid() else 0
	var candidates := trail_system.visible_trails_for(local_actor_id, intrusion_id, visible_node_ids(), tick, own_trail_visible)
	if bool(CONFIG.minimap_show_detected_enemy_trails): return candidates
	return candidates.filter(func(segment: TrailSegment): return segment.owner_actor_id == local_actor_id)

func trail_alpha_for(segment: TrailSegment) -> float:
	if segment == null: return 0.0
	var tick := int(trail_tick_provider.call()) if trail_tick_provider.is_valid() else 0
	return lerpf(float(CONFIG.minimap_trail_min_alpha), float(CONFIG.minimap_trail_max_alpha), segment.strength_at_tick(tick))

func _draw_visible_trails(points: Dictionary) -> void:
	var known_pairs := {}
	for link: Dictionary in known_internal_links():
		known_pairs[_node_pair_key(link.source, link.destination)] = true
	for segment in visible_trail_segments():
		if not points.has(segment.from_node_id) or not points.has(segment.to_node_id): continue
		if not known_pairs.has(_node_pair_key(segment.from_node_id, segment.to_node_id)): continue
		var base: Color = CONFIG.minimap_own_trail_color if segment.owner_actor_id == local_actor_id else CONFIG.minimap_enemy_trail_color
		draw_dashed_line(points[segment.from_node_id], points[segment.to_node_id], Color(base, trail_alpha_for(segment)), float(CONFIG.minimap_trail_width), float(CONFIG.minimap_trail_dash_length), true, true)

func dynamic_link_freshness(link_id: StringName) -> StringName:
	if knowledge == null: return &"UNKNOWN"
	var observations := knowledge.get_dynamic_link_information(link_id)
	if observations.any(func(record): return record.freshness == &"CURRENT"): return &"CURRENT"
	if observations.any(func(record): return record.freshness == &"STALE"): return &"STALE"
	return &"UNKNOWN"

func _draw_dynamic_link_information(link_id: StringName, start: Vector2, finish: Vector2) -> void:
	var freshness := dynamic_link_freshness(link_id)
	if freshness == &"UNKNOWN": return
	var base: Color = CONFIG.minimap_dynamic_current_color if freshness == &"CURRENT" else CONFIG.minimap_stale_color
	var alpha := 0.52 if freshness == &"CURRENT" else 0.24
	draw_dashed_line(start, finish, Color(base, alpha), 1.6 if freshness == &"CURRENT" else 1.0, 3.0, true, true)

func _node_pair_key(a: StringName, b: StringName) -> String:
	var first := String(a); var second := String(b)
	return "%s|%s" % [first, second] if first < second else "%s|%s" % [second, first]

func _draw_exit_marker(marker: Dictionary, points: Dictionary) -> void:
	var inside: StringName = marker.inside_node_id
	if not points.has(inside): return
	var node_center: Vector2 = points[inside]
	var direction := (node_center - size * 0.5).normalized()
	if direction == Vector2.ZERO: direction = Vector2.RIGHT
	var perpendicular := Vector2(-direction.y, direction.x)
	var fan_offset := (float(marker.host_exit_index) - (float(marker.host_exit_count) - 1.0) * 0.5) * float(CONFIG.minimap_exit_fan_spacing)
	var start := node_center + direction * 8.0
	var finish := node_center + direction * float(CONFIG.minimap_exit_length) + perpendicular * fan_offset
	var color: Color = CONFIG.minimap_exit_color if bool(marker.destination_known) else CONFIG.minimap_unknown_exit_color
	draw_line(start, finish, Color(color, 0.78), 1.4, true)
	var arrow_side := perpendicular * 2.8
	draw_colored_polygon(PackedVector2Array([finish + direction * 3.5, finish - direction * 2.5 + arrow_side, finish - direction * 2.5 - arrow_side]), color)
	var label := "→ %s" % String(marker.destination_label)
	var label_width := 116.0
	var label_origin := finish + direction * 5.0 + Vector2(-label_width * 0.5, 3.0)
	draw_string(ThemeDB.fallback_font, label_origin, label, HORIZONTAL_ALIGNMENT_CENTER, label_width, 7, Color(color, 0.9))

func _draw_exit(link: Dictionary, visible: Array[StringName], points: Dictionary) -> void:
	# Compatibility wrapper for callers predating structured boundary markers.
	var source: StringName = link.source; var destination: StringName = link.destination
	var inside := source if visible.has(source) else destination
	var marker := {"inside_node_id": inside, "destination_known": false, "destination_label": "UNKNOWN NETWORK REGION", "host_exit_index": 0, "host_exit_count": 1}
	_draw_exit_marker(marker, points)

func _known_shared_sleeve_state(a: StringName, b: StringName) -> int:
	for sleeve: Dictionary in knowledge.get_known_security_sleeves():
		var state := int(sleeve.get("state", SecuritySleeve.State.INTACT))
		if state == SecuritySleeve.State.DISABLED: continue
		var members: Array = sleeve.get("current_members", [])
		if members.has(a) and members.has(b): return state
	return -1

func _shares_known_sleeve(a: StringName, b: StringName) -> bool:
	return _known_shared_sleeve_state(a, b) >= 0

func _known_node_sleeve_state(node_id: StringName) -> int:
	for sleeve: Dictionary in knowledge.get_known_security_sleeves():
		var state := int(sleeve.get("state", SecuritySleeve.State.INTACT))
		if state != SecuritySleeve.State.DISABLED and sleeve.get("current_members", []).has(node_id): return state
	return -1

func _sleeve_state_alpha(state: int) -> float:
	return 1.0 if state == SecuritySleeve.State.INTACT else 0.52

func _node_has_known_current_sleeve(node_id: StringName) -> bool:
	for members: Array[StringName] in known_current_sleeve_groups().values():
		if members.has(node_id): return true
	return false

func _node_has_immediate_threat(node_id: StringName, view: Dictionary) -> bool:
	if bool(view.get("critical_alert", false)): return true
	for record: Dictionary in knowledge.ice_records.values():
		if record.get("node_id", &"") != node_id: continue
		if int(record.get("level", KnowledgeLevel.Value.UNKNOWN)) < KnowledgeLevel.Value.IDENTIFIED: continue
		if int(record.get("state", IceState.Value.DORMANT)) >= IceState.Value.HUNT: return true
	return false
