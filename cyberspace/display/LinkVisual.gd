class_name LinkVisual
extends Line2D

signal scan_requested(contact_id: StringName)
signal selected(contact_id: StringName)

const CYAN := Color("48e8ff")
const AMBER := Color("ffc857")

var link_id: StringName = &""
var unknown := false
var highlighted := false
var _phase := 0.0
var normal_width := 2.0
var highlight_width := 5.0
var _base_alpha := 0.72

func configure(p_link_id: StringName, start: Vector2, finish: Vector2, is_unknown: bool = false, config: Resource = null) -> void:
	link_id = p_link_id
	unknown = is_unknown
	normal_width = config.edge_width if config != null else 2.0
	highlight_width = config.highlighted_edge_width if config != null else 5.0
	width = normal_width
	default_color = Color(CYAN, 0.24 if unknown else 0.72)
	var direction := finish - start
	var normal := direction.normalized().orthogonal()
	points = PackedVector2Array([start, start + direction * 0.5 + normal * (config.edge_arc_offset if config != null else 14.0), finish])
	joint_mode = Line2D.LINE_JOINT_ROUND
	begin_cap_mode = Line2D.LINE_CAP_ROUND
	end_cap_mode = Line2D.LINE_CAP_ROUND
	set_process(true)

func set_view_context(zoom: float, visible_node_count: int, config: Resource) -> void:
	var detail_level: int = config.detail_level_for(zoom, visible_node_count)
	var lod_width_scale := 1.0 if detail_level == 0 else (0.78 if detail_level == 1 else 0.58)
	var lod_alpha := 1.0 if detail_level == 0 else (0.74 if detail_level == 1 else 0.48)
	normal_width = maxf(0.8, float(config.edge_width) * lod_width_scale)
	_base_alpha = (0.24 if unknown else 0.72) * lod_alpha
	width = highlight_width if highlighted else normal_width
	default_color = AMBER if highlighted else Color(CYAN, _base_alpha)

func set_highlighted(enabled: bool) -> void:
	highlighted = enabled
	width = highlight_width if enabled else normal_width
	default_color = AMBER if enabled else Color(CYAN, _base_alpha)

func _process(delta: float) -> void:
	_phase = fmod(_phase + delta * 4.0, TAU)
	if highlighted:
		default_color = Color(AMBER, 0.72 + sin(_phase) * 0.22)

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed or event.button_index not in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		return
	for index in range(points.size() - 1):
		var start := global_transform * points[index]
		var finish := global_transform * points[index + 1]
		if event.position.distance_to(Geometry2D.get_closest_point_to_segment(event.position, start, finish)) <= 10.0:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				scan_requested.emit(link_id)
			else:
				selected.emit(link_id)
			get_viewport().set_input_as_handled()
			return
