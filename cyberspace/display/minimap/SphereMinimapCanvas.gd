class_name SphereMinimapCanvas
extends Control

const CONFIG := preload("res://cyberspace/display/cyberspace_visualization_config.tres")

var graph: NetworkGraph
var position_model: PlayerNetworkPosition
var knowledge: PlayerKnowledge
var sphere_tracker: CurrentSphereTracker
var canonical_positions: Dictionary = {}
var current_sphere_id: StringName = &""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func set_models(p_graph: NetworkGraph, p_position: PlayerNetworkPosition, p_knowledge: PlayerKnowledge, p_tracker: CurrentSphereTracker = null) -> void:
	graph = p_graph; position_model = p_position; knowledge = p_knowledge; sphere_tracker = p_tracker
	refresh()

func refresh() -> void:
	current_sphere_id = &""
	if graph != null and position_model != null:
		var sphere := graph.get_sphere_for_node(position_model.current_node_id)
		if sphere != null: current_sphere_id = sphere.id
	canonical_positions = SphereMapLayout.positions_for(graph, current_sphere_id)
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

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.004, 0.012, 0.024, 0.96))
	if graph == null or knowledge == null or current_sphere_id == &"": return
	var visible := visible_node_ids()
	var points := {}
	for node_id in visible: points[node_id] = _screen_position(canonical_positions.get(node_id, Vector2(0.5, 0.5)))
	for link: Dictionary in known_internal_links():
		var source: StringName = link.source; var destination: StringName = link.destination
		if _shares_known_sleeve(source, destination): draw_line(points[source], points[destination], Color(0.72, 0.54, 0.29, 0.18), 4.0, true)
		draw_line(points[source], points[destination], Color(0.28, 0.78, 0.88, 0.46), 1.0, true)
	for link: Dictionary in known_exit_links(): _draw_exit(link, visible, points)
	for node_id in visible: _draw_node(node_id, points[node_id])

func _screen_position(normalized: Vector2) -> Vector2:
	var padding := Vector2(24, 24)
	return padding + normalized * (size - padding * 2.0)

func _draw_node(node_id: StringName, center: Vector2) -> void:
	var view := knowledge.get_node_view(node_id)
	var known_level := bool(view.get("level_known", false))
	var style: Resource = CONFIG.style_for_level(int(view.get("security_level", 0)), known_level)
	var radius := 8.0
	var vertices := PackedVector2Array()
	for index in 6:
		var angle := -PI * 0.5 + TAU * float(index) / 6.0
		vertices.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(vertices, style.fill_color)
	vertices.append(vertices[0]); draw_polyline(vertices, style.border_color, 1.4, true)
	if position_model.current_node_id == node_id: draw_circle(center, radius + 4.0, Color.WHITE, false, 1.5, true)
	var capabilities: Array = view.get("capability_types", [])
	if bool(view.get("local_san_present", false)) or capabilities.has(NodeCapabilityType.Value.SYSTEM_ACCESS_NODE):
		draw_line(center, center + Vector2(0, -15), Color("b9c7db"), 1.3, true); draw_circle(center + Vector2(0, -16), 2.2, Color("b9c7db"))
	if capabilities.has(NodeCapabilityType.Value.OBJECTIVE):
		var objective := PackedVector2Array([center + Vector2(12, 0), center + Vector2(16, 4), center + Vector2(12, 8), center + Vector2(8, 4)])
		draw_colored_polygon(objective, Color("d4b766"))
	if capabilities.has(NodeCapabilityType.Value.ICE):
		var ice := PackedVector2Array([center + Vector2(-15, -5), center + Vector2(-10, 0), center + Vector2(-15, 5), center + Vector2(-15, -5)])
		draw_polyline(ice, Color("d05e69"), 1.5, true)
	var label := String(view.get("short_id", view.get("display_name", node_id))).to_upper()
	if label.length() > 10: label = String(node_id).left(10)
	draw_string(ThemeDB.fallback_font, center + Vector2(-20, 20), label, HORIZONTAL_ALIGNMENT_CENTER, 40, 8, Color(0.72, 0.84, 0.87, 0.8))

func _draw_exit(link: Dictionary, visible: Array[StringName], points: Dictionary) -> void:
	var source: StringName = link.source; var destination: StringName = link.destination
	var inside := source if visible.has(source) else destination
	if not points.has(inside): return
	var start: Vector2 = points[inside]
	var direction := (start - size * 0.5).normalized()
	if direction == Vector2.ZERO: direction = Vector2.RIGHT
	var finish := start + direction * 22.0
	draw_line(start, finish, Color("d4b766"), 1.5, true)
	draw_string(ThemeDB.fallback_font, finish + Vector2(-8, -3), "OUT", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("d4b766"))

func _shares_known_sleeve(a: StringName, b: StringName) -> bool:
	for sleeve: Dictionary in knowledge.get_known_security_sleeves():
		var members: Array = sleeve.get("current_members", [])
		if members.has(a) and members.has(b): return true
	return false
